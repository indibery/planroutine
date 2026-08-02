# 안드로이드 M1 · 껍데기 출시 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `android/`를 Flutter 템플릿 상태에서 **Play 비공개 테스트 트랙에 올릴 수 있는 서명된 AAB**까지 끌어올린다. 기능이 아니라 타이머 두 개(테스터별 14일 · Play 앱 서명 지문)를 켜는 것이 목적이다.

**Architecture:** 코드 작업(C)과 콘솔 작업(H)이 교차한다. C의 검증이 어느 H 뒤에서만 가능한지가 순서를 정하므로, 이 계획은 **사람 게이트 4개**로 나뉜다. 게이트에서는 반드시 멈추고 사용자에게 넘긴다 — 되돌릴 수 없는 결정 셋(패키지명 확정 · keystore · 최종 제출)이 전부 게이트 안에 있다.

**Tech Stack:** Flutter 3.x / AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / fastlane(supply) / Ruby bundler

## Global Constraints

설계 근거는 **`docs/superpowers/specs/2026-08-01-android-release-design.md`**(이하 §스펙)에 있다. 아래는 모든 태스크에 걸리는 제약이다.

- **`applicationId` = `com.planroutine.app`** — iOS 번들과 통일. 첫 업로드로 **영구 확정**된다.
- **`compileSdk` 36 / `minSdk` 24 / `targetSdk` 36** — `flutter.*`에서 받는다. 하드코딩으로 내리지 말 것(2026-08-31부터 Play 신규·업데이트는 API 36 하한).
- **`desugar_jdk_libs:2.1.5`** — 실측 통과 버전. README의 1.2.2는 AGP 7.3.1 시절 문구다.
- **keystore는 리포 밖** `~/.android/keystores/planroutine-upload.jks`, 비번은 `android/key.properties`(gitignore).
- **release 빌드는 레인으로만** — `flutter build appbundle`을 손으로 치는 경로를 만들지 않는다. `build.gradle.kts`의 가드가 빌드 자체를 막는다.
- **트랙**: `beta` 레인 = **비공개 테스트(closed testing)**. internal은 14일을 **하루도 세지 않는다** — 틀리면 14일을 태운다.
- **하드코딩 금지**: 문자열은 도메인별 `*Strings` 클래스, 색상 `AppColors`, 크기 `AppSizes`.
- **기존 테스트 삭제 금지.** 현재 베이스라인은 `flutter test` **917건 통과**, `flutter analyze` **이슈 0**. 매 태스크 끝에서 둘 다 유지되어야 한다.
- **긴 코드는 §스펙에서 그대로 옮긴다.** `build.gradle.kts` 전문(§M1-C1)과 Fastfile 전문(§M1-C5)은 이 계획에 복사하지 않는다 — 복사하면 출처가 둘로 갈려 어긋난다(이 리포의 "출처를 갈라진 채 두지 않는다" 원칙). 절 이름으로 지목하니 그 블록을 통째로 쓸 것.

---

## 파일 구조

| 파일 | 책임 | 태스크 |
|---|---|---|
| `android/app/build.gradle.kts` | desugaring · applicationId · 서명 설정 · **release 가드 둘** | 1 |
| `android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt` | 빈 `FlutterActivity`(M2에서 채널이 붙는다) | 1 |
| `android/key.properties` | keystore 경로·비번 (**커밋 안 됨**) | GATE 1 |
| `android/.gitignore` · 루트 `.gitignore` | 빌드 세션·번들러 산출물·Play 비밀 | 1 |
| `android/Gemfile` · `android/bin/fastlane.sh` | Ruby 환경 고정 + Homebrew Ruby 주입 | 3 |
| `android/fastlane/Appfile` | 패키지명 + 서비스 계정 JSON **경로**(커밋함) | 3 |
| `android/fastlane/Fastfile` | 레인 5개 | 3 |
| `android/app/src/main/AndroidManifest.xml` | INTERNET 명시 + `allowBackup` 선언 | 6 |
| `lib/core/constants/strings/settings_strings.dart` | 방침 제목·URL·실패 문구 | 7 |
| `lib/features/settings/presentation/widgets/privacy_policy_list_tile.dart` | 방침 행(탭 → 브라우저) | 7 |
| `test/features/settings/privacy_policy_list_tile_test.dart` | 방침 행 가드 | 7 |
| `test/tools/gen_app_icon.dart` | 전경·배경 PNG 출력 추가 | 8 |
| `android/app/src/main/res/raw/keep.xml` · `android/app/proguard-rules.pro` | release 축소로부터 알림 아이콘·Gson 보호 | 9 |
| `.claude/skills/deploy/SKILL.md` · `CLAUDE.md` | 런북·프로젝트 규칙 동기화 | 10 |

---

## Task 1: 빌드 배선 — desugaring · 리네임 · 서명 · 가드

