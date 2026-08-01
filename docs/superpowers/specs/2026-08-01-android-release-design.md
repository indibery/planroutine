# 공직플랜 안드로이드 출시 — 설계

**2026-08-01**

## 개요

1년치 기능이 iOS에만 배선된 상태에서 `android/`를 Play Store 프로덕션까지 끌고 간다.
기능 범위는 **iOS와 완전 동일**(버스·구글 캘린더 포함)이고, 실기기 없이 **에뮬레이터 +
테스터 12명**으로 검증한다. 최근 만든 개인 계정이라 **비공개 테스트 12명 · 14일 연속**이
프로덕션의 관문이고, 그 14일이 총 기간을 지배하므로 **껍데기부터 먼저 올린다**(접근법 B).
마일스톤은 M1 껍데기 출시 → M2 기능 패리티 → M3 프로덕션이며, M1의 목적은 기능이 아니라
**타이머 두 개를 켜는 것**이다 — 테스터별 14일 카운트와 Play 앱 서명 지문 발급.
빌드는 첫날부터 fastlane 레인으로만 만들고(수동 `flutter build appbundle` 경로를 만들지
않는다), 업로드 키는 리포 밖에 둔다(iOS `.p8`과 같은 규칙).

**이 작업은 iOS도 재배포 대상으로 만든다.** 브리프는 "iOS는 한 줄도 안 바뀐다"였는데 결정
둘이 그것을 깼다 — 글꼴을 에셋으로 번들하는 것(§결정 A)은 플랫폼 공통
`app_text_styles.dart`·`pubspec.yaml`을 건드리고 **온보딩의 글꼴 렌더까지 바꾸며**(§M2-⑧),
인앱 처리방침 링크(§결정 B)는 **iOS 설정 화면에도 같은 행을 만든다**(양쪽 스토어가 같은
요건이다). 여기에 `app_theme.dart`의 내비게이션 바 필드와 바텀시트 `useSafeArea`가 더해진다.
확정 목록은 §범위 밖에 있다. 브랜치가 머지되면 **다음 iOS beta가 이 변경들을 함께 태우므로**
검증 계층에 iPhone 시뮬레이터 회귀 행이 들어간다(§검증 계층).

**14일 앞에 미지의 구간이 하나 더 붙는다.** 신규 앱의 첫 릴리즈는 테스트 트랙이라도 검토를
거치고, 릴리즈가 `사용 가능`이 되기 전에는 테스터가 설치할 수 없다. Play는 검토 기간을
"보통 7일 이내, 때로 더"로만 안내하므로 이 구간을 일수로 못박지 않는다 — 대신 **시계 시작을
릴리즈가 `사용 가능`이 된 시점으로 정의**하고, M2 일정을 그 뒤 14일 안에서 잡는다
(§M2 일정). 총 기간은 `14일`이 아니라 `첫 릴리즈 검토 + 14일`이다.

그리고 M1은 **콘솔 선행조건 셋**에 걸려 있다. 셋 다 코드가 아니라 계정 쪽이고, 하나라도
빠지면 레인이 돌지 않거나 릴리즈가 공개되지 않는다.

- **Play 서비스 계정** — `upload_to_play_store`·`google_play_track_version_codes`가 전부
  이 인증을 요구한다. 신규 계정은 API 액세스 활성이 즉시가 아닐 수 있어 **H1 직후**에
  착수한다(§M1-H1.6).
- **패키지명은 앱 생성이 아니라 첫 AAB 업로드가 확정한다** — `앱 만들기` 양식에 패키지명
  입력란이 없다(§순서 ③).
- **릴리즈 공개에 필요한 선언 전수**(방침 URL·데이터 안전·콘텐츠 등급 등)가 비공개 테스트
  공개의 전제일 수 있다. 전제면 M3의 두 항목이 M1으로 올라온다(§M1-H1.5).

브리프는 `M1 1번 작업 = 빌드 첫 통과`를 리스크로만 적었는데 **원인이 확정됐다**:
`flutter_local_notifications`가 요구하는 core library desugaring이 앱 gradle에 없어
`:app:checkDebugAarMetadata`에서 죽는다. 직접 재확인했다(§브리프 수정 1).

## 브리프 수정이 필요한 지점

조사에서 브리프의 전제와 어긋난 것들이다. 결정은 뒤집지 않았다 — **작업 목록과 난이도
추정이 바뀐다.**

| # | 브리프 | 실제 | 어디서 다루나 |
|---|---|---|---|
| 1 | 빌드 첫 통과가 리스크. `device_calendar` 의심 | **desugaring 미설정이 확정 원인.** `device_calendar`는 무관 | M1-C1 |
| 2 | M1-3 INTERNET 권한 추가 | **이미 병합돼 있다**(`google_sign_in_android`). 차단 요인 아님 | M1-C4 |
| 3 | M2-① `POST_NOTIFICATIONS` 권한 | **이미 병합돼 있다**(플러그인). 매니페스트 작업 0 | M2-① |
| 4 | M2-① boot receiver | **receiver가 둘이다.** `ScheduledNotificationReceiver`가 없으면 재부팅과 무관하게 알림이 아예 안 뜬다 | M2-① |
| 5 | 알림은 "Android 미배선" | **구조적으로 죽어 있다** — `init()`이 예외를 던지고 `catch(_)`가 먹으며, 스위치를 켤 수조차 없다 | M2-① |
| 6 | `requestPermission()`에 분기 | 플러그인 API 이름은 **`requestNotificationsPermission()`**(복수형). 브리프의 이름은 리포 자체 추상 메서드 | M2-① |
| 7 | 채널은 `AndroidNotificationDetails`가 만든다 | 만드는 시점이 **첫 발화 때**다 → ⑦ 안내의 목적지가 빈 화면 | M2-① |
| 8 | (없음) | 알림 본문이 두 줄인데 Android는 접힌 상태에서 한 줄만 보여준다 → `BigTextStyleInformation` | M2-① |
| 9 | M2-④ SHA-1 **두 개** | 신규 앱은 quantum-ready hybrid signing 자동 등록이라 **세 개일 수 있다.** GCP는 클라이언트당 SHA-1 하나 → 클라이언트 최대 5개 | M2-④ |
| 10 | (없음) | Play Console `App integrity` 경로가 **2026-05에 `Protected with Play`로 대체**됐다 | M1-H4 |
| 11 | M1-4 `key.properties` gitignore | **이미 되어 있다**(작업이 아니라 확인). 실제로 뚫린 것은 `android/.kotlin/`·fastlane 산출물·Play 서비스계정 JSON | M1-C3 |
| 12 | 파일 앱 running은 `onNewIntent` | DocumentsUI가 `FLAG_ACTIVITY_NEW_TASK`를 안 붙여 **`onCreate`가 주 경로**다 | M2-② |
| 13 | (없음) | `flutter_deeplinking_enabled` **기본 true** — 안 끄면 `content://`가 초기 라우트를 덮어 Page Not Found | M2-② |
| 14 | ⑥ edge-to-edge는 코드 변경 없음 | **라이트 테마 내비게이션 바 아이콘 밝기가 틀렸다.** iOS는 구조적으로 무영향 | M2-⑥ |
| 15 | 바텀시트 둘도 `useSafeArea: true` | 호출부는 **6곳**이고 `true`는 둘뿐. `isScrollControlled` + 누락이 3곳이며 **그 셋에 가드가 없다** | M2-⑥ |
| 16 | ⑦ `openAppSettings()` | **배터리 최적화 화면이 아니라 앱 정보 화면**까지만 간다 | M2-⑦ |
| 17 | (없음) | **온보딩에서 백 한 번에 앱이 종료된다**(ShellRoute 밖) | M2-③ |
| 18 | `PopScope(canPop: false)` | 고정하면 Android 16 back-to-home 예측형 애니메이션이 꺼진다. **동작이 같은 동적 형태**가 있다 | M2-③ |
| 19 | (없음) | `google_fonts`가 런타임에 `fonts.gstatic.com`을 부를 수 있다. **다만 지금 호출부가 0건**이라 방침 §6은 "거짓"이 아니라 **한 줄이면 거짓이 되는 상태**다 | 결정 A (에셋 번들) |
| 20 | (없음) | **인앱 처리방침 링크가 없다** — Play User Data 정책이 요구 | M1-C6 |
| 21 | internal은 카운트 안 됨 | 맞다. 추가로 **open testing도 우회로가 아니다** — 프로덕션 액세스를 먼저 받아야 들어간다 | M1-H5 · H6 |
| 22 | (없음) | debug 산출물이 release로 새는 경로 둘(registrant, `libsqlite3.so` 5.1MB) → 레인에 clean 필요 | M1-C5 |
| 23 | iOS `strip_dart_defines` 재사용 | Android는 **대응물이 불필요하다**(dart-define가 파일로 안 남는다). 대신 `--verbose` 금지 | M1-C5 |
| 24 | (없음) | 16 KB page size 요건은 **이미 통과한다**(작업 0) | 범위 밖 |
| 25 | (없음) | Play `정부 앱` 선언이 저평가된 리스크 — 조직 계정 제한 여지 | M3-H2 |
| 26 | (없음) | **Play 서비스 계정이 없으면 레인이 한 줄도 못 돈다.** `Appfile` + `~/.google_play/service_account.json` | M1-H1.6 · C5 |
| 27 | (없음) | Play Console `앱 만들기`에 **패키지명 입력란이 없다** — 첫 AAB 업로드가 바인딩한다 | §순서 ③ · M1-H3 |
| 28 | (없음) | release는 R8 축소 + **리소스 축소**가 기본 ON이다 → `ic_notification`·GSON 역직렬화가 죽는다 | M1-C8 |
| 29 | versionCode = Play 최신 + 1 (iOS와 대칭) | `google_play_track_version_codes`는 **그 트랙만** 본다 — iOS의 계정 스코프와 대칭이 아니다 | M1-C5 |
| 30 | (없음) | dart-define는 `classes.dex`가 아니라 **`base/lib/<abi>/libapp.so`**에 박힌다. 산출물 grep은 가드로 못 쓴다 | M1-C5 |
| 31 | (없음) | 첫 릴리즈는 트랙과 무관하게 **검토를 거친다** — 14일 앞에 미지 구간이 붙는다 | §개요 · M1-H5 |
| 32 | (없음) | `android:allowBackup` 미설정 = **기본 켜짐.** 일정 DB가 사용자 Google Drive로 나가므로 데이터 안전 답안과 방침이 이 한 줄에 매인다 | M1-C4 · M3-H3 |
| 33 | ⑥ 코드 변경 없음 | `useSafeArea` 누락 3곳은 고치는 것으로 끝나지 않는다 — 이 리포 규칙은 **재발한 함정을 가드로 승격**하는 것이다(같은 함정의 4·5·6번째 사례다) | M2-⑥ |
| 34 | (없음) | 리포의 오버플로 가드는 **폭만** 훑는다(`TextScaler` 사용 0건). Android는 글꼴 배율이 iOS보다 훨씬 흔하게 바뀐다 | M2-⑥ · M2 게이트 |
| 35 | (없음) | `/import`의 **주 입구**(`file_picker`)가 작업 목록에 없었다. Android는 `FileType.custom`이 `*/*` + `EXTRA_MIME_TYPES`로 번역된다 | M2-② |
| 36 | (없음) | Play 스크린샷 규격("최대변 ≤ 최소변 × 2")에 **기존 App Store 자료 두 세트와 Pixel 7이 전부 탈락**한다 | M3-H4 (촬영은 M2 기간) |
| 37 | (없음) | E2E 19건 중 한 건이 mock 없이 네이티브 공유 시트를 띄우고 **그 뒤에 시나리오가 둘 더 있다** | M2 게이트 |
| 38 | (없음) | `deploy` 스킬이 `android beta`를 **track: internal**로 적어 뒀다 — 그대로 따르면 14일이 0일이다. `CLAUDE.md`도 "Android는 코드만 존재하고 미검증"에서 멈춰 있다 | §리포 문서·규칙 갱신 |
| 39 | (없음) | `onboarding_screen.dart:113`이 **등록되지 않은** `fontFamily: 'Space Grotesk'`를 쓴다(FontManifest에 없다 — 조용히 기본 글꼴로 그려진다). 결정 A로 **iOS 렌더가 실제로 바뀐다** | M2-⑧ |
| 40 | ③ 온보딩은 "3페이지"까지만 | `PageView.builder` + `_page` 상태 + `PageController` 실물 확인. 되돌림 판정은 **순수 함수로 뺄 수 있다** | M2-③ |

### 1. desugaring — 두 조사 갈래의 "무수정 통과"는 오염된 관측이다

조사 6갈래 중 둘이 `flutter build apk --debug`·`flutter build appbundle --release`가
**소스 무수정으로 통과했다**고 보고했고, 한 갈래는 **실패했다**고 보고했다. 직접 재확인했다:

```
$ cd /Users/kwangsukim/i_code/planroutine/android && ./gradlew :app:checkDebugAarMetadata
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:checkDebugAarMetadata'.
   > An issue was found when checking AAR metadata:
       1.  Dependency ':flutter_local_notifications' requires core library desugaring to be
           enabled for :app.
BUILD FAILED in 16s
```

**실패가 맞다.** 통과를 본 갈래들은 다른 조사원이 `~/.gradle/init.d/zz-planroutine-probe.gradle`로
desugaring을 **전역 주입한 상태**에서 같은 워킹트리를 빌드했다. 그 init 스크립트는 조사 종료 시
삭제됐고(`~/.gradle/init.d/` 부재 확인), 지금은 위와 같이 실패한다.

같이 정리해 둘 것: "AGP가 AAR 메타데이터의 `coreLibraryDesugaringEnabled=true`를 소비 측에
**전파한다**"는 해석은 틀렸다. AGP는 전파하지 않고 **검사해서 실패시킨다** — 실패 태스크 이름이
`checkDebugAarMetadata`인 것이 그 증거다. `build/flutter_local_notifications/.../aar-metadata.properties`에
그 줄이 있는 것은 요구사항의 선언일 뿐 충족의 증거가 아니다.

> **일반화**: 병렬 조사에서 "빌드가 통과했다"는 보고는 **워킹트리 상태가 공유될 때 증거가 못
> 된다.** 다른 에이전트의 전역 설정·산출물이 관측에 섞인다. 결론이 뒤집히는 관측은 단독으로
> 재현해 확정한다.

## 순서가 결과를 바꾼다 — 세 개의 의존성

이 프로젝트에서 순서를 틀리면 **되돌릴 수 없거나 총 기간이 늘어난다.** 셋 다 M1 안에 있다.

### ① 14일 타이머 — 먼저 켜야 총 기간이 줄어든다

공식 문구는 **테스터별 롤링 창**이다(Play Console Help, 프로덕션 액세스 요건 FAQ verbatim):

> "we won't count testers who opted in, tested for less than 14 days, and then opted out.
> Even if they opt back in so that they are opted in for a total of 14 days, these 14 days
> must be consecutive…"

즉 카운트 대상은 **본인이 연속 14일 opted-in이었던** 테스터이고, 신청 자격은 **신청하는
순간** 그런 테스터가 12명 이상인 것이다("when you apply for production access").

- **트랙 생성일도, 12명이 찬 날도 시작점이 아니다.** 각 테스터의 시계가 그 사람이 opt-in한
  날부터 따로 돈다.
- 그래서 **M1을 먼저 올리고 M2를 그 14일 안에 한다.** 순서를 뒤집으면(기능을 다 맞춘 뒤 올리면)
  M2 기간과 14일이 직렬이 돼 총 기간이 그만큼 늘어난다. 브리프의 접근법 B가 이것이다.
- 13번째가 8일차에 합류해도 다른 12명이 14일을 채웠으면 신청할 수 있다. 반대로 12명 중 1명이
  10일차에 빠지면 **그 1명만** 0으로 돌아간다(공식 문구는 개인별 재계산만 말한다 —
  "전체 타이머 리셋"은 3rd-party 주장이고 근거를 못 찾았다, §미확인).
- 대응: **12명이 아니라 14~16명을 모은다.** 이건 근거 없는 여유가 아니라 "opted-in"의 정의가
  공식적으로 없다는 불확실성(§미확인 B1)에 대한 대비다.

### ② SHA-1 — 올려야 지문이 나온다 (닭-달걀)

Google 로그인은 **패키지명 + 서명 지문**으로 앱을 식별한다. 그런데 Play 앱 서명 키는
**Play가 생성**하고, 그 지문은 **첫 AAB를 업로드한 뒤에** Play Console에 나타난다.

```
업로드 키 keystore 생성 ─┬─→ 업로드 키 SHA-1 (지금 손에 있다)
                        │
                        └─→ AAB 서명 → Play 업로드 ─→ Play 앱 서명 키 지문 발급
                                                          ↓
                                        GCP Android OAuth 클라이언트 등록
                                                          ↓
                                        M2-④ 구글 로그인 실동작 검증
```

- 그래서 **M2-④(구글 로그인)는 M1 업로드 없이는 검증할 수 없다.** 브리프가 "M1을 먼저 올렸으므로
  두 지문 모두 이 시점에 손에 있다"고 쓴 근거다.
- **지문이 나오는 업로드는 H3(확정용 업로드)이다** — 비공개 테스트 릴리즈(H5)나 그 검토를
  기다릴 필요가 없다. 패키지명 확정과 지문 발급이 같은 한 번에 일어나므로(§순서 ③) M2-④의
  GCP 등록은 M1 중반에 시작해 C4~C8·H5와 병렬로 돈다.
- 에뮬레이터 개발용 debug 키 지문은 지금도 뽑을 수 있으므로(§M2-④) **로그인 코드 확인만은
  M1 업로드 전에도 가능하다.** 스토어 빌드에서의 로그인은 불가능하다.

### ③ applicationId — 확정 지점은 앱 생성이 아니라 **첫 업로드**다

`com.planroutine.app`이 공개 스토어에 없다는 것은 확인했다(3개 로케일 모두 HTTP 404, 대조군
`com.google.android.apps.maps` 200). **하지만 404는 "쓸 수 있다"의 증명이 아니다** — 남의 초안(draft),
삭제·정지된 앱, unlisted 앱은 패키지명을 점유하면서 스토어에 뜨지 않는다. Play는 삭제된 앱의
패키지명을 영구 보유한다.

**그런데 Play Console `앱 만들기` 양식에는 패키지명 입력란이 없다.** 받는 것은 앱 이름·기본
언어·앱/게임·무료/유료·정책 선언이고, `applicationId`는 **첫 AAB를 업로드할 때** 앱에
바인딩된다. 선점 충돌도 그 순간에 처음 드러난다.

> **그래서 "앱을 만들어 보면 확정된다"는 성립하지 않는다.** 확정 지점은 **첫 업로드**이고,
> 첫 업로드에는 리네임된 코드와 업로드 키가 이미 필요하다 — 즉 **리네임을 두 번 할 위험은
> 없앨 수 없고 앞당길 수만 있다.**

앞당기는 방법은 확정용 업로드를 **버리는 업로드**로 따로 세우는 것이다.

```
C1 desugaring → C2 리네임 → H2 keystore → C3 서명 배선 → C5 레인(build_aab)
   → H3 확정용 업로드 (internal 트랙 · draft) ← **콘솔에 사람이 올린다. 레인이 아니다**
```

- **internal 트랙이라 14일을 하루도 태우지 않는다**(§M1-H5의 트랙 비교표). 시계는 뒤의
  비공개 테스트 릴리즈에서 시작한다.
- **되돌릴 수 없는 것을 가장 싼 상태에서 밟는다.** 이 업로드에 필요한 코드는 C1·C2·C3
  셋뿐이고, 헛일이 될 수 있는 범위는 그만큼이다. C4 매니페스트·C6 인앱 방침 링크·C7
  아이콘·C8 축소 대비는 뒤로 밀어 두면 선점 충돌 시 손실이 0이다.
