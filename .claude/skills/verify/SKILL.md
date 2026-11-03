---
name: verify
description: 공직플랜(Flutter iOS 앱)을 iPhone 17 시뮬레이터에 실제로 설치·실행하고, 사용자처럼 탭·붙여넣기로 기능을 조작해 화면과 DB로 증명한다. 기능 변경 뒤 "시뮬레이터로 확인", 배포 전 런타임 확인, "verify", "실제로 되는지 봐" 요청 시 사용. 위젯 테스트로 끝나는 확인에는 쓰지 않는다.
---

# 공직플랜 검증 (verify)

실제 앱을 띄우고, 사용자 경로로 조작하고, 증거를 남긴다. 이 파일은 **공직플랜 고유 값과 순서**만 담는다. 탭·입력·녹화 같은 시뮬레이터 도구 사용법은 `driving-ios-simulator` 스킬이 원본이다(전역 스킬, 두 Mac에 따로 있음). 막히면 그 스킬의 iOS 27 절부터 본다.

- 주 표면: iOS 시뮬레이터 **iPhone 17 / iOS 27.0** (`UDID 832373BE-F5D2-4FDE-BCF7-65A9D8CD6592`).
- 다른 표면: iPad(`2CDE702D-…` iPad Pro 13), Android 에뮬레이터(`api36_pixel7`, 메모리 `android_api36_emulator` 참고). 이 스킬은 다루지 않는다.
- 실기기 전용(센서, 실제 공유시트·Face ID, 녹음 소리, 전사)은 시뮬로 증명할 수 없다. 사용자가 TestFlight로 확인한다고 보고에 적는다.
- **격리 불가**: 시뮬레이터 하나·8GB Mac이라 인스턴스를 둘 띄우지 않는다. 다른 세션·에이전트가 같은 시뮬을 쓰는 중이면 조작하지 않는다. 안드로이드 빌드(`build_aab`)와 동시에 돌리지 않는다(`flutter clean`이 `build/`를 지운다).

도우미는 `.claude/skills/verify/scripts/`에 있다. 아래에서 `V=.claude/skills/verify/scripts`.

## 실행 (Launch)

```bash
V=.claude/skills/verify/scripts
$V/launch.sh                # 부팅 → flutter build ios --simulator --debug → 앱 지우고 설치 → 실행
$V/launch.sh --no-build     # 방금 빌드했으면
$V/launch.sh --keep-data    # 데이터를 남긴 채 새 빌드만 올릴 때
```

- 기본은 **앱을 지우고 다시 설치**한다 → 빈 데이터, 온보딩부터 시작한다. DB 마이그레이션은 앱이 처음 DB를 열 때 돈다.
- **준비 신호**: `snapshot_ui`(또는 스크린샷)에 온보딩의 `건너뛰기`가 보이면 준비된 것이다. `건너뛰기`를 누르면 탭바(`오늘`·`캘린더`·`입력`·`설정`)가 보이고 그때 `planroutine.db`가 생긴다.
- 빌드는 첫 회 수 분, 이후 1분 안팎이다. 메모리가 부족하면 빌드나 SpringBoard가 죽는다 → 점검부터.
- 버스 기능을 볼 때만 TAGO 키를 넣은 빌드가 필요하다(`driving-ios-simulator` "버스 정류장 검색"). 키 없는 빌드에서 버스 결과가 비는 것은 결함이 아니다.

## 점검 (Doctor)

```bash
$V/doctor.sh    # ✓/✗ 줄, 하나라도 ✗면 exit 1
```

본다: 시뮬 부팅 · 앱 설치 · **설치된 Dart 코드(App.framework)가 `build/` 산출물과 같은가** · 빌드 뒤에 고친 `lib/` 파일이 없는가 · 앱 프로세스 · Gradle 데몬 · 메모리 여유.

- 처음 조작하기 전, 그리고 **뭔가 이상할 때마다** 먼저 돌린다.
- `integration_test`를 돌린 뒤의 설치본은 테스트 빌드이고, `flutter test`는 끝나면 앱을 지운다. 둘 다 이 점검에서 ✗로 드러난다 → `launch.sh`.
- 점검이 못 보는 것: 화면이 엉뚱한 상태에 멈춘 경우(시트가 열린 채 등). 그때는 `xcrun simctl terminate` 후 다시 `launch`한다.