§스펙 M1-C1·C2·C3. **같은 파일 하나를 고치므로 한 태스크다.**

**Files:**
- Modify: `android/app/build.gradle.kts` (전문 교체)
- Move: `android/app/src/main/kotlin/com/schedulenote/schedule_app/MainActivity.kt` → `.../com/planroutine/app/MainActivity.kt`
- Modify: `android/.gitignore`, 루트 `.gitignore`

**Interfaces:**
- Produces: `hasReleaseKeystore`·`hasTagoKey` 두 플래그와 `gradle.taskGraph.whenReady` 가드. Task 3의 레인이 이 가드에 의존한다(레인을 우회해도 빌드가 막히는 것이 관통 원칙 ①의 실효다).

- [ ] **Step 1: 현재 실패를 눈으로 확인한다 (빨강)**

```bash
cd android && ./gradlew :app:checkDebugAarMetadata
```
Expected: `FAILURE` — `Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app.`

- [ ] **Step 2: `build.gradle.kts`를 §M1-C1의 전문으로 교체**

§스펙 `### M1-C1` 안의 ```` ```kotlin // android/app/build.gradle.kts — 전문 ```` 블록을 **통째로** 복사해 파일 전체를 대체한다. 그 블록에는 C1(desugaring)·C2(`namespace`·`applicationId`)·C3(signingConfigs)·C5(dart-define 되읽기 + 가드 둘)가 모두 반영돼 있다.

- [ ] **Step 3: Kotlin 디렉터리와 package 선언 이동**

```bash
mkdir -p android/app/src/main/kotlin/com/planroutine/app
git mv android/app/src/main/kotlin/com/schedulenote/schedule_app/MainActivity.kt \
        android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt
rmdir -p android/app/src/main/kotlin/com/schedulenote/schedule_app 2>/dev/null || true
```
그리고 `MainActivity.kt` 첫 줄을 `package com.planroutine.app`으로 고친다.
매니페스트의 `android:name=".MainActivity"`는 **namespace 상대라 수정하지 않는다.**

- [ ] **Step 4: gitignore의 뚫린 곳을 막는다**

`android/.gitignore` 끝에 추가 (서명 쪽 `key.properties`·`**/*.jks`는 **이미 있다**):
```gitignore
/.kotlin
/vendor/
/.bundle/
```
루트 `.gitignore`의 Fastlane 블록에 추가:
```gitignore
android/fastlane/report.xml
android/fastlane/README.md
android/fastlane/Preview.html
android/fastlane/metadata/

android/fastlane/*.json
android/play-store-*.json
**/*.pepk
**/*.p12
```

- [ ] **Step 5: desugaring이 풀렸는지 확인 (초록)**

```bash
cd android && ./gradlew :app:checkDebugAarMetadata   # BUILD SUCCESSFUL
cd .. && flutter build apk --debug                   # ✓ Built app-debug.apk
```
⚠️ **`:app:checkReleaseAarMetadata`를 돌리지 말 것.** 태스크 그래프에 `compileFlutterBuildRelease`가 있어 이름이 `Release`로 끝나고, C3 가드가 발동해 "업로드 키가 없습니다"가 뜬다(실측). 데수가링 실패로 오진하게 된다.

- [ ] **Step 6: 리네임이 병합 매니페스트에 반영됐는지 확인**

```bash
grep -o 'package="[^"]*"' \
  build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml
```
Expected: `package="com.planroutine.app"`
⚠️ 경로를 **debug로 좁힌다.** `*/*` 글로브는 리네임 전 release 병합본까지 물어 옛 이름을 함께 출력한다.

- [ ] **Step 7: 기존 테스트 회귀 확인**

```bash
flutter analyze    # 이슈 0
flutter test       # 917건 통과
```

- [ ] **Step 8: Commit**

```bash
git add android/ .gitignore
git commit -m "build(android): desugaring·리네임·서명 배선과 release 가드 둘을 넣는다"
```

---

## ★ GATE 1 — 사람: 업로드 keystore 생성 (H2)

**여기서 멈추고 사용자에게 넘긴다.** 되돌릴 수 없다 — 이 파일과 비밀번호를 잃으면 앱 업데이트가 영구 불가다.

```bash
mkdir -p ~/.android/keystores
keytool -genkeypair -v \
  -keystore ~/.android/keystores/planroutine-upload.jks \
  -alias planroutine-upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=PlanRoutine, OU=PlanRoutine, O=PlanRoutine, L=Seoul, ST=Seoul, C=KR"