- **한 번에 네 개가 확정된다** — 패키지명(미확인 #2) · PKCS12 `.jks` 서명 AAB를 Play가
  받는지(#6) · Play가 신규 앱 첫 릴리즈를 draft로만 받는지(#4) · 그리고 **Play 앱 서명 키
  지문 발급**(§순서 ②의 닭-달걀이 여기서 풀린다 → M2-④를 M1 중반에 시작할 수 있다).
  서비스 계정 권한은 여기서 확정되지 않는다 — 사람이 콘솔로 올리므로 API를 안 태운다.
- 이 업로드는 테스터에게 가지 않는다. 트랙에 남은 draft 릴리즈는 그대로 두거나 삭제한다.

#### 왜 확정용 업로드를 레인이 못 하는가 (fastlane 소스 실측)

**Play Developer API는 패키지가 바인딩되기 전에는 어떤 호출도 받지 않는다.** 모든 supply
액션은 `packageName`으로 edit을 열고 시작한다:

```
supply/lib/supply/reader.rb:6      client.begin_edit(package_name: Supply.config[:package_name])
supply/lib/supply/uploader.rb:12   perform_upload 첫 줄에서 begin_edit
supply/lib/supply/client.rb:163    self.current_edit = call_google_api { client.insert_edit(package_name) }
```

`insert_edit`이 `applicationNotFound`(404)로 실패하고 **아무도 그것을 잡지 않는다.** 이 스펙이
근거로 든 404 rescue(§M1-C5의 `next_version_code` 주석)는 `client.rb:498-501`의
`get_edit_track`에만 걸려 있어 `trackEmpty`/`Track not found`만 흡수한다.

그래서 셋이 따라온다:

1. **`bootstrap` 레인으로 H3을 할 수 없다.** `assert_play_key`(파일 존재)를 지나 첫 네트워크
   호출에서 죽는다. `bootstrap`은 **패키지가 바인딩된 뒤**의 재업로드용으로만 남긴다.
2. **`check_play_key`는 H3보다 뒤에 있어야 한다.** H1.6 시점에는 트랙 조회가 원리적으로
   불가능하므로, 그때의 완료 신호는 **콘솔 육안**(릴리스 관리자 권한이 보인다)이다.
3. **H3 뒤에 `check_play_key`를 별 단계로 세운다**(H3.5). 서비스 계정 권한이 실제로 먹는지는
   거기서 처음 확정되고, 그것이 뒤따르는 `beta`(H5)의 선행조건이다.

`release_status: draft` 여부는 이 문제와 **무관하다** — draft로 바꿔도 edit을 못 여니 통과하지
않는다. 미확인 #4의 위험을 `release_status` 거부로만 좁혀 적었던 것을 여기서 바로잡는다.

> **일반화**: 되돌릴 수 없는 첫 등록은 자동화의 **입력**이지 산출물이 아니다. 자격증명으로
> 부르는 API는 대개 대상이 이미 존재한다고 가정한다 — 그 대상을 만드는 단계는 사람 몫으로
> 남는다. iOS에서 최종 제출 버튼을 사람에게 남긴 것과 같은 종류의 경계다.

### 착수 순서 (M1) — C와 H가 교차한다

C 블록과 H 블록은 직렬 두 덩어리가 아니다. C3의 검증에는 H2의 keystore가 필요하고, C5의
검증에는 H1.6의 서비스 계정이 필요하다. **각 작업의 검증이 어느 H 뒤에서만 가능한지가
순서를 정한다.**

```
H1   Play Console 앱 생성                    ← 앱 이름·정책 선언. 패키지명은 아직 안 정해진다
H1.5 릴리즈 공개 선행 선언 전수 확인          ← 전제면 M3-H2·H3를 H5 앞으로 당긴다
H1.6 Play 서비스 계정 발급 + 권한 부여        ← API 액세스 활성 대기가 있을 수 있어 여기서 착수
        │  (권한 전파를 기다리는 동안 코드가 돈다)
        ↓
C1   desugaring        검증: checkDebugAarMetadata + debug APK   ← release 태스크를 안 태운다(가드가 산다)
        ↓
C2   리네임            검증: debug 병합 매니페스트의 package
        ↓
H2   업로드 keystore 생성                     ← 여기서부터 release 태스크가 돌 수 있다
        ↓
C3   서명 배선 + gitignore  검증: signingReport · 가드 발동/해제
        ↓
C5   fastlane (Appfile · check_play_key · build_aab · bootstrap · beta)
        │  build_aab → 키·서명이 든 첫 release AAB (여기가 --release 검증 자리다)
        │  ⚠️ check_play_key·bootstrap·beta는 아직 못 돈다 — 패키지 미바인딩(§순서 ③)
        ↓
H3   확정용 업로드 = **콘솔에 사람이 올린다** (internal · draft)  ← 패키지명 영구 확정
        │                                                          AAB는 build_aab가 만든 것
        ↓
H3.5 check_play_key  ← 서비스 계정 권한이 실제로 먹는지가 **여기서 처음** 확정된다
        ↓
H4   Play 앱 서명 지문 수집  ───────────────→  M2-④ GCP 클라이언트 등록 (병렬로 시작)
        ↓
C4 매니페스트(+백업 선언) · C6 인앱 방침 링크 · C7 아이콘 · C8 축소 대비
     └ C9 deploy 스킬 개정 ← C5와 같은 커밋. 레인이 생긴 순간부터 스킬이 틀리다
        │
        ├─────────────────→ H6a 테스터 이메일 수집 (리드타임이 있다 — 여기서 착수)
        │                        ↓
        ↓                   H6b 콘솔 이메일 목록/그룹 생성 + 트랙에 연결
H5   비공개 테스트 첫 릴리즈 (beta) + 국가·지역 선택 → **검토 → `사용 가능`**
        ↓                        ↓
        └────────→ H6c opt-in 링크 전달 + 사람별 날짜 기록  ← 14일 시계 시작(사람마다 따로)
                            ↓                    ↓
                   H7 앱 등록 상태 확인    M2 나머지 (§M2 일정)
```

**H6a·H6b는 H5의 검토 대기와 나란히 간다.** 교사 12~16명의 Google 계정 주소를 모으는 것은
리드타임이 있는 사람 작업이고(H6a), 콘솔 목록 등록(H6b)은 릴리즈 상태와 무관하다. 기다려야
하는 것은 **H6c 하나뿐**이다 — opt-in 링크는 릴리즈가 `사용 가능`이 된 뒤에야 설치로 이어진다.
직렬로 그리면 검토 기간이 그대로 총 기간에 더해진다.

## 사람의 몫과 코드의 몫

콘솔 작업은 에이전트가 대신할 수 없고, 코드 작업은 사람이 기다릴 필요가 없다.

| | 사람이 콘솔에서 (Play Console / GCP / 로컬 키) | 코드 |
|---|---|---|
| **M1** | H1 앱 생성 · H1.5 선언 전수 확인 · **H1.6 Play 서비스 계정 발급·권한** · H2 keystore 생성(대화형 비번) · H3 확정용 업로드 · H4 Play 앱 서명 지문 수집 · H5 비공개 테스트 릴리즈 공개(국가·지역) · **H6 테스터 3단계** · H7 등록 상태 확인 | C1 desugaring · C2 리네임 · C3 서명 배선 · C4 매니페스트(+백업 선언) · C5 fastlane · C6 인앱 방침 링크 · C7 아이콘 · **C8 축소 대비** · **C9 `deploy` 스킬 개정** |
| **M2** | GCP Android OAuth 클라이언트 등록(지문마다 하나) · 에뮬레이터 이미지 설치 · 갤럭시 테스터 피드백 수집 · **테스터 과제 배분·회수**(§M2 일정) · **Play용 스크린샷 촬영·검수**(§M3-H4) | ①~⑨ 전부 |
| **M3** | 프로덕션 액세스 신청서 3섹션 · 앱 콘텐츠 선언 · 데이터 안전 양식 · 스토어 등록정보 자료 · 프로덕션 릴리즈 노트 입력 · 최종 제출 | (피드백 반영) |

**사람의 몫에서 되돌리기 어려운 것 셋**:

1. **H3 확정용 업로드** — `applicationId`가 앱에 영구 바인딩되고 **Play 앱 서명 키가
   생성된다.** H1(앱 생성)은 되돌릴 수 있다(앱 이름은 바꿀 수 있고, 업로드 전 앱은 지울 수
   있다) — 브리프가 "M1 최초 작업으로 확인. 막히면 뒤 전부가 흔들림"이라 적은 지점이 실제로는
   여기다.
2. **H2 keystore** — 파일·비밀번호 분실 = 업데이트 영구 불가.
3. **M3 최종 제출.**

iOS 레인이 `release`에서 최종 제출 버튼을 사람에게 남겨 둔 것과 같은 이유로, 이 셋은
자동화하지 않는다(H3은 레인이 빌드하고 **업로드는 사람이 콘솔에서** 한다 — 패키지가
바인딩되기 전에는 supply가 edit을 못 열기 때문이다, §순서 ③).

## M1 · 껍데기 출시

목표는 기능이 아니라 **타이머 두 개를 켜는 것**이다. M1 빌드에서 알림은 **100% 오지 않고**
CSV 공유 목록에도 뜨지 않는다 — 그게 정상이고, 테스터에게 그렇게 안내한다.

> 절 번호(`C1`~`C9` · `H1`~`H7`)는 **묶음 이름이지 착수 순서가 아니다.** 순서는 위
> §착수 순서 다이어그램이 정한다 — C4·C6·C7·C8은 H3(확정용 업로드) 뒤에 온다.

### M1-C1 · core library desugaring (빌드 차단 요인, 1번)

`flutter_local_notifications-18.0.1/android/build.gradle:24-26,40`이 desugaring을 요구하고
AAR 메타데이터가 소비 측(`:app`)에도 강제한다. **C1·C2·C3과 C5의 키 가드는 같은 파일 하나**를
고치므로 전문으로 적는다(`namespace`·`applicationId`는 C2의 값이 반영된 상태).

⚠️ **전문을 한 번에 넣으면 C1 시점에 release 가드 둘이 이미 살아 있다.** 그래서 C1의 검증은
`--release`를 태우지 않는다 — 가드가 잡는 것이 정상이므로 그 실패로는 desugaring을 판정할 수
없다. `--release` 산출물 검증은 **H2(keystore) 뒤 C5**에 있다.

```kotlin
// android/app/build.gradle.kts — 전문
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// [C3] 업로드 키는 리포 밖에 둔다(iOS `.p8`과 같은 규칙).
// android/key.properties(이미 .gitignore 처리됨)가 keystore 경로와 비밀번호를 가리킨다.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) keystorePropertiesFile.inputStream().use { load(it) }
}

// [C5] flutter가 넘긴 dart-define를 되읽는다.
// `flutter build`는 `-Pdart-defines=<base64("KEY=VALUE")>,<…>` 형태로 넘기고
// (flutter_tools/lib/src/build_info.dart:368 `toGradleConfig`, 인코딩은 :1081·:1095
//  `utf8 → base64`, 구분자는 `,`), Flutter Gradle 플러그인이 같은 이름으로 읽는다
// (FlutterPlugin.kt:597 `project.findProperty("dart-defines")`).
val dartDefines: Map<String, String> =
    ((project.findProperty("dart-defines") as String?) ?: "")
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { encoded ->
            runCatching {
                String(java.util.Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
                ?.split("=", limit = 2)
                ?.takeIf { it.size == 2 }
                ?.let { it[0] to it[1] }
        }
        .toMap()
val hasTagoKey = dartDefines["TAGO_KEY"].orEmpty().isNotEmpty()

android {
    namespace = "com.planroutine.app"          // [C2]
    compileSdk = flutter.compileSdkVersion     // 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // [C1] flutter_local_notifications 18.0.1이 AAR 메타데이터로 :app에도 요구한다.
        // 없으면 :app:checkDebugAarMetadata / :app:checkReleaseAarMetadata에서 죽는다.
        // AGP는 이 요구를 "전파"하지 않는다 — 검사해서 실패시킨다.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.planroutine.app"  // [C2] iOS 번들과 통일. 영구 확정
        minSdk = flutter.minSdkVersion         // 24
        // ⚠️ 하드코딩으로 내리지 말 것 — 2026-08-31부터 Play 신규/업데이트는 API 36 하한이다.
        targetSdk = flutter.targetSdkVersion   // 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // [C3] key.properties가 있을 때만 release 서명 설정을 만든다.
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // [C3] debug 키 고정 → release 키. 없으면 debug로 떨어지되 아래 가드가
            // release 태스크를 막는다(디버그 빌드는 계속 돌아간다).
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // [C1] 2.1.5로 실측 통과. 플러그인 README의 1.2.2는 AGP 7.3.1 시절 문구다.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// [C3][C5] release 산출물이 **서명 키 없이** 또는 **TAGO 인증키 없이** 나가는 것을 막는다.
// CLAUDE.md의 "키 빠진 IPA가 조용히 심사에 오른다" 함정의 Android판 예방이고, iOS와 달리
// **빌드 자체가 막힌다** — 레인을 우회해 손으로 쳐도 걸린다(그것이 관통 원칙 ①의 실효다).
gradle.taskGraph.whenReady {
    if (allTasks.none { it.name.endsWith("Release") }) return@whenReady

    if (!hasReleaseKeystore) {
        throw GradleException(
            "android/key.properties가 없습니다. 업로드 키 없이 release를 만들 수 없습니다.\n" +
                "  keystore: ~/.android/keystores/planroutine-upload.jks",
        )
    }
    if (!hasTagoKey) {
        throw GradleException(
            "TAGO_KEY dart-define가 비어 있습니다. 버스 기능이 죽은 release를 만들 수 없습니다.\n" +
                "  ./android/bin/fastlane.sh build_aab 으로 빌드하십시오" +
                "(레인이 ~/.planroutine/tago.env 를 읽어 --dart-define-from-file로 넘깁니다).",
        )
    }
}

flutter {
    source = "../.."
}
```

**Flutter 공식 문서 스니펫을 그대로 쓰지 말 것.** 공식 예제는 `keystoreProperties["keyAlias"] as String`
형태라 `key.properties`가 없으면 **debug 빌드까지 죽는다**. 위 형태는 파일이 없어도 debug가
돌아가고 release만 막힌다 — 서명 키가 없는 기기(CI·다른 사람)에서 앱을 실행해 볼 수는 있어야 한다.

- 속성 이름은 `.kts`에서 **`isCoreLibraryDesugaringEnabled`** 다(`gradle-api-8.11.1.jar`의
  `CompileOptions.setCoreLibraryDesugaringEnabled`). Groovy DSL의 `coreLibraryDesugaringEnabled`를
  `.kts`에 그대로 쓰면 컴파일되지 않는다.
- `minSdk = 24`라 `multiDexEnabled`는 불필요하다(native multidex는 API 21+).
- `--configuration-cache`는 이 스택에서 **애초에 켜지지 않는다**(Flutter Gradle 플러그인의
  `DependencyVersionChecker`가 직렬화 불가). 위 `whenReady` 가드가 원인이 아니다.

**검증 — `--release`를 태우지 않는다**
```bash
cd android && ./gradlew :app:checkDebugAarMetadata     # BUILD SUCCESSFUL (직전엔 여기서 죽었다)
cd .. && flutter build apk --debug                     # ✓ Built app-debug.apk
```
- `compileOptions`는 variant와 무관하므로 **debug 메타데이터 통과가 곧 설정 성공의 증거**다.
- **`checkReleaseAarMetadata`를 검증에 넣지 않는다.** 초안은 "가드가 `Release`로 끝나는 태스크만
  보고 `checkReleaseAarMetadata`는 `Metadata`로 끝나니 안 걸린다"고 적었는데 **틀렸다** — 가드는
  태스크 **그래프 전체**를 보고, 실측하면 그 그래프에 `compileFlutterBuildRelease`·
  `packJniLibsflutterBuildRelease`가 들어 있다(`--dry-run --offline`으로 45개 태스크 확인).
  `endsWith("Release")`가 참이 되어 가드가 발동한다. C1 시점에는 `key.properties`가 아직 없으므로
  (H2는 뒤다) 나오는 메시지는 TAGO가 아니라 **업로드 키 메시지**다 — 데수가링을 확인하러 온
  사람이 "업로드 키가 없습니다"를 받고 원인을 오진한다.
- debug는 설계 의도대로 안전하다: `:app:assembleDebug --dry-run`의 그래프에 `…Release`로 끝나는
  태스크가 **0개**라 일상 debug 빌드는 막히지 않는다(실측).
- release 메타데이터는 C5가 만드는 첫 AAB가 함께 증명한다 — 그때는 keystore와 키 주입 경로가
  둘 다 있어 가드를 정상 통과한다.
- `flutter build appbundle --release`는 **여기서 돌리지 않는다.** keystore(H2)도 TAGO 키 주입
  경로(C5)도 아직 없어 가드 둘에 반드시 걸린다.

2.1.5 미만 버전으로도 되는지는 **미확인**이다(1.2.2·2.0.x 미검증). 하한을 실험할 이유는 없다.

### M1-C2 · 리네임 (`com.schedulenote.schedule_app` → `com.planroutine.app`)

```bash
# 3곳: build.gradle.kts 2줄(위에 반영) + Kotlin 디렉터리 + package 선언
mkdir -p android/app/src/main/kotlin/com/planroutine/app
git mv android/app/src/main/kotlin/com/schedulenote/schedule_app/MainActivity.kt \
        android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt
rmdir -p android/app/src/main/kotlin/com/schedulenote/schedule_app 2>/dev/null || true
# MainActivity.kt 첫 줄: package com.planroutine.app
```

매니페스트의 `android:name=".MainActivity"`는 **namespace 상대라 수정하지 않는다.**

**검증**: `flutter build apk --debug` 통과 + 병합 매니페스트의 `package`가
`com.planroutine.app`인지 확인.
```bash
grep -o 'package="[^"]*"' \
  build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml
# ⚠️ 경로를 debug로 좁힌다. `*/*` 글로브로 두면 **리네임 전에 만들어진 release 병합본**까지
#    물어 옛 패키지명이 함께 출력된다(debug 빌드는 release 산출물을 갱신하지 않는다).
#    실측: 리네임 전 release 병합본에 package="com.schedulenote.schedule_app"가 남아 있었다.
```

### M1-C3 · 서명 (keystore는 리포 밖)

```bash
mkdir -p ~/.android/keystores
keytool -genkeypair -v \
  -keystore ~/.android/keystores/planroutine-upload.jks \
  -alias planroutine-upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=PlanRoutine, OU=PlanRoutine, O=PlanRoutine, L=Seoul, ST=Seoul, C=KR"
# storepass / keypass를 대화형으로 묻는다. -storepass 플래그를 쓰면 셸 히스토리에 남는다.
```

- **`-storetype`을 생략한다.** JDK 17 기본이 PKCS12이고, Flutter 문서의 `-storetype JKS`를 쓰면
  매 실행 `JKS 키 저장소는 고유 형식을 사용합니다 … PKCS12로 이전하는 것이 좋습니다` 경고가 붙는다.
  PKCS12 `.jks`가 Gradle 서명 + `keytool -printcert -jarfile`을 통과함을 실측 확인했다.
  (Play가 받아들이는지는 H3 업로드에서 확정 — AAB 안에는 keystore 포맷이 아니라 서명 블록만
  들어가므로 거부될 이유는 없다.)
- `-validity 10000` → 만료 **2053-12-17**. Google 요건 둘을 모두 만족한다(≥25년, 2033-10-22 이후).
- ⚠️ **이 파일과 비밀번호를 잃으면 앱 업데이트가 영구 불가다.** 리포 밖 + 별도 백업.

```properties
# android/key.properties — 커밋되지 않는다(android/.gitignore:12에 이미 있다)
storeFile=/Users/kwangsukim/.android/keystores/planroutine-upload.jks
storePassword=<발급 시 정한 비밀번호>
keyAlias=planroutine-upload
keyPassword=<발급 시 정한 비밀번호>
```

**`~`는 확장되지 않는다** — 절대경로로 쓸 것(Java `Properties`도 Gradle `file()`도 틸데를 모른다).
상대경로는 `android/app/`을 기준으로 풀린다.

**gitignore는 서명 쪽은 이미 끝나 있다**(`android/.gitignore`의 `key.properties`·`**/*.jks`·
`**/*.keystore`·`/local.properties` — `git check-ignore -v`로 확인). 뚫린 것만 더한다:

```gitignore
# android/.gitignore 끝에
/.kotlin                      # Kotlin 2.x 빌드 세션. 실제로 빌드마다 생성된다
/vendor/                      # bin/fastlane.sh가 `bundle config set --local path vendor/bundle`
/.bundle/                     #   + bundle install을 돌린다(ios/bin/fastlane.sh:24-28) → 수천 파일
```
`/vendor/`·`/.bundle/`는 **wrapper를 복제하는 순간 생긴다.** `ios/.gitignore:15-16`에는 둘 다
있고 `android/.gitignore`에는 없다 — 복제한 것은 스크립트인데 그 스크립트가 만드는 파일을
가리는 규칙은 복제되지 않았다.

```gitignore
# 루트 .gitignore — Fastlane 블록에
android/fastlane/report.xml
android/fastlane/README.md
android/fastlane/Preview.html
android/fastlane/metadata/     # 레인이 docs/release_notes/에서 생성한다(§C5). 파생물이다

# 루트 .gitignore — Play 배포 비밀 (원본은 iOS `.p8`처럼 리포 밖에 둔다)
android/fastlane/*.json
android/play-store-*.json
**/*.pepk
**/*.p12
```
`android/fastlane/Appfile`은 **커밋한다** — 서비스 계정 JSON의 *경로*만 들고 있고 비밀이
아니다(iOS `Appfile`이 team_id를 커밋해 둔 것과 같은 성질). 위 `*.json`이 실수로 리포 안에
떨어진 키를 잡는다.

**검증 — 산출물은 아직 만들지 않는다**
```bash
cd android && ./gradlew :app:signingReport | grep -A3 "Variant: release"
#   Config: release / Alias: planroutine-upload / SHA1: …
mv android/key.properties /tmp/ && cd android && ./gradlew :app:assembleRelease
#   가드 발동 → BUILD FAILED (한국어 서명 키 메시지)
mv /tmp/key.properties android/            # ← 복구. 다음 줄이 이 파일을 필요로 한다
cd android && ./gradlew :app:assembleRelease
#   되돌린 뒤에도 BUILD FAILED — 이번엔 **TAGO 키 메시지**다(C5의 가드).
#   두 메시지를 순서대로 본 것이 "가드 둘이 각각 산다"의 증거다.
```
`signingReport`는 서명 설정만 읽고 산출물을 만들지 않으므로 가드에 걸리지 않는다.
**AAB 서명 지문 일치 확인(`keytool -printcert -jarfile`)은 C5로 옮긴다** — 거기가 레인으로
만든 첫 release AAB가 나오는 자리다.

이 기기의 **debug 키 SHA-1은 `9F:9B:B9:64:3B:11:84:13:9D:C6:79:93:EA:A2:DE:51:DB:95:8A:84`**
(비밀이 아니다 — 모든 debug APK에 공개). M2-④에서 이것도 등록한다.

### M1-C4 · 매니페스트 (INTERNET 명시화 + 백업 선언)

```xml
<!-- android/app/src/main/AndroidManifest.xml — <manifest> 바로 아래 -->
<!-- 버스 공공데이터 + Google Calendar API.
     실측: 지금은 google_sign_in_android 6.2.1이 매니페스트 병합으로 넣어줘 release AAB에
     이미 들어 있다. 그러나 그 플러그인이 빠지면 조용히 사라지고, 버스 카드는 화면에
     "버스 정보를 불러올 수 없어요"만 띄워 사후 진단이 어렵다. 그래서 명시한다. -->
<uses-permission android:name="android.permission.INTERNET" />
```

#### 백업 — 켠다. 그리고 **켰다고 적는다**

현재 `<application>`의 속성은 `label`·`name`·`icon` 셋뿐이라 `android:allowBackup`이
**없다 = 기본 true**다. 그 상태로 출시하면 Android Auto Backup이 `planroutine.db`(1년치 업무
일정)와 `shared_prefs/FlutterSharedPreferences.xml`을 사용자 **본인** Google Drive로 보낸다.

```xml
<application
    android:label="공직플랜"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    <!-- 기기를 바꿔도 1년치 일정이 복원된다. 교사에게 실질 가치가 크고, iOS의 iCloud
         백업이 이미 같은 성질이라 방침 한 문단이 양쪽을 덮는다.
         ⚠️ **기본값에 맡기지 않고 명시한다.** "정하지 않아 기본값으로 출시된 것"과
            "정해서 켠 것"은 다르고, 이 한 줄이 §M3-H3 데이터 안전 답안의 전제다.
            뒤집으면 그 양식도 함께 뒤집어야 한다. -->
    android:allowBackup="true">
```

**제외 규칙(`dataExtractionRules`·`fullBackupContent`)은 만들지 않는다.** 버스 정류장 설정이
생활 반경 정보라 제외 후보였고, 실제로 검토했다 — **키 단위로는 제외할 수 없다.**

- `shared_preferences`의 Android 구현은 **키 전부를 파일 하나에** 담는다:
  `LegacySharedPreferencesPlugin.java:34`의 `SHARED_PREFERENCES_NAME = "FlutterSharedPreferences"`
  → `shared_prefs/FlutterSharedPreferences.xml`. Auto Backup 규칙의 단위는 **파일**이므로
  (`<exclude domain="sharedpref" path="…"/>`) 버스 설정만 빼는 것이 불가능하다.
- 그 파일을 통째로 빼면 **알림 설정·완료 도장·화면 테마·힌트 dismiss·버스 설정이 전부**
  기기 교체 때 초기화된다. 정류장 하나를 가리려고 나머지 넷을 잃는 교환이다.
- 그리고 가리는 대상이 **사용자 본인의 클라우드**다. CLAUDE.md가 정류장 이름을 익명 라벨로
  적게 한 것은 **리포·문서·화면이 개발자의 생활 반경을 남에게 드러내는 것**을 막는 규칙이고,
  사용자 본인 기기의 백업은 그 규칙이 겨냥한 대상이 아니다.
- **정말 빼야 할 날이 오면 고칠 곳은 규칙 파일이 아니다** — 버스 설정을 별 저장소로 분리해야
  한다(`shared_preferences`를 두 파일로 쓰거나 DB 테이블로 옮기는 변경). 그 비용을 알고
  안 하는 것이다.
- minSdk 24라 규칙을 쓰려면 `fullBackupContent`(API 24–30)와 `dataExtractionRules`(31+)를
  **둘 다** 둬야 한다는 점도 판단에 넣었다 — 아무것도 제외하지 않을 규칙 파일 두 장은
  과잉이다.

⚠️ 기본 제외 대상은 그대로 유효하다 — Auto Backup은 `cacheDir`를 빼므로 M2-②의
`cache/shared_csv`와 `file_picker` 캐시는 애초에 안 나간다. `databases/`는 **나간다.**
살아 있는 SQLite를 파일째 복사해 복원본이 깨지는 함정은 알려져 있지만, Auto Backup은
기기가 유휴·충전 중일 때 앱 프로세스가 뜨지 않은 상태로 돌므로 위험이 낮다고 본다 —
**실증하지 않았다**(§미확인).

이 결정에 따라오는 것 둘, 둘 다 별 작업으로 세운다:

- **처리방침에 기기 백업 절**(§M2-⑨) — Android Auto Backup / iOS iCloud 백업으로 일정
  데이터의 사본이 사용자 본인 클라우드에 생긴다는 사실.
- **데이터 안전 양식은 "전송을 인정하는 답안"으로 확정**(§M3-H3 · §결정 E). 켠 것을 알면서
  "전송되지 않음"이라고 답하는 것은 정책 불일치이고 앱이 내려갈 수 있다.

**나머지는 M1에서 이것뿐이다.** `POST_NOTIFICATIONS`·`VIBRATE`는 `flutter_local_notifications`가
자체 매니페스트로 선언해 병합되므로 **적지 않는다**(적으면 중복 선언이 아니라, 플러그인이
관리하는 것을 앱이 이중 관리하는 상태가 된다). 알림 receiver 둘과 인텐트 필터는 M2다.

**절대 넣지 않는 것**: `SCHEDULE_EXACT_ALARM` · `USE_EXACT_ALARM`.
브리프가 고른 `inexactAllowWhileIdle`은 `checkCanScheduleExactAlarms`를 거치지 않으므로
(`FlutterLocalNotificationsPlugin.java:740-756`의 else 분기) 필요가 없고, 넣는 순간 Play
고위험 권한 선언 양식 대상이 된다("Apps must only declare this permission if their core
functionality supports the need for an exact alarm").

**검증은 소스를 본다 — 병합본으로는 이 작업을 판정할 수 없다.**
C4의 목적은 "플러그인이 빠지면 INTERNET이 조용히 사라진다"를 막는 것이고, 그 플러그인이
아직 있으므로 **병합 결과는 C4 적용 전후가 동일하다.** 병합본만 보는 검증은 작업을 안 해도
통과한다(실측: C4 미적용 상태의 release 병합본에 이미 아래 5개가 들어 있다).

```bash
# ① 이 작업의 판정 — 소스에 줄이 있는지
grep -c 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml   # 1
grep -c 'android:allowBackup="true"' android/app/src/main/AndroidManifest.xml    # 1
#   백업도 같은 성질이다 — 기본값이 이미 true라 **병합본으로는 명시 여부를 못 가린다.**

# ② 회귀 확인 — 병합 결과가 늘거나 줄지 않았는지
grep -o 'uses-permission android:name="[^"]*"' \
  build/app/intermediates/merged_manifest/release/*/AndroidManifest.xml
# READ_CALENDAR WRITE_CALENDAR INTERNET VIBRATE POST_NOTIFICATIONS   ← 5개
# + com.planroutine.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION     ← androidx signature 1개
# (RECEIVE_BOOT_COMPLETED는 M2에서 추가되어 6개가 된다)
```
⚠️ androidx가 넣는 signature 권한은 **`applicationId` 접두를 쓴다.** C2 리네임 전 실측값은
`com.schedulenote.schedule_app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`이었다 — 리네임 뒤
이 문자열이 바뀌는 것이 정상이다.

### M1-C5 · fastlane — 손으로 빌드하는 경로를 만들지 않는다

관통 원칙 ①. 수동 `flutter build appbundle`에는 `--dart-define-from-file`이 없어 **TAGO 키가
빠진 AAB**가 나오고, 화면에는 `버스 정보를 불러올 수 없어요`만 떠서 사후 진단이 어렵다.

```
android/
├── Gemfile                 # fastlane 고정 (iOS와 별 Ruby 번들)
├── bin/fastlane.sh         # Homebrew Ruby 주입 wrapper (ios/bin/fastlane.sh 복제)
└── fastlane/
    ├── Appfile             # package_name + 서비스 계정 JSON 경로 (커밋한다)
    ├── Fastfile            # check_tago_key · check_play_key · build_aab · bootstrap · beta
    └── metadata/           # 레인이 docs/release_notes/에서 생성 (gitignore)
```

`android/bin/fastlane.sh`는 `ios/bin/fastlane.sh`를 그대로 복제하고 주석의 경로만 바꾼다
(`cd "$(dirname "$0")/.."`가 `android/`를 가리키므로 나머지는 동일).

#### 레인을 셋으로 쪼갠다 — 빌드와 업로드는 다른 일이다

한 덩어리 `beta`(버전코드 조회 → clean → 빌드 → 업로드)로 두면 **업로드를 뺀 실행 경로가
존재하지 않는다.** 그러면 (a) 첫 업로드가 API에 막혔을 때의 "콘솔 수동 업로드" 폴백이
말뿐이고, (b) M1 스모크에 쓸 AAB를 만들 방법이 없고, (c) Play 인증이 아직 안 풀린 동안
빌드를 검증할 수 없다.

| 레인 | 하는 일 | Play 인증 | 파괴적 |
|---|---|---|---|
| `check_tago_key` | TAGO 키 파일 확인 | 불필요 | 없음 |
| `check_play_key` | 서비스 계정 JSON + 트랙 4개 versionCode 조회. **H3 뒤에만 돈다**(H3.5) | **필요** | 없음 |
| `build_aab` | 가드 → clean → release AAB | 불필요 | clean |
| `bootstrap` | `build_aab` + internal·draft 업로드. ⚠️ **H3(첫 업로드)에는 쓸 수 없다** — 패키지 미바인딩 상태에서 `insert_edit`이 404다(§순서 ③). 바인딩 뒤 internal 재업로드용 | 필요 | clean |
| `beta` | 가드 → versionCode 계산 → `build_aab` → 비공개 테스트 업로드 | 필요 | clean |

#### `android/fastlane/Appfile`

```ruby
# android/fastlane/Appfile
package_name("com.planroutine.app")

# Play Developer API 인증. 원본은 리포 밖에 둔다(iOS `.p8`과 같은 규칙).
#
# 경로는 `.claude/skills/deploy/SKILL.md`가 이미 차단 요인 3번으로 적어 둔 값을 그대로
# 쓴다 — 운영 문서와 레인이 다른 경로를 말하면 다음 사람이 키를 두 곳에 만든다.
json_key_file(File.expand_path("~/.google_play/service_account.json"))
```

`supply` 계열 액션(`upload_to_play_store`·`google_play_track_version_codes`)은 `json_key`의
기본값을 `AppfileConfig.try_fetch_value(:json_key_file)`에서 가져온다
(`supply/lib/supply/options.rb:99`) — 그래서 **Appfile 한 곳에 두면 두 액션이 함께 인증된다.**
`json_key:`를 액션마다 쓰지 않는 이유다.

⚠️ **이 파일이 없으면 레인은 TAGO 가드를 지나 `flutter clean`까지 간 뒤 인증에서 죽는다.**
그래서 파일 존재 검사를 **clean 앞 첫 줄**에 둔다(아래 `assert_play_key`).

```ruby
# android/fastlane/Fastfile
default_platform(:android)

require "json"
require "tmpdir"
require "fileutils"

APP_PACKAGE = "com.planroutine.app"
AAB_PATH = "../build/app/outputs/bundle/release/app-release.aab"   # cwd = android/

# 비공개 테스트 트랙 identifier.
#
# Play Console이 처음부터 제공하는 트랙 넷의 API identifier는 고정이다 —
# 내부 테스트 `internal` / **비공개 테스트 `alpha`** / 공개 테스트 `beta` /
# 프로덕션 `production`(supply/lib/supply.rb:30-38의 `Tracks`가 같은 넷을 상수로 든다).
# **그래서 비공개 테스트 트랙을 새로 만들지 않고 기본 제공 트랙을 쓴다** — 새로 만들면
# identifier가 콘솔이 정하는 값이 되고, 그 값을 API로 열거하는 fastlane 액션이 없다.
CLOSED_TRACK = "alpha"

# versionCode를 계산할 때 훑는 트랙.
#
# `google_play_track_version_codes`는 **그 트랙만** 본다 — iOS의
# `latest_testflight_build_number`(계정 스코프)와 대칭이 아니다. 한 트랙만 보면
# §순서 ③의 확정용 업로드(internal)나 콘솔 수동 업로드가 남긴 코드를 못 보고
# `Version code N has already been used`로 튕긴다.
VERSION_SCAN_TRACKS = %w[internal alpha beta production].freeze

# ── 공통 헬퍼 ──
# TAGO 인증키를 리포 밖에서 읽는다. 키를 못 읽으면 레인을 실패시킨다.
#
# ⚠️ 이 15줄은 ios/fastlane/Fastfile:11-26의 복제다. iOS 배포 경로가 이미 돌고 있어
#    공용 파일로 뽑는 리팩터를 하지 않았다(그 경로를 건드리는 위험이 이득보다 크다).
#    **키 값 자체는 여전히 한 곳에만 있다** — ~/.planroutine/tago.env. 재발급 시
#    갱신할 파일은 하나이고, 복제된 것은 그 파일을 읽는 코드뿐이다.
def tago_key
  path = File.expand_path("~/.planroutine/tago.env")
  UI.user_error!("TAGO 키 파일이 없습니다: #{path}") unless File.exist?(path)

  key = File.readlines(path).map(&:strip)
           .find { |l| l.start_with?("TAGO_KEY_DECODING=") }
           &.split("=", 2)&.last&.strip
  UI.user_error!("TAGO_KEY_DECODING 이 비어 있습니다: #{path}") if key.nil? || key.empty?
  key
end

# Play 서비스 계정 JSON이 **있는지만** 본다. 인증이 실제로 먹는지는 API 호출이 답한다
# (`check_play_key`). 이 가드의 존재 이유는 clean 앞에서 값싸게 죽는 것이다 —
# 없으면 레인이 TAGO 가드를 지나 `flutter clean`(수 분, 되돌릴 수 없음)까지 간 뒤
# 인증에서 죽는다.
#
# 경로를 Fastfile에 다시 적지 않고 Appfile에서 읽는다 — 두 곳에 쓰면 한쪽만 고친다.
def play_json_path
  path = CredentialsManager::AppfileConfig.try_fetch_value(:json_key_file)
  UI.user_error!("android/fastlane/Appfile에 json_key_file이 없습니다") if path.to_s.empty?
  File.expand_path(path)
end

def assert_play_key
  path = play_json_path
  unless File.exist?(path)
    UI.user_error!(
      "Play 서비스 계정 JSON이 없습니다: #{path}\n" \
      "  Play Console › 설정 › API 액세스에서 발급해 리포 밖에 두십시오(§M1-H1.6)."
    )
  end
  path
end

# 업로드 키 설정이 있는지. gradle 가드가 같은 것을 보지만 그건 clean·설정 단계 뒤에 터진다.
def assert_release_keystore
  path = File.expand_path("../key.properties", __dir__)   # android/key.properties
  unless File.exist?(path)
    UI.user_error!("android/key.properties가 없습니다 (§M1-C3). 업로드 키 없이 release를 만들 수 없습니다.")
  end
  path
end

# debug 산출물이 release 빌드로 새는 두 경로를 막는다. iOS `reset_ios_caches`(함정 #6)와
# 같은 성격이고, 근거는 실측 두 건이다.
#
#  (a) android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
#      debug 빌드는 integration_test(dev dependency)를 registrant에 심는데, gradle release는
#      그 서브프로젝트를 뺀다(PluginHandler.kt:133) → javac 실패:
#        GeneratedPluginRegistrant.java:49: package dev.flutter.plugins.integration_test
#        does not exist
#      **이 파일은 소스 위치에 있고 `flutter clean`이 건드리지 않는다.** 실제로 막는 것은
#      아래 빌드에 `--no-pub`을 붙이지 않아 pub get이 재생성하는 것이고, 여기서 먼저 지우는
#      것은 "덮어썼는지"를 추측하지 않기 위해서다. 재생성이 안 되면 javac가 **큰 소리로**
#      죽는다 — 조용히 dev dependency가 섞이는 것보다 낫다. (gitignore돼 있다.)
#  (b) build/native_assets/android/jniLibs/
#      sqlite3(← sqflite_common_ffi, dev dependency)가 스테이징한 libsqlite3.so를
#      mergeReleaseJniLibFolders가 그대로 담는다. 실측 release APK 70.4MB → 65.3MB.
#      **`flutter clean`이 `build/` 전체를 지우므로**(clean.dart:52-53) 별도 rm이 필요 없다.
#
# ⚠️ `android/.gradle`·`android/app/build`·`build/native_assets`를 지우는 형태는 셋 다 헛것이다:
#    `android/app/build`는 **존재하지 않고**(Flutter가 빌드 디렉터리를 리포 루트 `build/app/`으로
#    돌린다 — 실측), `build/native_assets`는 직전 `flutter clean`이 이미 지웠고, `android/.gradle`은
#    유출과 무관한 Gradle 캐시라 지우면 매 빌드가 몇 분 느려질 뿐이다. **지울 것은 registrant
#    하나다** — 목록을 늘리면 무엇이 왜 있는지 흐려져 다음 사람이 틀린 쪽을 정리한다.
def reset_android_caches
  UI.header("Android 캐시 정리 — debug 산출물 유입 차단")
  project_root = File.expand_path("../..", __dir__)
  Dir.chdir(project_root) do
    sh("flutter", "clean")   # build/ + .dart_tool/ 삭제 → 이어지는 빌드가 pub get을 재수행
    sh("rm", "-f", "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
  end
end

# pubspec.yaml의 `version: X.Y.Z+N`. iOS Fastfile:67-73의 복제이고, 이유도 같다 —
# 돌고 있는 iOS 배포 경로를 건드리지 않는다. **값의 출처는 여전히 pubspec 하나다.**
def pubspec_version
  project_root = File.expand_path("../..", __dir__)
  pubspec = File.read(File.join(project_root, "pubspec.yaml"))
  match = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/)
  UI.user_error!("pubspec.yaml에서 version을 찾을 수 없습니다") unless match
  [match[1], match[2].to_i]
end

# versionCode. **트랙 전수의 최대값 + 1**을 쓰고, pubspec의 `+N`을 하한으로 둔다.
#
# ⚠️ android/local.properties의 flutter.versionCode를 원천으로 읽지 말 것 —
#    매 빌드가 pubspec 값으로 덮어쓴다.
def next_version_code
  # ⚠️ 트랙별로 rescue 한다. fastlane의 404 흡수는 `get_edit_track`의
  #    trackEmpty/Track not found 뿐이고(`client.rb:498-501`), 성공 경로에는 nil 방어가 없다 —
  #    `return result.releases.flat_map(&:version_codes) || []`에서 `|| []`가 flat_map **결과**에
  #    붙어 있어 `result.releases`가 nil이면 NoMethodError다. VERSION_SCAN_TRACKS는 릴리즈가
  #    한 번도 없었을 트랙(beta·production)까지 의도적으로 훑으므로 그 트랙이 "404가 아니라
  #    릴리즈 없는 200"으로 답하면 모든 업로드 레인이 Ruby 스택트레이스로 죽는다.
  codes = VERSION_SCAN_TRACKS.flat_map do |track|
    begin
      google_play_track_version_codes(package_name: APP_PACKAGE, track: track) || []
    rescue StandardError => e
      UI.important("트랙 #{track} 조회 실패 — 0으로 본다: #{e.class}")
      []
    end
  end
  _name, floor = pubspec_version
  new_code = [floor, (codes.max || 0) + 1].max
  UI.message("versionCode: 트랙 최대 #{codes.max.inspect} / pubspec 하한 #{floor} → #{new_code}")
  new_code
end

# 릴리즈 노트를 supply가 읽는 자리에 깔아 둔다. 원천은 iOS와 **같은 파일**이다.
#
# supply는 changelog를 `<metadata_path>/<언어>/changelogs/<versionCode>.txt`에서 읽는다
# (`supply/lib/supply/uploader.rb:239`). 그리고 `skip_upload_metadata`는 **changelog를
# 포함하지 않는다** — 옵션 설명 verbatim: "Whether to skip uploading metadata, changelogs
# not included"(`options.rb:196`). 그래서 스토어 등록정보 본문은 건드리지 않으면서
# 릴리즈 노트만 올릴 수 있다.
#
# 파일이 없으면 changelog 없이 올린다. Play는 릴리즈 노트를 필수로 요구하지 않으므로
# iOS 가드 E처럼 막지 않는다 — 막으면 M1 껍데기 업로드가 문구 작성에 걸린다.
#
# ⚠️ **그런데 지금은 "없음"이 아니다.** pubspec이 `1.3.0+52`이고
# `docs/release_notes/1.3.0.ko.txt`가 **이미 있다** — 내용은 iOS v1.3.0(버스 카드) 문구다.
# 그대로 두면 M1 껍데기 빌드가 그 문구를 달고 테스터에게 간다: 있지도 않은 버스 카드 개선을
# 알리고, 정작 알려야 할 "알림은 아직 오지 않습니다 / 14일 연속 opt-in을 유지해 주세요"는
# 어디에도 없다. **테스터에게 자동으로 닿는 유일한 채널이 이것이므로** M1에서는
# `docs/release_notes/1.3.0-android-m1.ko.txt`처럼 Android M1 전용 파일을 만들어
# `ANDROID_NOTE_SUFFIX`로 먼저 찾게 하거나(없으면 기존 파일로 폴백), H6c의 opt-in 안내
# 이메일에 그 문장을 싣는다. **어느 쪽인지 C5에서 정하고 적어 둔다.**
def stage_changelog(version_code)
  name, _code = pubspec_version
  src = File.expand_path("../../docs/release_notes/#{name}.ko.txt", __dir__)
  unless File.exist?(src)
    UI.important("릴리즈 노트 없음 → changelog 없이 올린다: #{src}")
    return nil
  end
  dir = File.join(__dir__, "metadata/android/ko-KR/changelogs")
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, "#{version_code}.txt"), File.read(src).strip)
  UI.message("changelog 준비: ko-KR/#{version_code}.txt")
  File.join(__dir__, "metadata/android")
end

