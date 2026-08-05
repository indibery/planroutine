---
name: deploy
description: 공직플랜 배포 — iOS는 게이트 검사(analyze/test) 후 fastlane.sh 실행(TestFlight/App Store), green이면 승인 없이 바로 진행. Android는 게이트(analyze/test + release AAB 스모크) 후 `./android/bin/fastlane.sh <레인>` 실행 — 비공개 테스트는 `beta`(트랙 `Alpha`), 첫 업로드는 `bootstrap`(트랙 `internal`·draft). "배포", "release", "beta", "fastlane 올려줘", "안드로이드/Play Store 배포" 요청 시 사용.
---

# 공직플랜 배포 런북

fastlane 3개 레인(`ios beta`/`ios release`/`ios check_builds`)을
**게이트 → 실행 → post-deploy** 순서로 돌린다. 기본 레인은 `ios beta`.

실행은 항상 wrapper로 한다 — `./ios/bin/fastlane.sh`가 Homebrew Ruby를 PATH 앞에
주입하고 최초 1회 `bundle install`을 끼운다. 맨 `fastlane`을 직접 부르지 않는다.

**워크플로우**: `게이트 → beta(업로드·실기기 검증, 반복) → release(promote·자동 제출, 한 번)`.
release는 **바이너리를 새로 빌드/업로드하지 않고**, beta로 올려 검증한 **최신 TestFlight
빌드를 승격(promote)**하고 심사 자동 제출 + 승인 시 자동 공개한다.

