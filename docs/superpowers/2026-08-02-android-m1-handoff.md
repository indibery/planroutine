# 안드로이드 M1 인수인계 — 2026-08-02

> **다음 세션이 여기서 이어간다.** SDD ledger(`.superpowers/sdd/…/progress.md`)는
> **git-ignored라 다음 세션이 못 볼 수 있다** — 이 파일이 커밋되는 상태 기록이다.
> 설계: `docs/superpowers/specs/2026-08-01-android-release-design.md`
> 계획: `docs/superpowers/plans/2026-08-02-android-m1-shell-release.md`

## 한 줄

**M1 코드 작업 100% 완료.** 브랜치 `feat/android-m1-shell-release`에 커밋 19개.
`flutter analyze` 0 / `flutter test` **919**. 남은 것은 **사람이 하는 콘솔·모집 작업**뿐이다.

---

## 지금 어디까지 왔나

| | 상태 |
|---|---|
| GATE 1 keystore | ✅ `~/.android/keystores/planroutine-upload.jks` |
| GATE 2 앱 생성·서비스 계정·앱 콘텐츠 | ✅ |
| GATE 3 첫 AAB 업로드(versionCode 52) | ✅ Alpha 트랙, **검토 중**(8/2 시작, 최대 7일) |
| Task 1~10 코드 | ✅ 전부 완료, 리뷰 clean |
| 최종 whole-branch 리뷰 | ✅ **Critical 0** |
| GATE 4 테스터·시계 | ⬜ **여기가 남았다** |

### 즉시 이어갈 것 — 셋

1. **52 검토 결과 확인** (Play Console 게시 개요)
   - **통과** → 테스터 opt-in 시작 → **14일 시계 켜짐** → 그 다음 53 업로드
   - **거절** → 사유 확인. 인앱 방침 링크 부재가 가장 유력했고 **53에는 들어 있다**
2. **테스터 16명 모집** ← **유일한 임계경로.** 요건은 12명이지만 "opted-in" 판정 기준이
   공식 문서에 없어 여유를 둔다
3. **versionCode 53 업로드** — AAB는 이미 빌드돼 있다(아래)

### 미제출로 남겨 둔 콘솔 변경 1건

**방침 URL 필드**를 `https://planroutine.indibery.dev/privacy_policy`로 고쳐 저장했으나
**전송하지 않았다.** 지금 전송하면 진행 중인 52 검토가 **취소·재시작**된다.
→ **53을 올릴 때 한 번에 전송**한다(리셋 1회로 끝난다).

> 14일 시계는 **빌드가 아니라 테스터의 opt-in 연속성**으로 센다. 새 빌드를 올려도
> 시계는 리셋되지 않는다 — 그래서 52를 통과시켜 시계를 먼저 켜는 것이 유리하다.

---

## versionCode 53 AAB (빌드 완료)

```
build/app/outputs/bundle/release/app-release.aab   50.9MB
서명 SHA-1  29:3F:97:79:89:F1:D2:C6:B3:42:C8:5F:F7:5C:0D:74:9C:69:DE:1D
```
52와 달라진 것: **인앱 방침 링크 · adaptive 아이콘 · keep.xml · proguard 규칙 ·
INTERNET 명시 · allowBackup 선언.**

⚠️ 다시 빌드해야 하면 **반드시 레인으로**: `./android/bin/fastlane.sh build_aab`
손으로 `flutter build appbundle`을 치면 gradle 가드가 막는다(TAGO 키가 없어서) — 그게 설계다.

---

## 지문 둘 (M2-④ 구글 로그인의 입력값)

| 키 | SHA-1 | GCP 등록 |
|---|---|---|
| **Play 앱 서명 키** | `96:2F:16:C1:F4:98:03:FB:24:E0:4B:01:A3:52:6F:30:72:BC:A8:BE` | **필수** — 테스터 기기에 깔리는 앱 |
| 업로드 키 | `29:3F:97:79:89:F1:D2:C6:B3:42:C8:5F:F7:5C:0D:74:9C:69:DE:1D` | 권장 |
| debug 키 | `9F:9B:B9:64:3B:11:84:13:9D:C6:79:93:EA:A2:DE:51:DB:95:8A:84` | 개발용 |