platform :android do
  desc "TAGO 키만 확인 (빌드·업로드·clean 없음)"
  lane :check_tago_key do
    UI.success("TAGO 키 OK: #{tago_key.length}자")
  end

  desc "Play 서비스 계정과 트랙만 확인 (빌드·업로드·clean 없음)"
  lane :check_play_key do
    UI.success("서비스 계정 JSON OK: #{assert_play_key}")
    VERSION_SCAN_TRACKS.each do |track|
      codes = google_play_track_version_codes(package_name: APP_PACKAGE, track: track)
      UI.message("  #{track.ljust(11)} versionCodes=#{codes.inspect}")
    end
  end

  desc "release AAB만 만든다 (업로드 없음). 스모크·폴백·검증이 여기서 나온다"
  lane :build_aab do |options|
    # 값싼 가드를 파괴적 단계(clean) 앞에 모으는 iOS 레인의 규칙 그대로다.
    key = tago_key
    assert_release_keystore
    UI.message("TAGO 키: #{key.length}자 주입")

    code = options[:code]   # nil이면 flutter가 pubspec의 +N을 쓴다

    reset_android_caches

    Dir.mktmpdir do |tmp|
      # 키를 argv에 실으면 fastlane의 `sh`가 실행 전에 명령 문자열을 그대로 찍는다.
      # 파일 경로만 넘기면 echo·에러 양쪽에서 키가 사라진다(iOS와 같은 이유).
      define_file = File.join(tmp, "tago.json")
      File.write(define_file, JSON.generate({ "TAGO_KEY" => key }))

      Dir.chdir("..") do
        # ⚠️ --no-pub 을 붙이지 않는다. registrant 재생성이 `if (!shouldRunPub) return;`로
        #    막혀 있어(flutter_command.dart:1963-1971) dev dependency가 release javac로
        #    흘러들어간다. 위 (a)를 레인이 스스로 재현하게 되는 플래그다.
        # ⚠️ --verbose 를 붙이지 않는다. 붙이면 flutter assemble 명령줄이
        #    ~/.gradle/daemon/<ver>/daemon-<pid>.out.log 에 --DartDefines=<base64>로
        #    남는다(실측). 권한 0600이라 iOS의 Generated.xcconfig(0644)보다 등급은
        #    낮지만 로그는 몇 달씩 지워지지 않는다.
        args = ["flutter", "build", "appbundle", "--release",
                "--dart-define-from-file=#{define_file}"]
        args << "--build-number=#{code}" if code
        sh(*args)
      end
    end

    UI.success("AAB 준비 완료#{code ? " (versionCode #{code})" : ''}")
    code
  end

  desc "패키지명 확정용 첫 업로드 — internal 트랙 draft. 테스터에게 가지 않는다 (§순서 ③)"
  lane :bootstrap do
    assert_play_key
    code = next_version_code
    build_aab(code: code)

    # internal·draft를 고정으로 박는다. 트랙을 옵션으로 받으면 실수로 실제 beta를
    # internal에 올릴 수 있고, 그때 14일이 하루도 세지 않는다.
    upload_to_play_store(
      package_name: APP_PACKAGE,
      track: "internal",
      release_status: "draft",
      aab: AAB_PATH,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
    UI.success("확정용 업로드 완료 (internal·draft, versionCode #{code}) — 패키지명이 확정됐다")
  end

  desc "비공개 테스트 트랙에 새 빌드 업로드"
  lane :beta do
    # ── 값싼 가드 셋을 clean 앞에 모은다 ──
    assert_play_key            # ① 파일 존재
    key = tago_key             # ②
    assert_release_keystore    # ③
    UI.message("TAGO 키: #{key.length}자 확인")

    # ④ 여기서 처음 네트워크를 쓴다 — 인증·권한이 실제로 먹는지가 이 호출로 드러난다.
    new_code = next_version_code

    build_aab(code: new_code)
    metadata = stage_changelog(new_code)

    upload_to_play_store(
      package_name: APP_PACKAGE,
      track: CLOSED_TRACK,
      aab: AAB_PATH,
      release_status: "completed",
      metadata_path: metadata,               # nil이면 supply가 기본 경로를 찾지만(options.rb:66)
      skip_upload_metadata: true,            #   그때는 아래 skip이 true라 아무것도 올리지 않는다
      skip_upload_changelogs: metadata.nil?, # 스토어 본문은 건드리지 않고 릴리즈 노트만 올린다
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )

    UI.success("비공개 테스트 업로드 완료! versionCode #{new_code} (track: #{CLOSED_TRACK})")
  end
end
```

**iOS의 `strip_dart_defines` 대응물은 만들지 않는다.** 실측 확인: dart-define는 gradle
project property(`-Pdart-defines=<base64 CSV>`)로만 넘어가고 `android/`·`.dart_tool/`·`build/`
어디에도 **파일로 남지 않는다**(평문·base64 양쪽 grep 0건). `android/local.properties`가 매
빌드 재작성되지만 담기는 것은 `flutter.buildMode`·`versionName`·`versionCode` 셋뿐이다.
남는 유일한 흔적이 위 주석의 daemon 로그이고, 그래서 대응이 파일 삭제가 아니라 **`--verbose`
금지**다.

#### 트랙을 틀리는 비용은 "모르고 지나갈 때"만 14일이다

`CLOSED_TRACK`이 틀리면 업로드는 성공하고 릴리즈는 다른 트랙에 얹힌다. 그 자체가 14일을
태우는 것은 아니다 — **태우는 것은 그 사실을 모른 채 테스터를 초대하는 것**이다. 그래서
순서를 이렇게 둔다:

1. 트랙 identifier를 **콘솔에서 먼저 읽는다**(기본 제공 트랙을 쓰므로 `alpha`).
2. `beta` 업로드 뒤 **콘솔 `테스트 및 출시 › 비공개 테스트`에서 릴리즈를 눈으로 확인**한다.
   H5의 완료 신호가 이것이고, 여기서 틀린 트랙이 즉시 드러난다.
3. 틀렸으면 versionCode를 하나 올려 다시 올린다(트랙 전수를 훑으므로 자동으로 올라간다).
   테스터는 아직 초대하지 않았으므로 손실은 빌드 한 번이다.

⚠️ `check_play_key`는 **트랙의 존재를 답하지 못한다.** 없는 트랙·빈 트랙에 대해 API가 404
`trackEmpty`/`Track not found`를 주면 fastlane이 예외 대신 **빈 배열**을 돌려준다
(`supply/lib/supply/client.rb:492-504`). 이 레인이 답하는 것은 **인증과 권한**이다.

**검증**
```bash
# ① 값싼 레인부터 — 파괴적 단계가 없다
./android/bin/fastlane.sh check_tago_key       # 64자 OK
./android/bin/fastlane.sh check_play_key       # 인증·권한 + 트랙 4개 versionCode

# ② 가드 셋이 각각 clean 앞에서 죽는지
mv ~/.google_play/service_account.json /tmp/ && ./android/bin/fastlane.sh beta       # 즉시 실패
mv /tmp/service_account.json ~/.google_play/                                         # ← 복구
mv ~/.planroutine/tago.env /tmp/            && ./android/bin/fastlane.sh build_aab   # 즉시 실패
mv /tmp/tago.env ~/.planroutine/                                                     # ← 복구
mv android/key.properties /tmp/             && ./android/bin/fastlane.sh build_aab   # 즉시 실패
mv /tmp/key.properties android/                                                      # ← 복구
#   셋 다 "Android 캐시 정리" 헤더가 **찍히기 전에** 멈춰야 한다. 찍힌 뒤 멈추면 가드가
#   있는 의미가 없다(clean은 수 분이고 되돌릴 수 없다).
#   ⚠️ **복구를 한 줄씩 짝지어 둔다.** 세 개를 몰아서 옮기고 나중에 되돌리려 하면 그 시점에
#   세 파일이 전부 /tmp에 있어 바로 다음 검증 ④·⑤가 실행 불가다(밟는 사람이 원인을 다시 찾는다).

# ③ 코드 게이트 — 레인 밖에서는 release 산출물이 나오지 않는다
flutter build appbundle --release            # BUILD FAILED: "TAGO_KEY dart-define가 비어 있습니다"
cd android && ./gradlew :app:bundleRelease   # 같은 메시지

# ④ 레인으로 만든 첫 release AAB (C3에서 미룬 지문 확인이 여기다)
./android/bin/fastlane.sh build_aab
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
#   C3의 signingReport SHA1과 일치해야 한다

# ⑤ 에뮬레이터에 설치 — AAB는 그냥 깔리지 않는다
brew install bundletool                     # 이 기기에 없다(실측: which bundletool → not found)
bundletool build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/planroutine.apks \
  --ks="$HOME/.android/keystores/planroutine-upload.jks" \
  --ks-key-alias=planroutine-upload        # 비밀번호는 대화형으로 묻는다(--ks-pass 금지)
bundletool install-apks --apks=/tmp/planroutine.apks
```

**TAGO 키가 AAB에 들어갔는지를 산출물 grep으로 확인하지 않는다.** dart-define는
`classes.dex`가 아니라 **Dart AOT 스냅샷(`base/lib/<abi>/libapp.so`)** 에 박히므로 dex를 보는
명령은 키가 들어갔든 아니든 0을 답한다(실측: Dart 리터럴 `shared_file`·`Pretendard`가
dex 0건 / libapp.so 1건). 그리고 `libapp.so`를 봐도 신뢰할 수 없다 — 같은 방법으로
`apis.data.go.kr`·`1613000`은 libapp.so에서도 안 잡혔다. **문자열 grep 자체가 가드로
부적절하다.** 대신 두 겹으로 본다:

- **(a) 빌드 단계 — 코드 게이트.** 위 ③이 그것이다. 키가 비면 산출물이 애초에 안 나오므로
  산출물을 뒤질 필요가 없다. iOS와의 차이가 여기다 — iOS는 가드 넷 어디도 키를 보지 않아
  "키 빠진 IPA"가 심사에 오를 수 있었다.
- **(b) 런타임 — 에뮬레이터에서 버스 카드가 실제 도착 정보를 그린다.** 버스는 Dart + `http`
  뿐이라 **M1 빌드에서도 그대로 돈다**(알림·CSV 공유와 달리 Android 배선이 필요 없다).
  `설정 › 버스 도착`을 켜고 정류장 하나(예: `02004` 서울역버스환승센터)를 등록해 남은 분이
  뜨면 키가 들어간 것이다. `버스 정보를 불러올 수 없어요`면 키가 빠졌거나 권한 문제다.

**가드가 지워지는 것을 막는 테스트**를 함께 세운다 — `test/android/release_guard_test.dart`.
리포에는 소스를 읽어 검사하는 선례가 있다(`test/features/settings/data_source_credit_test.dart`가
`bus_api_client.dart`의 기관코드·호스트를 읽어 출처 표시와 양방향 대조한다). 세 가지를 본다:

1. `android/app/build.gradle.kts`에 `hasReleaseKeystore` 가드와 `hasTagoKey` 가드가 **둘 다**
   있다(`dart-defines` 파싱 포함).
2. `android/fastlane/Fastfile`의 `build_aab`에서 `tago_key`·`assert_release_keystore` 호출이
   `reset_android_caches`보다 **앞에** 있다(문자열 인덱스 비교).
3. `beta`에서 `assert_play_key`가 `next_version_code`보다 앞에 있다.

자리를 `test/android/`로 두는 이유: 이것은 feature가 아니라 **빌드 설정에 붙는 가드**이고,
`test/tools/`는 파일명에 `_test`가 없는 생성기 자리라(`gen_app_icon.dart`·`seal_preview.dart`)
자동 스캔 대상 테스트를 섞으면 그 규칙이 흐려진다.

⚠️ **신규 앱의 첫 업로드는 API가 거부할 수 있다** — 이전 릴리즈가 없는 앱에는
`release_status: "completed"`로 올릴 수 없다는 보고가 있다(§순서 ③). `bootstrap`이 draft를
쓰는 것이 그 대비다. 그래도 막히면 **`build_aab`로 만든 AAB를 콘솔에서 사람이 올린다** —
`build_aab`가 독립 레인이므로 이 폴백이 실제로 실행 가능하다. **관통 원칙 ①은 "빌드"에 관한
것이므로 위반이 아니다.**

### M1-C6 · 인앱 개인정보처리방침 링크 (브리프에 없던 항목)

Play User Data 정책 verbatim: "All apps must post a privacy policy link in the designated field
within Play Console, **and a privacy policy link or text within the app itself**."

현재 `lib/` 전체에 방침 링크 UI가 **0건**이다(`grep -rni "privacy|개인정보|처리방침|indibery.dev" lib/`
→ 주석 1건만).

> **결정: `url_launcher`를 추가해 브라우저로 연다**(§결정 B). 방침 **본문을 인앱 화면**으로
> 넣는 안(의존성 0)은 기각했다 — 방침을 고칠 때마다 앱을 재배포해야 하고 웹/앱 이중 출처가
> 생긴다. 정책은 "link **or text**"를 허용하므로 둘 다 유효했고, 유지 비용이 판단 기준이었다.

**문자열과 URL은 `SettingsStrings`에 둔다**(하드코딩 금지 규칙). URL을 별 상수 파일로 빼지
않는 이유는 이 리포에 그런 자리가 없고, 같은 클래스가 이미 `dataSourceBody`처럼 **외부
사실을 담은 문자열**을 들고 있기 때문이다 — 방침 URL도 같은 성질이다.

```dart
// lib/core/constants/strings/settings_strings.dart — aboutSection 아래
  /// 인앱 개인정보처리방침 링크. **Play User Data 정책이 요구하는 항목이다** —
  /// "a privacy policy link **or text** within the app itself".
  /// 웹 호스팅본과 같은 URL이고, 이 값을 바꾸면 Google OAuth 동의 화면 필드가 바뀌어
  /// **재검증 트리거가 된다**(§M2-④). 본문만 고칠 때는 URL을 건드리지 않는다.
  static const privacyPolicyTitle = '개인정보처리방침';
  static const privacyPolicyUrl = 'https://planroutine.indibery.dev';
  static const privacyPolicyFailed = '브라우저를 열 수 없습니다';
```

```dart
// lib/features/settings/presentation/widgets/privacy_policy_list_tile.dart
// 탭이 있는 행이라 AppInfoListTile·DataSourceListTile의 Column에 **넣지 않는다** —
// 그 블록의 성격은 "둘 다 정보성이고 탭이 없다"이고(settings_screen.dart:83), 탭 가능한
// 행을 섞으면 어디를 누를 수 있는지가 흐려진다. 별 SettingsSection 하나로 앱 정보 위에 둔다.
//
// ⚠️ canLaunchUrl을 쓰지 않는다 — 아래 "Info.plist·<queries>" 참고.
onTap: () async {
  final ok = await launchUrl(
    Uri.parse(SettingsStrings.privacyPolicyUrl),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) { /* SnackBar(privacyPolicyFailed) */ }
},
```

**섹션 행 예산 심사**: 설정 행은 12행이고 여기서 **13행**이 된다. 이 리포가 19행을 12행으로
줄인 원칙("깊은 설정은 화면 밖으로")과 부딪히지 않는 이유는 이 행이 설정이 아니라 **법적
표시**라는 것이다 — 시트나 상세 화면으로 숨기면 정책이 요구하는 "within the app"의 발견
가능성이 떨어진다. 도장 모양·버스를 뺀 자리에 이것이 들어가는 것이 맞다.

**`Info.plist`도 `<queries>`도 필요 없다 — 확인했다**(§미확인 30 해소). `url_launcher` 6.3.2
README verbatim: *"Add any URL schemes passed to **`canLaunchUrl`** as `LSApplicationQueriesSchemes`
entries in your Info.plist file"* / Android도 *"Add any URL schemes passed to **`canLaunchUrl`**
as `<queries>` entries"*. 둘 다 **조회(`canLaunchUrl`)에만** 걸리는 요건이고,
`launchUrl`은 실행만 한다(`url_launcher/lib/src/url_launcher_uri.dart:39-61` — `canLaunch`를
경유하지 않는다). 그래서 위 코드는 `canLaunchUrl`을 부르지 않고 `launchUrl`의 반환값으로
실패를 판정한다. `mode: LaunchMode.externalApplication`을 명시하는 것은 기본값
(`platformDefault`)이 플랫폼마다 다르고 Android에서는 인앱 브라우저(Custom Tabs)로 갈 수
있는데, **그 판정에는 `<queries>`가 필요하기 때문**이다(README: "Checking for
`supportsLaunchMode(LaunchMode.inAppBrowserView)` also requires a `<queries>` entry").

이 항목은 **iOS에도 같은 요건이 App Store에 있어** iOS 설정 화면도 바뀐다 — 브리프의 "iOS 한
줄도 안 바뀐다"가 깨지는 지점이고 §범위 밖에 적었다. 코드는 플랫폼 공통 한 벌이다.

**검증**
```
□ 위젯 테스트 1건 — 설정 화면에 이 행이 있다(문자열은 SettingsStrings 참조로 찾는다)
□ 위젯 테스트 1건 — 탭하면 launchUrl이 privacyPolicyUrl로 불린다
   (url_launcher_platform_interface의 mock 플랫폼으로 인자를 붙잡는다. "행이 있다"만
    검사하면 v80 iPad share 사고와 같은 구멍이 남는다 — 존재 ≠ 동작)
□ E2E `_scrollToInSettings`로 행까지 스크롤된다
□ iOS 시뮬레이터·Android 에뮬레이터 양쪽에서 탭 → 브라우저가 열린다
□ Play Console `앱 콘텐츠 › 개인정보처리방침`에 **같은 URL**이 들어간다
```

### M1-C7 · adaptive 아이콘

이 리포는 아이콘을 파일로 두지 않고 `test/tools/gen_app_icon.dart`가 `BrandLogo`(LogoHybrid)를
렌더해 만든다. adaptive icon은 **배경/전경 분리 + 전경 안전 영역이 66%뿐**(원형 마스크)이라
현재 iOS의 90% 배치를 그대로 쓰면 잘린다.

1. `gen_app_icon.dart`에 **출력 둘을 더한다** — 배경 `drawRect` 없이(투명) 로고 **~60%**인
   `assets/icon/app_icon_foreground.png`와, `AppColors.navy` 단색 한 장인
   `assets/icon/app_icon_background.png`. 기존 1024 출력은 그대로 둔다(iOS 경로 불변).
2. `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  ios: true
  android: "ic_launcher"                                   # false → 생성 켜기
  image_path: "assets/icon/app_icon.png"
  remove_alpha_ios: true
  # 색 hex를 여기 박지 않는다 — `adaptive_icon_background`는 **이미지 경로도 받는다.**
  # hex로 두면 네이비의 출처가 AppColors와 pubspec 둘이 되고, 팔레트를 손볼 때
  # 아이콘 배경만 옛 색으로 남는다(그 사실은 홈 화면을 눈으로 봐야 드러난다).
  # gen_app_icon.dart가 이미 `Paint()..color = AppColors.navy`로 같은 색을 쓰고 있어
  # 배경 한 장을 더 뽑으면 출처가 **코드 하나**로 남는다.
  adaptive_icon_background: "assets/icon/app_icon_background.png"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```
키 이름은 `flutter_launcher_icons` 0.14.3 기준 <추측>이다 — 실행 산출물로 확정한다.
`adaptive_icon_background`가 이미지 경로를 받지 않는 판이면 폴백은 hex + **가드 테스트
1건**이다(`AppColors.navy.toARGB32()`와 pubspec 문자열을 대조 — 소스를 읽어 검사하는 선례가
`test/features/settings/data_source_credit_test.dart`에 있다). 둘 중 어느 쪽이든 **출처가
갈라진 채로 두지 않는다.**

**검증**
```bash
flutter test test/tools/gen_app_icon.dart   # 원본 + 전경 + 배경 세 장
dart run flutter_launcher_icons
ls android/app/src/main/res/mipmap-anydpi-v26/     # ic_launcher.xml 생성 확인
cat android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml  # <background>/<foreground>
```
그리고 **에뮬레이터 홈 화면에서 눈으로** — 원형 마스크에서 로고가 잘리지 않는지. 런처마다
마스크가 달라(원·스퀴클·티어드롭) 파일 검사로는 못 잡는다.

⚠️ Play **스토어** 아이콘(512×512 PNG, alpha 허용, ≤1024KB)은 adaptive icon과 **별개 자산**이다.
`assets/icon/app_icon.png`(1024²)를 축소해 M3에서 업로드한다.

### M1-C8 · release 축소 대비 — 테스터 빌드에서만 죽는 것을 막는다

**`flutter build appbundle --release`는 R8 코드 축소와 리소스 축소를 둘 다 기본으로 켠다.**
실측 근거(`flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt:262-268`):

```kotlin
if (FlutterPluginUtils.shouldShrinkResources(project)) {
    getByName("release") {
        isMinifyEnabled = true
        isShrinkResources = FlutterPluginUtils.isBuiltAsApp(project)
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), flutterProguardRules)
        // Optionally adds custom Proguard rules as needed from `android/app/proguard-rules.pro`.
        if (File("${project.projectDir}/proguard-rules.pro").exists()) { proguardFile("proguard-rules.pro") }
```
`shouldShrinkResources`는 **기본 true**다(`FlutterPluginUtils.kt:129-136` — `-Pshrink=false`는
multi-apk 분할에만 쓴다). 그리고 `android/app/proguard-rules.pro`가 **있으면 자동으로**
설정에 더해진다 — 파일을 만드는 것 말고 할 일이 없다.

이 리포에는 `android/app/src/main/res/raw/`도 `proguard-rules.pro`도 **없다**(실측:
`res/` 아래 9개 파일 전수 확인). 그래서 두 가지가 release에서만 조용히 깨진다.

**(a) 리소스 축소가 `ic_notification`을 지운다.** 그 drawable을 참조하는 곳은 Dart 문자열
(`AndroidInitializationSettings('ic_notification')`)뿐이고 XML·Java에는 없다 → 축소기가
"안 쓰는 리소스"로 판정한다. 플러그인 README:324 verbatim:

> "⚠️ Ensure that you have configured the resources that should be kept so that resources like
> your notification icons aren't discarded by the R8 compiler … **If you fail to do this,
> notifications might be broken. In the worst case they will never show, instead silently
> failing when the system looks for a resource that has been removed.**"

**(b) R8이 Gson 역직렬화를 깬다.** 클래스 이름이 남는 것(`@Keep`)과 Gson이 **필드·제네릭
시그니처로 되읽을 수 있는 것**은 다른 문제다. 플러그인은 예약 목록을
`new TypeToken<ArrayList<NotificationDetails>>(){}`로 되읽어 부팅 후 재예약과
`pendingNotificationRequests()`를 한다(`FlutterLocalNotificationsPlugin.java:508`).
README:322 verbatim: *"Rules specific to the GSON dependency being used by the plugin will need
to be added."* AGP 8.11.1이라 `android.enableR8.fullMode`가 기본 true인데
`android/gradle.properties`에는 그것을 끄는 줄이 없다(전문 2줄 확인).

```xml
<!-- android/app/src/main/res/raw/keep.xml
     drawable 전부를 남긴다. 지금은 launch_background뿐이고 M2-①이 ic_notification을 더한다 —
     이름을 하나씩 적으면 그때 이 파일을 함께 고쳐야 하는데, 안 고쳐도 **release에서만**
     깨져서 알 방법이 없다. 플러그인 예제도 `@drawable/*`를 쓴다. -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/*" />
```
```proguard
# android/app/proguard-rules.pro
# flutter_local_notifications 18.0.1이 예약 목록을 Gson으로 SharedPreferences에 넣고 되읽는다.
# 출처: 플러그인 example/android/app/proguard-rules.pro (README:322가 GSON 저장소의 규칙을
# 참조하라고 하므로, 규칙이 갱신되면 그쪽을 다시 볼 것).

## Gson rules
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
```

**파일은 M1에 넣고, 실효 검증은 M2-①에서 한다.** M1에는 `ic_notification`도 예약 알림도 아직
없어서 여기서 확인할 것이 없다 — 그런데 파일을 M2로 미루면 M1·M2 초반의 테스터 빌드가 전부
축소 설정 없이 나가고, 알림을 배선한 첫 빌드에서 "코드는 맞는데 알림이 안 온다"를 만난다.

**검증은 release 산출물에서만 성립한다.**
```bash
# M1: 두 파일이 자리에 있는지 — 그 이상은 M1에서 증명할 수 없다
ls android/app/proguard-rules.pro android/app/src/main/res/raw/keep.xml

# M1: R8 설정에 규칙 파일이 실제로 들어갔는지 (C5의 build_aab가 만든 산출물에서)
grep -c 'proguard-rules.pro' build/app/outputs/mapping/release/configuration.txt

# M2-①: bundletool로 깐 **release** 빌드에서
#   □ 상태바에 흰 실루엣이 뜬다 (아이콘이 지워지면 알림 자체가 안 뜬다)
#   □ adb reboot 뒤 dumpsys alarm에 예약이 남아 있다 (Gson 역직렬화 성공의 증거)
```
- **`gradlew … --dry-run | grep -i shrink`를 쓰지 않는다.** 초안에 있었고 두 번 무력하다:
  ① `--dry-run`도 `taskGraph.whenReady`를 발동시킨다(스크래치 프로젝트로 실측 — `--dry-run`은
  `-Pdart-defines`를 싣지 않으므로 TAGO 가드에 걸려 grep에 넘길 출력이 애초에 없다).
  ② 가드를 만족시켜 돌려도 **0건**이 나온다 — 실제 축소 태스크 이름은 `minifyReleaseWithR8`로
  `shrink`가 들어 있지 않다(실측). 게다가 축소 자체는 기본 ON이라(`FlutterPlugin.kt:262-268`)
  태스크 존재는 이 두 파일의 배선과 **무관**하다.
- 그래서 M1의 판정은 **`ls` + `configuration.txt` 대조**까지다. `configuration.txt`는 R8이
  실제로 읽은 설정 전문이라 "파일이 디스크에 있다"보다 한 단계 강하다. 이 산출물은 C5의
  `build_aab`가 만든다 — 그래서 C8 검증은 **C5 뒤**에 밟는다.
- 실효(아이콘이 살아남았는가·Gson이 되읽는가) 확인은 **M2-①의 release 스모크**가 담당한다.
  M1에서 이것까지 증명하려 들면 아직 없는 알림 배선을 태워야 한다.
⚠️ **debug 확인으로는 원리적으로 못 잡는다.** M2-①의 체크리스트를 `flutter run`(debug,
축소 없음)으로만 밟으면 에뮬레이터에서 전부 통과하고 테스터 AAB에서만 죽는다. 이것이
"TAGO 키 빠진 IPA"와 같은 계열의 함정이다 — **debug와 release가 다른 산출물이라는 것.**

### M1-C9 · `deploy` 스킬 개정 — 틀린 런북을 남기지 않는다

**배포는 이 스킬이 트리거된다**(frontmatter: `"안드로이드/Play Store 배포" 요청 시 사용`).
그 스킬이 지금 스펙과 **정면으로 어긋난** 내용을 담고 있고, 어긋난 항목이 하필 되돌릴 수
없는 손실(14일)이 걸린 자리다. 레인을 만들고 스킬을 그대로 두면 다음에 "안드로이드 배포해줘"가
오는 순간 스킬이 존재하지 않는 레인명과 **틀린 트랙**을 안내한다.

| `SKILL.md`의 현재 서술 | 이 스펙의 확정 | 왜 위험한가 |
|---|---|---|
| `android beta`(**track: internal**) | `beta` = 비공개 테스트(`alpha`), internal은 `bootstrap` 전용 | internal은 14일을 **하루도 세지 않는다**(§M1-H5). 이 한 줄대로 올리면 14일이 0일이다 |
| `flutter build appbundle --release` 직접 호출 | `build_aab` 레인(가드 → clean → `--dart-define-from-file`) | 수동 경로에는 TAGO 키가 없다. 관통 원칙 ①이 막으려는 그 명령이 런북에 적혀 있다 |
| "iOS의 `reset_ios_caches`는 Android에 불필요" | `reset_android_caches` **필수** | 실측 둘(registrant의 `integration_test`, `libsqlite3.so` 5.1MB, §M1-C5) |
| 차단 요인 1·2(서명·applicationId) | C2·C3가 해소한다 | 완료 후 **사실이 아니게 된다** |
| 차단 요인 3의 `~/.google_play/service_account.json` | **이 경로를 그대로 쓴다**(§Appfile) | 여기만 맞다. 스펙이 경로를 새로 정하지 않고 이 값을 따라간 이유다 |
| frontmatter `Android는 아직 미배선(차단 요인 안내)` | 배선 완료 | 스킬이 배포를 **거부**한다 |

작업은 「Android (계획 — 아직 미배선)」 절을 **런북으로 교체**하는 것이다:

```
□ frontmatter description에서 "Android는 아직 미배선(차단 요인 안내)" 삭제
□ 레인 5개를 iOS 절과 같은 형식으로 열거 —
  check_tago_key · check_play_key · build_aab · bootstrap · beta
  (호출은 항상 `./android/bin/fastlane.sh <레인>`, 맨 fastlane 금지 — iOS와 같은 규칙)
□ 트랙: `beta` = 비공개 테스트(`alpha`) / `bootstrap` = internal·draft(버리는 업로드)
  + "internal은 14일을 세지 않는다"를 **이유까지** 적는다(값만 적으면 다음 사람이 바꾼다)
□ 게이트: iOS와 동일(analyze + test) + Android는 여기에 **release AAB 스모크**가 붙는다
  (debug로는 축소가 지운 것을 못 잡는다, §M1-C8)
□ reset_android_caches를 하는 이유 두 줄(registrant · libsqlite3.so)
□ 서비스 계정 경로는 `~/.google_play/service_account.json` **하나로 통일**
□ versionCode 규칙: 트랙 전수 최대 + 1, pubspec `+N`이 하한(iOS의 계정 스코프와 대칭이 아니다)
□ 프로덕션 릴리즈는 레인이 없다 — 사람이 콘솔에서 만든다(§M3)
```

**착수 시점은 C5 직후다** — 레인이 존재하는 순간부터 스킬이 틀린 상태가 되므로, 레인과 같은
커밋에 넣는다. `CLAUDE.md` 쪽은 §리포 문서·규칙 갱신에 모아 뒀다.

**검증**: `SKILL.md`에서 `track: internal`·`flutter build appbundle`·`미배선` 세 문자열이
**사라진다.** 그리고 스킬을 실제로 불러 Android 경로를 안내하는지 한 번 태워 본다.

### M1-H · 사람이 콘솔에서

| # | 작업 | 세부 | 완료 신호 |
|---|---|---|---|
| H1 | Play Console 앱 생성 | 앱 이름·기본 언어·앱/게임·무료/유료·정책 선언. **패키지명 입력란은 없다**(§순서 ③) | 앱이 목록에 뜬다 |
| H1.5 | 릴리즈 공개 선행 선언 전수 확인 | 아래 별도 절 | 공개를 막는 항목 목록을 손에 넣는다 |
| H1.6 | **Play 서비스 계정 발급 + 권한** | 아래 별도 절. **H1 직후에 착수**(활성 대기가 있을 수 있다) | JSON을 리포 밖에 두었고 **콘솔에 릴리스 관리자 권한이 보인다**(육안). API 확인은 H3.5 |
| H2 | 업로드 keystore 생성 | C3의 `keytool` (비번 대화형) + 리포 밖 백업 | `signingReport`에 release alias 노출 |
| H3 | **확정용 업로드** | **콘솔에 사람이 올린다**(internal·draft). AAB는 `build_aab` 산출물. 레인으로는 불가(§순서 ③) | 콘솔에 `com.planroutine.app`이 바인딩된다 |
| H3.5 | **`check_play_key`** | `./android/bin/fastlane.sh check_play_key` — 서비스 계정 권한이 실제로 먹는지가 여기서 처음 확정된다 | 트랙 4개 versionCode를 조회한다. 실패면 H1.6 권한을 다시 본다 |
| H4 | Play 앱 서명 지문 수집 | 경로는 아래. **개수를 가정하지 않는다** | 지문 전부를 손에 넣는다 → M2-④ 착수 |
| H5 | 비공개 테스트 릴리즈 공개 | `beta` 레인 + **국가·지역 선택**. 첫 릴리즈는 검토를 거친다 | **릴리즈가 `사용 가능`이 된다**(트랙: 비공개 테스트) |
| H6a | 테스터 Google 계정 이메일 수집 | 인디스쿨. **목표 16명**(§순서 ①의 여유) | 이메일 16개 |
| H6b | 콘솔 이메일 목록/그룹 생성 + 트랙 연결 | 비공개 테스트는 opt-in 링크만으로 참여할 수 없다 | 트랙 테스터 목록에 16명 |
| H6c | opt-in 링크 전달 + **날짜 기록** | 사람별 날짜를 스프레드시트에 적는다 | 대시보드 카드가 세는 수가 늘기 시작한다 |
| H7 | 앱 등록 상태 확인 | Android developer verification — 앱 목록 상단 카드 | 등록 상태가 보인다 |

**H1.5 · 릴리즈 공개에 필요한 선언 전수 확인**

개인정보처리방침 URL · 앱 액세스 · 광고 · 콘텐츠 등급(IARC) · 타겟층 · **데이터 안전**은 Play가
릴리즈를 공개하기 전에 요구하는 선언들이다. **이 중 어디까지가 비공개 테스트의 전제인지가
계획 전체를 좌우한다** — 전제인 것을 M3(14일 뒤)에 두면 "타이머를 먼저 켠다"가 그 항목에
막히고, 접근법 B의 이득이 통째로 사라진다. 그래서 H1 직후에 확인한다.

- 확인 방법: H1 직후 콘솔 대시보드의 `앱 설정` 과제 목록과 `테스트 및 출시 › 비공개 테스트`의
  릴리즈 만들기 화면에서 **공개를 막는 항목이 무엇인지** 읽는다.
- **전제로 확인되면 M3-H2(앱 콘텐츠 선언)·M3-H3(데이터 안전)을 H5 앞으로 옮긴다.** 두 항목의
  답은 이미 다 정해져 있어(§M3-H2 근거표, §M3-H3) 옮기는 비용은 콘솔 입력 시간뿐이다.
- 데이터 안전은 2022-07-20부터 **모든 앱**에 필수가 됐고 미제출 시 업데이트가 차단된다고
  Google이 공지했다 — 테스트 트랙도 그 "모든 앱"에 든다고 보는 것이 안전하다. 그래서
  **전제라고 가정하고 일정을 잡고**, 아니면 그만큼 빨리 끝나는 쪽으로 둔다.
- **데이터 안전 답안이 미결이면 이 단계에서 막힌다.** 그 결정은 끝나 있다 — 기기 백업을 켠 채
  두기로 했으므로 전송을 인정하는 답안이 확정이다(§M3-H3 · §결정 E).
- **방침 URL이 전제라면 §M2-⑧(결정 A)과 §M2-⑨(방침 개정)이 M1으로 올라온다.** Play는 방침이
  정확할 것을 요구하고, `google_fonts`의 런타임 fetch가 살아 있는 동안은 방침 §6("이 셋이 통신
  전부")이 **한 줄이면 거짓이 되는 상태**다. ⑧은 `main.dart` 한 줄 + `pubspec.yaml` +
  에셋 넷(`.ttf` 둘 · `OFL-*.txt` 둘)이라 M1에 넣는 비용이 작다 — 방침 본문에 CDN을 임시로
  적고 나중에 지우는 쪽은 문서를 두 번 고치게 된다. ⑨는 문서 작업이라 코드 일정과 병렬이다.

**H1.6 · Play 서비스 계정 (레인이 도는 전제)**

```
Play Console
  → [설정] → [API 액세스]
  → Google Cloud 프로젝트 연결 (iOS와 같은 프로젝트를 써도 된다 — 번호 73700230470)
  → [서비스 계정 만들기] → GCP 콘솔에서 계정 생성 → 키(JSON) 발급
  → Play Console로 돌아와 [액세스 권한 부여] → 앱 권한: **릴리스 관리자**
     (필요한 것은 "프로덕션·비공개 테스트 트랙에 출시" + "앱 정보 보기")
  → JSON을 리포 밖으로: ~/.google_play/service_account.json  (Appfile이 이 경로를 가리킨다)
```
- **신규 계정은 API 액세스 활성·권한 전파가 즉시가 아닐 수 있다.** 그래서 H2·C1보다 앞,
  H1 바로 뒤에 착수한다 — 기다리는 동안 코드 작업이 돈다. 소요 시간은 **미확인**.
- **여기서는 콘솔 육안까지만 확인한다** — `사용자 및 권한`에 서비스 계정이 릴리스 관리자로
  보이는 것. `check_play_key`는 **H3.5**에서 처음 돈다. H1.6 시점에는 패키지가 아직
  바인딩되지 않아 supply가 edit을 못 열고, 이 레인도 404로 죽는다(§순서 ③).
  파괴적 단계가 없어 H3.5 이후엔 몇 번이든 다시 돌릴 수 있다.
- iOS `.p8`과 같은 규칙: 원본은 리포 밖, 경로만 커밋(`Appfile`), 실수로 리포에 떨어진 JSON은
  gitignore가 잡는다(§C3).

**H4 경로 (2026-05에 바뀌었다)**
```
Play Console
  → [Protected with Play]          ← 2026-05에 [App integrity]를 대체했다
  → [Play Store distribution]
  → [Go to Play app signing]
  → "App signing key" 섹션 → SHA-1 / SHA-256 복사
  → 같은 페이지 "Upload key certificate" = 업로드 키 지문(C3의 값과 일치해야 한다)
```
인터넷에 널린 `Test and release › App integrity`는 **구 경로다.**

**H5의 함정 둘**

**① 트랙.** 잘못 고르면 14일을 날린다. 공식 트랙 비교표 verbatim — internal testing의
Requirements는 **"None."**, production은 **"you must run a closed test with at least 12
opted-in testers for 14 days."** 그리고 open testing은 **"Must have gained access to
production to access open testing."** → **closed testing이 유일한 길이다.** open으로 넓히는
우회로는 존재하지 않는다. (그래서 H3의 확정용 업로드는 internal을 **의도적으로** 쓴다 —
세지 않는 트랙이라 시계를 낭비하지 않는다.)

**② 첫 릴리즈 검토.** 신규 앱의 첫 릴리즈는 **테스트 트랙이라도 검토를 거치고**, 그 사이
테스터는 설치할 수 없다. Play는 기간을 "보통 7일 이내, 때로 더"로만 안내한다. 그래서
- H5의 완료 신호는 "업로드 성공"이 아니라 **릴리즈 상태가 `검토 중` → `사용 가능`**이다.
- H6c(opt-in)는 그 뒤에 시작한다. **릴리즈가 공개되기 전에도 opt-in 자체가 가능한지는
  미확인**이고, 가능하더라도 "테스트했다"의 증거가 되기 어려우므로 기다리는 쪽을 고른다.
- 국가·지역 선택을 잊으면 릴리즈가 공개돼도 테스터가 못 받는다. 이 화면에서 함께 한다.

**H6의 함정**: **opt-in 링크만으로는 참여할 수 없다.** 비공개 테스트는 콘솔에서 **이메일
목록 또는 Google 그룹**에 테스터의 Google 계정을 등록해야 하고, 교사 16명의 계정 주소를 모으는
것은 리드타임이 있는 사람 작업이다(H6a). 그래서 H6를 셋으로 쪼갰다.

그리고 **"트랙 테스터 수가 12+"는 요건을 증명하지 않는다** — 콘솔의 테스터 수는 등록·초대 수이고
요건은 "본인이 연속 14일 opted-in이었던 테스터 12명"이다(§순서 ①). 관측 수단은 둘뿐이다:
- **Play Console 대시보드의 프로덕션 액세스 카드가 세는 숫자** — 공식 카운터다. 이것을 완료
  신호로 쓴다.
- **H6c의 날짜 기록** — 카드가 세는 값이 우리 기대와 다를 때 어디서 어긋났는지 아는 유일한
  단서다("opted-in"의 공식 정의가 없다, §미확인 7).

**H7 배경**: 2026년 3월부터 Play의 모든 앱이 Android developer verification에 자동 등록됐는데
(Google 발표 98%), 자동 등록은 **그 시점의 기존 앱** 대상이다. 신규 앱은 해당하지 않을 수 있다.
강제일은 2026-09-30(브라질·인도네시아·싱가포르·태국)이고 한국 배포에 즉시 차단은 아니지만,
카드를 M1에서 눈으로 확인해 둔다.

### M1 완료 신호

- `./android/bin/fastlane.sh check_play_key`와 `check_tago_key`가 초록이다.
- `./android/bin/fastlane.sh beta`가 초록이고, 콘솔 **`테스트 및 출시 › 비공개 테스트`**(내부
  테스트가 아니다)에 릴리즈가 있고 상태가 **`사용 가능`**이다.
- Play Console 대시보드의 프로덕션 액세스 카드에 테스터 수가 **세지기 시작했다.**
- Play 앱 서명 지문을 손에 넣었다(개수 그대로) → M2-④ GCP 등록이 이미 진행 중이다.
- **에뮬레이터 스모크** — 설치 수단을 명시한다. AAB는 에뮬레이터에 그냥 깔리지 않고, 손으로
  `flutter run --release`를 치면 `--dart-define-from-file`이 없어 **키 없는 빌드**를 보게 된다
  (관통 원칙 ①이 막으려던 그 상황이고, 스모크에서 "정상"과 구별되지 않는다).
  - `bundletool build-apks` + `install-apks`로 **레인이 만든 AAB를 그대로** 깐다(§C5 검증 ⑤).
  - 또는 Play **내부 앱 공유** 링크로 받는다(트랙과 무관해 14일에 영향 없음). 단 이 경로는
    Play 스토어가 있는 이미지가 필요하다(`google_apis_playstore`, §M2 게이트).
  - □ 앱이 뜨고 4탭이 돈다
  - □ `설정 › 버스 도착`을 켜고 정류장 하나를 등록하면 **남은 분이 뜬다** — TAGO 키가 AAB에
    들어갔다는 런타임 증거다(버스는 Dart + `http`뿐이라 M1에서도 돈다)
  - □ `설정 › 개인정보처리방침`을 탭하면 브라우저가 열린다(C6 — 스토어 제출 요건이다)
  - □ **알림은 안 오고 CSV 공유 목록에도 안 뜬다** — 정상이다. 테스터에게 그렇게 안내한다.
- **운영 문서가 코드와 같은 말을 한다** (§리포 문서·규칙 갱신의 M1 몫):
  - □ `deploy` 스킬이 Android 경로를 안내한다(`track: internal`·`미배선`이 사라졌다, §C9)
  - □ `CLAUDE.md`의 배포 명령·프로젝트 구조·기술 스택 표가 Android를 담는다

## M2 · 기능 패리티

M1의 14일이 흐르는 동안 코드를 맞춘다. 고칠 때마다 같은 트랙에 새 빌드를 올려 테스터가
실기기에서 밟는다.

항목은 아홉이다 — 브리프의 ①~⑦에 **⑧ 글꼴 에셋 번들**(§결정 A)과 **⑨ 처리방침 개정**이
더해졌다. 둘은 브리프에 없었지만 **스토어 요건에 걸려 있어 선택이 아니다**: ⑧은 방침 §6의
문장을 사실로 만드는 코드이고, ⑨는 Play User Data 정책이 요구하는 방침의 정확성이다. 그래서
"기능 패리티"라는 이름보다 넓지만 같은 마일스톤에 둔다 — 둘 다 M3 제출의 선행조건이고
릴리즈 공개의 전제일 수도 있다(§M1-H1.5).

### M2 일정 — 임계경로는 14일이 아니다

M3 신청서는 **"테스터가 앱의 모든 기능을 썼는지"**를 설명하라고 요구한다(공식 페이지 verbatim:
`used all of your app's features`). 그런데 그 목록 중 **알림과 CSV 공유 진입은 M2-①·②가 끝난
뒤에야 테스터가 밟을 수 있다** — M1 빌드에서는 알림이 100% 오지 않고 공유 목록에도 안 뜬다.

> 즉 실제 임계경로는 `max(14일, M2 완료 + 기능 사용 증거 수집 기간)`이다. M2가 14일 후반에
> 끝나면 14일이 차도 신청서를 채울 수 없다.

그래서 **기한을 일수로 못박는다.** `D+0` = **12번째 테스터가 opt-in한 날.**

앵커를 첫 테스터로 잡으면 표가 자기 조건과 모순된다 — 시계는 사람마다 따로 도므로(§순서 ①)
첫 사람 기준 `D+14`에는 12번째 사람이 아직 14일을 못 채운다. 12번째를 앵커로 잡으면 그날
`D+14`에 12명 전원이 채운다(먼저 들어온 사람은 더 채웠고, 그 여유가 중간 이탈의 완충이다).

⚠️ **그래서 `D+0`은 H6c 시작일이 아니다.** H6c에서 링크를 뿌린 날과 12번째가 실제로 opt-in한
날 사이에 며칠이 뜬다 — 코드 작업(`D+0 ~ D+7`)은 그 대기 기간에 **먼저 시작해도 된다.**
표의 기한은 "신청일로부터 거꾸로 세는 마감"으로 읽는다.

| 구간 | 할 일 | 왜 그 기한인가 |
|---|---|---|
| `D+0 ~ D+5` | **M2-①(알림) · M2-②(CSV 공유)** 완성 → 트랙에 새 빌드 | 이 둘만 M1 빌드에서 **아예 없는 기능**이다. 늦으면 증거를 모을 창이 사라진다 |
| `D+5 ~ D+7` | M2-③④⑥⑦⑧⑨ + M2 게이트(에뮬레이터·E2E) + **Play 스크린샷 촬영** | 나머지는 M1 빌드에서도 부분적으로 밟힌다. 스크린샷은 규격을 만족하는 자료가 리포에 하나도 없어(§M3-H4) 승인을 기다리며 찍으면 그때 탈락을 알게 된다 |
| `D+7 ~ D+12` | **테스터 과제 회수**(아래 표) | 알림 증거에는 "며칠 안 열고 뒀다가 아침"이 필요해 최소 3일 창이 있어야 한다 |
| `D+12 ~ D+14` | 피드백 반영 빌드 + 신청서 3섹션 초안 | 신청 시점에 만들어 쓰면 형식적인 답이 되고 그것이 반려 사유가 된다 |
| `D+14` | 프로덕션 액세스 신청(M3-H1) | 개인별 14일이 찬 테스터가 12명 이상인 것을 카드로 확인한 뒤 |

- **새 빌드를 올려도 14일 시계는 리셋되지 않는다.** 요건은 빌드가 아니라 **테스터의 opt-in
  연속성**이다(§순서 ①). 반대로 테스터 한 명이 중간에 opt-out하면 **그 한 명만** 0으로 돌아간다.
- ⚠️ **후속 릴리즈에도 검토가 붙는지는 미확인**이다. 붙으면 `D+5`가 위험해지므로, M2-①·②는
  **한 빌드로 함께** 올린다(고칠 때마다 올리는 것은 그 뒤부터).
- M1 안내문에 "알림은 아직 오지 않습니다"를 적을 때 **`14일 연속 opt-in 유지가 요건`임을 함께
  알린다.** 이탈이 개인별 리셋을 만들고, 그것이 16명을 모으는 이유다(§순서 ①).

#### 테스터 과제 배분 (기능별 1인 이상, 목표 16명)

| 기능 | 언제부터 밟을 수 있나 | 배정 |
|---|---|---|
| 작년 CSV 가져오기 · 확정 · 내보내기 · 휴지통 | `D+0` (M1 빌드) | 각 2명 |
| 캘린더 CRUD · 오늘 탭 완료 도장 | `D+0` | 각 2명 |
| 버스 카드 | `D+0` | 2명 (**긴 정류장 이름**을 쓰는 사람 1명 포함) |
| 구글 캘린더 저장 · 기기 캘린더 저장 | `D+0`(스토어 빌드에서, §M2-④) | 각 2명 |
| 사진 AI 왕복 | `D+0` | 2명 |
| **알림** | `D+5` | 3명. 그중 **갤럭시 사용자 1명은 "며칠 안 열고 두기"** 담당 |
| **CSV 공유 진입**(파일 앱 / 카카오톡 / 메일) | `D+5` | 3명. 앱별로 나눈다 |
| 글꼴 크게 쓰는 사람 | `D+0` | **1명 — 명시적으로 지정한다**(§⑥-d). 유닛은 `1.3`까지만 보고 에뮬레이터는 한 번 훑을 뿐이다. 삼성의 `글꼴 크기` + `화면 크기`를 둘 다 키운 상태로 4탭·버스 카드·설정 행을 봐 달라고 요청한다 |

회수 형식은 "됐다/안 됐다"가 아니라 **무엇을 눌러 무엇을 봤는지**다 — 그것이 M3-H1 섹션 1의
답이 되고, 고친 것이 섹션 3의 답이 된다.

### M2-① 알림 — "미배선"이 아니라 구조적으로 죽어 있다

브리프는 "Android 분기 추가"로 적었지만, 현재 상태는 **두 곳이 각각 조용히 실패 중**이다.
이걸 알고 고쳐야 증상 확인이 가능하다.

**사망 지점 1** — `notification_service.dart:63-71`이 `InitializationSettings(iOS: …)`만 준다.
플러그인 `flutter_local_notifications_plugin.dart:118-122`:
```dart
if (defaultTargetPlatform == TargetPlatform.android) {
  if (initializationSettings.android == null) {
    throw ArgumentError('Android settings must be set when targeting Android platform.');
```
→ Android에서 `init()`은 **첫 줄에서 예외를 던진다.** `main.dart:28-31`의 `try { … } catch (_) {}`가
먹으므로 **크래시하지 않고** `_initialized`도 안 켜지고 이어지는 `sync()`도 같은 catch에 먹힌다.
화면상 증상 0.

**사망 지점 2** — `requestPermission()`(`:76-85`)이 `IOSFlutterLocalNotificationsPlugin`만
resolve한다 → Android에선 null → `granted ?? false` → **false**. `notification_providers.dart:51-58`의
`setMaster(true)`가 false를 받으면 마스터를 도로 끄므로 **Android에서 알림 스위치를 켤 수 없다.**

#### 변경 1 · 채널 상수 — id는 로컬, **이름·설명은 `NotificationStrings`**

```dart
// lib/features/notifications/data/notification_details.dart — 새 파일(변경 4에서 만든다)
//
// 채널 id는 한 번 만들면 importance/sound를 코드로 못 바꾼다(Android 규칙).
// 바꿔야 하면 id를 bump 해야 한다. **그래서 이것은 `*Strings`에 두지 않는다** — UI 문자열이
// 아니라 DB 키·리소스 이름에 가깝고, `*Strings`에 두면 문구 정리 과정에서 바뀔 위험이 생긴다.
// 바뀌면 채널이 갈라져 사용자의 알림 설정이 초기화된다.
//
// ⚠️ **`_` 접두를 붙이지 않는다.** 소비처가 두 파일이다 — 이 파일의
// `buildNotificationDetails`(변경 4)와 `notification_service.dart`의
// `createNotificationChannel`(변경 2). Dart의 `_` 최상위 선언은 **라이브러리 private**이라
// 다른 파일에서 안 보인다. 한쪽에 리터럴을 다시 적으면 같은 id가 두 곳에서 따로 바뀌고,
// 그것이 바로 아래 문단이 경계하는 상태다.
const kAndroidChannelId = 'schedule_reminder';
```
```dart
// lib/features/notifications/data/notification_service.dart — 파일 로컬
//
// 아이콘 이름은 이 파일의 `init()`만 쓴다(소비처가 하나라 로컬로 둔다).
const _androidIcon = 'ic_notification';   // res/drawable/ic_notification.xml — 확장자 없이
```
```dart
// lib/core/constants/strings/notification_strings.dart — digestTitle 아래
  /// Android 알림 채널의 이름·설명. **`설정 › 앱 › 공직플랜 › 알림`에 그대로 노출되는
  /// UI 문자열이다** — 하드코딩 금지 규칙이 그대로 걸린다(채널 id는 예외, 위 참고).
  ///
  /// ⚠️ `digestTitle`과 값이 같아 보이지만 **공유하지 않는다.** 하나는 알림 제목이고
  /// 하나는 채널 이름이라 청중이 다르고, 공유하면 알림 제목만 고치려던 변경이
  /// 사용자에게는 **채널 이름이 바뀐 것**으로 보인다(채널이 갈라지지는 않는다 — id가
  /// 같으므로. 그래서 조용히 어긋난다).
  static const channelName = '일정 알림';
  static const channelDescription = '오늘·이번 주 일정을 아침에 알려줍니다';
```
아래 변경 2·4가 이 둘을 그대로 읽는다. **파일 로컬 리터럴로 두면 같은 문구가 두 곳에서 따로
바뀐다** — `digestTitle`이 이미 `'일정 알림'`으로 리포에 있어서(`notification_strings.dart:14`)
알림 제목만 고치고 채널명은 옛 이름으로 남는 상태가 실제로 만들어진다. CLAUDE.md의
"하드코딩 금지 — 문자열은 도메인별 `*Strings` 클래스"가 그대로 걸리는 자리다.

#### 변경 2 · `init()` — 채널을 명시 생성한다

```dart
const initSettings = InitializationSettings(
  android: AndroidInitializationSettings(_androidIcon),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);
await _plugin.initialize(initSettings);

// 채널을 여기서 먼저 만든다. 안 만들어도 첫 발화 때 자동 생성되지만
// (FlutterLocalNotificationsPlugin.java:256-262의 createNotification 경로), 그 시점은
// "예약할 때"가 아니라 "발화할 때"다 — 그때까지 `설정 › 앱 › 알림`에 채널이 없어
// ⑦의 "알림이 오지 않나요?" 안내가 빈 화면으로 간다.
await _plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(const AndroidNotificationChannel(
      kAndroidChannelId,
      NotificationStrings.channelName,
      description: NotificationStrings.channelDescription,
      importance: Importance.high,
    ));
_initialized = true;
```
`AndroidNotificationChannel`은 `const` 생성자이고 `NotificationStrings`의 두 값도
`static const`라 `const` 컨텍스트가 유지된다 — 문자열을 옮기는 대가로 const를 잃지 않는다.

#### 변경 3 · `requestPermission()` — Android 분기

```dart
@override
Future<bool> requestPermission() async {
  final android = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    // API 33+ 는 POST_NOTIFICATIONS 다이얼로그, 그 아래는 areNotificationsEnabled().
    // 즉 하위 버전에서도 no-op이 아니라 현재 상태를 답한다.
    return await android.requestNotificationsPermission() ?? false;
  }
  final ios = _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
  return granted ?? false;
}
```
- 플러그인 API 이름은 **`requestNotificationsPermission()`**(복수형, 반환 `Future<bool?>`) —
  `platform_flutter_local_notifications.dart:186`. 브리프의 `requestPermission()`은 **이 리포
  자체 추상 메서드**(`notification_service.dart:15`)이고 플러그인 API가 아니다.
- 요청이 이미 진행 중이면 `PlatformException(permissionRequestInProgress)`가 온다. 현재 호출부는
  스위치 탭과 테스트 버튼뿐이라 연속 호출이 어렵지만, 던지면 스위치가 예외로 죽는다 —
  호출부에 이미 있는 `try`가 먹는지 확인할 것(**M2에서 확인**).

#### 변경 4 · `NotificationDetails` — 본문이 두 줄이다

`computeNotifications`가 만드는 body는 `📌 오늘 — …\n🗓 이번 주 — …`(`notification_rules.dart`의
`_Digest.buildBody`, 섹션을 `'\n'`으로 join). **Android는 접힌 알림에서 한 줄만 보여준다** —
`BigTextStyleInformation`이 없으면 `이번 주` 섹션이 통째로 안 보인다. iOS는 여러 줄을 그대로
보여줘 이 차이가 지금까지 드러나지 않았다.

`const`를 포기하고 본문마다 만든다(`BigTextStyleInformation('')`을 const로 두면 펼쳤을 때 본문이
빈다). **조립을 순수 함수로 떼어 별 파일에 둔다** — `NotificationService`를 부르는 테스트가
리포에 0건이라 이 파일 안에 사설 함수로 두면 회귀 신호를 만들 방법이 없다(`computeNotifications`·
`busPollIntervalFor`와 같은 패턴이고, 같은 이유다):

```dart
// lib/features/notifications/data/notification_details.dart — 새 파일
//
// 플랫폼 details 조립. **순수 함수다** — 플러그인 인스턴스도 채널도 안 만들고 값만 만든다.
// 자리를 data/에 두는 이유: `NotificationDetails`가 플러그인 타입이라 domain/이 플러그인을
// 모르는 상태를 깨지 않는다(domain/에는 `notification_settings`·`pending_notification`만 있다).

/// 예약 알람의 스케줄 모드. **값 하나에 Play 심사가 달려 있다** —
/// `exact*`로 되돌리면 `SCHEDULE_EXACT_ALARM` 고위험 권한 선언 양식 대상이 된다(§M3-H2).
const kAndroidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

NotificationDetails buildNotificationDetails(String body) => NotificationDetails(
      android: AndroidNotificationDetails(
        kAndroidChannelId,
        NotificationStrings.channelName,
        channelDescription: NotificationStrings.channelDescription,
        importance: Importance.high,   // 채널 importance (Android 8.0+)
        priority: Priority.high,       // Android 7.1 이하 폴백
        category: AndroidNotificationCategory.reminder,
        // 본문이 두 줄이라 이것이 없으면 `이번 주` 섹션이 통째로 안 보인다.
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        // iOS 경로는 그대로 둔다. interruptionLevel은 DarwinNotificationDetails의
        // 필드이고, Android 경로는 notificationDetails.android만 꺼내 쓰므로
        // (flutter_local_notifications_plugin.dart:325-332) 메서드 채널에 실리지도
        // 않는다 — "무시된다"가 아니라 구조적으로 도달하지 않는다.
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
```
Android에서 `timeSensitive`에 정확히 대응하는 개념은 없다. 가장 가까운 자리가 채널
`Importance.high` + `category: reminder`이고, **등가는 아니다.**

`_schedule`(`:103-112`)과 `scheduleQuickTest`(`:152-156`)가 이 함수를 함께 쓴다.

#### 변경 5 · 스케줄 모드 — 두 곳

```dart
androidScheduleMode: kAndroidScheduleMode,   // 변경 4의 상수. 리터럴을 두 곳에 박지 않는다
```
`notification_service.dart:113`과 `:157` **양쪽**이다(현재 둘 다 `exactAllowWhileIdle`).
한 곳만 고치면 나머지 경로가 조용히 정확 알람을 요구하고, 그 요구는 **런타임 예외로만**
드러난다(`checkCanScheduleExactAlarms` → `ExactAlarmPermissionException`). 그래서 값을
상수 하나로 묶고 **양쪽이 그 상수를 쓰는지를 가드가 본다**(아래 §M2-① 테스트).

**권한이 필요 없다는 근거** — `ScheduleMode.java:10-27`에서 `inexactAllowWhileIdle`은
`useExactAlarm()==false`·`useAlarmClock()==false`이고, `FlutterLocalNotificationsPlugin.java:740-756`의
else 분기(`AlarmManagerCompat.setAndAllowWhileIdle`)로 가 **`checkCanScheduleExactAlarms`를
호출하지 않는다**(그 함수가 `ExactAlarmPermissionException`을 던지는 곳이다).
→ `SCHEDULE_EXACT_ALARM`·`USE_EXACT_ALARM` 둘 다 불필요. **브리프 전제 그대로 맞다.**

**대가는 Doze 9분 규칙이고, 이 앱에는 무해하다.** 공식 문서:
> "Neither `setAndAllowWhileIdle()` nor `setExactAndAllowWhileIdle()` can fire alarms more than
> once per nine minutes, per app."

`computeNotifications`가 발송 시각을 키로 병합해 **하루당 알림 1건**만 만들므로(id도 YYYYMMDD
기준) 발화 간격이 최소 24시간이다. **개별 이벤트마다 알림을 만드는 앱이었으면 이 결정이
성립하지 않았다** — 브리프의 "08:00~08:15" 가정을 떠받치는 것은 이 병합 구조다.

#### 변경 6 · 매니페스트 — receiver가 **둘**이다

```xml
<!-- <manifest> 바로 아래 -->
<!-- 재부팅 후 예약 알림 복원. 플러그인은 이 권한을 자체 선언하지 않는다.
     없으면 부팅 한 번에 예약 알림이 전멸한다. iOS엔 없는 문제라 놓치기 쉽다. -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```
```xml
<!-- <application> 안, flutterEmbedding meta-data 뒤 -->

<!-- 예약된 알람을 받아 실제로 알림을 띄우는 리시버.
     ⚠️ 이게 없으면 **재부팅과 무관하게 예약 알림이 한 건도 발화하지 않는다.**
     README 원문: "so that the plugin can actually show the scheduled notification(s)" -->
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />

<!-- 부팅/앱 교체 후 재예약. 액션 4개는 ScheduledNotificationBootReceiver.java:14-22와 1:1 -->
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

**플러그인은 receiver를 하나도 선언하지 않는다** — 자체 매니페스트가 권한 둘뿐임을 확인했고,
병합 매니페스트에도 `com.dexterous.*` receiver가 debug·release 양쪽 모두 없다. README:
> "Since version 16 onwards, the plugin will now only specify the bare minimum and these
> `POST_NOTIFICATIONS` and `VIBRATE` permissions."

R8 안전은 **클래스 이름에 대해서만** 확인됐다 — 두 receiver 모두 `@Keep`이고, release AAB의
`base/dex/classes.dex`에 `ScheduledNotificationBootReceiver` 문자열이 살아 있다.

⚠️ **그것으로 부팅 후 복원이 도는 것은 아니다.** 클래스가 남는 것과 **Gson이 필드·제네릭
시그니처로 예약 목록을 되읽을 수 있는 것**은 다른 문제다. receiver가 깨어나도 역직렬화가
실패하면 복원할 목록이 비어 결과는 같다 — 재부팅 한 번에 예약이 전멸한다. 그 규칙은
§M1-C8(`proguard-rules.pro`)이 담당하고, 확인은 **release 산출물에서만** 성립한다.

복원 동작(`rescheduleNotifications`, `:219-236`)은 SharedPreferences `"scheduled_notifications"`에
저장한 목록을 다시 건다. `cancelAll`이 이 캐시도 비우므로 현재의 `replaceAll`(cancelAll → 전량
재예약) 패턴과 정합한다.

#### 변경 7 · 알림 아이콘 — `res/drawable/`이고 mipmap이 아니다

플러그인 네이티브가 `getIdentifier(name, "drawable", packageName)`으로 찾는다
(`FlutterLocalNotificationsPlugin.java:132, 815-817`). defType이 `"drawable"`로 **고정**이므로
`res/mipmap/`에 두면 못 찾고, `initialize`가 아이콘 검증에 실패하면 **성공 응답 없이 return**해
Dart에 `PlatformException`이 온다(`:1650-1656`).

Android는 알림 아이콘의 **알파 채널만 읽고 전부 흰색으로 그린다**(Android 5.0 behavior changes:
"The system ignores all non-alpha channels… draws notification icons in white"). 그래서 컬러 PNG를
넣으면 불투명 영역이 통째로 흰 덩어리가 된다 — 브리프 서술 정확.

브리프의 **vector drawable 결정을 유지한다.** CLAUDE.md의 판단 기준(판다는 원·타원으로 되지만
다리 넷·말린 꼬리는 44px에서 손으로 못 맞췄다 → 알파 PNG 마스크)을 그대로 적용하면, **달력
그리드는 막대와 사각형뿐이라 손으로 그리는 쪽이 맞다.**

```xml
<!-- android/app/src/main/res/drawable/ic_notification.xml
     상태바 아이콘. 시스템이 알파만 읽어 전부 흰색으로 그리므로 fillColor는 불투명이면 된다.
     24dp 캔버스에 LogoHybrid의 달력 그리드만 단순화해 담는다.

     ⚠️ 테두리를 "바깥 사각형 + 안쪽 사각형" 한 path로 그리지 않는다 — 기본 fillType이
        nonZero라 구멍이 뚫리지 않고 통째로 칠해져 **상태바에 흰 사각형**이 뜬다(브리프가
        경계한 그 증상이 pathData 실수로도 재현된다). 막대 넷으로 나눠 그린다. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <!-- 바인더 링 둘 -->
    <path android:fillColor="#FFFFFFFF" android:pathData="M7,2 h2 v4 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M15,2 h2 v4 h-2 z" />
    <!-- 수첩 테두리 — 상단 띠(제목 영역) + 좌·우·하 막대 -->
    <path android:fillColor="#FFFFFFFF" android:pathData="M3,4 h18 v4 h-18 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M3,8 h2 v14 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M19,8 h2 v14 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M3,20 h18 v2 h-18 z" />
    <!-- 날짜 격자 5칸 -->
    <path android:fillColor="#FFFFFFFF" android:pathData="M7,11 h2 v2 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M11,11 h2 v2 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M15,11 h2 v2 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M7,15 h2 v2 h-2 z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M11,15 h2 v2 h-2 z" />
</vector>
```
이 값은 **시작점이고 24dp에서 눈으로 확정해야 한다.** 무위험 폴백은 밀도별 PNG
(16/24/32/48/64 px, mdpi→xxxhdpi)이고, 그 경로를 고르면 `gen_app_icon.dart` 방식으로 알파
실루엣을 렌더하는 것이 리포 컨벤션에 맞는다.

⚠️ API 21–23에서 vector를 small icon으로 쓰면 죽는 보고가 있다(issuetracker 37099638).
**minSdk 24라 그 구간 밖**이지만 기기에서 띄워 본 적은 없다 → 아래 검증 항목.

#### M2-① 검증

```
□ flutter test                     # 908건 + 신규 무손상 (아래 "테스트" 참고)
□ 에뮬레이터: 설정 › 알림 마스터 스위치가 **켜진다** (지금은 켤 수 없다)
□ 권한 다이얼로그가 뜬다 (API 33+ 이미지)
□ 설정 › 알림 › 고급 › 테스트 → 알림이 뜬다
□ 상태바 아이콘이 **흰 실루엣**이다 (흰 사각형·빈칸 아님)
□ 알림을 펼치면 두 섹션이 보인다 — 앵커는 `NotificationStrings.emojiToday`(`📅`)와
  `emojiWeek`(`🗓`)다. **글자를 이 문서에 베껴 적지 않는다** — 실제 값은 `📅`이고
  `📌`로 적어 두면 없는 글자를 찾다가 `BigTextStyleInformation` 쪽을 오진하게 된다
□ 접힌 알림에서 첫 줄이 잘려 보이지 않는다
□ 설정 › 앱 › 공직플랜 › 알림에 `일정 알림` 채널이 **첫 실행 직후** 있다
□ adb shell dumpsys package com.planroutine.app | grep -i dexterous  → receiver 둘
□ 예약 후 `adb reboot` → 재부팅 뒤에도 예약이 남아 있다
   (adb shell dumpsys alarm | grep planroutine)
□ adb shell dumpsys deviceidle force-idle 로 Doze 강제 후 발화 지연 관찰
```

**위 목록은 debug 빌드로 밟는다 — 그것만으로는 원리적으로 부족하다.** `flutter run`은 축소가
없어 §M1-C8의 두 함정(아이콘 리소스 삭제·Gson 규칙 누락)이 **전부 통과한다.** 그래서 아래 셋은
**레인이 만든 release AAB를 bundletool로 깔아** 다시 밟는다.

```
□ (release) 상태바에 흰 실루엣이 뜬다
   → 리소스 축소가 ic_notification을 지웠으면 알림이 **한 건도 뜨지 않는다**
     (initialize가 아이콘 검증에 실패해 성공 응답 없이 return → PlatformException)
□ (release) 예약 후 adb reboot → dumpsys alarm에 예약이 남아 있다
   → R8 fullMode가 Gson 역직렬화를 깼으면 여기서만 빈다
□ (release) 설정 › 알림 › 고급 › 예약된 알림 보기 → 목록이 보인다
   → 같은 Gson 경로(pendingNotificationRequests)를 태우는 두 번째 관측점이다
```
`aapt2`나 매니페스트 grep으로는 못 잡는다 — 지워진 것은 리소스이고, 지워졌다는 사실은 **런타임
조회 실패로만** 드러난다.

**`scheduleQuickTest`(5초)가 inexact에서 언제 뜨는지는 미확인이다.** 눈에 띄게 늦으면
`설정 › 알림 › 고급 › 테스트`가 "고장난 것"으로 읽힌다 — 그때는 **테스트 경로만**
`_plugin.show()`(즉시)로 바꾼다. 예약 경로는 건드리지 않는다(테스트 버튼의 목적은 채널·권한·
아이콘 확인이고 스케줄러 검증이 아니다).

#### 신규 테스트 — 이 마일스톤에서 로직이 가장 많이 바뀌는 항목이다

M2-①은 init·채널 생성·권한 분기·`BigTextStyleInformation`·스케줄 모드 두 곳을 건드리는데,
**직전까지 자동 검증이 0건이었다.** CLAUDE.md의 "신규 기능은 단위 + 위젯 테스트 작성"에
정면으로 걸리고, 회귀 신호가 없어 누가 `buildNotificationDetails`를 `const`로 되돌려도
908건이 전부 초록이다. 그래서 **발판을 먼저 만든다.**

**(가) 발판 — `test/helpers/fake_notification_service.dart`** (§결정 F)

`NotificationService`(추상 클래스)의 fake 구현. 받은 `List<PendingNotification>`·권한 응답·
`cancel` 호출을 기록해 검사할 수 있게 한다. 자리는 `test/helpers/test_database.dart`와 같은
곳이다 — 이 리포의 테스트 헬퍼 관례가 거기 하나뿐이고, `test/features/`는 대상 코드의 경로를
그대로 미러링하는 자리라 공용 fake가 앉을 곳이 아니다.

> ⚠️ **`notification_service.dart:10`의 doc은 함께 고친다.** 지금은
> `테스트에선 [FakeNotificationService]로 교체`라고 dartdoc 링크로 적혀 있는데, `lib/`는
> `test/`를 import할 수 없으므로 이 링크는 **어디에 만들어도 영구히 해소되지 않는다.**
> 링크를 걷고 경로를 평문으로 적는다(`test/helpers/fake_notification_service.dart`). Fake를
> `lib/`로 옮겨 링크를 살리는 쪽은 **테스트 코드를 앱 번들에 싣는 것**이라 하지 않는다.

**(나) 순수 함수 유닛 — `test/features/notifications/notification_details_test.dart`**

```
□ buildNotificationDetails(body).android!.styleInformation 가 BigTextStyleInformation이고
  bigText == body 다  ← 이것이 "이번 주 섹션이 안 보인다"의 회귀 가드다
□ 두 번 불러 만든 객체가 서로 다르다 (const로 되돌리면 본문이 공유돼 빈다)
□ channelId == 'schedule_reminder' (bump는 사용자 알림 설정을 초기화하는 변경이다)
□ 채널 이름·설명이 NotificationStrings.channelName / channelDescription과 같다
□ importance == high · priority == high · category == reminder
□ iOS 쪽 interruptionLevel == timeSensitive  ← iOS 회귀 가드. Android 작업이 이 값을
  건드리지 않았음을 유닛으로 고정한다(§검증 계층의 iOS 행)
□ kAndroidScheduleMode == AndroidScheduleMode.inexactAllowWhileIdle
```

**(다) 정적 가드 — 스케줄 모드가 두 곳에서 어긋나는 것을 막는다**

`_schedule`과 `scheduleQuickTest`가 **둘 다** 상수를 쓰는지는 값 검사로는 알 수 없다. 소스를
읽어 검사한다(`test/features/settings/data_source_credit_test.dart`가 같은 방법을 쓴다):

```
□ notification_service.dart에 `exactAllowWhileIdle` 리터럴이 0건이다
   (`inexactAllowWhileIdle`도 리터럴로 없어야 한다 — 상수를 경유해야 한다)
□ `androidScheduleMode:` 가 나오는 자리 전부가 `kAndroidScheduleMode`를 받는다
```
이 값을 실수하면 결과가 테스트 실패가 아니라 **Play 고위험 권한 심사**다. 그래서 값의
정확성보다 "두 곳이 갈라지지 않음"을 지킨다.

**(라) 기존 테스트 — 한 건도 깨지지 않는다**

- `notification_rules_test` / `notification_settings_test` — 순수 함수·직렬화만, 플랫폼 무관.
- `today_providers_test:128` — `notificationSyncerProvider`를 `_GatedSyncer`로 override해
  실제 서비스에 안 닿는다.
- `visual_check.dart` / `integration_test/app_test.dart:526-553` — 행이 하나 늘어도 견딘다
  (`probe`는 예외만 수집 + `scroll: true`, `_scrollToInSettings`는 20회 드래그 + `ensureVisible`).
- **`FlutterLocalNotificationService`를 직접 부르는 테스트는 0건이었다** — 위 (가)~(다)가
  그 공백을 메운다. 여전히 못 메우는 것은 **플러그인 메서드 채널 뒤**이고(실제 발화·채널
  생성·권한 다이얼로그), 그것은 에뮬레이터 체크리스트와 release 스모크의 몫이다.

### M2-② CSV 공유 진입 — 손이 가장 많이 가는 곳

`MainActivity.kt`가 `AppDelegate.swift` + `SceneDelegate.swift` 역할을 한다. **같은 채널명
`planroutine/shared_file`, 같은 프로토콜(`getPending` / `onFileShared`) → `app.dart`는 한 줄도
안 바뀐다.** 지켜야 하는 계약(iOS 실측):

| 항목 | 값 |
|---|---|
| 채널명 | `planroutine/shared_file` |
| native→Dart | `invokeMethod("onFileShared", <String path>)` |
| Dart→native | `invokeMethod<String>("getPending")` → `String?` 반환 후 **버퍼 비움** |
| 미구현 메서드 | `notImplemented()` |
| 인자 타입 | **파일시스템 절대경로 문자열**(URI 아님) |
| Dart 게이트 | `path.toLowerCase().endsWith('.csv')` 아니면 조용히 return (`app.dart:69`) |

**`importFromPath`가 `File(path).readAsBytes()`를 부르는 것이 결정적이다** —
`content://` URI를 그대로 넘기면 `dart:io`가 못 읽어 `ImportError`가 뜬다. 브리프의 "cacheDir
복사" 판단이 맞다.

#### 호출 순서는 구조적으로 보장된다 — `onCreate`를 오버라이드하지 않는다

Flutter 3.41.6 엔진 바이트코드 실측 순서:
```
FlutterActivity.onCreate
  → Activity.onCreate(savedInstanceState)        ← Intent는 이 이전에 이미 세팅돼 있다
  → delegate.onAttach → … → Host.configureFlutterEngine(flutterEngine)   ← 여기
FlutterActivity.onStart
  → delegate.onStart → doInitialFlutterViewRun → executeDartEntrypoint   ← Dart가 도는 곳
```
→ `configureFlutterEngine` 안에서 채널을 만들고 `intent`를 읽으면 **`getIntent()`는 이미 유효하고
Dart는 아직 돌지 않는다.** 순서 위험이 사라지므로 `onCreate`를 건드리지 않는다.

⚠️ **`super.configureFlutterEngine()`을 빼면 컴파일은 되고 앱은 뜨는데 모든 플러그인이
`MissingPluginException`을 던진다** — 그 안에서 `GeneratedPluginRegister.registerGeneratedPlugins`가
돈다(바이트코드 확인). sqflite·shared_preferences·google_sign_in·device_calendar·file_picker가
전부 죽는데 화면은 그려져서 원인 찾기가 오래 걸린다.

#### 파일 앱의 running 진입은 `onNewIntent`가 아니다

AOSP `DocumentsUI/AbstractActionHandler.buildViewIntent`는 `FLAG_GRANT_READ_URI_PERMISSION |
FLAG_ACTIVITY_SINGLE_TOP`만 붙이고 **`FLAG_ACTIVITY_NEW_TASK`를 붙이지 않는다.** 공식 문서:
"Typically, they're launched into the task that called `startActivity()`, unless the Intent object
contains a `FLAG_ACTIVITY_NEW_TASK` instruction."

→ 우리 액티비티가 **DocumentsUI의 태스크 위에 새 인스턴스로** 올라간다. `singleTop`은 "같은
태스크 맨 위에 이미 있을 때"만 재사용하므로 해당 없다. **즉 Android의 주 경로는 `onCreate` +
pending 버퍼이고, iOS와 정반대다**(iOS는 running이면 항상 `onFileShared` push).

부작용: 같은 프로세스에 FlutterEngine이 하나 더 생기고 Dart isolate가 하나 더 돌며 `main()`이
다시 실행된다(휴지통 purge·알림 sync 재실행, sqflite 두 번째 핸들). 크래시는 아니지만
**M2 에뮬레이터에서 확인할 항목**이고, 사용자에게는 "앱이 두 번 열린 것처럼" 보인다.
`onNewIntent` 오버라이드는 그래도 넣는다 — 8줄이고 iOS 패리티이며 sharesheet 경로는 다를 수 있다.
**다만 테스트 시나리오의 무게중심을 `onCreate`에 둔다.**

#### 중복 인스턴스의 직접 원인은 `android:taskAffinity=""`다 — 손잡이가 여기 있다

매니페스트의 `<activity>`에 **`android:taskAffinity=""`가 이미 있다**(실측, Flutter 템플릿의
기본값). 친화성이 빈 문자열이면 이 액티비티는 **어떤 태스크와도 친화성이 없다** — 그래서

- 파일 앱이 `FLAG_ACTIVITY_NEW_TASK` 없이 부른 인스턴스는 DocumentsUI 태스크 안에 살고,
- **런처로 다시 열면 그 인스턴스와 합쳐지지 않고 별 태스크가 뜬다.**
- 최근 앱 목록에 공직플랜 카드가 **둘** 남는다.

즉 "두 번째 FlutterEngine"(§미확인 13)은 우연이 아니라 이 속성의 결과다. 초안이 이 속성을
언급하지 않아 **조정 가능한 손잡이가 문서에서 사라져 있었다.**

지금은 **그대로 둔다** — 값을 지우면(기본 친화성 = 패키지명) 태스크가 합쳐지지만 그때
DocumentsUI 위에서 열린 화면이 런처 태스크로 끌려오는 다른 거동이 생기고, 그 거동은 우리가
관측한 적이 없다. **먼저 관측하고 나서 판단한다**: M2-② 검증에 "최근 앱 카드가 몇 개인가"를
넣고, 실제로 문제로 확인되면 후보 조치는 (a) `taskAffinity` 속성 제거, (b) 인텐트 필터
액티비티를 `taskAffinity`만 다른 alias로 분리 — 둘 중 하나다.

#### `flutter_deeplinking_enabled` — 브리프에 없던 함정

`FlutterActivityLaunchConfigs.deepLinkEnabled(Bundle)` 바이트코드: 메타데이터가 **없으면 true**다.
그러면 `maybeGetInitialRouteFromIntent`가 `intent.getData().toString()`을 초기 라우트로 밀어 넣고,
go_router 15.1.3의 `_effectiveInitialLocation`은 **플랫폼 기본이 `/`가 아니면 그것을 이긴다**
(`router.dart:542`, 이 리포는 `overridePlatformDefaultLocation`을 쓰지 않는다).

기존 redirect(`app_router.dart:46-47`)는 `uri.scheme == 'file' || uri.path.endsWith('.csv')`라
**제공자에 따라 갈린다**:
- `content://com.android.externalstorage.documents/document/primary%3ADownload%2Ffoo.csv`
  → `Uri.path`가 디코딩돼 `.csv`로 끝나 **우연히 통과**
- `content://media/external/downloads/1000000123` 또는 `.../document/msf%3A…`
  → **통과 못 함 → Page Not Found**

비결정적이라 에뮬레이터 한 번 성공으로는 못 잡는다. **매니페스트에서 끈다:**

```xml
<!-- <activity> 안 -->
<!-- Flutter가 intent.getData()를 초기 라우트로 밀어 넣는 기본 동작을 끈다(기본값 true).
     안 끄면 파일 앱에서 열었을 때 content:// URI가 go_router의 initialLocation을 덮어
     제공자에 따라 Page Not Found가 뜬다. 공유 파일 경로는 planroutine/shared_file
     채널이 전담한다. -->
<meta-data
    android:name="flutter_deeplinking_enabled"
    android:value="false" />
```
끄면 `getInitialRoute()`가 null → 엔진이 `"/"`를 쓰고 go_router가 자기 `initialLocation`을 쓴다.
**`app.dart`도 `app_router.dart`도 안 바뀌고 iOS 경로는 한 글자도 안 바뀐다.**

> 대안(둘 중 하나만): `app_router.dart`의 redirect에 `uri.scheme == 'content' ||` 한 줄 추가.
> 이쪽은 Dart 파일이 바뀌어 iOS와 공유되므로 매니페스트 쪽을 권한다. (`ACTION_SEND`는
> `intent.getData()`가 null이라 애초에 영향이 없다 — 문제는 `VIEW`뿐이다.)

#### 인텐트 필터

```xml
<!-- 파일 앱 / 문서 앱에서 "열기" (ACTION_VIEW).
     mimeType만 쓴 필터는 content:/file: 스킴을 자동 포함하므로 <data android:scheme>는
     불필요하다(AOSP IntentFilter.matchData 실측 + 공식 문서: "a component is presumed to
     support content: and file: data if its filter lists only a MIME type").
     text/comma-separated-values를 맨 위에 둔 것은 **스톡 안드로이드가 .csv에 실제로 붙이는
     타입이 이것**이기 때문이다(아래). 순서를 바꾸지 말 것. -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/comma-separated-values" />
    <data android:mimeType="text/csv" />
    <data android:mimeType="application/csv" />
    <data android:mimeType="application/vnd.ms-excel" />
</intent-filter>

<!-- 카카오톡 / 메일 / 드라이브에서 "공유" (ACTION_SEND).
     URI는 intent.data가 아니라 EXTRA_STREAM으로 온다. -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/comma-separated-values" />
    <data android:mimeType="text/csv" />
    <data android:mimeType="application/csv" />
    <data android:mimeType="application/vnd.ms-excel" />
</intent-filter>
```

`android:exported="true"`·`android:launchMode="singleTop"`·`android:taskAffinity=""`는 **이미
있으므로 이번에 건드리지 않는다**(셋째의 대가는 위 절에 적었다 — 모르고 두는 것이 아니다).
`CATEGORY_DEFAULT`는 필수(암시적 인텐트), `BROWSABLE`은 불필요(브라우저에서 여는 링크가 아니다).
`<queries>`도 손대지 않는다 — 가시성 필터링은 **우리가 남을 조회할 때만** 걸리고, 인텐트를
받는 데는 영향이 없다.

**MIME 4종 중 진짜 1순위가 확정됐다.** AOSP `frameworks/base/mime/java-res/android.mime.types:114`가
`?text/comma-separated-values csv`이고 `?`는 **MIME→확장자 방향만** putIfAbsent라 확장자→MIME
방향은 강제 덮어쓰기다. Debian `mime.types:739`의 `text/csv`가 먼저 로드되지만 뒤에 덮인다
(`DefaultMimeMapFactory.java:70-72`). 그리고 `FileSystemProvider.getDocumentType()`(`:495`)이
확장자→`MimeTypeMap`으로 타입을 정해 `buildViewIntent`의 `setDataAndType`에 그대로 넣는다.
→ **`MimeTypeMap.getMimeTypeFromExtension("csv")` = `text/comma-separated-values`.**
브리프가 이 값을 넣은 것은 정확할 뿐 아니라 스톡에서 1순위다.

`text/plain` 제외의 대가는 **파일 앱 경로에서 0**이다(위 타이핑 때문에 plain으로 올 일이 없다).
그리고 인텐트 타입이 `*/*`이면 mimeType을 하나라도 선언한 필터에 **자동으로 걸리므로**
(`IntentFilter.findMimeType`: `if (typeLength == 3 && type.equals("*/*")) return !t.isEmpty();`)
범용 공유 앱도 커버된다.

⚠️ **`application/octet-stream`이 남은 구멍이다.** 4종에 없고 `*/*`에도 안 걸린다. 메일 앱은
첨부의 Content-Type을 그대로 쓰므로 발신 측이 octet-stream으로 보낸 CSV는 우리가 목록에 안 뜬다.
넣으면 모든 바이너리 공유에 우리가 뜬다(Dart의 `.csv` 게이트가 있어 오동작은 없지만 목록 오염).
**결정: 넣지 않는다**(§결정 C). `text/plain`을 뺀 것과 같은 성격의 트레이드오프이고 같은 답을
골랐다 — 사진·zip·apk를 공유하는 사람에게 공직플랜이 뜨는 대가가 메일 첨부 몇 건보다 크다.
메일 첨부 CSV는 **"파일 앱에 저장 후 열기"** 경로로 받는다(위 `ACTION_VIEW` 필터가 잡는다).
다음 사람이 "메일이 안 되네"로 되돌리지 않게 이 문단을 남긴다.

⚠️ **`mimeType` 필터는 타입 없는 인텐트를 못 받는다**(`findMimeType(null)` → `NO_MATCH_TYPE`).
타입 없이 `file:///…/x.csv`만 던지는 구식 파일 매니저는 안 잡힌다. API 24+에서 `file://` 공유는
발신 측이 `FileUriExposedException`을 맞으므로 **가치가 낮아 대응하지 않는다.**

`ACTION_SEND_MULTIPLE`도 넣지 않는다 — iOS에 대응물이 없어 패리티가 깨진다(§범위 밖).

#### 고르는 쪽 — `file_picker`도 Android에서 갈린다

위까지가 **받는 쪽**(인텐트)이다. 그런데 `/import`의 **주 입구는 `파일 선택`**이고 그 경로도
Android에서 iOS와 구조가 다르다. 초안이 이쪽을 검증 항목조차 두지 않았다.

`import_providers.dart:82-85`는 `FileType.custom` + `allowedExtensions: ['csv']`를 쓴다.
Android 번역 경로(전부 `file_picker-9.2.3` 실측):

```
FileType.custom
  → FilePickerPlugin.resolveType("custom") = "*/*"                      (:179-180)
  → FileUtils.getMimeTypes(["csv"])
      = [MimeTypeMap.getSingleton().getMimeTypeFromExtension("csv")]    (:53)
      = ["text/comma-separated-values"]        ← 우리가 §인텐트 필터에서 1순위로 확정한 그 값
  → Intent(ACTION_OPEN_DOCUMENT) + CATEGORY_OPENABLE                    (:250-254)
      setType("*/*") + EXTRA_MIME_TYPES = ["text/comma-separated-values"]  (:259-269)
```

**급소는 `EXTRA_MIME_TYPES`가 SAF의 필터라는 것이다.** DocumentsUI는 각 항목의 **제공자가
보고한 타입**을 이 목록과 맞춰 보고, 안 맞으면 **회색으로 선택 불가**로 만든다. 그래서
확장자가 `.csv`여도 제공자가 다른 타입을 보고하면 사용자가 그 파일을 고를 수 없다 —
카카오톡·메일로 받아 `다운로드`에 떨어진 파일에서 실제로 자주 나는 증상이고, **화면에는
아무 오류도 없어** "앱이 내 CSV를 못 본다"로만 보인다.

받는 쪽에서 `application/octet-stream`을 뺀 결정(§결정 C)은 **여기에 대한 답이 아니다.**
그쪽은 "우리가 공유 목록에 뜰지"이고, 이쪽은 "우리 화면에서 파일을 고를 수 있을지"다.
목록 오염이라는 대가가 없으므로 판단 기준이 다르다.

**검증 — 두 경우를 손으로 눌러 본다**
```
□ (a) 확장자·타입이 정상인 CSV — `adb push … /sdcard/Download/x.csv` 뒤 파일 선택
□ (b) 제공자가 octet-stream으로 타이핑한 CSV — 메일 첨부 저장본 또는
      `adb shell content insert` 로 MediaStore에 mime_type을 바꿔 넣은 것
      (에뮬레이터에서 (b)를 만들 방법이 확실치 않으면 테스터 과제로 돌린다)
□ 고른 뒤 `result.files.first.path`가 non-null이다 — file_picker가 content://를
  `cacheDir/file_picker/`로 복사해 경로를 준다. null이면 `importFromPath`가 아예 못 돈다
□ 한글 파일명이 온전히 넘어온다
```

**폴백 방침을 미리 정한다.** (b)가 막히면 `allowedExtensions`를 유지하는 우회는 없다 —
플러그인이 확장자→MIME 한 방향만 만들고 MIME을 직접 넘기는 API가 없다. 그때는
**`FileType.any` + Dart 쪽 `.csv` 게이트**로 간다:

- Dart 쪽 확장자 검사가 **이미 있다**(`app.dart:69`의 공유 경로와 같은 성질) → 안전망이 선다.
- 대가는 파일 선택 화면에 모든 파일이 보이는 것이다. `/import`는 "작년 업무 CSV"를 고르러
  들어온 전용 화면이라 그 대가가 작다 — 목록 오염이 **앱 밖**으로 새지 않는다.
- ⚠️ 이 폴백은 **iOS 동작도 바꾼다**(iOS는 `UTType`으로 정확히 걸러 지금 문제가 없다).
  그래서 폴백을 고르면 `Platform.isAndroid` 분기로 **Android에서만** `any`를 쓴다 —
  플랫폼 분기 규칙은 §M2-⑦에서 정한 것과 같다.

#### `MainActivity.kt`

```kotlin
package com.planroutine.app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * 다른 앱(카카오톡/메일/파일 앱)이 CSV를 "공직플랜으로 열기"/"공유"로 넘길 때
 * iOS의 AppDelegate + SceneDelegate가 하는 일을 한다.
 * 채널명·메서드명·인자 타입은 iOS와 같아야 한다 — app.dart는 한 줄도 안 바뀐다.
 *
 * iOS와 다른 점 둘:
 *  1. 넘어오는 것이 파일 경로가 아니라 content:// URI라서 cacheDir에 복사한다
 *     (iOS의 LSSupportsOpeningDocumentsInPlace에 해당하는 제자리 열기가 없다).
 *  2. 파일 앱의 ACTION_VIEW는 FLAG_ACTIVITY_NEW_TASK 없이 오므로 앱이 떠 있어도 이
 *     액티비티가 새로 만들어진다 → 주 경로는 onNewIntent가 아니라 configureFlutterEngine이다.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "PlanRoutineShare"
        private const val CHANNEL = "planroutine/shared_file"

        /** cacheDir 안의 전용 폴더. 새 공유가 올 때마다 통째로 비운다. */
        private const val SHARED_DIR = "shared_csv"

        /** 확장자가 없을 때만 .csv를 붙여도 되는 MIME 화이트리스트. */
        private val CSV_MIMES = setOf(
            "text/comma-separated-values",   // 안드로이드가 .csv에 실제로 붙이는 타입
            "text/csv",
            "application/csv",
            "application/vnd.ms-excel",
        )
    }

    /** Flutter가 아직 안 돌 때 받아 둔 경로. getPending으로 꺼내면 비운다. */
    private var pendingPath: String? = null
    private var sharedChannel: MethodChannel? = null

    /**
     * onCreate를 오버라이드하지 않는다 — FlutterActivity.onCreate가 내부에서
     * Activity.onCreate → delegate.onAttach → 이 메서드 순으로 흐르고, Dart entrypoint는
     * 그보다 뒤인 onStart에서 실행된다. 여기서 채널을 만들고 인텐트를 읽으면 순서가
     * 구조적으로 보장된다(getIntent()는 Activity.onCreate 전에 이미 세팅돼 있다).
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 절대 빼지 말 것 — GeneratedPluginRegister가 여기서 돈다.
        // 빠지면 sqflite·shared_preferences·google_sign_in 등 전부 MissingPluginException.
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        sharedChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPending" -> {
                    val path = pendingPath
                    pendingPath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // cold-start (그리고 파일 앱 경로에서는 running도 여기로 온다)
        pendingPath = materializeSharedCsv(intent)
    }

    /**
     * launchMode=singleTop + 같은 태스크 맨 위일 때만 온다.
     * 실제로는 잘 안 타지만 iOS의 running push와 대칭을 맞춰 둔다.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)   // 이후 getIntent()가 새 인텐트를 가리키도록

        val path = materializeSharedCsv(intent) ?: return
        val channel = sharedChannel
        if (channel != null) {
            channel.invokeMethod("onFileShared", path)
        } else {
            // 엔진이 아직/이미 없을 때만 버퍼로 떨어뜨린다. 무조건 버퍼에 넣으면
            // 액티비티 재생성 시 옛 경로가 다시 재생된다.
            pendingPath = path
        }
    }

    // ── URI → cacheDir 복사 ─────────────────────────────────────────

    private fun materializeSharedCsv(intent: Intent?): String? {
        val uri = extractUri(intent) ?: return null
        return try {
            copyToCache(uri, intent?.type)
        } catch (e: Exception) {
            // 공유 실패로 앱 기동을 막지 않는다. Dart는 null을 받고 평소대로 뜬다.
            Log.w(TAG, "공유 파일 복사 실패: $uri", e)
            null
        }
    }

    private fun extractUri(intent: Intent?): Uri? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> streamExtra(intent) ?: clipUri(intent)
            else -> null
        }
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    private fun clipUri(intent: Intent): Uri? =
        intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri

    private fun copyToCache(uri: Uri, intentType: String?): String? {
        val name = fileNameFor(uri, intentType)

        val dir = File(cacheDir, SHARED_DIR)
        // 정리 시점 = "다음 공유가 올 때". 항상 최대 1개만 남는다.
        // (file_picker의 cacheDir/file_picker/ 는 이 앱이 clearTemporaryFiles()를 한 번도
        //  부르지 않아 이미 새는 중이다 — 새 경로는 같은 실수를 반복하지 않는다.)
        dir.deleteRecursively()
        if (!dir.mkdirs() && !dir.isDirectory) return null

        val target = File(dir, name)
        // DISPLAY_NAME에 '/'나 '..'가 섞여 오는 경우 방어
        if (!target.canonicalPath.startsWith(dir.canonicalPath + File.separator)) return null

        contentResolver.openInputStream(uri).use { input ->
            if (input == null) return null
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        return target.absolutePath
    }

    /**
     * 복사본 파일명. Dart의 _handleSharedFile이 `.csv` 접미사를 보고 거르므로
     * **확장자를 살리는 것이 이 함수의 존재 이유**다.
     *
     * 확장자가 없을 때만, 그리고 인텐트가 스스로 CSV라고 밝힌 경우에만 .csv를 붙인다.
     * 무조건 붙이면 Dart 쪽 2차 방어선이 무력해진다.
     */
    private fun fileNameFor(uri: Uri, intentType: String?): String {
        val raw = queryDisplayName(uri) ?: uri.lastPathSegment
        val base = raw?.substringAfterLast('/')?.trim().orEmpty()
        val safe = if (base.isEmpty() || base == "." || base == "..") "shared" else base
        if (safe.lowercase().endsWith(".csv")) return safe

        val type = (intentType ?: contentResolver.getType(uri))?.lowercase()
        return if (type in CSV_MIMES) "$safe.csv" else safe
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return null
        return contentResolver
            .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c ->
                if (!c.moveToFirst()) return@use null
                val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (i >= 0) c.getString(i) else null
            }
    }
}
```

#### M2-② 검증

```bash
# 0) 에뮬레이터에 CSV 밀어넣기
adb push data/sample/2025_생산문서등록대장.csv /sdcard/Download/planroutine_test.csv
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Download/planroutine_test.csv