```
- `-storetype`을 **생략한다**(JDK 17 기본 PKCS12). `-storepass`를 플래그로 주지 말 것 — 셸 히스토리에 남는다.
- `-validity 10000` → 만료 2053-12-17. Google 요건(≥25년, 2033-10-22 이후) 충족.
- **리포 밖 별도 백업**을 반드시 남길 것.

그리고 `android/key.properties`를 만든다(커밋되지 않는다):
```properties
storeFile=/Users/kwangsukim/.android/keystores/planroutine-upload.jks
storePassword=<발급 시 정한 비밀번호>
keyAlias=planroutine-upload
keyPassword=<발급 시 정한 비밀번호>
```
**`~`는 확장되지 않는다** — 절대경로로 쓸 것.

---

## Task 2: 서명 설정과 가드 둘이 각각 사는지 검증

**Files:** 없음(검증 전용). 실패하면 Task 1로 돌아간다.

- [ ] **Step 1: release 서명 설정이 붙었는지**

```bash
cd android && ./gradlew :app:signingReport | grep -A3 "Variant: release"
```
Expected: `Config: release` · `Alias: planroutine-upload` · `SHA1: …`
`signingReport`는 산출물을 만들지 않아 가드에 걸리지 않는다.

- [ ] **Step 2: 서명 키 가드가 사는지**

```bash
mv android/key.properties /tmp/ && cd android && ./gradlew :app:assembleRelease
```
Expected: `BUILD FAILED` — `android/key.properties가 없습니다…`(한국어)

- [ ] **Step 3: 복구하고, TAGO 키 가드가 사는지**

```bash
mv /tmp/key.properties android/
cd android && ./gradlew :app:assembleRelease
```
Expected: `BUILD FAILED` — 이번엔 `TAGO_KEY dart-define가 비어 있습니다…`
**두 메시지를 순서대로 본 것이 "가드 둘이 각각 산다"의 증거다.**
⚠️ Step 3의 복구를 빠뜨리면 이후 모든 release 검증이 엉뚱한 메시지를 낸다.

- [ ] **Step 4: 결과를 사용자에게 보고**

두 가드 메시지를 그대로 인용해 보고한다. 커밋할 파일 변경은 없다.

---

## Task 3: fastlane 레인 5개

§스펙 M1-C5.

**Files:**
- Create: `android/Gemfile`, `android/bin/fastlane.sh`, `android/fastlane/Appfile`, `android/fastlane/Fastfile`

**Interfaces:**
- Produces: `check_tago_key` · `check_play_key` · `build_aab` · `bootstrap` · `beta`. Task 4가 `build_aab`를, Task 5가 `check_play_key`를 부른다.
- Consumes: Task 1의 `hasTagoKey` 가드(레인이 `--dart-define-from-file`로 키를 넣어야 빌드가 통과한다).

- [ ] **Step 1: Ruby 환경 — `ios/`에서 복제**

```bash
cp ios/Gemfile android/Gemfile
mkdir -p android/bin && cp ios/bin/fastlane.sh android/bin/fastlane.sh
chmod +x android/bin/fastlane.sh
```
`fastlane.sh` 안의 iOS 경로 참조를 `android/`로 고친다(스크립트가 자기 디렉터리를 기준으로 `bundle exec fastlane`을 돈다).

- [ ] **Step 2: `Appfile` 작성**

§스펙 `#### android/fastlane/Appfile` 블록 그대로. `package_name("com.planroutine.app")` + 서비스 계정 JSON **경로**(`~/.google_play/planroutine.json` — `.claude/skills/deploy/SKILL.md`가 이미 적어 둔 값과 일원화). **이 파일은 커밋한다** — 경로만 들고 있고 비밀이 아니다.

- [ ] **Step 3: `Fastfile` 작성**

§스펙 `### M1-C5` 안의 Fastfile 전문을 그대로 옮긴다. 반드시 포함되어야 하는 성질 넷:
1. `assert_play_key`·`tago_key` 가드가 **`flutter clean` 앞**에 있다(값싼 가드를 파괴적 단계 앞에).
2. `build_aab`가 **업로드를 하지 않는다**(폴백이 실제로 존재해야 한다).
3. `next_version_code`가 트랙 전수 최대 + 1이고 **트랙별 `rescue`**로 감싸여 있다.
4. TAGO 키를 `--dart-define-from-file`로 넘긴다(argv에 실으면 로그에 평문으로 남는다).

- [ ] **Step 4: Play 인증이 필요 없는 레인부터 검증**

```bash
./android/bin/fastlane.sh check_tago_key    # "TAGO 키 OK: N자"
```

- [ ] **Step 5: 가드 셋이 clean 앞에서 죽는지 (한 줄씩 복구하며)**

```bash
mv ~/.planroutine/tago.env /tmp/ && ./android/bin/fastlane.sh build_aab   # 즉시 실패
mv /tmp/tago.env ~/.planroutine/
mv android/key.properties /tmp/ && ./android/bin/fastlane.sh build_aab    # 즉시 실패
mv /tmp/key.properties android/
```
Expected: 둘 다 **"Android 캐시 정리" 헤더가 찍히기 전에** 멈춘다. 찍힌 뒤 멈추면 가드 위치가 틀렸다(clean은 수 분이고 되돌릴 수 없다).
⚠️ **복구를 한 줄씩 짝지어 둘 것.** 몰아서 옮기면 다음 단계가 실행 불가다.

