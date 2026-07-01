---
name: deploy
description: 공직플랜 배포 — iOS는 게이트 검사(analyze/test) 후 fastlane.sh 실행(TestFlight/App Store), green이면 승인 없이 바로 진행. Android는 아직 미배선(차단 요인 안내). "배포", "release", "beta", "fastlane 올려줘", "안드로이드/Play Store 배포" 요청 시 사용.
---

# 공직플랜 배포 런북

fastlane 3개 레인(`ios beta`/`ios release`/`ios check_builds`)을
**게이트 → 실행 → post-deploy** 순서로 돌린다. 기본 레인은 `ios beta`.

실행은 항상 wrapper로 한다 — `./ios/bin/fastlane.sh`가 Homebrew Ruby를 PATH 앞에
주입하고 최초 1회 `bundle install`을 끼운다. 맨 `fastlane`을 직접 부르지 않는다.

> beta/release 레인은 시작 시 `reset_ios_caches`(flutter clean + Pods/build 제거)를
> 자동 실행해 시뮬 슬라이스 함정(#6)을 막는다. 이어지는 `flutter build ipa`가
> pub get + pod install을 재수행한다. clean 때문에 매 배포가 수 분 더 걸린다.

## 1) PRE-FLIGHT 게이트 (GO/NO-GO)

순서대로 실행하고, 하나라도 실패하면 **NO-GO** — 원인을 리포트하고 중단한다.

```bash
flutter analyze            # 이슈 0건이어야 GO
flutter test               # 유닛/위젯 전수 통과 (단일 실행, flaky 반복 아님)
```

> **cold-start 주의**: `flutter clean` 직후 또는 오래 쉰 뒤 첫 `flutter test`는
> cold 컴파일로 수 분간 멈춘 듯 보일 수 있다(per-test 타임아웃도 안 먹음). 죽은 게
> 아니라 cold 빌드 중 → 한 번 warm-up 후 진행.

**버전/빌드번호:**
- build number는 Fastfile이 `latest_testflight_build_number + 1`로 자동 계산.
- **release 레인**: `pubspec.yaml`의 versionString이 App Store *승인본*과 같으면
  minor/patch를 올려야 한다 — 안 올리면 업로드 단계에서
  `CFBundleShortVersionString must contain a higher version`로 거부된다(함정 #5).
  versionString은 pubspec 직접 수정(레인에 bump 옵션 없음).

## 2) 실행 (승인 정책)

**게이트 GO이면 사용자 승인 없이 바로 실행한다.** 배포 실패 시에만 멈춰서 리포트한다.
(release 레인의 versionString bump가 필요한 경우는 예외 — pubspec 수정 여부를 먼저 질의)

```bash
./ios/bin/fastlane.sh beta      # TestFlight
./ios/bin/fastlane.sh release   # App Store (submit_for_review: false — 업로드까지만)
```

실행 후 push까지 진행. IPA 파일명이 한글(`공직플랜.ipa`)이라 Fastfile은 `Dir.entries`로
직접 순회해 찾는다 — glob 깨짐 걱정 없음.

## 3) POST-DEPLOY

```bash
./ios/bin/fastlane.sh check_builds   # 최근 5개 빌드 processing_state 조회
```
- `processing_state`가 VALID면 정상. PROCESSING이면 잠시 후 재조회.
- **TestFlight 앱에 새 빌드가 안 보이면** pull-to-refresh로는 갱신 안 된다.
  **앱 강제종료 후 재실행**하면 즉시 표시된다.

## 트러블슈팅 (레인 실패 시)

- **#5 higher version 거부** (upload): 게이트의 버전 결정에서 선제 차단. 재발 시
  `pubspec.yaml` versionString을 승인본보다 높게 수정 후 재실행.
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

## Android (계획 — 아직 미배선)

현재 iOS 전용. Android는 코드만 존재하고 **출시 불가 상태**라 Play Store 레인을
의도적으로 만들지 않았다(만들면 죽은 코드). 실제 Android 출시를 결정하면 아래 차단
요인을 먼저 해소한 뒤 레인을 추가한다.

**차단 요인 체크리스트 (해소 순서):**
1. **release 서명 분리** — `android/app/build.gradle.kts`의 `release` 블록이 현재
   `signingConfig = signingConfigs.getByName("debug")` (디버그 키). 업로드 keystore
   생성(`keytool`) + `android/key.properties`(리포 밖/gitignore) + release용 signingConfig로 교체.
2. **applicationId 통일** — 현재 `com.schedulenote.schedule_app` (리브랜딩 이전 ID).
   iOS와 맞춰 `com.planroutine.app`으로 변경(Play Console 등록 ID와 일치해야 함).
3. **Play 서비스계정** — Google Play Console에서 service account json 발급 →
   리포 밖(예: `~/.google_play/service_account.json`)에 보관.

**준비 완료 후 추가할 레인 패턴** (바로팀 `fastlane/` 참조 — 검증된 레퍼런스):
- `fastlane/Appfile`에 `json_key_file(...)` + `package_name "com.planroutine.app"`.
- `android beta`(track: internal) / `android release`(track: production) 레인:
  `flutter build appbundle --release` → `upload_to_play_store(aab: "build/app/outputs/bundle/release/app-release.aab", ...)`.
- iOS의 `reset_ios_caches`는 Android에 불필요(시뮬 슬라이스 함정은 iOS 전용).