# 1) 필터가 실제로 걸렸는지
adb shell dumpsys package com.planroutine.app | sed -n '/Activity Resolver Table/,/^$/p'

# 2) 로그로 어느 경로를 탔는지
adb logcat -s PlanRoutineShare:V flutter:V ActivityTaskManager:I

# 3) 태스크가 몇 개 생겼는지 = 중복 인스턴스 여부 (taskAffinity="" 의 결과를 본다)
adb shell dumpsys activity activities | grep -i "Task\|planroutine"

# 4) 캐시가 쌓이는지 (항상 1개여야 한다)
adb shell run-as com.planroutine.app ls -la cache/shared_csv
```
```
□ 파일 앱에서 CSV를 손으로 탭 → /import로 가고 즉시 파싱된다 (cold-start)
□ 앱을 띄운 채 같은 동작 → 동작한다 (경로가 onCreate여도 결과는 같아야 한다)
□ Page Not Found가 뜨지 않는다 (deeplinking off 검증 — 여러 제공자로)
□ 한글 파일명(2025_생산문서등록대장.csv)이 온전히 넘어온다
□ 공유 두 번 연속 → cache/shared_csv에 파일이 1개만 남는다
□ /import에서 뒤로가기 한 번 → 오늘 탭 (종료 아님, §M2-③)
□ /import → `파일 선택`으로 CSV를 고를 수 있다 (§고르는 쪽 — (a)·(b) 두 경우)
□ **최근 앱 목록에 공직플랜 카드가 몇 개인가** — `taskAffinity=""`대로면 둘이다.
   숫자를 적어 둘 것. 예상과 다르면 그것도 정보다(위 절의 판단 근거가 된다)