- [ ] **Step 6: Commit**

```bash
git add android/Gemfile android/bin android/fastlane
git commit -m "build(android): fastlane 레인 5개를 배선한다 — 빌드와 업로드를 가른다"
```

---

## ★ GATE 2 — 사람: Play Console 앱 생성 + 서비스 계정 (H1 · H1.5 · H1.6)

**여기서 멈춘다.** 아래 셋을 콘솔에서 하고 결과를 알려주면 Task 4로 간다.

1. **H1 앱 생성** — Play Console에서 앱을 만든다(앱 이름·기본 언어·앱/게임·무료/유료·정책 선언). ⚠️ **이 양식에 패키지명 입력란이 없다** — `applicationId`는 첫 AAB 업로드 때 바인딩된다. 선점 충돌도 그때 드러난다.
2. **H1.5 릴리즈 공개 선행 선언 확인** — 콘솔에서 "비공개 테스트 릴리즈를 공개하려면 무엇이 필요한지" 전수 확인. 무엇이 전제인지에 따라 **M3 항목이 M1으로 당겨진다**(§스펙 M1-H1.5):
   - 앱 콘텐츠·데이터 안전이 전제면 → M3-H2·H3를 GATE 4 앞으로.
   - **방침 URL 제출이 전제면 → M2-⑧(미사용 `google_fonts` 제거)과 M2-⑨(처리방침 개정)도 M1으로.** ⑧은 2파일 3곳 삭제라 당기는 비용이 사실상 0이다. ⑨는 방침 본문에 기기 백업 절을 추가하는 작업이라 Task 6(백업을 켠 것으로 선언)과 짝이다.
   - 셋 다 전제가 아니면 그대로 M2·M3에 둔다.
3. **H1.6 서비스 계정** — Play Console `설정 › API 액세스` → GCP 프로젝트 연결(iOS와 같은 프로젝트 가능) → 서비스 계정 생성 → **릴리스 관리자** 권한 → JSON을 `~/.google_play/planroutine.json`에 둔다.
   - 완료 신호는 **콘솔 육안**(사용자 및 권한에 서비스 계정이 보인다)까지다. `check_play_key`는 아직 돌지 않는다 — 패키지 미바인딩이라 API가 404다.
   - 신규 계정은 API 액세스 활성·권한 전파가 즉시가 아닐 수 있다.

---

## Task 4: 첫 release AAB를 레인으로 만들고 검증

**Files:** 없음(산출물 검증). 실패하면 Task 1·3으로 돌아간다.

- [ ] **Step 1: 레인으로 AAB를 만든다**

```bash
./android/bin/fastlane.sh build_aab
```
Expected: `build/app/outputs/bundle/release/app-release.aab` 생성.