GCP 프로젝트 **planroutine**(번호 73700230470, iOS와 같은 것).
서비스 계정 JSON: `~/.google_play/planroutine.json`
⚠️ `service_account.json`이 **아니다** — 그 자리는 바로팀이 쓴다. 가드가 `client_email`에
`planroutine`이 없으면 막는다.

---

## 브랜치를 어떻게 할까 (결정 대기)

`feat/android-m1-shell-release` 19커밋. 최종 리뷰 Critical 0.

- **머지** — 다음 `beta` 실행이 깔끔해진다. 코드는 완성됐고 리뷰도 끝났다
- **브랜치 유지** — 53이 검토를 통과할 때까지 기다린다

어느 쪽이든 코드 상태는 같다. 사용자에게 물을 것.

---

## 후속으로 남긴 것 (M2에서)

| | 무엇 | 왜 |
|---|---|---|
| M-1 | `test/android/release_guard_test.dart` | gradle 가드 둘과 **레인의 가드 순서**를 기계로 지키는 것이 없다. `whenReady` 블록을 지우거나 `reset_android_caches`를 값싼 가드 위로 올려도 `flutter analyze`·`test`는 `.kts`·`.rb`를 안 봐서 **조용히 통과**한다 |
| M-4 | `gen_play_assets.py`의 팔레트 hex | 같은 마일스톤 Task 8이 아이콘에서 정확히 이것을 거부했는데 여기만 남았다 |
| M-5 | 방침 URL 테스트가 상수를 상수와 비교 | 이 브랜치의 Critical이었던 그 값에 대해 무조건 통과한다. 대조 대상이 리포에 있다(`release_checklist.md:17`) |
| M-2 | `bootstrap` 레인 | 실행된 적 없고 desc가 런북과 모순("첫 업로드용"인데 첫 업로드는 레인으로 불가) |

**M-1·M-4·M-5는 "소스를 읽는 정적 가드" 한 파일로 묶는 것이 이 리포 관례다**
(선례: `test/features/settings/data_source_credit_test.dart`).

---

## M2 착수 시 먼저 읽을 것

스펙 `### M2-①`~`⑨`가 전문이다. 항목 아홉이고 **①(알림)이 가장 크다** —
"미배선"이 아니라 **구조적으로 죽어 있다**(`init()`이 예외를 던지고 `catch(_)`가 먹어
스위치를 켤 수조차 없다). 그리고 receiver가 **둘**이다(`ScheduledNotificationReceiver`가
없으면 재부팅과 무관하게 알림이 한 건도 발화하지 않는다).

M2 기간에 함께 할 것:
- Android 실물 스크린샷으로 스토어 자료 교체(`test/tools/gen_play_assets.py`의 `SRC_SHOTS`만 바꿔 재실행)
- **iPhone 시뮬레이터 회귀** — 이 브랜치가 바꾼 공유 코드(설정 방침 행)를 iOS에서 한 번도
  실행하지 않았다. 다음 iOS beta 전에 확인할 것. 그때 `ios/Podfile.lock`도 재생성된다
- iOS App Store 설명의 낡은 서술 수정 — 도장이 `완료·결재·좋아요`로 적혀 있는데
  `좋아요`는 없어졌고 판다·도마뱀이 들어왔다

---

## 이 세션에서 배운 것 (반복 방지)

**스펙 결함 다섯이 실행 중에 드러났다.** 워크플로 리뷰를 세 라운드 돌려 BLOCKER를 0으로
만든 문서였는데도 그랬다:

1. 컴파일되지 않는 Kotlin — AGP가 `java` 확장을 등록해 `java.util.Base64` 정규화 참조를 가린다
2. 유효하지 않은 XML — 주석을 `<application>` 시작 태그 속성 사이에 뒀다
3. **서비스 계정 경로가 바로팀 것**이었다
4. **방침 URL이 홈페이지를 가리켰다** — 스펙→계획→브리프→코드 **네 문서를 통과**했다
5. **콘솔 메뉴가 없어졌다** — `설정 › API 액세스`

3·4·5의 공통점: **리포 밖 사실**이다. 내가 쓴 문서끼리 대조해선 영원히 보이지 않는다.
→ **외부 사실(URL·경로·계정·콘솔 경로)은 그 원천과 대조한다.**

1·2의 공통점: **실행해야만 드러난다.** 문서 검토는 "말이 되는가"를 보고 실행은
"그렇게 되는가"를 본다.