□ 카드 둘 상태에서 sqflite·알림이 멀쩡한가 (§미확인 13 — 같은 관찰로 함께 확정된다)
```
**손으로 탭해서 검증한다.** `adb am start`로 만든 `content://` URI는 제공자·기기마다 달라
스모크 이상의 값이 없다(§미확인).

### M2-③ 뒤로가기

판정을 순수 함수로 뺀다. **Android 없이 유닛 테스트로 고정할 수 있는 유일한 부분**이고,
자리는 `MainShell.indexForLocation` 바로 옆이다 — 그 함수가 이미 static이고 같은 파일이
`AppRoutes`를 import하며, 테스트도 `test/shared/main_shell_tab_index_test.dart` 하나로 모여 있다.
`features/*/domain/`의 순수 함수들(`buildTodayView`·`busPollIntervalFor`)은 feature 도메인
소속이라 라우팅 판정과 결이 다르다.

```dart
// lib/shared/widgets/main_shell.dart — indexForLocation 바로 아래
  /// 뒤로가기가 갈 곳. **null이면 앱을 종료한다.**
  ///
  /// 오늘 탭이 홈이다 — 다른 탭에서 백을 누르면 오늘로 오고, 오늘에서 한 번 더 누르면
  /// 나간다(스낵바 없음).
  ///
  /// ⚠️ push 라우트(`/trash`·`/import`·`/bus/*`)도 **여기 들어온다.** 보통은 그 Route가
  /// 백을 먼저 가져가지만(실측), 외부 CSV 공유로 `/import`가 스택 맨 아래인 콜드스타트에서는
  /// 중첩 Navigator가 pop할 것이 없어 셸까지 온다. 넷 모두 값이 정의돼 있어야 한다.
  static String? backTargetFor(String location) =>
      location == AppRoutes.today ? null : AppRoutes.today;
```

#### `canPop`을 고정하지 않는다 — 동작은 브리프와 같고 예측형 백이 살아난다

브리프는 `PopScope(canPop: false)`다. 그 형태로도 동작은 정확히 의도대로지만, `canPop: false`는
**앱 수명 내내** `frameworkHandlesBack=true`를 만들어(`WidgetsApp`이
`SystemNavigator.setFrameworkHandlesBack`을 호출) Android 16의 기본 back-to-home 예측형
애니메이션을 끈다. `PopScope` 문서가 명시한다: "Android's predictive back feature will not
animate when this boolean is false."

`canPop`을 `target == null`로 두면 **동작은 완전히 같으면서** 오늘 탭에서 시스템 기본 경로가
유지된다. 실측으로 확인한 두 경우:
```
/settings 백 → 콜백 [didPop=false, target=/today] → context.go('/today'), platform 호출 없음
/today    백 → 콜백 0회, handled=false → 프레임워크가 스스로 SystemNavigator.pop()
```
push 라우트가 얹힌 동안은 중첩 Navigator가 `canHandlePop: true`로 재발행하므로 그때만 자동으로
억제된다.

```dart
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = indexForLocation(location);
    final target = backTargetFor(location);

    return PopScope(
      // target == null(= 오늘 탭)일 때만 시스템에 넘긴다. 넘기면 프레임워크가 알아서
      // SystemNavigator.pop()을 부르고(binding.dart:983-991), 예측형 백 애니메이션도 남는다.
      // canPop: false로 고정하면 그 애니메이션이 앱 수명 내내 꺼진다.
      canPop: target == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || target == null) return;
        context.go(target);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: FloatingTabBar(/* 기존 그대로 */),
      ),
    );
  }
```
- `onPopInvoked`는 **deprecated**다(`'Use onPopInvokedWithResult instead. This feature was
  deprecated after v3.22.0-12.0.pre.'`). 둘을 동시에 주면 생성자 `assert`가 막는다.
- 종료에 `SystemNavigator.pop()`을 **직접 부를 필요가 없다.** 프레임워크가 부른다. 직접 부르는
  형태(브리프안)를 택하더라도 `dart:io`의 `exit()`은 쓰지 않는다 — 공식 문서가 "the latter may
  cause the underlying platform to act as if the application had crashed"라고 명시한다.
  엔진 경로는 `FlutterActivity extends Activity`라 `activity.finish()`다(표준 종료).
- `GoRouterState.of(context).uri.path`가 push 중에 무엇을 반환하는지는 **한 줄 프로브로
  확정할 것** — 이 값이 이제 `canPop` 계산에도 들어간다(§미확인).

#### 예측형 백을 Android 13~15에서도 켜려면 (선택)

```xml
<application
    android:label="공직플랜"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:enableOnBackInvokedCallback="true">
```
target 36 + Android 16은 기본 true라 무의미하지만, API 33~35 기기에서는 이 줄이 없으면
Flutter의 `registerOnBackInvokedCallback`이 무시되고 레거시 경로로 떨어져 예측형 백이 나오지
않는다. `flutter create` 템플릿은 이 줄을 넣지 않는다.

#### 온보딩 — 브리프에 없던 항목

`/onboarding`은 ShellRoute **밖** 루트 Navigator의 첫 라우트라 `MainShell`의 `PopScope`가 닿지
않는다. 실측: `handlePopRoute()`가 false를 반환 → 프레임워크가 `SystemNavigator.pop()` →
**뒤로가기 한 번에 앱이 종료된다.**

> **결정: 페이지를 되돌린다. 첫 페이지에서 누르면 종료**(§결정 D). 이미 정한 원칙("한 단계
> 되돌린다, 되돌릴 게 없으면 종료")의 예외가 될 이유가 없다 — 온보딩 중 실수로 백을 누르면
> 앱이 꺼져 처음부터 다시 하는 현재 동작이 그 원칙과 어긋난다.

**실물 구조를 확인했다 — 작업이 0이 아니다.** `onboarding_screen.dart`는
`_OnboardingScreenState`에 `PageController _controller`와 `int _page`를 들고
`PageView.builder(itemCount: _pages.length, onPageChanged: (i) => setState(...))`로 3페이지를
그린다(`:22-23`, `:122-127`). 즉 **되돌릴 상태(`_page`)와 되돌릴 수단(`PageController`)이 이미
둘 다 있다.** 붙이는 것은 `PopScope` 하나와 판정 한 줄이다.

```dart
// lib/features/onboarding/presentation/screens/onboarding_screen.dart
//
// 판정을 순수 함수로 뺀다 — `MainShell.backTargetFor`와 같은 이유이고, 같은 형태로
// "null이면 여기서 더 되돌릴 게 없다"를 뜻한다. 두 함수의 관용구를 맞춰 두면 다음 사람이
// 뒤로가기 규칙을 한 곳에서 읽는다.
//
/// 온보딩에서 뒤로가기가 갈 페이지. **null이면 앱을 종료한다.**
///
/// ⚠️ **`OnboardingScreen`(공개 위젯 클래스)의 static으로 둔다 — `_OnboardingScreenState`가
/// 아니다.** State 클래스는 `_` private이라 테스트가 이름으로 부를 수 없고,
/// `@visibleForTesting`도 private 클래스 멤버에는 아무 효력이 없다.
/// `MainShell.backTargetFor`가 공개 위젯의 static인 것과 같은 이유다(테스트도 같은 형태로 부른다).
class OnboardingScreen extends ConsumerStatefulWidget {
  @visibleForTesting
  static int? backPageFor(int current) => current <= 0 ? null : current - 1;
  ...
}

  @override
  Widget build(BuildContext context) {
    final back = backPageFor(_page);
    return PopScope(
      // canPop을 고정하지 않는 이유는 MainShell과 같다 — 첫 페이지에서만 시스템에 넘겨
      // 예측형 백 애니메이션을 살린다.
      canPop: back == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || back == null) return;
        // animateToPage가 onPageChanged를 불러 _page가 따라온다 — setState를 따로
        // 부르지 않는다(부르면 상태가 두 곳에서 갱신돼 인디케이터가 한 프레임 어긋난다).
        _controller.animateToPage(
          back,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(/* ⑥-b 그대로 */),
    );
  }
```

- `AnnotatedRegion`(§⑥-b)과 `PopScope`가 **같은 화면에 함께 들어간다** — 둘을 다른 순서로
  중첩해도 동작은 같지만, ⑥-b를 나중에 넣다가 `PopScope`를 지우는 사고를 막으려면 한 커밋에
  같이 넣는 것이 낫다.
- **`건너뛰기`·`시작하기`는 건드리지 않는다.** 둘 다 `_finish()`로 `markDone()` + `context.go`이고
  백과 경로가 다르다.

**유닛 테스트** — `test/features/onboarding/onboarding_back_page_test.dart`
```
□ OnboardingScreen.backPageFor(0) == null    (첫 페이지 = 종료)
□ OnboardingScreen.backPageFor(1) == 0
□ OnboardingScreen.backPageFor(2) == 1
□ OnboardingScreen.backPageFor(-1) == null   (방어 — 음수에서 종료. 예외를 던지지 않는다)
```
페이지 수를 인자로 받지 않는 이유: 되돌리기는 **위쪽 경계만** 본다. `_pages.length`를 넘기면
쓰지 않는 인자가 생기고, 페이지를 늘릴 때 함수도 고쳐야 하는 것처럼 읽힌다.

#### M2-③ 검증

```dart
// test/shared/main_shell_back_target_test.dart
void main() {
  group('뒤로가기 목적지 — 탭 라우트', () {
    test('오늘 탭에서는 null(종료)', () {
      expect(MainShell.backTargetFor(AppRoutes.today), isNull);
    });
    test('나머지 세 탭은 오늘로 온다', () {
      expect(MainShell.backTargetFor(AppRoutes.calendar), AppRoutes.today);
      expect(MainShell.backTargetFor(AppRoutes.schedule), AppRoutes.today);
      expect(MainShell.backTargetFor(AppRoutes.settings), AppRoutes.today);
    });
  });

  group('뒤로가기 목적지 — push 라우트', () {
    // 보통은 그 Route가 백을 먼저 가져가 여기까지 오지 않는다. 그러나 외부 CSV 공유로
    // `/import`가 스택 맨 아래인 콜드스타트에서는 실제로 들어온다(실측).
    test('푸시 라우트 넷 모두 오늘로 온다 — 종료하지 않는다', () {
      for (final route in [
        AppRoutes.trash, AppRoutes.import, AppRoutes.busSettings, AppRoutes.busStops,
      ]) {
        expect(MainShell.backTargetFor(route), AppRoutes.today, reason: route);
      }
    });
  });

  test('매핑에 없으면 오늘로 온다(종료하지 않는다)', () {
    expect(MainShell.backTargetFor('/nope'), AppRoutes.today);
  });
}
```
```
□ 설정 → 버스 도착 → 정류장 검색까지 들어가 백 두 번 → 한 단계씩 돌아온다
□ 바텀시트·다이얼로그가 떠 있을 때 백 → 그것만 닫힌다 (탭 이동 안 함)
□ 외부 CSV 공유로 콜드스타트 → /import에서 백 → 오늘 탭 (종료 아님)
□ 오늘 탭에서 백 → 종료. 제스처를 끝까지 안 끌고 취소하면 예측형 미리보기가 보인다
□ 온보딩 3페이지 → 백 → 2페이지 → 백 → 1페이지 → 백 → 종료 (인디케이터 점도 따라온다)
□ 온보딩 1페이지에서 백 → 종료. 여기서도 예측형 미리보기가 보인다(canPop: true)
```
⚠️ 온보딩은 **최초 실행 1회만** 뜨는 화면이라 재확인이 번거롭다 —
`설정 › 데이터 관리 › 전체 데이터 초기화`로는 돌아오지 않는다(`onboarding_done`은
`shared_preferences`에 있고 초기화 범위는 DB뿐이다). 에뮬레이터에서는
`adb shell pm clear com.planroutine.app`로 되돌린다.

### M2-④ 구글 로그인 — 앱 코드 변경 0, 콘솔 작업만

`google_calendar_service.dart:15`의 `GoogleSignIn(scopes: [calendarEventsScope])` 한 줄이
**Android에서 정확히 올바른 형태다.** 근거:
- `GoogleSignInPlugin.java:217-219` 주석: "The clientId parameter is not supported on Android.
  Android apps are identified by their package name and the SHA-1 of their signing key."
- **`clientId`를 넣으면 오히려 해롭다** — 플러그인이 `serverClientId`로 오해해 경고를 찍고
  `requestIdToken`을 켠다(`:223-228`). 이 리포는 `clientId`를 아무 데서도 넘기지 않는다(grep 0건).
- 이 서비스가 쓰는 것은 `account.authHeaders`뿐이고 Android 구현은
  `GoogleAuthUtil.getToken(context, account, "oauth2:" + scopes)`다 — **google-services.json도
  clientId도 경유하지 않는다.**
- **`google-services.json`은 필요 없다.** `google_sign_in` README verbatim: "You don't need to
  include the google-services.json file in your app unless you are using Google services that
  require it." 게다가 `google_sign_in_android`의 gradle에 `com.google.gms.google-services`
  플러그인이 없어 **넣어도 파싱하는 주체가 없다.**

#### GCP 클라이언트는 여러 개다 — (패키지명, SHA-1) 쌍마다 하나

```
Google Cloud Console (프로젝트 번호 73700230470 — iOS와 같은 프로젝트)
  → [Google Auth Platform] → [Clients] → [CREATE CLIENT]     ← 구 [APIs & Services > Credentials]
  → Application type: Android
  → Name:         PlanRoutine Android (upload key)   ← 자유 문자열, 식별용
  → Package name: com.planroutine.app
  → SHA-1 certificate fingerprint: <지문 하나>       ← 클라이언트당 하나뿐
  → (선택) Verify ownership of your Android application — optional, 건너뛰어도 동작
```
입력 필드가 SHA-1 **하나**뿐이다. Google 공식 블로그: *"It's important to register every package
name + SHA1 fingerprint pair… you'll need to repeat this process for each package / certificate
pair you end up using."* (Firebase 콘솔의 "Add fingerprint" 버튼은 Firebase가 뒤에서 OAuth
클라이언트를 하나씩 자동 생성해 주는 것이고, 이 프로젝트는 Firebase를 안 쓴다.)

| # | 용도 | SHA-1 출처 | 언제 |
|---|---|---|---|
| 1 | 에뮬레이터 개발 | `~/.android/debug.keystore` (`9F:9B:…:8A:84`) | M2 시작 시 |
| 2 | 업로드 키 | `~/.android/keystores/planroutine-upload.jks` | M1-H2 직후 |
| 3~5 | Play 앱 서명 키 | Play Console `App signing key` 섹션의 **모든** 지문 | M1-H4 후 |

**개수를 가정하지 않는다.** 브리프는 "SHA-1 두 개"인데, 2026-05부터 신규 앱은 quantum-ready
hybrid signing에 **자동 등록**된다. 공식 문서 verbatim:
> "Quantum-ready hybrid signing combines a classical RSA 4096-bit key and a post-quantum
> ML-DSA-65 key." … "resulting in your app using **three distinct keys**." … "you must copy the
> fingerprints for three keys and **register each of them** with your API providers"

→ Android OAuth 클라이언트가 최대 **5개**가 된다. **공직플랜이 실제로 hybrid signing에 걸리는지는
M1-H4에서 화면을 보고 확정한다**(롤아웃이 "during the Android 17 release cycle"이라 계정·시기에
따라 다를 수 있다).

지문 조회:
```bash
keytool -list -v -keystore ~/.android/keystores/planroutine-upload.jks \
  -alias planroutine-upload | grep -E "SHA1|SHA256"
cd android && ./gradlew :app:signingReport      # debug 키까지 한 번에
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab   # 사후 검증
```
한국어 로케일이라 다른 라벨은 한글로 나오지만 `SHA1:`/`SHA256:`은 영문이라 위 grep이 그대로
먹는다(전체 영문은 `keytool -J-Duser.language=en`).