- [ ] **Step 2: 서명 지문이 Task 2의 것과 같은지**

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```
Expected: SHA1이 Task 2 Step 1의 `signingReport` 값과 **일치**.

- [ ] **Step 3: R8 설정에 규칙 파일이 들어갔는지** *(Task 9 이후 재실행)*

```bash
grep -c 'proguard-rules.pro' build/app/outputs/mapping/release/configuration.txt
```
지금은 Task 9 전이라 **0이 정상**이다. Task 9 뒤에 다시 돌려 1 이상을 확인한다.

- [ ] **Step 4: 에뮬레이터 스모크 — AAB를 그대로 깐다**

```bash
brew install bundletool
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/planroutine.apks --local-testing
bundletool install-apks --apks=/tmp/planroutine.apks
```
⚠️ **손으로 `flutter run --release`를 치지 말 것** — `--dart-define-from-file`이 없어 키 없는 빌드를 보게 되고, 스모크에서 "정상"과 구별되지 않는다(관통 원칙 ①이 막으려던 상황).
확인: 앱이 뜨고 4탭이 돈다. **알림과 CSV 공유는 M2라 안 되는 것이 정상이다.**

- [ ] **Step 5: 결과 보고**

AAB 경로·크기·SHA1과 에뮬레이터 스모크 결과를 보고한다. 커밋할 변경은 없다.

---

## ★ GATE 3 — 사람: 확정용 업로드 (H3)

**여기서 멈춘다. 되돌릴 수 없다 — 패키지명이 영구 확정된다.**

Task 4가 만든 `app-release.aab`를 **Play Console에 사람이 직접 업로드**한다. 트랙은 **internal**, 릴리즈는 **draft**.

- **레인으로 할 수 없다.** Play Developer API는 패키지 바인딩 전에 edit을 못 연다(`supply/lib/supply/client.rb:163` `insert_edit` → 404). `bootstrap` 레인은 바인딩 **뒤**의 재업로드용이다.
- **internal이라 14일을 하루도 태우지 않는다.**
- 이 업로드로 넷이 확정된다: 패키지명 · PKCS12 `.jks` 수용 여부 · draft 제약 · **Play 앱 서명 키 지문 발급**.
- 지문은 `테스트 및 출시 › 설정 › 앱 서명`에서 수집한다(2026-05에 `Protected with Play`로 경로가 바뀌었다). **지문이 셋일 수 있다**(신규 앱은 hybrid signing 자동 등록).
- 선점 충돌이 나면 여기서 멈추고 `applicationId`를 다시 정한다 — 그때 헛일이 되는 범위는 Task 1·3뿐이다.

---

## Task 5: 서비스 계정 권한이 실제로 먹는지 확정 (H3.5)

- [ ] **Step 1: `check_play_key` 실행**

```bash
./android/bin/fastlane.sh check_play_key
```
Expected: 트랙 4개의 versionCode를 조회해 출력한다(릴리즈가 없는 트랙은 빈 배열).
실패하면 GATE 2의 권한 부여로 돌아간다 — 여기가 **서비스 계정 권한이 처음 확정되는 자리**다.

- [ ] **Step 2: 결과 보고.** 커밋할 변경은 없다.

---

## Task 6: 매니페스트 — INTERNET 명시 + 백업 선언

§스펙 M1-C4.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: `<manifest>` 바로 아래에 INTERNET 추가**

```xml
<!-- 버스 공공데이터 + Google Calendar API.
     지금은 google_sign_in_android 6.2.1이 병합으로 넣어주지만, 그 플러그인이 빠지면
     조용히 사라지고 버스 카드는 "버스 정보를 불러올 수 없어요"만 띄운다. 그래서 명시한다. -->
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 2: `<application>`에 백업을 명시적으로 켠다**

§스펙 `#### 백업 — 켠다. 그리고 켰다고 적는다`의 블록을 그대로 옮긴다. `android:allowBackup="true"`를 **명시**한다 — 기본값에 맡기지 않는다("정하지 않아 기본값으로 출시되는 것"과 "정해서 켠 것"은 다르다).

- [ ] **Step 3: 소스에 들어갔는지 확인**

```bash
grep -c 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml   # 1
grep -c 'android:allowBackup' android/app/src/main/AndroidManifest.xml           # 1
```
⚠️ **병합 매니페스트로 검증하지 말 것.** 병합 결과는 이 작업 전후가 동일하다(플러그인이 이미 INTERNET을 넣는다) — 작업을 안 해도 통과한다.

- [ ] **Step 4: 회귀 확인 후 커밋**

```bash
flutter analyze && flutter test
git add android/app/src/main/AndroidManifest.xml
git commit -m "build(android): INTERNET을 명시하고 자동 백업을 켠 것으로 선언한다"
```

---

## Task 7: 인앱 개인정보처리방침 링크

§스펙 M1-C6. **이 태스크만 진짜 TDD가 가능하다.**

**Files:**
- Modify: `pubspec.yaml` (`url_launcher` 추가)
- Modify: `lib/core/constants/strings/settings_strings.dart`
- Create: `lib/features/settings/presentation/widgets/privacy_policy_list_tile.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/settings/privacy_policy_list_tile_test.dart`

**Interfaces:**
- Produces: `SettingsStrings.privacyPolicyTitle` · `privacyPolicyUrl` · `privacyPolicyFailed`, 위젯 `PrivacyPolicyListTile`.

- [ ] **Step 1: 실패하는 위젯 테스트를 쓴다**

```dart
// test/features/settings/privacy_policy_list_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/widgets/privacy_policy_list_tile.dart';

void main() {
  testWidgets('방침 행이 보이고 탭하면 URL을 연다', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrivacyPolicyListTile(onOpen: (url) async => opened.add(url)),
      ),
    ));

    expect(find.text(SettingsStrings.privacyPolicyTitle), findsOneWidget);

    await tester.tap(find.text(SettingsStrings.privacyPolicyTitle));
    await tester.pumpAndSettle();
    expect(opened, [SettingsStrings.privacyPolicyUrl]);
  });

  testWidgets('열기에 실패하면 스낵바로 알린다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrivacyPolicyListTile(onOpen: (_) async => throw Exception('no browser')),
      ),
    ));

    await tester.tap(find.text(SettingsStrings.privacyPolicyTitle));
    await tester.pumpAndSettle();
    expect(find.text(SettingsStrings.privacyPolicyFailed), findsOneWidget);
  });
}
```
`onOpen`을 주입 가능하게 두는 이유: `url_launcher`를 위젯 테스트에서 실호출할 수 없고, 주입이 없으면 이 행은 **테스트 0건**이 된다.