## 조작 (Drive)

도구는 `driving-ios-simulator` 스킬의 "두 도구 함께 쓰기"를 따른다. 요약:

- **읽기와 누르기는 MobileBuildMCP `snapshot_ui` + `tap`(elementRef)** 를 기준으로 쓴다. 세션 기본값이 비어 있으면 `session_set_defaults`로 시뮬 UDID를 준다.
- `snapshot_ui`에 안 나오는 곳은 번들 AXe로 좌표를 누른다(포인트 단위, iPhone 17 폭 402pt): `AXE=$(ls ~/.npm/_npx/*/node_modules/mobilebuildmcp/bundled/axe | head -1); AXE_HID_STABILIZATION_MS=200 $AXE tap -x <x> -y <y> --udid $UDID`.
- 스와이프: `$AXE swipe --start-x … --start-y … --end-x … --end-y … --udid $UDID`. 한글 입력은 AXe로 안 된다(US 키보드만) → 붙여넣기나 mobile MCP.
- 좌표보다 **화면 글자 라벨**을 손잡이로 쓴다. 앱의 누르는 요소는 `ButtonSemantics`로 이름이 붙어 있어(가드가 지킨다) `snapshot_ui`에 버튼으로 나온다.
- 일정 넣기의 표준 경로는 **사진 AI 붙여넣기**다(`features/ai-paste.md`). 대량 입력을 손으로 치지 않는다.
- 꺼진 선택 기능(포스트잇·지도 기록·장소 예약·버스)은 `설정 › 기능 관리`에서 켜고 본다. 지도 기록 잠금은 시뮬 Face ID로 푼다(`driving-ios-simulator` "잠금·꺼진 기능 열기"). 잠금·꺼짐을 이유로 미확인 처리하지 않는다.

기능별 절차는 `features/README.md`의 목차에서 고른다.

## 증거 (Evidence)

```bash
E=$($V/evidence.sh <기능-id>)      # ~/.planroutine/verify/<RUN_ID>/<기능-id>/ 를 만들고 출력. source.txt에 커밋 기록
$V/shot.sh "$E" 01-before          # 정적 화면
$V/db.sh "SELECT title, status, kind FROM schedules WHERE deleted_at IS NULL"   # 저장된 값 (읽기 전용)
```

같은 실행의 여러 기능은 `export VERIFY_RUN_ID=$(date +%Y%m%d-%H%M%S)`를 먼저 두고 같은 RUN_ID를 쓴다.

증명 기준:

- **사용자 경로를 탄다.** DB에 직접 쓰거나, 테스트 전용 진입점이나 provider override로 상태를 만들지 않는다(시드도 붙여넣기 경로로).
- **동작 전·후를 함께** 남긴다. 마지막 화면 한 장으로는 부족하다.
- **부수 효과를 확인한다.** 화면에 보이는 것과 함께 `db.sh`로 행을 읽는다. 예: 확정 → `calendar_events`에 행이 생기고 `schedules.status='confirmed'`.
- **몇 초짜리 UI(스낵바·도장 애니메이션)는 녹화**한다: `xcrun simctl io $UDID recordVideo --codec=h264 "$E/clip.mp4"`를 백그라운드로 띄우고 조작 뒤 `kill -INT`. 장면은 `driving-ios-simulator/frames.swift`로 뽑는다.
- 증거 파일 이름에 순서 번호를 붙이고, 보고에는 기능 ID·진입점·증거 경로를 함께 적는다.

## 정리 (Cleanup)

```bash
$V/cleanup.sh                # 앱 종료, mobile MCP 에이전트 종료, 이번 실행이 켠 시뮬레이터면 끈다
$V/cleanup.sh --uninstall    # 앱과 데이터까지 지운다
```

- 이 실행이 띄운 것만 내린다. 프로세스 이름으로 `kill`하지 않는다.
- **증거는 지우지 않는다**: `~/.planroutine/verify/`에 남는다(리포 밖이라 커밋되지 않고, Android 레인의 `flutter clean`도 건드리지 않는다). 오래된 실행 폴더는 사용자가 원할 때만 지운다.
- 테스트 데이터를 남기고 시뮬을 계속 쓸 거면 앱의 `설정 › 전체 데이터 초기화`로 비운다(설정은 남는다).

## 도우미