#### OAuth 재검증 — 여전히 미확인, 그러나 진짜 위험은 다른 데 있다

명시적 재검증 트리거는 둘뿐이다 — (a) 새 sensitive/restricted 스코프 추가, (b) OAuth 동의 화면
필드 변경(앱 이름·로고·리디렉션 URI·홈페이지·**개인정보처리방침 링크**). Android 클라이언트
추가는 (a)도 (b)도 아니다(스코프 그대로, Android 클라이언트엔 리디렉션 URI가 없다) —
**구조적으로는 불필요해 보이지만 공식 문서 세 곳 모두 "새 클라이언트/새 플랫폼 추가"를
명시적으로 다루지 않는다.** 추측으로 메우지 않는다.

> ⚠️ **처방침 URL을 바꾸면 그것이 (b) 트리거다.** 브리프가 "처리방침에 Android 문장 추가"라고
> 적었는데, `https://planroutine.indibery.dev` **URL은 그대로 두고 본문만 고칠 것.** 본문 수정
> 자체는 트리거가 아니다.

#### M2-④ 검증

```
□ 에뮬레이터(google_apis_playstore 이미지, 구글 계정 로그인 상태)에서
  설정 › 캘린더 연동 › 계정 연결 → 동의 화면이 뜨고 계정이 연결된다
□ 캘린더에서 오른쪽 스와이프 → Google 캘린더에 이벤트가 생긴다
□ 같은 이벤트를 다시 저장 → 중복 생성 안 됨 (google_event_id 재사용)
□ 스토어 빌드(비공개 테스트에서 내려받은 것)에서 같은 흐름 — 여기가 Play 앱 서명 키 경로다
```
`docs/privacy_policy.md`의 iOS 전제 서술은 **세 곳이 아니라 여덟 곳**이고, §2 표의 저장 위치 칸은
문장 치환이 아니라 **사실 확인이 필요한 항목**이다(Android에서는 앱이 토큰을 보관하지 않으므로
"Keychain"의 대응물이 없다). 대상 전수와 새 문장은 **§M2-⑨**에 모았다.

### M2-⑤ 기기 캘린더 — 코드 변경 0, 런타임 흐름만 확인

`READ_CALENDAR`·`WRITE_CALENDAR`는 이미 매니페스트에 있고(`:3-4`) release 병합에도 들어간다.
iOS 흐름이 그대로 돈다:
- `device_calendar` Android 구현이 `arePermissionsGranted()` = `checkSelfPermission(WRITE) &&
  checkSelfPermission(READ)`, `requestPermissions()` = `requestPermissions(arrayOf(WRITE, READ))`로
  **iOS와 같은 의미**다(`CalendarDelegate.kt:669-672, 686`) → Dart 분기 불필요.
- `permission_handler`의 `Permission.calendarFullAccess`(값 37)가 Android 상수와 일치하고
  (`PermissionConstants.java:62`), full access는 두 권한을 **둘 다** 매니페스트에서 찾아 요청한다.
  ⚠️ **하나만 있으면 무조건 denied**(`PermissionManager.java:414-419`) — 지금은 둘 다 있어 통과한다.
  캘린더 권한을 손볼 때 한 줄만 지우면 조용히 전부 거부된다.
- Android 14/15/16 behavior changes에 **캘린더 권한 변경은 없다**(문서 확인). Android 6 이후
  런타임 권한 체계가 그대로다.

**검증**
```
□ 캘린더에서 기기 캘린더 저장 스와이프 → 권한 다이얼로그(읽기·쓰기 동시) → 저장된다
□ 거부 후 다시 저장 → 스낵바 "설정 열기" → 앱 정보 화면으로 간다
□ 설정 › 캘린더 연동에서 대상을 기기로 바꿔도 같은 흐름
```
⚠️ **에뮬레이터에 쓰기 가능한 캘린더가 없을 수 있다.** `_resolveDefaultCalendarId()`가
`isReadOnly == false`인 캘린더를 못 찾으면 `DeviceCalendarException('writable 캘린더가 없습니다')`가
난다 — **권한은 정상인데 저장만 실패**해 권한 버그로 오진하기 쉽다. 에뮬레이터에 구글 계정을
넣거나 캘린더 앱으로 로컬 캘린더를 하나 만든 뒤 테스트한다.

### M2-⑥ edge-to-edge — "확인"이 아니라 세 곳의 구현이고, 축이 하나 더 있다

브리프의 판단(레이아웃 골격은 iOS 대응이 그대로 Android 인셋 처리가 됐다)은 **맞다**:
`bottomNavigationBar`는 앱 전체에 하나뿐이고, 화면 Scaffold 8개가 `AppBar`를 써 상단 인셋이
자동이며, `FloatingTabBar`가 `SafeArea(top: false)`로 감싸져 있고, 화면 끝에 붙인 `Positioned`가
없다. `/trash`·`/import`·`/bus/*`도 ShellRoute 안이라 하단이 탭바로 막혀 있다.

프레임워크도 이미 일을 한다 — `PlatformPlugin.java:352-371` 주석: *"If the Flutter app targets
Android SDK 15 (API 35) or later (Flutter does this by default), then this mode [EDGE_TO_EDGE] is
used by default."* 인셋은 `MediaQuery.padding`으로 그대로 오므로 `SafeArea`가 정상 동작하고,
앱이 `SystemChrome.setEnabledSystemUIMode`를 부를 필요가 없다. `windowOptOutEdgeToEdgeEnforcement`도
`styles.xml`에 없다(있으면 Android 16에서 크래시할 수 있다 — 넣지 말 것).

**그런데 세 곳이 실제로 틀렸다.** 그리고 고치는 것만으로 끝나지 않는 것이 둘 더 있다 — 셋 중
하나(`useSafeArea`)는 **이미 가드가 만들어진 재발 함정**이고(⑥-c의 가드), 리포가 한 번도 보지
않은 축이 하나 남아 있다(⑥-d 글꼴 배율).

#### ⑥-a 내비게이션 바 아이콘 밝기 (라이트 테마)

`app_theme.dart:35-36`은 `systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : .light`다.
상태바는 **정상**이다(`.dark` = `statusBarIconBrightness: Brightness.dark` = 어두운 아이콘 =
밝은 배경용). 문제는 그 상수들이 내비게이션 바 필드까지 들고 있다는 것 —
`system_chrome.dart:316-330`에서 `.light`와 `.dark` **둘 다**
`systemNavigationBarIconBrightness: Brightness.light` / `systemNavigationBarColor: 0xFF000000`이다.

그리고 `AppBar`의 `AnnotatedRegion` **하나가 하단까지 지배한다** — 하단에 `AnnotatedRegion`이
없으면(`grep AnnotatedRegion lib/` → 0건) `rendering/view.dart:471-489`의 단일 스타일 경로로 가
상단 스타일이 `systemNavigationBar*` 전부를 공급한다. Android 플랫폼 오버라이드로 실제 테마를
펌프해 `SystemChrome.latestStyle`을 읽은 결과:
```
LIGHT  statusBarIconBrightness=dark   navBarIconBrightness=light  navBarColor=#000000
DARK   statusBarIconBrightness=light  navBarIconBrightness=light  navBarColor=#000000
```
라이트 테마의 하단 배경은 `FloatingTabBar`의 `Container(color: surface)` = **`#FFFFFF`**이고
그 컨테이너 **안쪽**에 `SafeArea(top: false)`가 있어 흰 배경이 내비게이션 바 영역까지 칠해진다
(iOS 홈 인디케이터를 노린 의도된 설계). 결과:
- **제스처 내비**: 색은 target 35+에서 무시되고 핸들만 `light`(흰색) → **흰 바 위 흰 핸들**
- **3버튼 내비**: `#000000`이 80% alpha로 살아남아 흰 앱 밑에 검은 띠

```dart
// lib/core/theme/app_theme.dart:35-36 교체.
// SystemUiOverlayStyle.dark/.light 둘 다 systemNavigationBarIconBrightness: light를 박아 두고
// 있고 copyWith는 `??`라 systemNavigationBarColor: #000000을 지울 수 없다 → 직접 조립한다.
// iOS는 rendering/view.dart:485-489가 systemNavigationBar* 네 필드를 전부 null로 만들어
// **구조적으로 무영향**이다 — 이 브랜치가 iOS를 건드리는 다른 항목들과 달리(§범위 밖)
// 여기는 렌더가 바뀌지 않는다. statusBarBrightness 값도 종전과 같다.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,        // target 35+에서 무시. iOS도 무관
          statusBarBrightness:                       // iOS 전용
              isLight ? Brightness.light : Brightness.dark,
          statusBarIconBrightness:                   // Android 전용 — 지금 값과 동일
              isLight ? Brightness.dark : Brightness.light,
          // 내비게이션 바 — AppBar의 AnnotatedRegion 하나가 하단까지 지배하므로 여기서 정한다.
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        ),
```
아이콘 밝기는 target 35+에서도 **앱이 지배한다** — Flutter가 `WindowInsetsController.setAppearance`
계열(`setAppearanceLightStatusBars`/`setAppearanceLightNavigationBars`)을 쓰고 그 API는 무효화
목록에 없다. 무효화된 것은 `setStatusBarColor`·`setNavigationBarColor`(제스처)·
`setDecorFitsSystemWindows` 쪽이다.

#### ⑥-b 온보딩의 상태바

`onboarding_screen.dart`는 ShellRoute 밖이고 `AppBar`가 없다 → `AnnotatedRegion` 0개 →
`rendering/view.dart:442-444`("no overlay style → return")로 **플랫폼에 아무 값도 안 보낸다.**
첫 실행의 **첫 화면**이라 이전 값도 없고, 남는 것은 런치 테마 기본값이다 —
`styles.xml`의 부모가 `@android:style/Theme.Light.NoTitleBar`(night는 `Theme.Black.NoTitleBar`)이고
**둘 다 `windowLightStatusBar`를 설정하지 않아** 기본 false = 흰 아이콘. 라이트 모드 온보딩
배경은 `#F6F8FB`다.

`AppTheme`에 `static SystemUiOverlayStyle overlayStyle(Brightness)`를 하나 만들어
`appBarTheme`과 온보딩이 **같이 부른다**(값을 두 곳에 두면 ⑥-a를 고칠 때 온보딩만 옛 색으로 남는다):

```dart
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(/* 기존 그대로 */),
      ),
    );
```
`appBarTheme.systemOverlayStyle!`을 참조하는 형태는 CLAUDE.md의 "강제 언래핑 금지"에 걸린다.

⚠️ 런치 테마의 밝기는 `values/` vs `values-night/`로 **OS 다크모드**를 따르는데 이 앱의 테마는
인앱 설정(`themeModeProvider`)이다. OS가 라이트인데 앱을 "어둡게"로 쓰면 스플래시가 흰색으로
번쩍인다 — **에뮬레이터에서 눈으로 확인할 항목.** 고치려면 런치 테마를 한쪽으로 고정하는
수밖에 없다(인앱 설정을 네이티브가 알 방법이 없다).

#### ⑥-c 바텀시트 — `useSafeArea` 누락 3곳

호출부는 **6곳**이고 `useSafeArea: true`는 둘뿐이다:

| 파일 | `isScrollControlled` | `useSafeArea` |
|---|---|---|
| `stamp_style_sheet.dart:31-36` | – | **true** |
| `bus_stop_confirm_sheet.dart:79-90` | true | **true** |
| `schedule_edit_sheet.dart:21-31` | true | **없음** |
| `event_edit_dialog.dart:45-62` | true | **없음** |
| `ai_photo_flow.dart:70-77` | true | **없음** |
| `calendar_integration_section.dart:67-69` | 없음 | 없음(안쪽 `SafeArea` 있음) |

`useSafeArea: false`(기본)면 `MediaQuery.removePadding(removeTop: true)`가 걸려 **시트 안쪽
`SafeArea`의 상단이 무력화된다**(`bottom_sheet.dart:1121-1123`). CLAUDE.md가
`bus_stop_confirm_sheet`에 대해 기록한 "다이나믹 아일랜드와 겹쳐 읽히지 않았다"와 **정확히 같은
함정이 세 곳 더 남아 있다.** `isScrollControlled: true`라 높이 상한이 화면 전체여서 긴 폼
(`event_edit_dialog`: 제목·연도칩·설명 4~6줄·날짜·성격 카드·버튼)은 상태바까지 닿을 수 있다.

**표가 규칙을 그대로 보여준다**: `useSafeArea: true`인 둘은 **안쪽에 `SafeArea`가 있고**,
없는 셋은 **`viewInsets.bottom`을 손으로 더하고 있다**(`event_edit_dialog.dart:102,108` ·
`schedule_edit_sheet.dart:93` · `ai_photo_flow.dart:124`). 즉 갈린 것은 우연이 아니라 **두 가지
관용구가 공존**하기 때문이고, 상단을 잃은 쪽이 정확히 손으로 조립한 쪽이다.

```dart
// event_edit_dialog.dart:45 / schedule_edit_sheet.dart:21 / ai_photo_flow.dart:70
      isScrollControlled: true,
      // 기본값(false)은 시트를 화면 top까지 뻗게 하고 그 모드에서는 MediaQuery의 top padding이
      // 제거돼 안쪽 SafeArea가 무력해진다(stamp_style_sheet·bus_stop_confirm_sheet와 동일).
      useSafeArea: true,
```
`calendar_integration_section.dart:67`에도 함께 넣는다. 지금은 시트가 짧아 상단에 닿지 않아
증상이 없지만(안쪽 `SafeArea`는 있다), **호출부마다 관용구가 다른 상태를 남기지 않는다** —
아래 정적 가드가 여섯 곳 전부를 같은 규칙으로 본다.

**하단은 `useSafeArea`가 일부러 남긴다.** `bottom_sheet.dart:1121-1123`:
```dart
    Widget bottomSheet = useSafeArea
        ? SafeArea(bottom: false, child: content)      // ← bottom: false
        : MediaQuery.removePadding(context: context, removeTop: true, child: content);
```
그래서 저장/취소 버튼 줄이 제스처 핸들과 겹칠 수 있다. **적용 대상은 위 세 시트이고**, 세 곳에
같은 계산이 들어가므로 헬퍼 하나로 모은다 — 복붙하면 네 번째 시트에서 또 빠진다.

```dart
// lib/shared/widgets/sheet_insets.dart — 새 파일
//
// 자리를 shared/widgets/에 두는 이유: `core/utils/`는 프레임워크를 모르는 순수 함수 자리이고
// (`date_utils.formatDate`), 이 함수는 `BuildContext`를 받는다.

/// 바텀시트 본문 하단에 줄 인셋.
///
/// `showModalBottomSheet(useSafeArea: true)`는 `SafeArea(bottom: false)`만 걸어
/// (`bottom_sheet.dart:1121-1123`) **하단을 일부러 남긴다** — 키보드 처리를 시트가 직접
/// 하도록 두려는 설계다. 그래서 제스처 핸들 인셋은 호출부가 더해야 한다.
double sheetBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  // viewInsets.bottom = 키보드. padding.bottom = 제스처 핸들/3버튼 바 중 **키보드에 덮이지
  // 않은 만큼**(padding은 viewPadding에서 viewInsets를 뺀 값이다). 그래서 `max`도 삼항도
  // 필요 없고 **더하면 된다** — 키보드가 올라오면 padding.bottom이 스스로 0이 된다.
  //
  // ⚠️ `viewPadding.bottom`을 쓰면 안 된다. 그 값은 키보드와 무관하게 유지돼 키보드 위에
  //    핸들 높이만큼 빈 띠가 남는다.
  return mq.viewInsets.bottom + mq.padding.bottom;
}
```
- `event_edit_dialog.dart:102` `final bottomInset = MediaQuery.of(context).viewInsets.bottom;`
  → `final bottomInset = sheetBottomInset(context);` (`:108`의 `EdgeInsets.only(bottom:)`은 그대로)
- `schedule_edit_sheet.dart:93` / `ai_photo_flow.dart:124`의
  `MediaQuery.of(context).viewInsets.bottom + AppSizes.spacing24`(각각 `spacing16`)
  → `sheetBottomInset(context) + AppSizes.spacing24`. **기존 여백 상수는 그대로 둔다** —
  디자인 값이고 인셋과 목적이 다르다.
- 기대 결과: 키보드가 없을 때 시트 최하단 버튼의 아래 여백이 제스처 핸들 높이만큼 늘고,
  키보드가 올라오면 종전과 **픽셀 단위로 동일**하다(그래서 iOS 회귀 위험이 작다 — iOS도
  홈 인디케이터가 있으므로 이득은 같다).

#### ⑥-c의 가드 — 이 함정은 이미 네 번째다

`useSafeArea` 누락은 실기기에서 한 번 잡혀 **가드까지 만들어진** 함정이다
(`bus_stop_search_test.dart:224-242`). 이번이 4·5·6번째 사례이므로 고치는 것으로 끝내면
다음 시트가 7번째가 된다 — 이 리포 규칙은 **재발한 함정을 문서에서 가드로 승격**하는 것이다.

**(가) 위젯 테스트 3건** — 기존 가드와 같은 형태로, 파일은 각 시트의 테스트 자리에 둔다.
```dart
// 패턴은 bus_stop_search_test.dart:224-242 그대로
tester.view.devicePixelRatio = 3.0;
tester.view.padding = const FakeViewPadding(top: 177);   // 59 논리픽셀
addTearDown(tester.view.reset);
await <시트를 show()로 띄운다>;                            // ← 본문만 pump하면 안 된다
expect(tester.getTopLeft(find.text(<제목>)).dy, greaterThanOrEqualTo(59.0));
```
- **반드시 `show()`로 띄운다.** `stamp_style_sheet_test.dart:15-16`이 이미 적어 뒀다 —
  "시트 본문만 pump하면 `show()`의 `useSafeArea` 같은 설정이 **검증에서 빠진다**".
- **픽스처는 가장 긴 내용으로.** 시트 높이가 내용 의존이라 짧은 입력으로 재면 시트가 top에
  닿지 않아 그냥 통과한다(CLAUDE.md가 "노선 10개 픽스처를 쓴다 — 3개로 재면 통과한다"로
  기록한 그 이유다). 각각:
  - `event_edit_dialog` — 제목 + 연도 칩(연도 둘) + 설명 6줄 + 날짜 + 성격 카드 + 버튼
  - `schedule_edit_sheet` — 제목 + 설명 여러 줄
  - `ai_photo_flow` — 붙여넣기 미리보기에 항목을 여러 건 넣은 상태

**(나) 정적 가드 1건 — `test/shared/sheet_safe_area_test.dart`**

세 건을 고쳐도 **일곱 번째 시트**는 못 막는다. 호출부를 훑는 가드가 더 싸고 강하다
(소스를 읽어 검사하는 선례: `test/features/settings/data_source_credit_test.dart`):
```
□ lib/ 전체에서 `showModalBottomSheet`를 부르는 파일을 찾는다(현재 6곳)
□ 각 호출 인자 목록에 `useSafeArea: true`가 있다
□ 그 파일들에서 `viewInsets.bottom` **직접 참조가 0건**이다 (전부 `sheetBottomInset` 경유)
□ 없으면 실패 — 메시지에 "왜"를 적는다(다이나믹 아일랜드/상태바에 제목이 겹친다 /
  하단은 `useSafeArea`가 `SafeArea(bottom: false)`라 일부러 남기므로 헬퍼가 필요하다)
```
호출부 수를 상수로 못박지 않는다 — 시트가 늘어날 때마다 테스트를 고치게 되고, 그러면
사람이 숫자만 올리고 지나간다. **찾아서 전수 검사하는 형태**여야 새 시트가 자동으로 걸린다.