- [ ] **Step 2: 실패를 확인**

```bash
flutter test test/features/settings/privacy_policy_list_tile_test.dart
```
Expected: FAIL — `privacy_policy_list_tile.dart` 없음.

- [ ] **Step 3: 문자열 셋을 `SettingsStrings`에 추가**

```dart
  /// 인앱 개인정보처리방침 링크. **Play User Data 정책이 요구하는 항목이다** —
  /// "a privacy policy link **or text** within the app itself".
  /// 이 URL을 바꾸면 Google OAuth 동의 화면 필드가 바뀌어 **재검증 트리거가 된다**.
  /// 방침 본문만 고칠 때는 URL을 건드리지 않는다.
  static const privacyPolicyTitle = '개인정보처리방침';
  static const privacyPolicyUrl = 'https://planroutine.indibery.dev/privacy_policy';
  static const privacyPolicyFailed = '브라우저를 열 수 없습니다';
```

⚠️ **경로를 빼면 안 된다.** 루트(`/`)는 **앱 소개 페이지**이고 방침은 `/privacy_policy`다
(실측: 루트 title `공직플랜 | … 공식 지원 페이지` / `/privacy_policy` title
`공직플랜(PlanRoutine) 개인정보 처리방침`). 초안이 루트를 적어 뒀는데 그대로 두면
**탭했을 때 방침이 아니라 홈페이지가 뜬다** — Play가 요구하는 "앱 안의 방침 링크"의 실효가
없어진다. 리포의 다른 문서들도 전부 `/privacy_policy`를 쓰고(`docs/release_checklist.md:17`,
`docs/oauth_verification_demo_script.md:44`), **OAuth 동의 화면 등록값도 그것**이다.
확장자 없는 pretty URL을 쓴다 — GitHub Pages가 `.html`로 매핑한다.
- [ ] **Step 4: 위젯 구현**

§스펙 `### M1-C6`의 `privacy_policy_list_tile.dart` 블록을 그대로 옮기되, `onOpen` 주입 파라미터를 둔다(기본값이 `url_launcher`의 `launchUrl`). 실패 시 `SettingsStrings.privacyPolicyFailed` 스낵바.

- [ ] **Step 5: `pubspec.yaml`에 `url_launcher` 추가 후 통과 확인**

```bash
flutter pub add url_launcher
flutter test test/features/settings/privacy_policy_list_tile_test.dart   # PASS
```

- [ ] **Step 6: 설정 화면에 배선**

`settings_screen.dart`에서 **앱 정보 위에 별 `SettingsSection` 하나**로 둔다. `AppInfoListTile`·`DataSourceListTile`의 `Column`에 **넣지 않는다** — 그 블록은 "둘 다 정보성이고 탭이 없다"는 성격이고, 탭 가능한 행을 섞으면 어디를 누를 수 있는지 흐려진다.

- [ ] **Step 7: iOS 확인 — 이 행은 양쪽에 생긴다**

```bash
flutter analyze && flutter test
```
그리고 **iPhone 시뮬레이터**에서 설정 탭을 열어 행이 보이고 탭하면 브라우저가 열리는지 확인한다. iOS 설정 화면이 바뀌는 것은 **의도된 변화**다(양쪽 스토어가 같은 요건).

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ test/
git commit -m "feat(settings): 인앱 개인정보처리방침 링크를 넣는다 — 양쪽 스토어 요건"
```

---

## Task 8: adaptive 아이콘

§스펙 M1-C7.

**Files:**
- Modify: `test/tools/gen_app_icon.dart` (출력 둘 추가)
- Modify: `pubspec.yaml` (`flutter_launcher_icons` 설정)
- Create: `assets/icon/app_icon_foreground.png`, `assets/icon/app_icon_background.png` (생성물)

- [ ] **Step 1: `gen_app_icon.dart`에 출력 둘을 더한다**

현재 파일은 `test('generate 1024x1024 app icon PNG')` 하나이고, 그 안에서
`canvas.drawRect`(navy 배경) → `LogoHybridPainter().paint`(90%) → `toImage` →
`assets/icon/app_icon.png` 순으로 돈다. **그 테스트는 손대지 않는다**(iOS 경로 불변).

렌더 3줄이 같으므로 헬퍼로 묶고 테스트 둘을 더한다:

```dart
/// 1024×1024 캔버스에 그려 PNG로 쓴다. [drawBackground]가 false면 알파가 남는다.
Future<void> _writeIcon(
  String path, {
  required bool drawBackground,
  required double markScale,
}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  if (drawBackground) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = AppColors.navy,
    );
  }
  if (markScale > 0) {
    final markSize = size * markScale;
    final offset = (size - markSize) / 2;
    canvas.save();
    canvas.translate(offset, offset);
    LogoHybridPainter().paint(canvas, Size(markSize, markSize));
    canvas.restore();
  }

  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(byteData, isNotNull);
  final bytes = byteData!.buffer.asUint8List();
  File(path).writeAsBytesSync(bytes);
  print('Wrote ${bytes.length} bytes → $path');
}
```
```dart
  test('generate adaptive foreground PNG', () async {
    // 배경 없이(투명) 로고 60%. adaptive 전경은 **안전 영역이 66%뿐**이라
    // iOS의 90% 배치를 그대로 쓰면 원형 마스크에서 테두리가 잘린다.
    await _writeIcon('assets/icon/app_icon_foreground.png',
        drawBackground: false, markScale: 0.6);
  });

  test('generate adaptive background PNG', () async {
    // navy 단색 한 장. 색의 출처를 AppColors 하나로 남기기 위한 것이다 —
    // pubspec에 hex를 박으면 팔레트를 손볼 때 아이콘 배경만 옛 색으로 남는다.
    await _writeIcon('assets/icon/app_icon_background.png',
        drawBackground: true, markScale: 0);
  });