| 스크립트 | 하는 일 |
|---|---|
| `env.sh` | UDID·번들 ID·빌드 경로·증거 위치. `VERIFY_UDID`로 다른 기기를 줄 수 있다 |
| `launch.sh` | 부팅·빌드·설치·실행 |
| `doctor.sh` | 읽기 전용 점검 |
| `db.sh "<SQL>"` | 샌드박스 `planroutine.db` 읽기 전용 조회 |
| `evidence.sh <id>` | 증거 폴더 생성 |
| `shot.sh <폴더> <이름>` | 스크린샷 |
| `cleanup.sh` | 정리 |

## 알려진 막힘

**2026-11-03 01시, 이 스킬을 처음 만든 날**: 빌드는 성공했는데 시뮬레이터에서 `simctl install`·`launch`·`io screenshot`과
MCP `launch_app_sim`·`screenshot`이 오류 없이 멈췄다. 다음을 해 봤고 풀리지 않았다.

- `simctl shutdown` 후 다시 부팅 → 스크린샷만 한 번 됐고 설치에서 다시 멈춤
- `killall -9 com.apple.CoreSimulator.CoreSimulatorService`(하루 넘게 떠 있었다) → 설치는 됐고 `launch`·스크린샷이 멈춤
- 다른 기기(iPhone 17e) → 설치부터 멈춤
- 메모리 여유 31~63%, Gradle 데몬 없음, 디스크 여유 48GB → 자원 부족은 아니다
- 그때 Mac 화면 캡처(`screencapture`)가 완전히 검었다(디스플레이 2분 뒤 잠듦 설정, 원격 작업 중). `caffeinate -u`로 깨워도 그대로였다.

**2026-11-03 08시 재현**: 같은 날 아침에도 Mac 화면 캡처가 검었고, 빌드(42초)·부팅은 됐지만 `simctl uninstall`이 60초 시간 초과로
멈췄다. 이번엔 `wt`가 안내를 내고 끝났다(그 전에는 `launch.sh`의 `2>/dev/null`이 안내까지 버려 말없이 끝났다 — 고쳤다).
화면 상태는 사용자가 확인하기로 했다.

**원인 확인(2026-11-03 18시)**: 디스플레이가 아니라 **부팅 직후 CPU 포화**다. Mac 화면이 켜진 상태에서도 같은 자리에서 멈췄다.

- 부팅하면 iOS 27 런타임이 `assistantd`·`promotedcontentd`·`passd`·`fitcored`·`biomed`·`siriactionsd`·`maild`·`intelligenceplatformd`
  등 데몬 수십 개를 한꺼번에 돌린다(각 20~40%). 8코어 MacBook Air에서 load **114(1분)·266(5분)**, CPU 시스템 90%·유휴 0.5%였다.
- 이때 시뮬 안 installd는 설치를 **1초 만에** 끝냈는데(`MobileInstallation` 로그의 `Install successful`) `simctl install`은 응답을 못 받고 멈췄다.
  스크린샷도 4초에 됐다가 다음엔 멈췄다 — 성공과 멈춤이 섞여 "가끔 된다"로 보인다. **메모리 여유는 72%** 라 메모리만 보면 놓친다.
- **부팅 뒤 약 13분**에 load가 8 아래로 내려왔고, 그 뒤로 스크린샷·실행이 1~2초에 끝났다. `CoreSimulatorService` 재시작이나
  다시 부팅은 오히려 폭주를 처음부터 다시 시작시킨다.
- 그래서 `launch.sh`는 빌드 뒤 load가 코어 수 이하가 될 때까지 기다리고(최대 15분), `doctor.sh`는 `CPU 부하` 줄을 낸다.
  시뮬을 켜 둔 채 쓰면 이 대기는 처음 한 번뿐이다 — 검증을 여러 번 할 때 `cleanup.sh`로 끄지 않는 편이 낫다.

simctl 호출에는 계속 `wt`(시간 제한)를 걸어, 멈추면 무한 대기 대신 `✗ 시간 초과`와 복구 방법을 낸다.

## 유지

앱이 바뀌면 `features/`가 낡는다. 큰 기능 추가 뒤나 출시 전에 전역 `create-verification-skill` 스킬의 "유지 점검" 절을 따른다. 지도에 있는 동작을 앱이 더 하지 않으면, 지도가 틀린 것인지 제품 회귀인지 먼저 가른다.