**세 번째 줄이 없으면 이 가드는 절반만 지킨다.** 위 진단(§"갈린 것은 우연이 아니라 두 가지
관용구가 공존하기 때문")대로 문제는 관용구가 둘이라는 것인데, `useSafeArea`만 검사하면
없애는 것은 관용구 하나뿐이다. 네 번째 시트가 하단을 `MediaQuery.of(context).viewInsets.bottom`
으로 손조립해도 전수 테스트가 초록이고, 그러면 CLAUDE.md에 남긴 규칙이 **잡힌다고 거짓말을
한다.** 상단 인셋 가드 3건(위 (가))은 시트 본문을 pump해 보는 위젯 테스트이고, 하단은
**소스 대조**가 맞다 — 제스처바 인셋은 `FakeViewPadding`으로 재현해도 시트 내부 여백과
구별되지 않아 위젯 테스트로 판정하기 어렵다.

#### ⑥-d 글꼴 배율 — 리포가 한 번도 안 본 축

CLAUDE.md가 "같은 함정을 두 번 밟았다"로 기록한 오버플로 계열은 실은 **폭 × 글자 크기** 두
축인데, 리포의 가드는 폭만 훑는다(`bus_slot_tile_long_name_test.dart:53`의
`for (final width in [320.0, 390.0, 430.0])`). 그리고 `TextScaler`·`textScaler`·
`textScaleFactor`를 쓰는 코드·테스트가 **리포 전체에 0건**이다(grep).

Android는 이 축이 iOS보다 훨씬 흔하게 움직인다 — 삼성은 `설정 › 디스플레이`에서 **글꼴 크기와
화면 크기를 따로** 키울 수 있고, 교사 사용자층에 크게 쓰는 사람이 실제로 있다. 320/390/430pt를
통과한 행이 `fontScale 1.3`에서 무너지는 것을 **지금은 아무도 잡지 않는다.**

**작업 (가) — 기존 긴 이름 가드에 축을 곱한다.** 유닛이라 비용이 거의 0이고 Android 없이 돈다.
```dart
// test/features/bus/bus_slot_tile_long_name_test.dart — _pump에 인자 하나
Future<void> _pump(WidgetTester tester, String arrivalName, double width,
    {double textScale = 1.0}) async {
  …
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        // 폭만 훑던 가드에 글꼴 배율을 곱한다. 두 축이 곱해질 때만 나는 결함이 있다 —
        // 긴 이름이 45% 폭 안에서 두 줄이 되면 제목 쪽 계산이 함께 흔들린다.
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(…),
      ),
    ),
  ));
}
// for (final width in [320.0, 390.0, 430.0])
//   for (final scale in [1.0, 1.3])
```
`1.3`을 고른 이유: Android 접근성 글꼴 크기의 흔한 상단이 이 근처이고, 여기서 안 깨지면 폭
가드가 잡던 45%/55% 균형이 유지된다는 뜻이다. **최대 배율(삼성 1.8 이상)까지 유닛으로
쫓지 않는다** — 그 구간은 레이아웃을 다시 설계해야 하는 별 문제이고, 이 마일스톤의 목표가
아니다(대신 에뮬레이터·테스터가 본다).

**작업 (나)·(다)**는 에뮬레이터 체크리스트와 테스터 배분이다 — §M2 게이트와 §테스터 과제
배분에 각각 한 줄로 들어간다(과제 배분에는 "글꼴 크게 쓰는 사람 1명"이 이미 있다).

⚠️ **⑥-a·⑥-b는 실제 픽셀을 본 적이 없다.** Flutter가 보내는 값과 탭바 배경색은 코드로
확정했지만, Android 15+ 제스처 핸들의 실제 렌더 색과 시스템 자체 대비 보정 정도는
**에뮬레이터 스크린샷으로만 확정된다.** 가드는 이 항목을 검증 체크리스트로 둔다.

**⑥-a·⑥-b에도 유닛 가드가 하나 붙는다.** ⑥-b가 만드는 `AppTheme.overlayStyle(Brightness)`의
반환값을 고정한다 — 라이트에서 `statusBarIconBrightness == dark` ·
`systemNavigationBarIconBrightness == dark`, 다크에서 그 반대, 그리고 두 경우 모두
`systemNavigationBarColor == transparent`. 실측으로 확정한 값을 코드로 못박는 가장 싼 방법이고,
**같은 테스트가 iOS 쪽 `statusBarBrightness`도 지킨다**(`app_theme.dart:35-36`은 앱 전역
`appBarTheme`이라 화면 8개가 즉시 영향을 받는데, 지금 그 값을 검사하는 테스트가 0건이다 —
`grep systemOverlayStyle test/` → 0건).

### M2-⑦ 배터리 최적화 안내 (Android 전용)

삼성은 안 쓰는 앱을 절전 대상으로 자동 편입하고 그러면 예약 알림이 조용히 안 온다. 공직플랜은
매일 여는 앱이 아니라 정확히 이 대상이고, 느슨한 알람을 골라 Doze에 더 취약하다.

기존 `고급` ExpansionTile **안**에 한 줄. 최상위에 두지 않는다(설정 행 19개를 12개로 줄인 원칙).

```dart
// lib/features/settings/presentation/widgets/notification_settings_tiles.dart
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';  // 이미 의존성에 있다

class NotificationSettingsTiles extends ConsumerWidget {
  const NotificationSettingsTiles({super.key, this.showBatteryHint});

  /// 배터리 안내 행을 그릴지. **null이면 `Platform.isAndroid`.**
  ///
  /// 주입점을 두는 이유는 하나다 — `Platform.isAndroid`는 **호스트 OS**를 보므로
  /// macOS에서 도는 `flutter test`로는 "Android에서 이 행이 보이고 탭하면
  /// `openAppSettings()`가 불린다"를 **검증할 방법이 아예 없다.** 값 하나를 받으면
  /// 위젯 테스트가 두 경우(보임/안 보임)와 탭→호출을 전부 태울 수 있고,
  /// `visual_check`·E2E·실제 앱은 기본값으로 종전 그대로다.
  final bool? showBatteryHint;

  /// 배터리 안내 행을 찾는 키. 문구가 결정 대기(§결정이 남은 것 G)라 **문자열로 찾지 않는다.**
  static const batteryHintKey = Key('settings.notification.batteryHint');
  …
}

// ExpansionTile children 끝에:
if (showBatteryHint ?? Platform.isAndroid)
  ListTile(
    key: batteryHintKey,
    leading: const SizedBox(width: 40),
    title: const Text(NotificationStrings.batteryHint, style: TextStyle(fontSize: 14)),
    trailing: Icon(Icons.chevron_right, color: AppColors.sub),
    onTap: () => openAppSettings(),
  ),
```

**`Platform.isAndroid`를 쓰고 `defaultTargetPlatform`을 쓰지 마라.** `flutter test`는
`FLUTTER_TEST` 환경변수를 보고 `defaultTargetPlatform`을 **강제로 `TargetPlatform.android`로**
만든다(`flutter/lib/src/foundation/_platform_io.dart:29-34`의 assert 블록). 후자를 쓰면 macOS
호스트에서 도는 `visual_check.dart`·E2E에까지 이 행이 렌더된다 — **위젯 테스트 전체에 Android
전용 행이 나타난다.** `Platform.isAndroid`는 호스트 OS를 보므로 macOS 테스트에서 false다.

> `lib/` 전체에 이 두 관용구가 **한 곳도 없다**(grep 확인) — 이번이 첫 도입이고 프로젝트
> 컨벤션이 없다. **규칙을 여기서 정한다: 플랫폼 분기는 `dart:io`의 `Platform.isAndroid`.**
> 그리고 이 규칙과 그 함정(`defaultTargetPlatform`이 테스트에서 항상 android)은
> **`CLAUDE.md`에 적는다**(§리포 문서·규칙 갱신) — 이 스펙은 머지되면 읽히지 않는 설계
> 문서이고, 이 리포에서 규칙이 사는 곳은 `CLAUDE.md`다.

**대가를 정직하게 적는다**: 규칙을 지키면 기본값 경로는 테스트로 못 밟는다. 그것을 메우는
것이 `showBatteryHint` 주입점이고, 그래도 남는 것은 **"기본값이 실제로 `Platform.isAndroid`인가"**
한 줄이다 — 그건 에뮬레이터·시뮬레이터 눈 확인의 몫이다. `AppFeatures`류 상수를 경유하는
안(`lib/core/config/app_features.dart` 선례가 있다)은 기각했다: 그 파일은 **심사·승인 같은
외부 조건에 따라 사람이 켜고 끄는 플래그** 자리이고, 플랫폼 판정은 그 성질이 아니다.

**문구가 두 단계를 더 안내해야 한다.** `openAppSettings()`는
`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`(앱 정보 화면)까지만 간다
(`AppSettingsManager.java:25`) — **배터리 최적화 화면이 아니다.** 거기로 가는 유일한
`permission_handler` 경로는 `Permission.ignoreBatteryOptimizations.request()`이고 그건
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 매니페스트 권한을 요구한다. 그 권한은 **쓰지 않는다**
(Play 정책이 알람·통신 앱으로 제한해 반려 위험) → 도달할 수 없다.

그래서 `NotificationStrings.batteryHint`는 목적지를 정직하게 말해야 한다. **문구는 아직
정해지지 않았다 — §결정이 남은 것 G다.** 제조사마다 경로 이름이 달라(픽셀 `앱 정보 › 배터리 ›
제한 없음` vs 삼성 `배터리 › 백그라운드 사용 제한`) 한 문장으로 두 기기를 다 안내할 수 없고,
그래서 **테스터 피드백(M2)으로 확정하는 것이 자연스럽다.** 그 전까지는 위 `batteryHintKey`로
테스트를 쓰고 문구는 비워 두지 않는다(자리표시 문구를 두고 확정 시 교체한다).

**검증**
```
□ flutter test — 기본값 경로: visual_check·E2E에 이 행이 나타나지 않는다
   (`Platform.isAndroid`가 macOS에서 false라는 확인이기도 하다)
□ flutter test — 위젯 2건: showBatteryHint: true면 batteryHintKey가 있고,
   false면 없다
□ flutter test — 위젯 1건: showBatteryHint: true에서 행을 탭하면 openAppSettings()가
   불린다(permission_handler의 메서드 채널을 mock해 호출을 붙잡는다).
   **"행이 있다"만 검사하면 v80 iPad share 사고와 같은 구멍이 남는다** — 존재 ≠ 동작
□ 에뮬레이터: 설정 › 알림 › 고급 을 펼치면 행이 보이고, 탭하면 앱 정보 화면으로 간다
□ iOS 시뮬레이터: 이 행이 보이지 않는다
```

### M2-⑧ 글꼴을 에셋으로 — 통신을 없앤다 (§결정 A)

목적은 **처리방침 §6의 문장을 사실로 만드는 것**이다. "이 셋이 본 앱이 외부와 주고받는 통신
전부입니다"를 고치는 대신 지키는 쪽을 골랐다(§결정 A).

**먼저 지금 상태를 정확히 적는다 — 초안이 이 부분을 과장했다.**

`app_text_styles.dart:2,77`이 `GoogleFonts.spaceGrotesk(...)`를 쓰고 `allowRuntimeFetching`
기본값은 `true`다. 그러나 그 함수 `AppTextStyles.numeric()`은 **호출부가 0건이다**
(`grep -rn 'numeric(' lib/ test/ integration_test/` → 선언 한 줄뿐). `google_fonts`는 스타일
게터를 **부를 때** 로드를 걸므로, 지금 실제로 나가는 요청은 **없다.**

> 즉 방침 §6은 "거짓"이 아니라 **한 줄이면 거짓이 되는 상태**다. 결정은 그대로 유지한다 —
> `allowRuntimeFetching = false`는 그 상태를 **구조적으로 만들 수 없게** 하고, 그것이 이
> 결정의 실효다. (`numeric()`과 `google_fonts` 의존성을 지우는 안도 통신을 없애지만, 그건
> 이 마일스톤의 범위를 넘는 제거이고 판단이 사용자 몫이다.)

**그리고 Space Grotesk를 쓰는 자리가 하나 더 있다 — 등록되지 않은 채로.**
`onboarding_screen.dart:113`이 `fontFamily: 'Space Grotesk'`를 **문자열 리터럴로** 쓰는데
그 family가 어디에도 선언돼 있지 않다. 실측 `FontManifest.json`은
`MaterialIcons` · `Pretendard` · `packages/cupertino_icons/CupertinoIcons` 셋뿐이다 →
지금 그 eyebrow(`GONGJIKPLAN · 2026`)는 **조용히 기본 글꼴로 그려진다.**
번들하면 처음으로 의도한 글꼴이 나온다 — **iOS 온보딩 렌더가 실제로 바뀌는 지점이고**,
§범위 밖에 적었다.

#### `allowRuntimeFetching = false`의 자리 — `main.dart`

```dart
// lib/main.dart — WidgetsFlutterBinding.ensureInitialized() 직후
import 'package:google_fonts/google_fonts.dart';

  WidgetsFlutterBinding.ensureInitialized();

  // 글꼴을 런타임에 받아오지 않는다. 처리방침 §6("이 셋이 통신 전부")을 코드로 지키는 줄이고,
  // 부수 이득으로 오프라인 첫 실행에서도 글꼴이 나온다.
  //
  // ⚠️ 첫 GoogleFonts.* 호출보다 먼저여야 한다. `AppTextStyles`는 static getter 모음이라
  //    위젯이 그려지는 순간 평가되므로 `runApp` 앞이면 충분하다.
  // ⚠️ 에셋이 없으면 이 플래그는 예외를 던진다(`google_fonts_base.dart:178-184`) —
  //    플러그인이 그 예외를 잡아 print만 하고 `fontFamilyFallback`으로 떨어뜨리므로
  //    **화면은 조용히 기본 글꼴이 된다.** 그래서 아래 번들과 **한 쌍**이다.
  GoogleFonts.config.allowRuntimeFetching = false;
```

`AppTextStyles`에 두지 않는 이유: 그 클래스는 값만 만드는 getter 모음이고, 전역 설정을
게터 부작용으로 켜면 **어떤 게터를 처음 부르느냐에 따라 켜지는 시점이 달라진다.**

#### `pubspec.yaml` — 선언은 `fonts:`에 하고, **파일명이 계약이다**

```yaml
  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/PretendardVariable.ttf
    # family 이름은 `onboarding_screen.dart:113`의 리터럴과 **정확히 같아야** 한다.
    # 파일명은 Google Fonts API 규약을 **바꾸지 말 것** — google_fonts가 애셋을 찾는 기준이다.
    - family: Space Grotesk
      fonts:
        - asset: assets/fonts/SpaceGrotesk-Medium.ttf
          weight: 500
        - asset: assets/fonts/SpaceGrotesk-SemiBold.ttf
          weight: 600
```

**`assets:`가 아니라 `fonts:`로 충분하다 — 실측으로 확인했다.** `google_fonts`는
`AssetManifest`를 훑어 애셋 **경로**를 찾는데(`google_fonts_base.dart:147-154`), `fonts:`로만
선언한 파일도 AssetManifest에 들어간다: 이 리포의 `assets/fonts/PretendardVariable.ttf`는
`assets:`에 없고 `fonts:`에만 있는데 빌드 산출물
`build/app/intermediates/flutter/release/flutter_assets/AssetManifest.bin`에 그대로 있다.
(README는 `assets:`에 넣으라고만 안내하지만 필요조건은 그것이 아니다.)

**진짜 계약은 파일명이다.** `_findFamilyWithVariantAssetPath`(`:308-333`)가 애셋 경로에서
확장자를 떼고 **`${family}-${variant}`로 끝나는지**만 본다
(`google_fonts_family_with_variant.dart:20-22`). 그래서:

| 요청 굵기 | 찾는 접미사 | 파일명 |
|---|---|---|
| w400 | `SpaceGrotesk-Regular` | `SpaceGrotesk-Regular.ttf` |
| w500 | `SpaceGrotesk-Medium` | `SpaceGrotesk-Medium.ttf` |
| w600 | `SpaceGrotesk-SemiBold` | `SpaceGrotesk-SemiBold.ttf` |

**번들 대상은 실제로 요청되는 굵기뿐이다** — 지금은 둘이다: `numeric()`의 기본값 w600과
온보딩의 w500. Space Grotesk는 API에 w300~w700 다섯 변형이 있지만(`part_s.g.dart:10252-10287`,
각 ~69KB) 안 쓰는 굵기를 넣지 않는다.

> **규칙: `GoogleFonts.*`에 새 굵기를 넘기면 그 변형 파일도 함께 번들한다.** 안 하면
> `allowRuntimeFetching = false`가 예외를 던지고 **화면이 조용히 기본 글꼴로 떨어진다**
> (컴파일도 테스트도 통과한다). 이 규칙은 `CLAUDE.md`에 적는다(§리포 문서·규칙 갱신).

#### 라이선스 — 확인했다

- **Space Grotesk: SIL Open Font License 1.1.** 배포본 `OFL.txt` 1행 verbatim:
  `Copyright 2020 The Space Grotesk Project Authors (https://github.com/floriankarsten/space-grotesk)`,
  3행: `This Font Software is licensed under the SIL Open Font License, Version 1.1.`
  (google/fonts 저장소 `ofl/spacegrotesk/`, `METADATA.pb`의 license 필드도 `OFL`).
  → **에셋 번들·재배포가 허용된다.** 의무는 **라이선스 사본과 저작권 고지를 함께 배포하는
  것**이다(OFL §2).
- **예약 이름(Reserved Font Name) 의무는 Space Grotesk에 없다** — 저작권 행에
  `with Reserved Font Name`이 **선언되지 않았다**(실물 확인). 이름을 바꿔 파생본을 만들
  계획도 없으므로 이 조항은 이 작업에 걸리지 않는다.
- ⚠️ **Pretendard는 다르다.** 리포가 이미 `assets/fonts/PretendardVariable.ttf`를 담고 있고
  그 라이선스는 OFL 1.1이며 **예약 이름이 네 개 선언돼 있다**(`Pretendard` · `Source` ·
  `Inter` · `M PLUS 1` — Pretendard가 세 글꼴을 합친 결과다). 그런데 **리포에 라이선스 사본이
  없다.** 이번에 함께 채운다.

```
assets/fonts/OFL-SpaceGrotesk.txt    ← 배포본 OFL.txt 그대로
assets/fonts/OFL-Pretendard.txt      ← 기존 부채를 여기서 갚는다
```
`pubspec.yaml`의 `assets:`에 `assets/fonts/`를 더해 두 텍스트가 번들에 들어가게 하고,
`main.dart`에서 `LicenseRegistry.addLicense`로 등록한다(google_fonts README가 같은 형태를
든다) — 그러면 `설정 › 앱 정보`에서 열리는 Flutter 기본 라이선스 화면에 나타나 **"함께
배포한다"가 사용자 눈에 보이는 형태로** 성립한다.

#### 검증

```
□ 선행: 두 ttf(SpaceGrotesk-Medium/-SemiBold)와 두 OFL 텍스트를 **파일로 확보한다**
   — Google Fonts 저장소(github.com/google/fonts, OFL)에서 받아 assets/fonts/에 넣고
   pubspec `fonts:`·`assets:`에 선언한다. 아래 rootBundle 가드의 선행조건이다
   (초안은 경로만 정하고 파일을 어디서 받는지를 작업으로 세우지 않았다)
□ ~~flutter test — google_fonts가 네트워크를 시도하지 않는다~~ **이 검증은 쓰지 않는다.**
   플래그를 켜는 자리가 `main.dart`의 `main()`이고 `flutter test`는 그것을 실행하지 않아
   테스트 환경의 `allowRuntimeFetching`은 **기본값 true로 남는다** — 에셋 이름이 어긋나면
   조용히 fetch 쪽으로 떨어진다. 판정은 아래 rootBundle 가드가 한다
□ 가드 1건 — rootBundle.load로 두 ttf와 두 OFL 텍스트가 **실제로 로드된다**
   이 리포의 선례를 그대로 따른다: 에셋 마크는 위젯 존재 검증으로 못 지킨다(파일이나
   pubspec 선언이 빠져도 트리에는 Image/TextStyle이 그대로 있고 **런타임에만** 빈다).
   CLAUDE.md의 "가드는 rootBundle로 실제 로드까지 확인한다"가 이 경우다
□ 가드 1건 — AppTextStyles.numeric()이 반환하는 fontFamily가 SpaceGrotesk 계열이고
   예외가 print되지 않는다(debugPrint를 가로채 'unable to load font'가 없음을 본다)
□ 기내 모드 에뮬레이터 + **앱 데이터 삭제 후 첫 실행** — Space Grotesk를 쓰는 화면이
   같은 글꼴로 뜬다. 데이터를 안 지우면 기기 파일시스템 캐시가 남아 통과해 버린다
   (`google_fonts_base.dart:159-167`이 캐시를 먼저 본다)
□ iOS 시뮬레이터 — 온보딩 eyebrow가 **바뀐다**(기본 글꼴 → Space Grotesk).
   의도된 변화이므로 스크린샷으로 남긴다. 나머지 화면은 그대로여야 한다
□ 설정 › 앱 정보 › 라이선스에 두 OFL이 나타난다
```

**착수 시점**: 기본은 M2다. 단 **방침 URL이 비공개 테스트 공개의 전제로 확인되면 M1로
당긴다**(§M1-H1.5) — Dart 두 줄 + 에셋 넷 + `pubspec.yaml`이라 옮기는 비용이 작고, 방침 본문에
CDN을 임시로 적고 나중에 지우는 쪽은 문서를 두 번 고치게 된다.

### M2-⑨ 처리방침 개정 — iOS 서술 8곳 + §2 표 + 새 절

Play User Data 정책은 방침이 **정확할 것**을 요구한다. 지금 `docs/privacy_policy.md`는 iOS를
전제로 쓰여 있어 Android에서 사실과 다른 문장이 여럿이고, 여기에 이 작업이 만든 사실 둘
(기기 백업 · 글꼴 통신 제거)이 더해진다. **URL은 그대로 둔다** — 바꾸면 Google OAuth 동의 화면
필드가 바뀌어 재검증 트리거가 된다(§M2-④). 본문 수정 자체는 트리거가 아니다.

**대상은 8곳이다**(grep 실측, 초안이 "세 곳"으로 적었던 것을 확정):

| 줄 | 현재 | 무엇을 해야 하나 |
|---|---|---|
| `:3` | `App Store 지원 URL과 Google OAuth 동의 화면에서 링크로 참조` | Play Console `앱 콘텐츠`와 **인앱 설정 화면**(§M1-C6)을 더한다 |
| `:18` | §2 표 저장 위치 칸 = `iOS Keychain` | **아래 별도** — 문장 치환이 아니다 |
| `:32` | `iOS 기기 시스템에 예약하기 위해` | `기기 시스템` — 플랫폼 이름을 뺀다(양쪽 다 맞는 서술이 된다) |
| `:35` | `OAuth 토큰을 Keychain에 저장합니다` | 아래 §2 표와 같은 사실로 다시 쓴다 |
| `:109` | §6 `iOS Keychain(kSecClass = …)에 저장돼` | 같음. Android 문장을 나란히 둔다 |
| `:115` | §6 `이 셋이 … 통신 전부입니다` | **그대로 둔다** — §M2-⑧이 이 문장을 사실로 만든다 |
| `:130-131` | `iOS 홈 화면에서 앱을 삭제하면 … iOS 표준 동작` | Android 앱 삭제도 같은 결과다. 단 **기기 백업 사본은 남는다**(새 절이 설명) |
| `:163` | 각주 `App Store Review Guidelines §5.1.1` | Google Play User Data 정책을 함께 적는다 |

**§2 표의 `iOS Keychain` 칸은 사실 확인이 먼저였다 — Android에 대응물이 없다.**
`google_calendar_service.dart`가 쓰는 것은 `account.authHeaders`뿐이고 Android 구현은
`GoogleAuthUtil.getToken(context, account, "oauth2:" + scopes)`다(§M2-④) — **앱이 토큰을
보관하지 않는다.** 계정 자격증명은 Google Play 서비스가 들고 있고, 앱은 호출할 때마다 단기
액세스 토큰을 받아 메모리에서 쓴다. 리프레시 토큰은 앱에 오지 않는다. 그래서 이 칸은
플랫폼별로 갈라 적는다:

```
| Google OAuth 토큰 | 액세스 토큰 | Google 로그인 성공 후 |
    iOS: 기기 Keychain / Android: 앱이 저장하지 않음(Google Play 서비스가 계정 자격증명을
    보관하고, 앱은 요청 시마다 단기 토큰을 받아 메모리에서만 사용) |
```
⚠️ **`리프레시 토큰` 항목도 함께 손봐야 한다** — Android 경로에서는 앱에 오지 않으므로
"액세스 토큰, 리프레시 토큰"을 두 플랫폼 공통으로 적으면 그 자체가 부정확하다.

**새 절 — 기기 백업**(§5와 §6 사이, 새 번호). §M1-C4의 결정이 만든 사실이다:

```
## 5-4. 기기 백업으로 생기는 사본

본 앱은 기기 백업을 **허용합니다**(`android:allowBackup="true"`). 기기를 바꿀 때
1년치 업무 일정을 그대로 옮기기 위한 선택입니다.

- Android: Android Auto Backup이 앱의 일정 데이터베이스와 앱 설정을 **사용자 본인의
  Google Drive**에 백업합니다. 이 사본은 Google 계정 소유자만 접근할 수 있고,
  개발자는 접근할 수 없습니다.
- iOS: iCloud 백업이 켜져 있으면 같은 성질의 사본이 사용자 본인 iCloud에 생깁니다.
- 백업을 원하지 않으면 기기 설정에서 이 앱의 백업을 끌 수 있습니다
  (Android: 설정 › Google › 백업 / iOS: 설정 › Apple 계정 › iCloud).
- 앱을 삭제해도 이 사본은 사용자 클라우드에 남을 수 있습니다 — 기기 설정에서 지웁니다.
```
- **버스 정류장 설정도 이 사본에 포함된다**는 것을 §2 표의 해당 행 또는 이 절에 적는다.
  제외할 수 없는 이유(키 단위 제외 불가)는 방침에 적지 않는다 — 사용자에게 필요한 것은
  "포함된다"이고 구현 이유는 §M1-C4에 있다.
- 이 절이 **§M3-H3 데이터 안전 답안의 사용자 대면 짝**이다. 한쪽만 고치면 스토어 카드와
  방침이 어긋난다.

**`§9 개정 이력`에 항목을 추가한다**(리포 관례 — 기존 4건 모두 무엇을 왜 고쳤는지 적는다):
Android 출시에 맞춰 iOS 전용 서술 정정 · §2 표의 토큰 저장 위치를 플랫폼별로 분리 ·
기기 백업 절(§5-4) 추가 · 글꼴 CDN 요청을 없애 §6의 통신 열거를 유지.

**검증**
```
□ grep -n -i 'ios\|iphone\|keychain' docs/privacy_policy.md — 남은 iOS 언급이 전부
  **의도적으로 iOS를 가리키는 것**이다(§2 표의 iOS 칸, §5-4의 iCloud, 각주)
□ Play Console `앱 콘텐츠 › 개인정보처리방침` URL과 `SettingsStrings.privacyPolicyUrl`이 같다
□ §M3-H3 데이터 안전 양식의 답과 §5-4의 서술이 같은 사실을 말한다
□ 웹 호스팅본이 갱신됐다 (리포 문서만 고치면 스토어가 보는 것은 옛 문장이다)
```

### M2 게이트 — 에뮬레이터

브리프 확인: 로컬은 `system-images/android-34/google_apis/arm64-v8a` 하나뿐이고 AVD도 `Pixel_7`
하나(`PlayStore.enabled=no`). `platforms;android-35`·`android-36`은 **이미 설치돼 있다.**

```bash
SDK=/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin

# API 35 (edge-to-edge 강제 시작) / API 36 (필수 targetSdk와 동일) — Play 스토어 포함
$SDK/sdkmanager "system-images;android-35;google_apis_playstore;arm64-v8a"
$SDK/sdkmanager "system-images;android-36;google_apis_playstore;arm64-v8a"

$SDK/avdmanager create avd -n Pixel_7_API36 \
  -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_7
```
- `google_apis_playstore`를 고르면 Play 스토어가 올라와 **Google 로그인 흐름을 에뮬에서 밟을 수
  있다**(M2-④). 대신 그 이미지는 **root 불가**라 `adb root`로 DB를 들여다보는 디버깅이 안 된다 —
  그 용도가 필요하면 `google_apis` 변형을 하나 더 받는다.
- 16 KB 페이지 검증용 `…;google_apis_playstore_ps16k;arm64-v8a`도 목록에 있으나 **현재 코드가
  이미 요건을 만족하므로 선택 사항이다**(아래).
- ⚠️ root 불가가 `integration_test` 19개에 걸리는지는 **미확인** — 걸리면 그 게이트만
  `google_apis` 이미지로 돌린다.

**16 KB page size는 이미 통과한다 — 작업 0.** release APK의 arm64 `.so` 전부 LOAD 정렬 실측:
`libapp.so`·`libflutter.so` `0x10000`(64KB), `libdartjni.so`·`libdatastore_shared_counter.so`·
`libsqlite3.so` `0x4000`(16KB). `zipalign -c -P 16 -v 4` 도 `Verification successful`.
요건은 2025-11-01부터 targetSdk 35+ 앱에 발효 중이다.

```
□ integration_test 19개를 Android 에뮬레이터에서 통과
   (플러그인 채널 실호출: sqflite · shared_prefs · file_picker)
   ⚠️ 19건 중 한 건은 Android에서 별 Activity를 띄운다 — 아래 별도 절
□ flutter test 908건 + 신규 무손상
□ API 35 + API 36 이미지에서 4탭 + push 화면 3개 + 바텀시트 6개 전수 렌더
□ 라이트/다크 × 제스처/3버튼 내비 네 조합에서 상·하단 시스템 바
□ **설정 › 디스플레이 › 글꼴 크기 최대 + 화면 크기 최대**에서 4탭 · 버스 카드 ·
   설정 행 전수 · 바텀시트 6개를 훑는다(§⑥-d. 유닛은 1.3까지만 본다)
□ Play용 스크린샷 촬영 — 9:16 AVD로 5화면(§M3-H4). **여기서 찍는다.** 프로덕션 승인을
   기다리며 찍으려 하면 규격 탈락을 그때 알게 된다
□ ①~⑨의 각 검증 체크리스트
```

#### E2E 한 건의 방침을 미리 정한다 — 여기서 막히면 게이트가 선다

`integration_test/app_test.dart:556-580`의 「AI로 보내기: 실제 share 호출이 예외 없이 네이티브
시트를 띄운다」는 **의도적으로 mock 없이** `share_plus`를 부르고 2초 pump 후 예외만 본다.
iOS의 `UIActivityViewController`는 같은 Activity 위의 뷰라 프레임 펌프가 계속 도는데,
Android의 chooser는 **별 Activity**라 우리 액티비티가 stop되고 vsync가 끊긴다. 그리고
**같은 파일에 그 뒤로 시나리오가 둘 더 있다**(`:581`, `:595`) — 위험은 이 테스트가 실패하는
것보다 **뒤따르는 pump가 멈추는 것**이다. 아무도 시트를 닫아 주지 않는다.

"19개 통과"를 게이트로 걸었으니 방침을 먼저 정한다. **기존 테스트는 지우지 않는다**(리포 원칙):

1. **먼저 그냥 돌려 본다.** 실제로 멈추는지가 미확인이다 — Android chooser가 뜬 뒤에도
   `pumpAndSettle`이 타임아웃으로 빠져나오면 뒤 시나리오는 무사할 수 있다.
2. 멈추면 **Android에서만 채널을 mock한다.** `share_plus`의 메서드 채널에
   `setMockMethodCallHandler`를 걸어 성공 응답만 돌려준다. 이 테스트의 목적은
   "우리가 채널을 올바른 인자로 부른다 + 예외가 없다"이고 그 목적은 mock으로도 지켜진다 —
   **네이티브 시트가 그려지는 것을 보는 것이 목적이 아니다**(그것은 테스터의 몫이다).
3. mock으로도 뒤 시나리오가 안 살면 **플랫폼 분기로 이 한 건만 건너뛴다.** iOS에서는 종전
   그대로 실호출로 남으므로 커버리지가 줄지 않는다. 건너뛰는 형태로 갈 때는
   `skip: Platform.isAndroid`가 아니라 **이유를 담은 상수**로 적어 다음 사람이 왜인지 알게 한다.

⚠️ 알림 마스터 스위치는 E2E가 켜지 않으므로(`:526-553`은 존재 확인만) **권한 다이얼로그 쪽
위험은 없다.** 위험은 이 한 건에 몰려 있다.

## M3 · 프로덕션

14일 충족 + 사전 출시 보고서 반영 → 프로덕션 액세스 신청 → 출시. **거의 전부 사람의 몫이다.**

### M3-H1 · 프로덕션 액세스 신청서 (Play Console Dashboard)

공식: **"This usually takes 7 days or less, but may occasionally take longer."** 세 섹션이고,
**M2 기간 중에 재료를 모아둬야 한다** — 신청 시점에 만들어 쓰면 형식적인 답이 되고 그것이
반려 사유가 된다(공식 페이지가 테스터가 **"used all of your app's features"** 했는지를 설명하라고
요구한다).

```
섹션 1 — About your closed test
  · 테스터를 어떻게 모았는가       → 인디스쿨 커뮤니티 현직 교사 12+명
  · 테스터가 어떤 기능을 썼는가     → 기능별로 답할 수 있게 M2 기간 중 기록해 둘 것:
                                    CSV 가져오기 / 사진 AI / 확정 / 캘린더 / 구글 저장 /
                                    기기 캘린더 / 알림 / 버스 카드 / 휴지통 / 내보내기
  · 받은 피드백 요약               → 구체적 이슈 + 대응 versionCode
섹션 2 — About your app/game
  · 대상 사용자 / 앱의 가치 / 첫 해 예상 설치 수
섹션 3 — Production readiness
  · 테스트 결과 무엇을 고쳤는가
```
> **"문제 없었음" 같은 답은 준비하지 말 것** — 반려 사유로 보고된다(3rd-party, <추측>).
> M2가 실제로 고칠 것을 만들어 주므로(알림·인텐트·인셋) 재료는 자연히 생긴다.

### M3-H2 · 앱 콘텐츠 선언

```
개인정보처리방침 URL : https://planroutine.indibery.dev
앱 액세스 권한       : 모든 기능을 특별한 액세스 권한 없이 사용 가능
광고                 : 아니요, 앱에 광고가 없습니다
광고 ID              : 아니요
타겟층               : 18세 이상
아동 대상            : 아니요
뉴스 앱              : 아니요
COVID-19 접촉 추적   : 아니요
정부 앱              : 아니요 (정부/공공기관을 대신해 제공하지 않음)
금융 기능            : 아니요
건강 앱              : 아니요
콘텐츠 등급 설문      : 작성 (IARC)
권한 선언 양식        : 해당 없음
```
근거:
- **앱 액세스 권한**: Google 로그인은 선택이고 로그인 벽이 없다(방침 §7 "둘 다 기본 꺼짐").
- **광고 / 광고 ID**: 광고 SDK 없음(`pubspec.yaml` 전수), 어떤 플러그인도
  `com.google.android.gms.permission.AD_ID`를 선언하지 않음(설치본 매니페스트 전수 grep).
- **권한 선언 양식 해당 없음**: 고위험 목록(SMS/Call Log, background location,
  `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, AccessibilityService, Health Connect,
  **`USE_EXACT_ALARM`**)에 우리 권한 6개가 하나도 없다. `USE_EXACT_ALARM`이 그 목록에 있다는
  사실이 브리프의 "느슨한 알람" 결정을 뒷받침한다.
- **계정 삭제 요건 해당 없음**: 앱 계정을 만들지 않는다(서버 없음). 공식 페이지에 "Apps where
  accounts are created and operated offline also fall outside policy scope" 예외 서술이 있다.
  ⚠️ 제3자 로그인만 쓰는 앱이 범위인지는 공식 문서가 **명시하지 않는다**(3rd-party는 포함이라
  주장) — 콘솔의 실제 양식 문구를 보고 답할 것.

> ⚠️ **`정부 앱` 선언이 가장 저평가된 리스크다.** 앱 이름이 **공직플랜**이고 스토어 설명이
> "공직자 업무 플랜"을 표방하면 심사가 정부 정보 전달 앱 요건에 걸릴 여지가 있다. 검색 결과에
> **"Government apps are limited to organization accounts only."** 라는 서술이 있고, 브리프는
> **개인 계정**을 쓴다 — 이 카테고리로 분류되면 계정 타입 자체가 막힌다. **다만 그 문장을 공식
> 페이지 본문에서 verbatim으로 확인하지 못했고**, 공식 페이지는 정의도 제외 기준도 명시하지
> 않는다. 공직플랜은 정부를 **대신하지 않는** 제3자 생산성 도구이므로 "아니요"가 맞다고 보되,
> 완화책을 함께 쓴다:
> - 스토어 설명에 **교육청·정부 기관과 무관한 개인 개발자의 도구**임을 명시한다.
> - 정부 기관 로고·명칭·공식 문서 서식을 스크린샷에 노출하지 않는다.
> - ⚠️ **`assets/images/edufine_csv_guide.png`는 에듀파인 화면 캡처다 — 스토어 스크린샷에
>   쓰지 말 것.**

### M3-H3 · 데이터 안전 양식 — 전송을 인정하는 답안으로 확정

공식 정의: **Collection** = "Transmitting data from your app off a user's device."
**로컬 처리 면제** = "User data accessed by your app that is only processed locally on the user's
device and not sent off device does not need to be disclosed."

| 데이터 | 어디로 | 판정 | 근거 |
|---|---|---|---|
| SQLite 일정·이벤트, shared_preferences 설정 | **사용자 본인 Google Drive** (Android Auto Backup) | **Yes** | 아래 |
| 기기 캘린더 쓰기(`WRITE_CALENDAR`) | 기기 내 CalendarProvider | **No** | 로컬 처리 면제 |
| 캘린더 이벤트 → 사용자 본인 Google 캘린더 | Google | **No**(유추) | 아래 FAQ |
| 버스 조회(정류장 ID·도시코드·검색어) | `apis.data.go.kr` | **No**(매핑 대상 없음) | 아래 |
| 폰트 파일 요청 | (없어진다) | **해당 없음** | Space Grotesk를 에셋으로 번들하고 런타임 fetch를 끈다(§결정 A) |

**Google 캘린더 판정의 근거는 Drive/Dropbox FAQ verbatim이다:**
> "If the user chooses to upload their data directly to their own external drive or cloud storage
> account (such as Google Drive, Dropbox, or similar services) and this upload is governed by the
> external drive or cloud storage provider's terms of service and privacy policy, and your app
> never collects or accesses the data in question, then your app does not need to declare the
> collection of this data."

공직플랜은 조건 셋을 다 만족한다 — 사용자가 스와이프로 명시 선택 / 사용자 **본인** 계정 /
앱은 **읽지 않는다**(scope가 `calendar.events` 쓰기 전용, 자체 서버 없음).
⚠️ **그러나 FAQ는 캘린더를 명시하지 않는다**("or similar services"). 반대 신호도 있다 —
데이터 타입 표에 `Calendar events | READ_CALENDAR, WRITE_CALENDAR`가 있다(단 그 권한은 **기기**
캘린더이고 기기 밖으로 안 나간다).

**버스 조회**는 14개 카테고리 어디에도 정확히 안 맞는다. `Approximate location`은 기기 위치
API에서 나온 값을 뜻하는데 정류장 ID는 **사용자가 이름으로 검색해 고른 값**이고
`lib/features/bus/`에 위치 권한도 위치 API도 없다(매니페스트에 `ACCESS_*_LOCATION` 없음).
`In-app search history`는 검색어가 나가긴 하지만 저장되지 않는다. **"선언 안 함"이 방어 가능한
이유는 면제 조항에 명시적으로 해당해서가 아니라 매핑 대상이 없어서다.**

```
[답안 A — 기각]   "아무것도 기기를 떠나지 않는다"
Does your app collect or share any of the required user data types?   → No
  → 기각 이유: android:allowBackup을 켠 채 두므로 이 전제가 성립하지 않는다.
```
```
[답안 B — 채택]   기기 백업 경로를 인정한다
Does your app collect or share any of the required user data types?   → Yes
Is all of the user data collected by your app encrypted in transit?   → Yes
Do you provide a way for users to request that their data is deleted? → Yes
  - 인앱: 설정 › 데이터 관리 › 전체 데이터 초기화
  - 앱 삭제 시 잔여 설정까지 제거
  - 문의: bery97@gmail.com

Calendar events → Collected: Yes / Shared: No / 목적: App functionality /
                  Optional: Yes (기기 백업이 켜져 있을 때) / 전송 중 암호화 / 삭제 가능
                  근거: Android Auto Backup이 SQLite 일정·이벤트를 사용자 본인
                        Google Drive로 보낸다. iOS의 iCloud 백업도 같은 성질이다.
```
- **버스 조회로 나가는 검색어·정류장 ID는 여전히 선언하지 않는다** — 위 표의 "매핑 대상 없음"이
  백업과 무관하게 성립한다(기기 위치 API를 쓰지 않고 저장하지도 않는다).
- **백업에서 빠지는 것은 없다 — 그 결정은 끝났다**(§M1-C4). 버스 정류장 설정을 빼려 했는데
  `shared_preferences`가 Android에서 **키 전부를 파일 하나에** 담아(`FlutterSharedPreferences.xml`)
  키 단위 제외가 불가능하다. 그래서 **`shared_preferences`에 든 설정 전체가 백업 대상이고**,
  버스 정류장(정류장 ID·이름·번호·선택 노선·출퇴근 시간대)도 사본에 포함된다.
  - 정류장 설정은 **`Approximate location`에 넣지 않는다** — 그 카테고리는 기기 위치 API에서
    나온 값을 뜻하고, 이 값은 사용자가 이름으로 검색해 고른 것이다(`lib/features/bus/`에 위치
    권한도 위치 API도 없다). 나가는 곳도 **사용자 본인 클라우드뿐**이다.
  - 남는 문제는 `shared_preferences`의 알림·도장·테마 설정을 **어느 카테고리로 신고할지**이고,
    이것만 콘솔 양식 문구를 보고 정한다(§미확인 22). 그 전에 정해져야 했던 **코드 쪽 결정은
    이미 끝나 있다** — 순서가 코드 → 양식이라는 원칙은 유지되고, 이제 막힐 것이 없다.
> **결정: 답안 A 기각, 답안 B 채택.** A의 전제("일정 데이터는 기기를 떠나지 않는다")가
> **매니페스트 한 줄로 깨진다** — `android:allowBackup`을 켠 채 두기로 했으므로(기기 교체 시
> 1년치 일정 복원이 교사에게 실질 가치가 크다) Android Auto Backup이 SQLite DB와
> `shared_preferences`를 사용자 Google Drive로 **기기 밖으로** 보낸다. 켠 것을 알면서
> "전송되지 않음"이라고 답하는 것은 **Data safety 불일치이고 앱이 내려갈 수 있다.**
>
> 그래서 답은 하나로 정해진다 — **전송을 인정한다.** 대가는 스토어 데이터 안전 카드에
> 항목이 뜨는 것이고, 그 대가는 처리방침의 기기 백업 절(§5-4, §M2-⑨)이 함께 설명한다.
> **제외 항목은 없다** — 검토했고 키 단위 제외가 구조적으로 불가능하다(§M1-C4).
>
> ⚠️ **판정이 매니페스트에 매여 있다는 것이 이 항목의 급소다.** `allowBackup`을 뒤집으면
> 이 양식도 함께 뒤집어야 하고, 반대로 이 양식만 보고 코드를 고치면 스토어 카드가 거짓이 된다.
> 그래서 매니페스트에 **`android:allowBackup="true"`를 명시한다** — 기본값에 맡기면 "정하지
> 않아 기본값으로 출시된 것"과 "정해서 켠 것"이 구별되지 않는다.

**"암호화 Yes"의 근거**: 실제 나가는 통신 전부가 HTTPS다(Google 로그인·Calendar API·
`apis.data.go.kr` TLS 1.3 실측). **폰트 CDN은 목록에서 빠진다** — §결정 A로 요청 자체가
없어진다(§M2-⑧). 기기 백업 경로도 Google/Apple의 백업 전송이 TLS이고 Android 9+는 사용자
화면 잠금으로 백업을 암호화한다.
**"삭제 가능 Yes"의 근거**: 공식 정의가 "a discoverable mechanism like in-app features, contact
forms, or email aliases"이고 셋 다 있다. ⚠️ 방침 §4·§7이 "전체 데이터 초기화는 DB만 지우고
shared_preferences는 앱 삭제 때까지 남는다"고 적어 뒀으므로 **답변 근거를 앱 삭제까지 포함해
잡아야 한다**(모순은 아니다). ⚠️ **백업 사본은 앱을 삭제해도 사용자 클라우드에 남을 수 있다** —
지우는 방법(기기 설정)을 §5-4가 안내하므로 "discoverable mechanism"은 유지되지만, 이 사실을
방침에 적지 않고 양식만 Yes로 두면 그것이 불일치다.

### M3-H4 · 스토어 등록정보 자료

```
[필수]
  아이콘        512 × 512   PNG 32-bit (alpha 허용)   ≤ 1024KB
  그래픽 이미지  1024 × 500  JPEG 또는 PNG 24-bit (alpha 금지)   ★ 리포에 없음 — 신규 제작
  스크린샷      최소 2장    JPEG 또는 PNG 24-bit (alpha 금지)
                최소변 ≥ 320px, 최대변 ≤ 3840px, 최대변 ≤ 최소변 × 2
[프로모션 자격까지 노리면]
  스크린샷 4장 이상, 1080px 이상, 9:16 세로 (예: 1080 × 1920)
[텍스트]
  앱 이름       ≤ 30자    "공직플랜"(4자, 여유)
  짧은 설명     ≤ 80자
  자세한 설명   ≤ 4,000자   ← docs/app_store_description.md 를 출발점으로
```
금지(공식 문구 요지): 제목에 대문자 강조·이모지·`무료`·`광고 없음`·순위 주장(`#1`, `App of the
year`)·가격/프로모션. 설명에 익명 후기 인용, `best`/`#1 rated`, 과도한 반복, 타 앱 오도 참조.

**1024×500 그래픽 이미지가 리포에 없다** — `assets/icon/app_icon.png`(1024²)와
`assets/images/edufine_csv_guide.png`뿐이다. 신규 제작 대상이고, 위 ⚠️대로 **에듀파인 캡처를
쓰지 않는다.**

#### 스크린샷도 재사용이 불가능하다 — 규격을 만족하는 자료가 리포에 없다

`최대변 ≤ 최소변 × 2`로 계산하면 **가진 것이 전부 탈락한다**(실측 픽셀):

| 자료 | 해상도 | 비 | 상한(최소변×2) | 판정 |
|---|---|---|---|---|
| `docs/screenshots/appstore/6.5/*.png` | 1284 × 2778 | 2.163 | 2568 | ✗ |
| `docs/screenshots/appstore/6.9/*.png` | 1320 × 2868 | 2.172 | 2640 | ✗ |
| M2 게이트의 `Pixel_7` AVD | 1080 × 2400 | 2.222 | 2160 | ✗ |

즉 **"에뮬레이터에서 찍으면 된다"가 성립하지 않는다.** 요즘 폰은 전부 2:1보다 길어서, Play
규격을 맞추려면 **9:16(정확히 2.0) 화면**이 필요하다 — 그리고 9:16 · 1080px 이상은 프로모션
자격 조건과도 같다.

**촬영 경로 (M2 기간에 한다, §M2 게이트)**

```bash
# ① 9:16 전용 AVD. 프로필은 pixel_7을 쓰고 해상도만 바꾼다 —
#    16:9 기기 프로필(Nexus 5 등)로 만드는 쪽은 API 36 이미지와의 조합을 확인하지 않았다.
$SDK/avdmanager create avd -n Play_916_API36 \
  -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_7
#    ~/.android/avd/Play_916_API36.avd/config.ini 를 고친다
#      hw.lcd.width=1080
#      hw.lcd.height=1920
#      hw.lcd.density=420      ← 1080×1920에서 420dpi면 논리 411×731dp, 폰 레이아웃 그대로다

# ② 기존 스크린샷 테스트를 그대로 돌린다
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d <emulator-serial> \
  --dart-define=SCREENSHOT_MODE=true
```

- **`screenshot_test.dart`는 이미 Android에서 돈다.** `binding.convertFlutterSurfaceToImage()`를
  촬영마다 부르고 있는데(`:53`·`:63`·`:74`·`:89`·`:101`) 그 호출이 정확히 **Android에서 필수인
  단계**다(iOS는 없어도 된다). 즉 남은 작업은 **출력 규격**이고 촬영 코드가 아니다.
- 출력은 `docs/screenshots/play/`로 옮긴다. 파일 머리 주석에 iOS 규격 둘(6.9"·6.5")만
  적혀 있으므로(`:13-17`) **Play 항목을 함께 적는다** — 안 적으면 다음 사람이 iOS AVD 크기로
  찍고 규격 탈락을 콘솔에서 알게 된다.
- **후처리(레터박스·리사이즈)는 폴백이다.** AVD 해상도를 바꾸는 쪽이 나은 이유는 찍힌 것이
  실제 렌더라는 것이다 — 2400 높이를 1920으로 리샘플하면 글자가 눌리고, 레터박스는 스토어
  카드에 검은 띠로 남는다.
- 촬영 대상은 App Store와 같은 5화면이고 **에듀파인 캡처가 들어간 화면은 쓰지 않는다**
  (§M3-H2의 ⚠️). `4_import`는 가이드 섹션이 접힌 상태로 찍혀야 한다.
- ⚠️ 1080×1920 논리 크기(411×731dp)는 M2 게이트가 훑는 폭 목록(320·390·430pt)의 **가운데**다 —
  촬영 화면이 곧 레이아웃 확인이 되지는 않으니 게이트를 대신하지 못한다.

### M3 완료 신호 / 순서

```
14일 충족 확인(대시보드 카드) → H1 신청서 제출 → (심사 ≤7일) → 프로덕션 액세스 승인
   ↓
H4 등록정보 자료 (승인 대기 중에 병행 가능)
   ↓
프로덕션 트랙 릴리즈 생성 + 릴리즈 노트 → **사람이 제출**
```
⚠️ **H2(앱 콘텐츠 선언)·H3(데이터 안전)은 M1으로 올라갈 수 있다** — §M1-H1.5에서 비공개 테스트
공개의 전제로 확인되면 그렇게 한다. 그러면 M3에 남는 것은 H1 신청서·H4 자료·최종 제출이다.

**Android 릴리즈 노트는 리포가 단일 출처를 유지한다.** `beta` 레인이
`docs/release_notes/<versionName>.ko.txt`를 읽어
`android/fastlane/metadata/android/ko-KR/changelogs/<versionCode>.txt`로 깔고 supply가 그것을
올린다(§C5 `stage_changelog`). `skip_upload_metadata`는 changelog를 포함하지 않으므로 스토어
등록정보 본문은 건드리지 않는다.
- **iOS 가드 E와 다른 점**: 파일이 없으면 **막지 않고** changelog 없이 올린다. Play는 릴리즈
  노트를 필수로 요구하지 않고, 막으면 M1 껍데기 업로드가 문구 작성에 걸린다.
- **프로덕션 릴리즈는 사람이 콘솔에서 만든다**(레인이 없다). 그때도 문구는 같은 파일에서
  복사한다 — 손으로 새로 쓰면 iOS·Android 스토어 문구가 갈라진다.
⚠️ **targetSdk 36 하한이 2026-08-31 발효**다. M1 껍데기를 8월 안에 올려도 M3 제출은 발효 후가
되지만, Flutter 3.41.6 기본이 이미 36이라 **문제가 없다.** 단 `targetSdk`를 내리는 변경을 하면
그 순간 제출이 막힌다.

## 결정된 것 (전에는 열린 질문이었다)

브리프의 범위나 원칙과 충돌해서 스펙이 혼자 정할 수 없던 여섯이다. **전부 결정됐고, 그래서
M1이 결정 대기에 막히지 않는다** — 특히 E(데이터 안전)는 §M1-H1.5가 "릴리즈 공개의 전제일
수 있다"고 본 항목이라 미결로 두면 M1 임계경로에 걸렸다. 남은 결정은 **G 하나**이고
(§결정이 남은 것) 그것은 M1·M2 착수를 막지 않는다.

| | 결정 | 어디에 살는가 |
|---|---|---|
| **A** `google_fonts`가 방침을 반박 | **통신을 없앤다** — `GoogleFonts.config.allowRuntimeFetching = false` + Space Grotesk를 `assets/fonts/`에 번들. 방침 §6 문장을 고치는 대신 **문장을 사실로 만든다** | **M2-⑧.** 단 방침 URL이 릴리즈 공개의 전제면 **M1으로 당긴다**(§M1-H1.5) |
| **B** 인앱 방침 링크의 형태 | **`url_launcher` 추가, 브라우저로 연다.** 방침을 고칠 때 앱 재배포가 필요 없고 리포/웹 이중 출처를 만들지 않는다 | M1-C6 |
| **C** `application/octet-stream` | **넣지 않는다.** `text/plain`을 뺀 것과 같은 이유 — 사진·zip·apk 공유 목록까지 오염된다. 메일 첨부는 "파일 앱에 저장 후 열기"로 충분하다 | M2-② |
| **D** 온보딩 뒤로가기 | **페이지를 되돌린다. 첫 페이지에서 누르면 종료.** 이미 정한 원칙("한 단계 되돌린다, 되돌릴 게 없으면 종료")의 예외가 될 이유가 없다 | M2-③ |
| **E** 데이터 안전 답안 | **전송을 인정한다**(답안 B). 기기 백업을 켠 채 두기로 했으므로 "안 나감"이라고 답할 수 없다 | M3-H3 · M1-H1.5 |
| **F** `FakeNotificationService` | **만든다** — `test/helpers/fake_notification_service.dart`. `notification_service.dart:10`의 doc이 이미 참조하는 죽은 참조이고(그 dartdoc 링크는 함께 걷는다), Android 분기에 테스트를 붙일 발판이 없다. **소비처를 아래에 못박는다** | **M2-①의 선행 작업** |

**F의 소비처 — 만들기만 하고 안 쓰면 과잉이다.** 이 fake를 태우는 테스트를 **한 건** 세운다:
`test/features/notifications/master_switch_permission_test.dart`

M2-①이 고치는 사망 지점 2가 그 대상이다 — `requestPermission()`이 false를 돌려주면
`notification_providers.dart:51-58`의 `setMaster(true)`가 마스터를 **도로 꺼서** Android에서
알림 스위치를 켤 수 없다. fake의 권한 응답을 true/false로 바꿔 두 경우를 고정하면
그것이 "스위치를 켤 수 없다"의 회귀 가드가 되고, **이 마일스톤에서 실제로 고치는 동작에
처음으로 자동 검증이 붙는다.**

```
□ 권한 승인(fake가 true) → setMaster(true) 후 마스터가 켜져 있다
□ 권한 거부(fake가 false) → 마스터가 꺼진 상태로 남고, 스위치가 되돌아간 이유가 UI에 보인다
```

이 소비처가 없으면 F를 **"죽은 dartdoc 링크 정리"로 범위를 줄이고 fake 제작을 뺀다** —
`notification_details.dart`의 순수 함수 분리(변경 4)가 이미 Android 분기 대부분의 테스트
발판을 만들어 두었으므로, 아무도 안 쓰는 헬퍼를 남기는 것은 CLAUDE.md의 "과잉 엔지니어링
금지"에 걸린다.

⚠️ **A와 B는 브리프의 "iOS는 한 줄도 안 바뀐다"를 깬다** — A는 플랫폼 공통
`app_text_styles.dart`와 `pubspec.yaml`을, B는 iOS 설정 화면까지 바꾼다(양쪽 스토어가 같은
요건이다). **숨기지 않고 범위 선언에 적는다**(§범위 밖). iOS도 재배포 대상이다.

아래는 각 결정의 배경이다 — 왜 그 선택이 문제였는지가 남아 있어야 다음 사람이 되돌리지 않는다.

**A. `google_fonts`가 처리방침을 반박할 수 있었다.**
`app_text_styles.dart:2,77`이 `GoogleFonts.spaceGrotesk(...)`를 쓰고 `allowRuntimeFetching`
기본값이 `true`, `pubspec.yaml`의 `fonts:`에는 Pretendard만 있다 → 그 스타일이 쓰이는 순간
Space Grotesk가 `https://fonts.gstatic.com/s/a/<hash>.ttf`에서 다운로드된다.
- **초안의 단정을 고쳤다**: 그 함수 `AppTextStyles.numeric()`은 **호출부가 0건이라**(grep)
  지금 실제로 나가는 요청은 **없다.** `docs/privacy_policy.md:115`의 "이 셋이 본 앱이 외부와
  주고받는 통신 전부입니다"는 **거짓이 아니라 한 줄이면 거짓이 되는 상태**다.
- 결정은 그대로다. `allowRuntimeFetching = false`는 그 상태를 **구조적으로 만들 수 없게** 하고,
  Play User Data 정책이 요구하는 것은 방침이 **계속** 정확한 것이다.
- ① **(채택)** `GoogleFonts.config.allowRuntimeFetching = false` + 에셋 번들 — 통신을 없앤다.
  방침 문장을 고치는 대신 **문장을 지키는 쪽**이다. 부수 이득: 오프라인 첫 실행에서도 글꼴이
  나온다. **둘은 한 쌍이어야 한다** — 끄기만 하면 `numeric()`을 살리는 순간 글꼴이 조용히
  기본 폰트로 떨어진다(플러그인이 예외를 잡아 print만 한다).
- ② (기각) 방침 §6 문장만 수정 — 코드 0. 대신 방침에 폰트 CDN이 영구히 등장한다.
- **라이선스는 실물로 확인했다**(google/fonts `ofl/spacegrotesk/`):
  - `OFL.txt` 3행 verbatim — `This Font Software is licensed under the SIL Open Font License,
    Version 1.1.` / 1행 — `Copyright 2020 The Space Grotesk Project Authors
    (https://github.com/floriankarsten/space-grotesk)`. `METADATA.pb`의 license 필드도 `OFL`.
    → **에셋 번들·재배포가 허용된다.** 남는 의무는 OFL §2의 **라이선스 사본 + 저작권 고지 동봉**이다.
  - **예약 이름(Reserved Font Name) 조항은 Space Grotesk에 걸리지 않는다** — 저작권 행에
    `with Reserved Font Name`이 **선언되지 않았다.** (초안이 이것을 의무로 적었던 것을 고쳤다.)
  - ⚠️ **Pretendard는 다르다.** 같은 OFL 1.1이지만 예약 이름이 **네 개** 선언돼 있다
    (`Pretendard` · `Source` · `Inter` · `M PLUS 1`). 그런데 리포는
    `assets/fonts/PretendardVariable.ttf`를 **라이선스 사본 없이** 담고 있다 — 기존 부채이고
    이번에 함께 갚는다(§M2-⑧의 `OFL-*.txt` 둘).
- 실행 세부(자리·파일명·굵기·검증)는 **§M2-⑧**에 있다.

**B. 인앱 처리방침 링크의 형태 → `url_launcher`.** 정책은 "link **or text**"를 허용하므로 방침
**본문을 인앱 화면**으로 넣는 안도 있었다(의존성 0). 기각 이유는 **문서 이중 관리**다 — 방침을
고칠 때마다 앱을 재배포해야 하고 웹과 앱이 갈라진다. 링크는 재배포가 필요 없다. 대가는 의존성
하나(`url_launcher`)이고, iOS 쪽에 `Info.plist` 설정(`LSApplicationQueriesSchemes`)이 필요한지는
**M1-C6에서 확인해 적는다**(`https` 외부 브라우저 열기에는 보통 불필요하다).

**C. `application/octet-stream`은 넣지 않는다.** 넣으면 메일 첨부 CSV를 더 받는 대신 **모든
바이너리 공유 목록에 공직플랜이 뜬다**(사진·zip·apk까지). Dart `.csv` 게이트가 있어 오동작은
없지만 목록 오염은 남는다. `text/plain`을 뺀 것과 **같은 성격의 트레이드오프**이고 같은 답을
골랐다. 메일 첨부는 "파일 앱에 저장 후 열기" 경로로 충분하다 — **이 문단이 남는 이유는 다음
사람이 "메일이 안 되네"로 되돌리지 않게 하기 위해서다.**

**D. 온보딩 뒤로가기 → 페이지를 되돌린다.** 첫 페이지에서 누르면 종료. 지금은 백 한 번에
앱이 꺼져 처음부터 다시 해야 하는데, 그것이 이미 정한 원칙("한 단계 되돌린다, 되돌릴 게 없으면
종료")의 예외가 될 이유가 없다.
- **작업량은 확정됐다.** `onboarding_screen.dart`가 이미 `PageController`와 `int _page`를
  들고 있어(`:22-23`) 되돌릴 상태와 수단이 둘 다 있다 — 붙이는 것은 `PopScope` 하나와 판정
  한 줄이다. 판정은 `backTargetFor`와 같은 형태의 순수 함수 `backPageFor(int)`로 빼고 유닛
  테스트 4건을 붙인다(§M2-③).

**E. 데이터 안전 → 전송을 인정한다**(§M3-H3의 답안 B). 기기 백업을 켠 채 두기로 한 결정에
종속이다.

**F. `FakeNotificationService`를 만든다.** doc이 참조하는데 리포에 없다(죽은 참조). 만들면
Android 분기에 유닛 테스트를 붙일 발판이 생기고, CLAUDE.md의 "신규 기능은 단위 + 위젯 테스트"를
지킬 수 있다. 자리는 **`test/helpers/fake_notification_service.dart`** — 이 리포의 테스트 헬퍼
관례가 `test/helpers/test_database.dart` 하나뿐이고, `test/features/`는 대상 코드 경로를
미러링하는 자리라 공용 fake가 앉을 곳이 아니다.
- **`notification_service.dart:10`의 dartdoc 링크는 함께 걷는다.** `lib/`는 `test/`를 import할 수
  없으므로 `[FakeNotificationService]` 링크는 **어디에 만들어도 해소되지 않는다** — 경로를
  평문으로 적는다. Fake를 `lib/`로 옮겨 링크를 살리는 쪽은 테스트 코드를 앱 번들에 싣는 것이라
  하지 않는다.
- F는 **열린 질문이 아니라 M2-①의 선행 작업**이다. 발판 없이 착수하면 그 마일스톤에서 로직이
  가장 많이 바뀌는 항목이 자동 검증 0건으로 남는다(§M2-① 신규 테스트).

## 결정이 남은 것

| | 무엇 | 왜 지금 못 정하나 | 확정 시점 |
|---|---|---|---|
| **G** | `NotificationStrings.batteryHint` **문구** | 목적지 이름이 제조사마다 다르다 — 픽셀 `앱 정보 › 배터리 › 제한 없음` vs 삼성 `배터리 › 백그라운드 사용 제한`. **한 문장으로 두 기기를 다 안내할 수 없고**, 어느 쪽을 기준으로 쓸지는 실기기를 쓰는 사람이 판단할 문제다. 게다가 `openAppSettings()`가 데려가는 곳은 **앱 정보 화면까지**라(§M2-⑦) 문구가 그 뒤 두 단계를 말로 안내해야 한다 | **M2 테스터 피드백**(갤럭시 담당 1명, §테스터 과제 배분) |

- **G는 M1·M2 착수를 막지 않는다.** 행 자체는 `batteryHintKey`로 찾으므로 테스트가 문구에
  묶이지 않고, 자리표시 문구를 두고 확정 시 교체한다.
- ⚠️ 그래도 **비워 두고 출시하지 않는다.** 이 문구가 화면에 남는 유일한 배터리 최적화 안내이고,
  제조사 배터리 최적화는 이 앱의 **가장 큰 실전 리스크**다(§에뮬레이터로 못 잡는 것).

## 검증 계층

| 계층 | 무엇을 잡나 | 언제 |
|---|---|---|
| 기존 908 유닛/위젯 | 회귀 — Dart 로직은 플랫폼 무관, 한 건도 깨지면 안 됨 | 매 커밋 |
| 신규 유닛 `backTargetFor` · `backPageFor` | 뒤로가기 판정(탭 4 + push 4 + 미지 / 온보딩 3페이지 + 경계) | M2-③ |
| 신규 유닛 `test/android/release_guard_test.dart` | **빌드 가드가 지워지는 것** — gradle 키 가드 둘 + 레인의 가드 순서 | 매 커밋 |
| 신규 유닛 `notification_details_test` | `BigTextStyleInformation` 본문 · 채널 이름·설명의 출처 · **`inexactAllowWhileIdle`** · iOS `timeSensitive` | M2-① |
| 신규 정적 가드 (소스 읽기) | ① 알림 스케줄 모드가 두 곳에서 갈라지는 것 ② `showModalBottomSheet` 호출부의 `useSafeArea` 누락 — **호출부를 전수 검색한다**(개수를 박지 않는다) | M2-①·⑥ |
| 신규 위젯 가드 | 시트 3종 상단 인셋(`FakeViewPadding`, **가장 긴 내용**으로) · 방침 행 존재+탭 · 배터리 행 두 경우+탭 | M2-⑥·M1-C6·M2-⑦ |
| 신규 에셋 가드 (`rootBundle`) | 글꼴 `.ttf` 둘 + `OFL-*.txt` 둘이 **실제로 로드된다** — 선언·파일이 빠져도 트리는 멀쩡하고 런타임에만 빈다 | M2-⑧ |
| 기존 폭 가드 **× 글꼴 배율** | 긴 정류장 이름이 `TextScaler.linear(1.3)`에서 무너지는 것 — 리포가 한 번도 안 본 축 | M2-⑥ |
| `flutter analyze` | — | 매 커밋 |
| `integration_test` 19개를 **Android 에뮬레이터에서** | 플러그인 채널 실호출. ⚠️ 한 건이 별 Activity를 띄운다(§M2 게이트) | M2 게이트 |
| API 35+ 에뮬레이터 수동 (**debug**) | edge-to-edge, 인텐트, 권한 다이얼로그, 아이콘 마스크, **글꼴 크기·화면 크기 최대** | M2 |
| **release AAB를 bundletool로 설치해 수동** | 축소가 지운 것(알림 아이콘·Gson 역직렬화) · 서명 · TAGO 키 주입 | M1 스모크 · M2-① |
| **iPhone 시뮬레이터 회귀** | 이 브랜치가 바꾸는 **공유 코드** — 시트 3종 상단·하단 인셋, 라이트/다크 상태바, 온보딩 글꼴, 설정 방침 행, 알림 details | M2 끝 (다음 iOS beta 전) |
| 테스터 12명 + 사전 출시 보고서 | 실기기 — 렌더·크래시·제조사 차이·**배터리 최적화**·글꼴 크게 | M1부터 상시 |

⚠️ **iPhone 시뮬레이터 행이 빠지면 이 브랜치의 대가를 아무도 안 본다.** 브리프의 "iOS 한 줄도
안 바뀐다"가 깨졌으므로(§개요·§범위 밖) 머지 뒤 다음 iOS beta가 미검증 공유 변경을 심사에
태운다. `deploy` 스킬이 이미 규칙을 적어 뒀다 — **"[필수] 시뮬레이터 런타임 확인 … UI·동작
변경이면 배포 전 시뮬에서 실제 동작을 태운다."** 이 브랜치는 그 규칙의 대상이다.

⚠️ **위 두 줄은 서로를 대신하지 못한다.** debug 빌드에는 R8 축소가 없어 `ic_notification`
삭제·Gson 규칙 누락이 **전부 통과한다**(§M1-C8). 반대로 release 빌드는 debuggable이 아니라
`adb shell run-as`로 앱 데이터를 들여다볼 수 없고(M2-②의 `cache/shared_csv` 확인이 그 경로다)
스택 트레이스가 난독화돼 원인 추적이 느리다. **그래서 둘을 나눈다** — 인텐트·인셋·권한
다이얼로그는 debug에서, **알림 3종은 release에서 한 번 더** 밟는다.

### 에뮬레이터로 못 잡는 것 (테스터에게 명시적으로 시킬 것)

- **제조사 배터리 최적화** — 가장 큰 실전 리스크. 갤럭시 사용자에게 "며칠 안 열고 뒀다가 아침
  알림이 오는지"를 물어야 한다. 공식 문서로 확인한 것은 "9분당 1회 상한"과 "표준 알람은
  maintenance window로 연기"까지이고, **브리프의 "08:00~08:15" 상한이 실제로 지켜지는지는
  에뮬레이터로도 확인할 수 없다.**
- **실제 긴 정류장 이름 렌더**(`석수체육공원.자동차학원.원태우지사의거지`) — 픽스처로는 원리적으로
  못 잡는다.
- **실제 버스 타이밍·배차** — 서버 예측이 30초 사이 중앙값 33초씩 수정된다(상대 오차 16.2%).
- **Google 로그인 실기기 흐름** — 특히 Play 앱 서명 키 경로.
- **카카오톡·Gmail·네이버메일이 CSV에 붙이는 MIME**, 그리고 **카카오톡이 시스템 sharesheet를
  쓰는지 자체 목록(`queryIntentActivities`)을 쓰는지**. 후자라면 카카오톡이 `<queries>`를
  선언하지 않은 한 우리 앱이 목록에 안 뜬다 — **우리가 고칠 수 없는 문제다.**
  - **에뮬레이터에서 먼저 시도한다.** M2 게이트가 `google_apis_playstore` 이미지를 새로 받으므로
    (§M2 게이트) Play 스토어가 올라와 있고 카카오톡 설치를 시도할 수 있다. "깔 수 없다"는
    단정은 옛 AVD(`PlayStore.enabled=no`)를 전제한 것이었다.
  - 설치가 안 되거나(로그인·기기 인증 등) 동작이 실기기와 달라 보이면 그때 위임한다 —
    **테스터 한 명에게 명시적으로 시킨다.** 어느 쪽이든 실기기 확인은 남는다(제조사 공유 앱은
    에뮬레이터에 없다).
- **삼성 "내 파일"의 ACTION_VIEW MIME** — 오픈소스가 아니다.

## 리포 문서·규칙 갱신 — 이 스펙은 머지되면 읽히지 않는다

이 스펙은 새 프로젝트 규칙을 여럿 선언한다. 그런데 **이 리포에서 규칙이 사는 곳은
`CLAUDE.md`다** — "개수가 고정된 설정은 세그먼트, 늘어나는 설정은 시트", "애니메이션 키는
정체성", "긴 정류장 이름은 폭을 묶을 것"이 모두 거기 있다. 설계 문서에만 적어 두면
§M2-⑦이 스스로 경고한 그대로 된다: **"규칙을 안 적어 두면 다음 사람이 반대쪽을 고른다."**

그래서 문서 갱신을 **마일스톤 완료 조건**으로 넣는다. 리포 관례대로 `document-release` 스킬
경로를 쓴다.

### M1 완료 조건에 포함

| 문서 | 무엇을 |
|---|---|
| `.claude/skills/deploy/SKILL.md` | Android 절을 런북으로 교체 — **§M1-C9가 전문이다** |
| `CLAUDE.md` › `## 배포` › `명령` | `./android/bin/fastlane.sh {check_tago_key,check_play_key,build_aab,bootstrap,beta}` 5줄. **트랙을 값과 함께 적는다**(`beta` = 비공개 테스트 = `alpha`) |
| `CLAUDE.md` › 프로젝트 구조 | `android/{Gemfile,bin/fastlane.sh,fastlane/{Appfile,Fastfile}}` · `android/key.properties`(리포 밖 keystore를 가리킨다) · `android/app/{proguard-rules.pro,src/main/res/raw/keep.xml}` · `test/android/release_guard_test.dart` |
| `CLAUDE.md` › 기술 스택 표 | `iOS 배포 중. Android는 코드는 있으나 미검증` → 실제 상태로. Play 트랙·서명 방식(Play 앱 서명 + 업로드 키)도 한 줄 |
| `CLAUDE.md` › 위험한 작업 사전 확인 | Play 관련 되돌릴 수 없는 것 셋(§사람의 몫) — 확정용 업로드 · keystore · 최종 제출 |
| `CLAUDE.md` › 배포 플로우 정책 | iOS 정책("green이면 승인 없이 beta")이 Android에도 같은지 명시. **트랙을 틀리면 14일을 태우므로** 첫 `beta`는 콘솔 육안 확인을 끼운다는 예외를 적는다 |

### M2 완료 조건에 포함

| 규칙 | 왜 CLAUDE.md에 |
|---|---|
| **플랫폼 분기는 `dart:io`의 `Platform.isAndroid`** | `defaultTargetPlatform`은 `flutter test`에서 **항상 `android`**다(`_platform_io.dart:29-34`) → 그걸 쓰면 macOS 호스트에서 도는 `visual_check`·E2E **위젯 테스트 전체에** Android 전용 행이 나타난다. 함정과 규칙을 함께 적는다 |
| 그 대가와 완화 | `Platform.isAndroid`는 위젯 테스트로 못 밟는다 → **주입점을 둔다**(`showBatteryHint`). 새 플랫폼 분기 UI마다 같은 형태를 쓴다 |
| `flutter_deeplinking_enabled="false"`의 **이유** | 값만 남으면 다음 사람이 딥링크를 붙이려고 켠다 → `content://`가 `initialLocation`을 덮어 **제공자에 따라** Page Not Found(§M2-②). 공유 파일은 `planroutine/shared_file` 채널이 전담한다 |
| 알림 채널 규칙 | **id는 `notification_details.dart`의 공개 상수 `kAndroidChannelId`, 이름·설명은 `NotificationStrings`.** id를 `*Strings`에 두면 문구 정리로 바뀌어 채널이 갈라진다. 소비처가 두 파일이라 `_` 접두를 쓸 수 없다(라이브러리 private). 그리고 `channelName`과 `digestTitle`은 값이 같아도 **공유하지 않는다** |
| 스케줄 모드 | `inexactAllowWhileIdle`을 고른 이유(권한 화면 없음 · Play 고위험 권한 양식 회피)와 그것을 떠받치는 구조(`computeNotifications`가 **하루 1건**으로 병합해 Doze 9분 규칙이 무해하다). **개별 이벤트마다 알림을 만들면 이 결정이 무너진다** |
| 글꼴 굵기 규칙 | `GoogleFonts.*`에 새 굵기를 넘기면 **그 변형 파일도 번들한다.** `allowRuntimeFetching = false`라 안 하면 화면이 조용히 기본 글꼴로 떨어진다(§M2-⑧) |
| 바텀시트 규칙 | `showModalBottomSheet`에는 **항상 `useSafeArea: true`** + 하단은 `sheetBottomInset(context)`. `sheet_safe_area_test.dart`가 **둘 다** 전수 검사하지만(호출부에 `useSafeArea`, 그 파일에 `viewInsets.bottom` 직접 참조 0건) 이유는 여기 적는다 — `useSafeArea`는 `SafeArea(bottom: false)`라 하단을 일부러 남긴다 |
| 기기 백업 | `allowBackup="true"`는 **결정**이고 §M3-H3 데이터 안전 답안의 전제다. 뒤집으면 양식과 방침을 함께 뒤집어야 한다. 키 단위 제외가 불가능한 이유(`FlutterSharedPreferences.xml` 한 파일)도 |
| 글꼴 배율 축 | 오버플로 가드는 **폭 × 글꼴 배율** 두 축이다. 폭만 훑는 가드는 절반이다(§⑥-d) |

⚠️ **`CLAUDE.md`의 "iOS 중심 (Android 코드만 존재)"·"iOS 배포 중"류 서술은 M1 시점에 이미
거짓이 된다.** 릴리즈가 `사용 가능`이 되는 순간부터 실제 사용자(테스터)가 Android 빌드를
쓰고 있으므로, 이 갱신을 M3까지 미루지 않는다.

## 미확인 목록

스펙이 단정하지 않은 것들이다. 대부분 M1/M2에서 실물을 보면 확정된다.

| # | 미확인 | 확정 시점 |
|---|---|---|
| 1 | `desugar_jdk_libs` 하한 버전(2.1.5로 통과 확인, 1.2.2·2.0.x 미검증) | 실험할 이유 없음 |
| 2 | `com.planroutine.app` 실제 사용 가능(404는 증명이 아니다. **앱 생성으로는 확정되지 않는다**) | M1-H3 확정용 업로드 |
| 3 | Play 앱 서명 지문 **개수**(hybrid signing 적용 여부) | M1-H4 |
| 4 | supply가 신규 앱 첫 업로드를 받는지(`release_status: completed`가 거부된다는 보고) | M1-H3 |
| 5 | `CLOSED_TRACK` — 기본 제공 비공개 테스트 트랙을 쓰므로 `alpha`로 못박았다. **트랙 존재를 API로는 확인할 수 없다**(404 → 빈 배열) | M1-H5 콘솔 육안 |
| 6 | PKCS12 `.jks`로 서명한 AAB를 Play가 받는지(거부 이유는 없다) | M1-H3 |
| 7 | **"opted-in"의 공식 정의** — Google 문서에 없다. "설치까지 해야 카운트"는 전부 3rd-party | Console Dashboard 카드 관찰 |
| 8 | 테스터 이탈 시 "글로벌 14일 리셋" 여부 — 공식 문구는 **개인별 재계산만** 말한다 | 같음 |
| 9 | Google OAuth 재검증 필요 여부 — 공식 문서 세 곳이 "새 클라이언트 추가"를 다루지 않는다 | M2-④ |
| 10 | vector drawable을 알림 small icon으로 쓸 때의 실제 렌더 | M2-① |
| 11 | `scheduleQuickTest`(5초)가 inexact에서 체감상 언제 뜨는지 | M2-① |
| 12 | `requestNotificationsPermission()`의 Activity 의존(호출부는 둘 다 Activity 생존) | M2-① |
| 13 | 두 번째 FlutterEngine이 생겼을 때 sqflite·알림이 멀쩡한지 | M2-② |
| 14 | `OpenableColumns.DISPLAY_NAME`이 한글 파일명을 온전히 주는지 | M2-② |
| 15 | URI 권한이 `configureFlutterEngine` 시점에 유효한지(<추측> 액티비티 생존 중 유효) | M2-② |
| 16 | 흰 바 위 흰 핸들이 **실제로** 안 보이는지 / 3버튼 80% alpha 결과물 | M2-⑥ |
| 17 | 런치 테마 밝기 불일치가 실제로 번쩍이는지 | M2-⑥ |
| 18 | `GoRouterState.of(context).uri.path`가 push 중 반환하는 값 | M2-③ 한 줄 프로브 |
| 19 | `google_apis_playstore`의 root 불가가 `integration_test`에 걸리는지 | M2 게이트 |
| 20 | `flutter_launcher_icons` 0.14.3의 adaptive 키 이름 **그리고 `adaptive_icon_background`가 이미지 경로를 받는지**(hex만 받으면 가드 테스트로 폴백, §M1-C7) | M1-C7 실행 |
| 21 | 한국 시장 특유의 Play 요건(청소년보호책임자 표기 등) — 조사하지 않았다 | M3 |
| 22 | 콘솔 실제 양식 문구(모든 답안은 공식 도움말 기준) | M3 |
| 23 | **Play API 액세스 활성·서비스 계정 권한 전파 소요 시간**(신규 계정) | M1-H1.6 |
| 24 | **비공개 테스트 릴리즈 공개에 필요한 선언 전수** — 앱 콘텐츠·데이터 안전이 전제인지 | M1-H1.5 |
| 25 | **첫 릴리즈 검토 기간** — 공식 안내는 "보통 7일 이내, 때로 더"뿐이다 | M1-H5 |
| 26 | 릴리즈가 `사용 가능`이 되기 전에도 테스터가 opt-in할 수 있는지 / 그것이 카운트되는지 | M1-H6c |
| 27 | 후속 릴리즈(M2 빌드)에도 검토가 붙는지 — 붙으면 `D+5` 기한이 위험하다 | M2 초반 |
| 28 | `keep.xml`·`proguard-rules.pro`가 실제로 아이콘·Gson을 지키는지 — **release 산출물에서만** 확인된다 | M2-① (bundletool 설치본) |
| ~~29~~ | ~~`./gradlew :app:checkReleaseAarMetadata`가 release 가드를 발동시키는지~~ → **확정: 발동한다.** 그래프에 `compileFlutterBuildRelease`가 있다(실측). C1 검증에서 뺐다 | 해소 |
| 30 | ~~`url_launcher`의 iOS `Info.plist` 설정~~ → **해소.** `LSApplicationQueriesSchemes`·`<queries>`는 **`canLaunchUrl` 전용**이고 `launchUrl`은 조회를 경유하지 않는다(README + `url_launcher_uri.dart:39-61`). 그래서 `canLaunchUrl`을 쓰지 않는다 | — |
| 31 | Auto Backup이 살아 있는 SQLite를 파일째 복사해 **복원본이 깨질** 가능성. 백업은 기기 유휴·충전 중에 앱 프로세스 없이 돌아 위험이 낮다고 보지만 실증하지 않았다 | 테스터 기기 교체·복원(있으면) |
| 32 | E2E share 한 건이 Android chooser 때문에 **뒤 시나리오를 멈추는지** — 방침 셋은 정해 뒀다 | M2 게이트 첫 실행 |
| 33 | `file_picker`가 **octet-stream으로 타이핑된 CSV**를 회색 처리하는지, 그리고 에뮬레이터에서 그 상태를 만들 방법 | M2-② |
| 34 | 1080×1920으로 고친 AVD(`config.ini`)가 API 36 이미지에서 정상 부팅하는지 / 16:9 기기 프로필로 만드는 쪽이 더 나은지 | M2 스크린샷 촬영 |

## 범위 밖 (명시적으로 안 함)

- **Android 태블릿 대응** (iOS도 iPhone 전용)
- **Material You 다이나믹 컬러** — 네이비+골드가 브랜드 정체성
- **위젯 / 퀵세팅 타일**
- **`ACTION_SEND_MULTIPLE`** — iOS에 대응물이 없어 패리티가 깨진다
- **타입 없는 `file://` 인텐트 대응** — API 24+에서 발신 측이 `FileUriExposedException`을 맞는다
- **16 KB page size 작업** — 이미 통과한다
- **`google-services.json` / Firebase** — 필요 없고, 넣어도 파싱하는 주체가 없다
- **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 권한** — Play 정책 반려 위험
- **`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`** — 느슨한 알람을 골랐으므로 불필요하고, 넣으면
  고위험 권한 심사 대상이 된다
- **`strip_dart_defines`의 Android 대응물** — dart-define가 파일로 남지 않는다
- **iOS Fastfile 리팩터**(`tago_key` 공용화) — 돌고 있는 배포 경로를 건드리는 위험이 이득보다 크다
- **`file_picker` 캐시 누수 정리**(`clearTemporaryFiles()` 미호출, iOS 포함 기존 부채) — 새
  `shared_csv` 경로는 스스로 정리하지만 기존 누수는 별 작업이다
- **iOS 코드 변경** — 브리프는 "한 줄도 안 바뀐다"였지만 **결정 A·B로 그 선언은 깨졌다.**
  아래가 확정 목록이고, **iOS 렌더가 실제로 바뀌는 것과 구조적으로 무영향인 것을 갈라 적는다** —
  회귀 검증의 대상이 앞의 것들이다(§검증 계층의 iPhone 시뮬레이터 행).

  | 파일 | 무엇 | iOS 영향 |
  |---|---|---|
  | `app_text_styles.dart` · `pubspec.yaml` · `main.dart` | 결정 A — 글꼴 에셋 번들 + 런타임 fetch 차단 | **렌더가 바뀐다.** `onboarding_screen.dart:113`의 `fontFamily: 'Space Grotesk'`가 지금은 등록돼 있지 않아 기본 글꼴로 그려진다(FontManifest 실측) — 번들하면 처음으로 의도한 글꼴이 나온다 |
  | 설정 › 앱 정보 위의 방침 행 | 결정 B — 인앱 방침 링크 | **화면이 바뀐다.** 행이 하나 늘고 `url_launcher` 의존성이 붙는다(양쪽 스토어가 같은 요건) |
  | 바텀시트 3종 `useSafeArea` + `sheetBottomInset` | ⑥-c | **렌더가 바뀐다.** 상단은 **이득**이고(CLAUDE.md가 기록한 다이나믹 아일랜드 함정) 하단은 홈 인디케이터만큼 여백이 는다. 키보드가 올라온 상태는 픽셀 단위로 동일하다 |
  | `app_theme.dart:35-36` | ⑥-a 내비게이션 바 필드 | **무영향.** `rendering/view.dart:485-489`가 iOS에서 `systemNavigationBar*` 네 필드를 전부 null로 만든다. `statusBarBrightness`는 값이 종전과 같다(가드 테스트가 고정한다) |
  | `notification_service.dart` + 새 `notification_details.dart` | ①의 Android 분기 · details `const` 해제 | **무영향이어야 한다.** iOS는 `DarwinNotificationDetails`만 보고 `interruptionLevel`이 그대로다 — 유닛 가드가 이 값을 고정한다 |
  | `gen_app_icon.dart` | 전경·배경 출력 추가 | **무영향.** 기존 1024 출력과 iOS 아이콘 경로는 그대로다 |
  | `main_shell.dart` | ③ `PopScope` 래핑 | **무영향.** iOS에는 시스템 백이 없어 콜백이 불리지 않는다(스와이프 back은 라우트 단위) |
  | `import_providers.dart` | ②의 `file_picker` 폴백을 고를 경우에만 | 폴백을 고르면 `Platform.isAndroid` 분기로 **Android에서만** `FileType.any`를 쓴다 — iOS는 그대로 |

  **iOS도 재배포 대상이다** — 이 브랜치가 머지되면 다음 iOS beta가 위 변경들을 함께 태운다.

## 정리해 둘 것

- `test/tmp_verify/`(조사 중 임시 프로브 자리)와 오염된 `build/app/outputs/`는 **이미 삭제됐다**
  (실측 부재 확인). `~/.gradle/init.d/`도 없다 — §브리프 수정 1의 "오염된 관측"을 만든 전역
  주입 스크립트가 남아 있지 않다는 뜻이다.
- 직전까지 `build/`에 있던 `app-release.aab`는 **debug 키 서명 + TAGO 키 없음**이었다. 지금은
  없어졌지만, 같은 것이 다시 생기지 않게 하는 것이 §C5의 gradle 가드 둘이다 — 그 산출물은
  브리프가 경계한 함정의 실물이었고, **이제는 만들 수 없다.**

## 다음 targetSdk 압력

SDK 목록에 이미 API 37 이미지가 떠 있다(`system-images;android-37.0;…`,
`android-37.2-beta1;…`). **Play는 iOS와 달리 매년 targetSdk를 강제한다** — 이 앱의 Android 유지
비용에 그 주기를 반영할 것.