```

- [ ] **Step 2: 세 장이 나오는지 확인**

```bash
flutter test test/tools/gen_app_icon.dart
ls -la assets/icon/
```
Expected: `app_icon.png` · `app_icon_foreground.png` · `app_icon_background.png`

- [ ] **Step 3: `pubspec.yaml`의 `flutter_launcher_icons` 설정**

§스펙 M1-C7의 yaml 블록 그대로. `android: "ic_launcher"`로 켜고, `adaptive_icon_background`/`_foreground`에 **이미지 경로**를 준다.
⚠️ **색 hex를 pubspec에 박지 않는다** — 네이비의 출처가 `AppColors`와 pubspec 둘로 갈린다. 배경도 코드가 뽑은 한 장을 쓰면 출처가 하나로 남는다.

- [ ] **Step 4: 생성 후 산출물 확인**

```bash
dart run flutter_launcher_icons
ls android/app/src/main/res/mipmap-anydpi-v26/
cat android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
```
Expected: `ic_launcher.xml`에 `<background>`/`<foreground>`.
⚠️ `adaptive_icon_background`가 이미지 경로를 **안 받으면**(키 이름은 0.14.3 기준 <추측>) 폴백은 hex + **가드 테스트 1건**이다 — `AppColors.navy.toARGB32()`와 pubspec 문자열을 대조한다(선례: `test/features/settings/data_source_credit_test.dart`). 어느 쪽이든 출처를 갈라진 채 두지 않는다.

- [ ] **Step 5: 에뮬레이터 홈 화면에서 눈으로**

원형 마스크에서 로고가 잘리지 않는지 확인한다. 런처마다 마스크가 달라(원·스퀴클·티어드롭) **파일 검사로는 못 잡는다.**

- [ ] **Step 6: 회귀 확인 후 커밋**

```bash
flutter analyze && flutter test
git add assets/icon pubspec.yaml test/tools android/app/src/main/res
git commit -m "feat(android): adaptive 아이콘 — 배경·전경을 코드로 뽑는다"
```

---

## Task 9: release 축소 대비

§스펙 M1-C8. **debug 검증으로는 원리적으로 못 잡는 것들이다.**

**Files:**
- Create: `android/app/src/main/res/raw/keep.xml`
- Create: `android/app/proguard-rules.pro`

- [ ] **Step 1: `keep.xml` — 리소스 축소로부터 알림 아이콘을 지킨다**

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- release는 리소스 축소가 기본 ON이다(FlutterPlugin.kt:262-268).
     ic_notification을 참조하는 곳은 Dart 문자열뿐이라 축소기가 "안 쓰는 리소스"로 지운다.
     지워지면 initialize()가 아이콘 검증에 실패해 **알림이 한 건도 뜨지 않는다.** -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
```
`ic_notification` 자체는 M2에서 만든다 — 이 파일이 먼저 있어야 그때 안전하다.

- [ ] **Step 2: `proguard-rules.pro` — Gson 역직렬화를 지킨다**

```proguard
# flutter_local_notifications가 SharedPreferences에 저장한 목록을
# TypeToken<ArrayList<NotificationDetails>>로 되읽어 부팅 후 재예약한다.
# R8 fullMode(AGP 8.x 기본)에서 시그니처가 지워지면 그 경로가 release에서만 깨진다.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
```
`android/app/proguard-rules.pro`가 **있으면 Flutter Gradle이 자동으로** 설정에 더한다 — 파일을 만드는 것 말고 할 일이 없다.

- [ ] **Step 3: R8 설정에 실제로 들어갔는지**