> **beta 레인**은 시작 시 `reset_ios_caches`(flutter clean + Pods/build 제거)를 자동
> 실행해 시뮬 슬라이스 함정(#6)을 막는다. 이어지는 `flutter build ipa`가 pub get +
> pod install을 재수행한다. clean 때문에 매 beta가 수 분 더 걸린다. **release는 빌드가
> 없어**(promote 전용) 빠르고, 업로드 중단(kill) 함정에서도 자유롭다.

## 1) PRE-FLIGHT 게이트 (GO/NO-GO)

순서대로 실행하고, 하나라도 실패하면 **NO-GO** — 원인을 리포트하고 중단한다.

```bash
flutter analyze            # 이슈 0건이어야 GO
flutter test               # 유닛/위젯 전수 통과 (단일 실행, flaky 반복 아님)
```

> **cold-start 주의**: `flutter clean` 직후 또는 오래 쉰 뒤 첫 `flutter test`는
> cold 컴파일로 수 분간 멈춘 듯 보일 수 있다(per-test 타임아웃도 안 먹음). 죽은 게
> 아니라 cold 빌드 중 → 한 번 warm-up 후 진행.

> **[필수] 시뮬레이터 런타임 확인** — analyze/test/컴파일만으론 부족. UI·동작 변경이면
> 배포 전 **시뮬에서 실제 동작을 태운다**: `integration_test/`로 앱 구동해 탭까지(플러그인
> 채널 실호출) 검증, 또는 앱을 띄워 직접 상호작용, 또는 최소한 그 동작을 태우는 테스트(예:
> 플랫폼 채널 mock으로 탭→호출 인자 확인). 위젯 테스트의 "위젯 존재" 검증 ≠ "탭하면 동작"
> 검증. GUI를 직접 못 밟는 경로는 **"미검증" 명시** 후 실기기 확인을 사용자에게 넘긴다.
> (교훈: v80 'AI로 보내기'가 iPad에서 share sharePositionOrigin 누락으로 미동작 — 위젯
> 존재만 보고 탭 동작을 안 봐서 놓침. [[feedback-simulator-before-deploy]])
>
> **디바이스: iPhone 시뮬레이터 기준** — 공직플랜은 iPhone 전용 감각의 앱. 이미 부팅된
> iPad가 있어도 그걸로 때우지 말고 **iPhone 시뮬로 검증**한다(예: iPhone 17
> `7FF7798F-1FC4-4DBF-80D8-FB8DD2611663`). iPad는 share 팝오버 등 iPad 고유 케이스를
> 볼 때만 보조로.

**버전/빌드번호:**
- build number는 Fastfile이 `latest_testflight_build_number + 1`로 자동 계산.
- **versionString(X.Y.Z)**: beta/release 레인이 시작 시 `assert_version_bumped`로
  App Store *승인본*과 비교해, pubspec 버전이 승인본 이하이면 **clean 빌드 전에 자동
  NO-GO**로 중단한다(함정 #5 선제 차단). 걸리면 안내대로 `pubspec.yaml`의 versionString을
  올려 재실행. 버전 자동 증가는 하지 않는다 — 증가폭(patch/minor/major)은 사람 판단이라
  pubspec을 직접 수정한다(레인에 bump 옵션 없음).

## 2) 실행 (승인 정책)

**beta는 게이트 GO이면 사용자 승인 없이 바로 실행**하고 push까지 진행. 배포 실패 시에만
멈춰서 리포트한다.

**release는 제출하지 않는다** — 승격·릴리즈 노트·스크린샷까지 준비하고 멈춘다.
최종 '심사를 위해 제출'은 사용자가 ASC에서 누른다. `submit:true`를 사용자가 명시적으로
요청했을 때만 자동 제출한다.

⚠️ **예외: 한 번 제출했다가 `withdraw_review`로 내린 버전**(DEVELOPER_REJECTED)에
빌드를 다시 연결하면 **ASC가 이전 제출을 복원해 스스로 WAITING_FOR_REVIEW가 된다**(실측).
그래서 release는 마지막에 **실제 상태를 다시 읽어** 보고한다 — 의도가 아니라 결과를 말한다.
처음 만든 버전(PREPARE_FOR_SUBMISSION)에서는 제출되지 않는다.

**스토어 문구도 release가 맞춘다** — 리포가 단일 출처다.
- 설명: `docs/app_store_description.md`의 ```text 블록 → 버전 로컬라이제이션 `description`
- 심사 메모: `docs/app_review_notes.md`의 ```text 블록 → App Review Information `notes`
- 릴리즈 노트: `docs/release_notes/<버전>.ko.txt` → `whats_new`
ASC에서 직접 고친 내용은 덮어써진다. 그래야 "코드에서 기능을 뺐는데 스토어 설명은 그대로"인
어긋남이 안 생긴다. `asc_state`가 리포와 다른지 미리 보여준다.
⚠️ **Apple이 설명에서 거부하는 문자가 있다** — `★`를 넣었더니 반려됐다(실측:
`Description can't contain the following character(s): ★`). 특수기호는 글로 풀어 쓸 것.
⚠️ ```text 블록 형식이 깨지면 release가 중단된다(길이·마크다운 혼입 검증).

**스크린샷은 release에 포함된다** (`shots:false`로 건너뛸 수 있음).
`overwrite_screenshots: true`가 실제로는 기존 것을 지우지 않아 업로드분이 중복으로 쌓인다
(실측: 10장 올렸는데 20장). 그래서 release가 업로드 직후 `dedupe_screenshots!`로
파일명 중복을 정리한다 — 이 단계가 빠지면 스토어에 같은 화면이 두 번 보인다.

⚠️ **`dedupe_screenshots!`는 함수이고 레인이 아니다.** `release`가 부르는
Fastfile 내부 함수다(`Fastfile:517`) — 명령줄에서 부를 수 없다. 스크린샷을 올리는
**유일한 경로는 `release`**이고, 확인 수단은 `asc_state`뿐이며 **장수만** 알려준다.

```bash
./ios/bin/fastlane.sh beta                  # TestFlight 업로드 (재빌드 O)
./ios/bin/fastlane.sh release build:115     # 승격 + 노트·설명·스크린샷 반영 (제출은 안 함 ← 기본)
./ios/bin/fastlane.sh release submit:true   # 제출까지 자동 (명시해야만)
./ios/bin/fastlane.sh release build:115 shots:false   # 스크린샷만 건너뛰고 승격
./ios/bin/fastlane.sh withdraw_review       # 심사 철회 (편집 가능 상태로)
```

**iOS 레인은 일곱 개다** — `load_asc_api_key`·`check_tago_key`·`beta`·`release`·
`withdraw_review`·`asc_state`·`check_builds`. 이 목록에 없는 이름을 부르면
`Could not find lane`으로 끝난다(실측 2026-08-06: 이 문서가 적어둔
`check_screenshots`를 불러 헛돌았다).

- **release는 재빌드/재업로드가 없다** — `skip_binary_upload: true`로 승격만 한다.
  그래서 빠르고 업로드 중단 함정과 무관.
- ⚠️ **빌드 연결은 deliver가 안 해준다(실측 v124).** deliver는 `build_number`를 받아도
  **제출 흐름 안에서만** 빌드를 고른다 — `submit_for_review: false`(= 이 레인의 기본값)면
  그 단계를 통째로 건너뛴다. 로그에는 `build_number | 124`가 찍히고 deliver도 성공으로
  끝나는데 편집 버전의 선택된 빌드는 **옛것 그대로** 남는다. 그래서 레인이
  `select_build`로 직접 붙이고 `빌드 연결: vNN`을 찍는다. **그 줄이 없으면 승격이 안 된 것**
  — `asc_state`의 `선택된 빌드`로 교차 확인할 것(fastlane exit 0은 근거가 아니다).
- ⚠️ **승격 대상 기본값은 "최신"이다.** 실기기 검증을 끝낸 뒤 `beta`를 한 번 더 돌리면
  release가 **검증하지 않은 빌드**를 심사에 올린다. 검증한 빌드가 최신이 아닐 수 있으면
  `release build:<N>`으로 못박을 것. (기본값도 편집 버전 train으로 한정된다)
- **수동 제출 흐름을 섞지 말 것** — ASC에서 직접 제출할 거면 release를 아예 돌리지 않거나
  `release submit:false`로 빌드만 연결한다. 섞으면 가드 D가 막는다(그게 막으라고 있는 가드).
- release는 `submit_for_review: true` + `automatic_release: true`라 **실행 즉시 Apple 심사행
  → 승인 시 자동 공개**된다. 되돌리기 어려운 외부 작업이므로, **실기기 검증이 끝난 뒤에만**
  실행한다. 알림·UI 동작처럼 시뮬에서 못 밟는 변경이 있었으면 사용자 실기기 확인을 먼저 받는다.
- 암호화/IDFA 심사 질문은 `submission_information`이 자동 응답(둘 다 false).

beta의 IPA 파일명이 한글(`공직플랜.ipa`)이라 Fastfile은 `Dir.entries`로 직접 순회해 찾는다
— glob 깨짐 걱정 없음. (release는 빌드가 없어 해당 없음.)

## 3) POST-DEPLOY

```bash
./ios/bin/fastlane.sh asc_state      # 심사 단계 + 선택된 빌드 + 스크린샷 장수 (진단 1순위)
                                     #   PREPARE_FOR_SUBMISSION → 제출 가능
                                     #   WAITING_FOR_REVIEW/IN_REVIEW → 손대지 말 것
./ios/bin/fastlane.sh check_builds   # 최근 5개 빌드 processing_state 조회
```
- `processing_state`가 VALID면 정상. PROCESSING이면 잠시 후 재조회.
- `asc_state`는 **설명·심사 메모가 리포와 일치하는지**까지 보여준다. 승격 직후
  `빌드 연결: vNN`을 봤더라도 여기서 `선택된 빌드`를 교차 확인할 것.
- **스크린샷은 장수만 나온다**(`ko / APP_IPHONE_65 6장`). 파일명·순서·어느 장이
  빠졌는지는 **로컬에서 알 수 없다** — ASC 웹에서 직접 봐야 한다.
  ⚠️ 실측(2026-08-06): release 직후 `65 6장 / 67 6장`이 제출 뒤 `65 5장 / 67 6장`이
  됐다. 슬롯마다 장수가 달라도 Apple은 받으므로, 고치려고 `withdraw_review`를
  돌려 대기열 처음으로 가는 대신 **다음 릴리스에서 맞추는 편이 값싸다.**
- **TestFlight 앱에 새 빌드가 안 보이면** pull-to-refresh로는 갱신 안 된다.
  **앱 강제종료 후 재실행**하면 즉시 표시된다.

## 트러블슈팅 (레인 실패 시)

- **버전 페이지 자동 생성**: ASC에 그 버전 페이지가 없으면 `ensure_edit_version`이
  `app.ensure_version!`로 만든다. **minor/major를 올릴 때는 항상 없다**(patch는 기존
  페이지가 남아 통과). 자동화 전에는 여기서 fastlane 2.233.0이 `sync_app_previews`의
  `NoMethodError: get_app_store_version_localizations for nil`로 죽어 원인을 못 읽었다.
- **스크린샷**: `ios/fastlane/screenshots/ko/`에 두면 **`release`가** 올린다(전용 레인은 없다).
  deliver가 **이미지 크기로** 기기 슬롯을 판단하므로 파일명에 규격을 붙여 두 세트를
  함께 둔다(`6.5_*.png` = 1284x2778, `6.9_*.png` = 1320x2868). **파일명 순서 = 노출 순서.**
  원본은 `docs/screenshots/appstore/{6.5,6.9}/`, 촬영은 `screenshot_test.dart`.
  ⚠️ **심사 대기/진행 중에는 가드 D가 막는다** — 스크린샷을 갈아치우면 심사가 되돌려질 수
  있다. 다음 버전 준비 때 올리거나, ASC에서 '심사에서 제거' 후 올릴 것(대기열 처음으로).
- **가드 E (릴리즈 노트 없음)**: `docs/release_notes/<버전>.ko.txt`가 없으면 중단.
  Apple이 "이번 버전의 새로운 기능"을 업데이트 심사에 필수로 요구하므로 비어 있으면
  어차피 제출이 막힌다. **버전을 올리면 이 파일을 먼저 만든다.**
  release가 이 파일을 읽어 ASC에 자동 입력한다(스토어 문구도 git 리뷰 대상이 된다).
- **가드 D (이미 심사 단계)**: 편집 버전 상태가 `PREPARE_FOR_SUBMISSION`/`*_REJECTED`가
  아니면 중단. `submit_for_review`로 제출된 버전을 다시 건드리면 **진행 중인 심사가
  되돌려진다**. 수동 제출 후 실수로 release를 돌리는 사고를 막는다.
  이미 제출됐으면 아무것도 하지 말 것.
- **가드 A (#5 higher version 거부)**: beta/release 진입 시 `assert_version_bumped`가
  pubspec versionString을 App Store 승인본과 비교해 이하이면 즉시 중단. 걸리면 안내대로
  `pubspec.yaml` versionString을 승인본보다 높게 수정 후 재실행.
- **가드 B (release: 승격할 빌드 없음)**: release는 최신 TestFlight 빌드가 ASC에
  **VALID**로 있어야 promote한다. 방금 beta로 올렸다면 처리(40~60분)가 끝나기 전엔
  VALID가 아니라 가드 B로 중단된다. → `check_builds`로 VALID 확인 후 release 재실행.
- **#6 altool 91169 Simulator platforms** (upload): beta/release 레인이 시작 시
  `reset_ios_caches`로 자동 정리하므로 거의 안 난다. 그래도 나면 수동 확인:
  ```bash
  vtool -show build/ios/iphoneos/Runner.app/Frameworks/<framework> | grep platform
  # platform IOS = OK / platform IOSSIMULATOR = 차단 → flutter clean 후 재빌드
  ```
- **CocoaPods broken / Generated.xcconfig 없음** (clean 후): `flutter pub get`
  → `cd ios && pod install` 순서로 복구 후 재빌드.
- **App Store Connect API key 인증 실패**: key_id/issuer_id는 Fastfile
  `load_asc_api_key` 레인에 정의. 개인키는 `~/.appstoreconnect/private_keys/`에
  있어야 한다(리포 밖).

## 배포 검증 함정 (실측으로 데인 것 — 반드시 지킬 것)

배포 성공을 주장하기 전 **신선한 증거**로 확인한다. exit 코드나 로그 "느낌"이 아니라
업로드 성공 라인을 직접 봐야 한다.

- **`flutter ... | tail` 금지** — 파이프하면 `$?`가 **tail의 exit 코드**라 fastlane
  실패를 못 잡는다(exit 0으로 보임). 전체 출력을 **파일로 리다이렉트**하고
  `grep "배포 완료\|Successfully uploaded the new binary"`로 확인한다.
  ```bash
  ./ios/bin/fastlane.sh beta > /tmp/beta.txt 2>&1   # 파이프 말고 리다이렉트
  grep -aE "빌드 번호|Successfully uploaded the new binary|배포 완료" /tmp/beta.txt
  ```
- **배포는 `run_in_background`로** — 하니스가 추적해 완료 알림을 준다. 셸 `&`는 추적
  불가(orphan 위험, 알림 없음).
- **성공 판정 = 업로드 라인** — `TestFlight 배포 완료! vNN` 또는 `Successfully
  uploaded the new binary`. fastlane이 끝에 뿌리는 업데이트 changelog는 성공/실패와 무관.
- **빌드번호 교차 확인** — 로그의 `빌드 번호: N → N+1`이 직전 최신+1인지. 그대로면
  업로드가 실제로 안 됐을 수 있다(`check_builds`로 재확인).
- **배포 중단(killed) 시 = 실도달을 `check_builds`로 교차 확인** — 업로드 도중 프로세스가
  강제 종료되면(출력에 altool 에러 없이 "업로드 중…" 직후 끊김) 빌드는 됐어도 TestFlight
  도달 여부가 불명이다. **추측하지 말고** `check_builds`로 최신 빌드번호를 본다. 목록은
  `-uploadedDate` 정렬이라 **맨 위가 최신**(`tail`로 자르면 오래된 것만 보이니 `head`로 볼 것).
  미도달이면 재배포(빌드번호 latest+1 자동 재계산).
- **배포가 반복 kill되면 nohup 분리** — 백그라운드 배포가 연속 중단되는 환경에선
  `nohup ./ios/bin/fastlane.sh beta > out.txt 2>&1 & disown`으로 하니스와 분리해 띄우고
  pid 폴링(`kill -0`)으로 종료를 감지한다. 폴러가 죽어도 배포는 계속된다.
  (v85: 2연속 kill → nohup 3차 시도 성공.)
- **업로드 성공 ≠ 즉시 노출 — 처리에 40~60분** — `skip_waiting_for_build_processing: true`라
  "Successfully uploaded"는 ASC 전달 완료까지만 의미. 이후 비동기 처리로 TestFlight/`check_builds`
  목록에 뜨기까지 **최근 실측 40~60분**. 방금 올린 빌드가 `check_builds`에 안 보여도 **실패로
  단정 금지** — 직전 빌드가 지연 끝에 뜬 전례가 근거. 실패는 killed(위)처럼 다른 신호로 판단.
- **업로드 단계 클라이언트 오류 ≠ 실제 실패 — 재시도 전 `check_builds` 필수** — `upload_to_testflight`가
  전송 *후* 단계(`CHANGE UPLOAD STATE TO COMPLETE` HTTP 500 / `network connection was lost` -1005)에서
  에러를 뱉으며 "Error uploading ipa file"로 끝나도, 바이너리는 이미 Apple이 수신·처리했을 수 있다.
  실패로 오인해 재시도하면 **같은 코드가 여러 빌드번호로 중복 등록**된다(무해하나 낭비).
  **반드시 `check_builds`로 해당 빌드번호가 VALID로 올라왔는지 먼저 확인**하고, 올라왔으면 재시도 금지.
  (v90 "HTTP 500" / v91 "network lost" 둘 다 실제로는 업로드 성공 → 불필요 재시도로 v90·v91·v92 중복.)

## Android

fastlane 5개 레인(`check_tago_key`/`check_play_key`/`build_aab`/`bootstrap`/`beta`)을
**게이트 → 실행** 순서로 돌린다. 기본 레인은 `android beta`.

실행은 항상 wrapper로 한다 — `./android/bin/fastlane.sh`가 Homebrew Ruby를 PATH 앞에
주입한다(iOS wrapper와 같은 패턴). 맨 `fastlane`을 직접 부르지 않는다.

**레인 5개:**

| 레인 | 하는 일 | Play 인증 | 트랙 | 파괴적 |
|---|---|---|---|---|
| `check_tago_key` | TAGO 키 파일 확인 | 불필요 | – | 없음 |
| `check_play_key` | 서비스 계정 JSON + client_email 검증 + 트랙 4개 versionCode 조회 | 필요 | – | 없음 |
| `build_aab` | 가드 → clean → release AAB 생성 (**업로드하지 않는다**) | 불필요 | – | clean |
| `bootstrap` | `build_aab` + internal 트랙 draft 업로드(패키지명 확정용, 최초 1회만) | 필요 | `internal`(draft) | clean |
| `beta` | 가드 → versionCode 계산 → `build_aab` → **비공개 테스트** 업로드 | 필요 | `Alpha`(비공개 테스트) | clean |

```bash
./android/bin/fastlane.sh check_tago_key   # TAGO 키 확인 (빌드·업로드 없음)
./android/bin/fastlane.sh check_play_key   # Play 서비스 계정 + 트랙 4개 versionCode 확인
./android/bin/fastlane.sh build_aab        # release AAB만 생성 (업로드 없음)
./android/bin/fastlane.sh bootstrap        # 패키지명 확정용 첫 업로드 (internal·draft, 최초 1회만)
./android/bin/fastlane.sh beta             # 비공개 테스트(Alpha) 업로드
```

⚠️ **`track: internal`은 `bootstrap` 전용이다.** internal은 비공개 테스트 14일
요건을 **하루도 세지 않는다**. 테스터에게 실제로 보낼 빌드는 반드시 `beta`(트랙
`Alpha` = Play 콘솔의 "비공개 테스트")로 올린다. **콘솔에서 트랙 이름을 육안
확인**할 것 — `테스트 및 출시 › 비공개 테스트`이지 "내부 테스트"가 아니다.

**`reset_android_caches`가 매 빌드 필수다** — `build_aab`가 자동 실행한다. 근거는
실측 둘:
- debug 빌드가 소스 위치에 심는 `GeneratedPluginRegistrant.java`가
  `integration_test`(dev dependency)를 참조해 release javac가 실패한다
  (`flutter clean`만으로는 이 파일이 안 지워져 직접 rm한다).
- `sqflite_common_ffi`(dev dependency)가 스테이징한 `libsqlite3.so`가 release
  APK에 그대로 섞여 들어간다(실측 70.4MB → 65.3MB로 축소 확인).

**서비스 계정 JSON은 `~/.google_play/planroutine.json` 하나로 일원화한다.** 같은
디렉터리의 `service_account.json`은 **바로팀이 이미 쓰고 있는 자리**라 잘못 집으면
엉뚱한 앱 자격증명으로 배포한다 — `assert_play_key`가 `client_email`에
`planroutine`이 있는지까지 확인해 막는다.

**게이트는 iOS와 동일**(`flutter analyze` + `flutter test`) **+ release AAB
스모크**: bundletool로 AAB를 에뮬레이터에 설치해 버스 카드가 실제 도착 정보를
그리는지 확인한다 — TAGO 키가 release 빌드에 실제로 주입됐다는 유일한 증거다.

⚠️ **첫 업로드는 레인으로 할 수 없다.** Play API는 패키지가 앱에 바인딩되기
전엔 `insert_edit`에서 404를 던진다. 이 앱은 이미 콘솔 수동 업로드로 그 벽을
지났지만, **다음 앱을 낼 때 같은 벽을 다시 만난다** — 그때는 콘솔에서 최초
1건을 수동으로 올려 패키지를 바인딩한 뒤에야 `bootstrap`/`beta`가 동작한다.

**되돌릴 수 없는 것**: 패키지명 · keystore · 최종 심사 제출. `beta`는
`release_status: "completed"`라 업로드 즉시 Play 심사로 들어간다 — 실기기(또는
최소 release AAB 스모크) 검증 후에만 실행한다.