```bash
./android/bin/fastlane.sh build_aab
grep -c 'proguard-rules.pro' build/app/outputs/mapping/release/configuration.txt
```
Expected: **1 이상**(Task 4 Step 3에서 0이었던 것이 바뀐다).
⚠️ `gradlew … --dry-run | grep -i shrink`를 쓰지 말 것 — `--dry-run`도 가드를 발동시키고, 통과해도 실제 태스크명은 `minifyReleaseWithR8`이라 0건이 나온다(실측).

- [ ] **Step 4: 커밋**

```bash
git add android/app/src/main/res/raw/keep.xml android/app/proguard-rules.pro
git commit -m "build(android): release 축소로부터 알림 아이콘과 Gson 경로를 지킨다"
```
실효(아이콘이 살아남는가·Gson이 되읽는가) 확인은 **M2-①의 release 스모크**가 담당한다.

---

## Task 10: 런북과 프로젝트 규칙 동기화

§스펙 M1-C9. **레인이 생긴 순간부터 스킬이 틀리다.**

**Files:**
- Modify: `.claude/skills/deploy/SKILL.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: `deploy` 스킬의 Android 절을 런북으로 교체**

지금 스킬은 `android beta`를 **`track: internal`**로 적어 뒀다 — 그대로 따르면 **14일이 0일이다.** 고칠 것:
- 레인 5개를 iOS 절과 같은 형식으로 열거. 호출은 항상 `./android/bin/fastlane.sh <레인>`
- **트랙을 값과 함께** 적는다(`beta` = 비공개 테스트, internal은 `bootstrap` 전용)
- `reset_android_caches`가 **필수**인 이유(registrant의 `integration_test`, `libsqlite3.so` 5.1MB)
- 서비스 계정 경로 일원화
- 게이트: iOS와 동일(analyze + test) + **release AAB 스모크**
- frontmatter `description`에서 "Android는 아직 미배선" 삭제

- [ ] **Step 2: `CLAUDE.md` 갱신**

- `## 배포 › 명령`에 Android 레인 5개
- 프로젝트 구조에 `android/{Gemfile,bin/fastlane.sh,fastlane/{Appfile,Fastfile}}` · `android/app/{proguard-rules.pro,src/main/res/raw/keep.xml}`
- 기술 스택 표의 `iOS 배포 중. Android는 코드는 있으나 미검증` → 실제 상태로
- 위험한 작업 사전 확인에 되돌릴 수 없는 것 셋(확정용 업로드 · keystore · 최종 제출)
- 배포 플로우 정책에 **"첫 `beta`는 콘솔 육안 확인을 끼운다"** 예외(트랙을 틀리면 14일을 태운다)

- [ ] **Step 3: 스킬이 실제로 Android를 안내하는지 확인**

`.claude/skills/deploy/SKILL.md`를 읽어 `track: internal`·`미배선`이 사라졌는지 grep으로 확인한다.

```bash
grep -c "internal\|미배선" .claude/skills/deploy/SKILL.md
```
Expected: `internal`은 `bootstrap` 설명에서만 나온다(0이 아니어도 되지만 `beta`와 묶여 있으면 안 된다).

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/deploy/SKILL.md CLAUDE.md
git commit -m "docs: Android 배포 런북과 프로젝트 규칙을 실제 배선에 맞춘다"
```

---

## ★ GATE 4 — 사람: 비공개 테스트 릴리즈 + 테스터 (H5 · H6 · H7)

M1의 마지막이다. Task 10까지 끝난 뒤.

1. **H5** — `./android/bin/fastlane.sh beta`로 **비공개 테스트** 트랙에 올린다. 콘솔에서 트랙 이름을 **육안 확인**할 것(internal에 올라가면 14일이 하루도 안 센다). 국가·지역을 선택하고, 릴리즈가 `검토 중` → **`사용 가능`**이 되는 것까지 기다린다.
2. **H6** — (a) 테스터 이메일 수집 (b) 콘솔 이메일 목록/그룹 생성 + 트랙 연결 (c) opt-in 링크 전달 + **사람별 날짜 기록**. (a)·(b)는 H5의 검토 대기와 **병렬로** 진행한다.
3. **H7** — 앱 등록(developer verification) 상태 카드 확인.

**M1 완료 신호**
- `check_play_key`·`check_tago_key`가 초록
- 콘솔 `테스트 및 출시 › 비공개 테스트`(내부 테스트가 아니다)에 릴리즈가 있고 **`사용 가능`**
- 프로덕션 액세스 카드에 테스터 수가 **세지기 시작**
- Play 앱 서명 지문 확보 → M2-④ GCP 등록 착수 가능
- `deploy` 스킬이 Android 경로를 안내하고 `CLAUDE.md`가 Android를 담는다

---

## 이 계획이 다루지 않는 것

M2(기능 패리티)와 M3(프로덕션)는 별 계획이다. M1 빌드에서 **알림은 100% 오지 않고 CSV 공유 목록에도 뜨지 않는다** — 정상이며 테스터에게 그렇게 안내한다.
