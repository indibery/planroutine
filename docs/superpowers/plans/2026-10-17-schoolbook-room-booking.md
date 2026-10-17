# 장소 예약(스쿨북) 탭 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공직플랜에 선택 탭 `장소 예약`을 더해, 스쿨북 학교의 교실 하나 × 하루 예약을 보고 · 예약하고 · 취소한다(시안 B).

**Architecture:** `lib/features/schoolbook/`에 data(HTTP 클라이언트 · 파서) · domain(Freezed 모델 · 순수 함수) · presentation(Riverpod · 화면 · 시트)을 둔다. 버스 기능처럼 기기에서 스쿨북 API를 직접 부르고, 결과는 던지지 않는 `SbResult`로 돌려준다. 저장은 `shared_preferences` JSON 키 하나, DB는 쓰지 않는다. 등록부에 탭형 선택 기능으로 들어간다.

**Tech Stack:** Flutter 3.44.8 · Riverpod 2 · GoRouter · `http`(+`package:http/testing.dart`) · `shared_preferences` · Freezed 3.

**Spec:** `docs/superpowers/specs/2026-10-17-schoolbook-room-booking-design.md` (스쿨북 API 원문: `Szzng/SchoolBook`의 `BackEnd/docs/api.md`)

## Global Constraints

- 기능 id `schoolbook` · prefs 키 `schoolbook_settings_v1` — **저장값이라 배포 뒤 바꾸지 않는다.**
- 주소 `https://schoolbook.zzolab.com/api`. 인증 헤더 `Authorization: <학교 코드 13자>`.
- 앱이 부르는 것은 **다섯뿐**: `GET accounts/login/<code>/` · `GET rooms/` · `GET rooms/<id>/bookings/?date=` · `POST rooms/<id>/bookings/` · `DELETE rooms/<id>/bookings/<bid>/`. 설정을 바꾸는 API는 부르지 않는다.
- **예약 비밀번호는 보안 저장소(`flutter_secure_storage`, 키 `schoolbook_password_v1`)에만** 저장하고 예약 시트에 미리 채운다. prefs · 로그 · 스낵바에는 넣지 않는다. **취소 시트는 채우지 않는다**(매번 입력). (사용자 변경 2026-10-17, Task 7 진행 중 — 원장 Ruling 참고)
- **확인 창 없음.** 비밀번호 입력이 확인이다.
- 예약·취소 요청은 **자동 재시도하지 않는다**(스쿨북에 중복 방지 키가 없다).
- 예약 가능한 날: 오늘 ~ 다음 해 2월 말일의 **평일**. 예약자 1~20자, 비밀번호 숫자 4자리.
- 테스트 학교 `플랜테스트`의 학교 코드는 **리포에 적지 않는다**(공개 리포). 코드는 로컬 메모리
  `reference_schoolbook_test_school.md`에 있다. 픽스처의 코드 칸은 `xxxxxxxxxxxxx`로 가린다.
- 리포 규칙: 문자열은 `SchoolbookStrings`, 색은 `AppColors` 토큰(기존 값 무수정), `!` 금지, 아이콘 이름은 `Icon(semanticLabel:)`(tooltip 금지),
  누르는 영역은 `ButtonSemantics`, 위젯 테스트의 실제 I/O는 `tester.runAsync`, 플랫폼 분기 없음(iOS·Android 둘 다).
- 기존 테스트를 지우지 않는다(`protect-tests.sh`가 선언 수 감소를 막는다). 목록에 한 줄 더하는 Edit는 `old_string`에 다른 `test(`를 넣지 않는다.
- 작업 브랜치 `feat/schoolbook-room-booking`(main에서 분기). 태스크마다 커밋.

## Review Focus

1. **붙여 넣은 링크가 지저분하다** — 앞뒤 공백 · `http://` · 끝 `/` · `?query` · `#hash` · `/<code>/room/12` · 대문자 호스트. 모두 코드를 뽑아야 한다 → Task 2 `parseSchoolCode` 테스트.
2. **예약 버튼을 두 번 누른다 / 요청 중 시트를 닫는다** — POST는 한 번만 가야 한다 → Task 8 `예약 버튼은 요청 중에 다시 눌리지 않는다`.
3. **긴 교실 이름 · 한 칸에 예약자 넷 이상 · 큰 글자** — 320pt에서 넘치지 않는다 → Task 7 넘침 테스트(320·390·430, textScaler 1.3).
4. **스쿨북이 `429`(초당 15회 제한)나 `5xx`, JSON이 아닌 HTML을 준다** — 크래시 없이 `network`로 → Task 4 클라이언트 테스트.
5. **주말이나 2월 말 다음 날에 앱을 연다 / 탭을 켜 둔 채 자정이 지난다** — 처음 날짜는 다음 평일, ▶는 마지막 날에서 멈춘다, 화면 복귀 시 지난 날짜면 체크를 막는다 → Task 2 날짜 테스트 + Task 7 `지난 날짜는 체크할 수 없다`.

---

## 파일 구조

```
lib/core/constants/strings/schoolbook_strings.dart   문구 전부
lib/features/schoolbook/
  domain/
    schoolbook_link.dart        parseSchoolCode
    booking_dates.dart          예약 가능일 · 평일 넘기기 · 처음 날짜
    schoolbook_models.dart      Freezed: SchoolInfo · SchoolbookRoom · RoomDay · PeriodSlot · SlotBooking
    schoolbook_settings.dart    Freezed: SchoolbookSettings (+ toJson/fromJson 손으로)
    period_row.dart             PeriodRowView · buildPeriodRow (한 교시 줄 판정)
  data/
    sb_result.dart              SbOutcome · SbResult<T>
    schoolbook_parser.dart      JSON → 모델
    schoolbook_api_client.dart  SchoolbookApiClient
  presentation/
    providers/schoolbook_providers.dart
    screens/schoolbook_screen.dart            탭(연결 전: 연결 화면 / 후: B 화면)
    screens/schoolbook_settings_screen.dart   기능 상세 설정
    widgets/schoolbook_connect_view.dart
    widgets/room_bar.dart · day_nav.dart · period_row_tile.dart
    widgets/room_picker_sheet.dart · book_sheet.dart · cancel_sheet.dart
    widgets/schoolbook_module_summary.dart
test/fixtures/schoolbook/*.json                실측 응답(코드 가림)
test/features/schoolbook/...                   태스크별
```

---

### Task 1: 테스트 학교 준비 + 실측 픽스처

코드 없음. 테스트 학교에 데이터를 만들고 응답을 저장한다. **이 학교 외의 학교에는 아무 요청도 보내지 않는다.**

**Files:**
- Create: `test/fixtures/schoolbook/` 아래 JSON 9개(이름은 아래 표)

- [ ] **Step 1: 브랜치 만들기** — `git switch -c feat/schoolbook-room-booking`
- [ ] **Step 2: 테스트 학교 데이터 만들기**(curl, `CODE`는 메모리 값을 셸 변수로만 쓴다)
  - `PUT /api/accounts/periods/` — 6개: `1교시 09:00-09:40` … `6교시 14:10-14:50` + 시각 없는 `방과후`(7번째).
  - `POST /api/rooms/` — `체육관`(정원 1), `과학실`(정원 2), `3층 다목적실 겸 방과후 돌봄교실`(정원 1, 20자 — 긴 이름 확인용).
  - `POST /api/rooms/<체육관>/timetables/` — `starts_on` 오늘, 화요일(`weekday 1`) 1교시 `3-2`.
  - 다음 주 화요일(이하 D) 과학실 3교시에 `5-1`·`6-2` 예약, 체육관 3교시 `5-1`, 5교시 `6-3`(비밀번호 `1234`).
  - D 과학실 4교시에 `4-1`·`4-2` 예약 후 `PATCH` 정원 1로 줄이며 `confirm:true` → 늦게 잡은 `4-2`가 `capacity_reduced`로 취소됨. 정원을 다시 2로.
- [ ] **Step 3: 응답 저장**(본문 그대로, 학교 코드가 나오는 칸만 `xxxxxxxxxxxxx`로 바꾼다)

| 파일 | 요청 |
|---|---|
| `login.json` | `GET accounts/login/<code>/` |
| `rooms.json` | `GET rooms/` |
| `day_gym.json` | 체육관 D (고정 + 예약 + 빈 교시 + 시각 없는 교시) |
| `day_science.json` | 과학실 D (정원 2, 두 명 · 취소된 예약 포함) |
| `book_ok.json` | 체육관 D 2·4교시 POST (`booker: 체육전담`) |
| `book_full.json` | 체육관 D 3교시 POST → 400 |
| `cancel_wrong_password.json` | 위에서 만든 예약 DELETE `password 0000` → 400 |
| `login_unknown.json` | 없는 코드 login → 401 |
| `cancel_not_found.json` | 이미 지운 예약 DELETE → 404 |

  각 파일은 `{"status": <코드>, "body": <응답 본문>}` 모양으로 감싼다(테스트가 상태 코드도 재현한다).
- [ ] **Step 4: 확인** — `grep -r "<실제 코드>" test/fixtures/schoolbook` 결과 0줄. book_ok로 만든 예약은 DELETE로 지워 둔다.
- [ ] **Step 5: 커밋** — `test: 스쿨북 실측 픽스처(테스트 학교, 코드 가림)`

---

### Task 2: 링크 파싱 · 예약 가능일 (순수 함수)

**Files:**
- Create: `lib/features/schoolbook/domain/schoolbook_link.dart`, `lib/features/schoolbook/domain/booking_dates.dart`
- Test: `test/features/schoolbook/domain/schoolbook_link_test.dart`, `test/features/schoolbook/domain/booking_dates_test.dart`

**Interfaces:**
- Produces:
  - `String? parseSchoolCode(String input)` — 13자 `[a-z0-9]` 코드 또는 null.
  - `DateTime lastBookableDate(DateTime today)` — 다음 해 2월 말일(날짜만).
  - `bool isBookableDate(DateTime day, DateTime today)`
  - `DateTime initialDay(DateTime today)` — 오늘이 평일이면 오늘, 아니면 다음 월요일.
  - `DateTime? nextWeekday(DateTime day, DateTime today)` — 다음 평일, `lastBookableDate`를 넘으면 null.
  - `DateTime previousWeekday(DateTime day)` — 하한 없음.
  - 모든 날짜는 시각을 버린 `DateTime(y, m, d)`로 다룬다.

- [ ] **Step 1: 실패하는 테스트**
  - `parseSchoolCode`: `'s367dozt0uhch'`·`' https://schoolbook.zzolab.com/s367dozt0uhch '`·`'http://schoolbook.zzolab.com/s367dozt0uhch/'`·`'https://SchoolBook.zzolab.com/s367dozt0uhch/room/12?x=1#a'`·`'schoolbook.zzolab.com/s367dozt0uhch'` → 모두 `'s367dozt0uhch'`(테스트 값은 가짜 코드 `abcdefghijk12`로 쓴다 — 실제 코드 금지).
    `''`·`'https://schoolbook.zzolab.com/'`·`'abc'`·`'https://example.com/abcdefghijk12'`·`'ABCDEFGHIJK12'`(대문자 코드) → null.
  - `lastBookableDate(2026-10-01)` = 2027-02-28, `(2027-05-01)` = 2028-02-29.
  - `initialDay`: 금 2026-10-16 → 그날, 토 10-17 → 10-19(월), 일 10-18 → 10-19.
  - `nextWeekday(2026-10-16 금)` = 10-19, `nextWeekday(2027-02-26 금, today 2026-10-17)` = null.
  - `previousWeekday(2026-10-19 월)` = 10-16.
  - `isBookableDate`: 어제 false · 오늘(평일) true · 토 false · 2027-03-01 false.
- [ ] **Step 2: 실행해 실패 확인** — `flutter test test/features/schoolbook/domain` → FAIL(정의 없음)
- [ ] **Step 3: 구현** — 호스트가 있으면 `schoolbook.zzolab.com`(대소문자 무시)일 때만 받고, 첫 경로 조각을 `^[a-z0-9]{13}$`로 검사한다. 스킴 없는 입력은 `https://`를 붙여 `Uri.tryParse`.
- [ ] **Step 4: 통과 확인** — 같은 명령 PASS
- [ ] **Step 5: 커밋** — `feat: 스쿨북 링크 파싱 · 예약 가능일`

---

### Task 3: 모델 · 파서 · 교시 줄 판정

**Files:**
- Create: `domain/schoolbook_models.dart`, `domain/schoolbook_settings.dart`, `domain/period_row.dart`, `data/schoolbook_parser.dart` (모두 `lib/features/schoolbook/` 아래)
- Test: `test/features/schoolbook/data/schoolbook_parser_test.dart`, `test/features/schoolbook/domain/period_row_test.dart`, `test/features/schoolbook/domain/schoolbook_settings_test.dart`
- Test helper: `test/features/schoolbook/fixture.dart` — `({int status, Object? body}) loadSchoolbookFixture(String name)`

**Interfaces:**
- Consumes: Task 1 픽스처, Task 2 없음.
- Produces (Freezed, `memo.dart` 모양 — `abstract class X with _$X`, `const X._()`, `part '….freezed.dart'`):
  - `SchoolInfo({required String code, required String name, required int periodCount})`
  - `SchoolbookRoom({required int id, required String name, required int capacity})`
  - `SlotBooking({required int id, required String booker, required bool canceled})` — `canceled` = `cancel_reason != null`.
  - `PeriodSlot({required int id, required String name, String? startTime, String? endTime, required bool archived, required int remaining, required List<String> fixed, required List<SlotBooking> bookings})`
  - `RoomDay({required DateTime date, required List<PeriodSlot> periods})`
  - `SchoolbookSettings({String? code, String? schoolName, int? lastRoomId, String? booker})` + `Map<String, dynamic> toJson()` · `factory SchoolbookSettings.fromJson(Map<String, dynamic>)`(모르는 키·틀린 형은 null). `static const empty = SchoolbookSettings()`. `bool get connected => code != null`.
  - 파서: `SchoolInfo parseLogin(Object? body)` · `List<SchoolbookRoom> parseRooms(Object? body)` · `RoomDay parseRoomDay(Object? body)` · `String? parseDetail(Object? body)`. 형이 틀리면 `FormatException`(클라이언트가 잡는다).
  - `PeriodRowView({required PeriodSlot slot, required List<PersonChip> people, required bool selectable, required int? remainingToShow})`
  - `PersonChip({required String label, required bool fixed, int? bookingId, required bool cancellable})`
  - `PeriodRowView buildPeriodRow(PeriodSlot slot, {required int capacity, required bool bookableDay, required bool pastDay})`

- [ ] **Step 1: 실패하는 테스트**
  - 파서: `day_gym.json` → 1교시 `fixed == ['3-2']`, 시각 없는 교시는 `startTime == null`. `day_science.json` → 4교시 `bookings`에 `canceled: true`인 `4-2`. `login.json` → `name == '플랜테스트'`, `periodCount == 7`. `book_full.json` → `parseDetail`이 서버 문구 그대로. `parseRooms('<html>')` → `FormatException`.
  - `buildPeriodRow`:
    - 취소된 예약은 `people`에 없다.
    - 고정은 `fixed: true, cancellable: false`, 날짜 예약은 `bookingId` 있음.
    - `pastDay: true`면 모든 `cancellable == false`, `selectable == false`.
    - `remaining == 0` → `selectable == false`. `archived` → `selectable == false`.
    - `bookableDay: false`(주말·범위 밖) → `selectable == false`.
    - `capacity == 1` → `remainingToShow == null`. `capacity == 2, remaining 1` → `remainingToShow == 1`. `remaining == 0` → null.
  - 설정: `toJson` 키는 정확히 `code`·`schoolName`·`lastRoomId`·`booker`(null은 빼도 된다). **어떤 입력에도 `password`라는 키가 없다.** `fromJson({'lastRoomId': 'x'})` → `lastRoomId == null`.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/schoolbook` → FAIL
- [ ] **Step 3: 구현 + 코드 생성** — `dart run build_runner build --delete-conflicting-outputs`
- [ ] **Step 4: 통과 확인** — PASS, `flutter analyze` 0 issues
- [ ] **Step 5: 커밋** — `feat: 스쿨북 모델 · 파서 · 교시 줄 판정`

---

### Task 4: API 클라이언트

**Files:**
- Create: `lib/features/schoolbook/data/sb_result.dart`, `lib/features/schoolbook/data/schoolbook_api_client.dart`
- Test: `test/features/schoolbook/data/schoolbook_api_client_test.dart`

**Interfaces:**
- Consumes: Task 3 파서·모델.
- Produces:
  - `enum SbOutcome { ok, rejected, unauthorized, noPeriods, notFound, network }` — `rejected` = 400(+`detail`), `unauthorized` = 401, `noPeriods` = 403, `notFound` = 404, `network` = 시간 초과 · 연결 실패 · 429 · 5xx · 파싱 실패.
  - `class SbResult<T> { const SbResult(this.outcome, {this.value, this.detail}); final SbOutcome outcome; final T? value; final String? detail; }` — 버스처럼 `isOk` 게터를 두지 않는다.
  - `const schoolbookBaseUrl = 'https://schoolbook.zzolab.com/api';`
  - `SchoolbookApiClient({http.Client? client})`, 시간 초과 10초.
    - `Future<SbResult<SchoolInfo>> login(String code)` — 헤더 없음. 교시 0개면 `noPeriods`.
    - `Future<SbResult<List<SchoolbookRoom>>> rooms(String code)`
    - `Future<SbResult<RoomDay>> roomDay(String code, int roomId, DateTime date)`
    - `Future<SbResult<void>> book(String code, int roomId, {required DateTime date, required List<int> periodIds, required String booker, required String password})`
    - `Future<SbResult<void>> cancel(String code, int roomId, int bookingId, {required String password})`
    - 공개 메서드는 던지지 않는다. 요청 본문은 JSON(`content-type: application/json`), 응답은 `utf8.decode(bodyBytes)`.

- [ ] **Step 1: 실패하는 테스트**(`MockClient`, 응답 헤더 `content-type: application/json; charset=utf-8` — 버스 테스트 헬퍼와 같은 이유)
  - 픽스처 9개를 상태 코드와 함께 돌려주고 outcome을 확인: login ok/401 → unauthorized, book_full → rejected + 서버 문구, cancel_wrong_password → rejected, cancel_not_found → notFound, login 교시 `[]` → noPeriods.
  - 요청 모양: `rooms`는 `Authorization` 헤더 = 코드, `roomDay`는 `?date=2026-10-20`, `book` 본문 키가 정확히 `date`·`period_ids`·`booker`·`password`, `cancel`은 DELETE + 본문 `{"password": "1234"}`.
  - 429 · 500 · `<html>` 본문 · `TimeoutException` · `SocketException`(MockClient가 던짐) → 모두 `network`, 예외가 새지 않는다.
  - **재시도 없음**: `book`이 `network`로 끝난 뒤 MockClient 호출 수 == 1.
- [ ] **Step 2: 실패 확인** — FAIL
- [ ] **Step 3: 구현** — 상태 코드 → outcome 매핑을 private 함수 하나에 모은다.
- [ ] **Step 4: 통과 확인** — PASS
- [ ] **Step 5: 커밋** — `feat: 스쿨북 API 클라이언트`

---

### Task 5: 설정 저장 · provider

**Files:**
- Create: `lib/features/schoolbook/presentation/providers/schoolbook_providers.dart`
- Test: `test/features/schoolbook/presentation/schoolbook_providers_test.dart`

**Interfaces:**
- Consumes: Task 3 `SchoolbookSettings`, Task 4 클라이언트.
- Produces:
  - `const schoolbookSettingsPrefsKey = 'schoolbook_settings_v1';`
  - `final schoolbookApiClientProvider = Provider<SchoolbookApiClient>((ref) => SchoolbookApiClient());`
  - `final schoolbookSettingsProvider = AsyncNotifierProvider<SchoolbookSettingsNotifier, SchoolbookSettings>(...)` — 메서드 `Future<void> connect(SchoolInfo info)`(code·schoolName 저장, lastRoomId 초기화) · `Future<void> disconnect()`(키 삭제) · `Future<void> setLastRoom(int roomId)` · `Future<void> setBooker(String booker)`(앞뒤 공백 정리, 빈 값이면 null). 손상된 저장값 → `SchoolbookSettings.empty`. `BusSettingsNotifier`의 `_save` 패턴.
  - `final schoolbookRoomsProvider = FutureProvider.autoDispose<SbResult<List<SchoolbookRoom>>>` — 연결 안 됐으면 요청 없이 `SbResult(unauthorized)`.
  - `typedef RoomDayKey = ({int roomId, DateTime date});`
  - `final roomDayProvider = FutureProvider.autoDispose.family<SbResult<RoomDay>, RoomDayKey>`
  - 캐시 없음: 화면이 다시 부르려면 `ref.invalidate(roomDayProvider(key))`.

- [ ] **Step 1: 실패하는 테스트**(`SharedPreferences.setMockInitialValues({})`, `ProviderContainer` + 클라이언트 override)
  - connect → 저장 JSON에 `code`·`schoolName`. setBooker(`' 체육전담 '`) → `'체육전담'`. disconnect → 키 없음. 손상값 `'{'` → empty.
  - **저장된 문자열 전체에 `password`·`1234`가 없다**(book 호출을 한 번 거친 뒤에도).
  - 연결 안 된 상태에서 `schoolbookRoomsProvider`를 읽어도 MockClient 호출 0.
- [ ] **Step 2: 실패 확인** · **Step 3: 구현** · **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `feat: 스쿨북 설정 저장 · provider`

---

### Task 6: 기능 등록 · 라우트 · 문구 · 연결 화면

**Files:**
- Create: `lib/core/constants/strings/schoolbook_strings.dart`, `lib/features/schoolbook/presentation/screens/schoolbook_screen.dart`, `lib/features/schoolbook/presentation/widgets/schoolbook_connect_view.dart`, `lib/features/schoolbook/presentation/screens/schoolbook_settings_screen.dart`(이 태스크에선 뼈대: 앱바 + 연결 안내), `lib/features/schoolbook/presentation/widgets/schoolbook_module_summary.dart`
- Modify: `lib/core/constants/app_strings.dart`(export 한 줄), `lib/core/modules/app_module.dart`(`ModuleIds.schoolbook = 'schoolbook'`), `lib/core/modules/module_catalog.dart`(탭 상수 + 항목), `lib/core/router/app_router.dart`(`AppRoutes.schoolbook = '/schoolbook'`, `schoolbookSettings = '/schoolbook/settings'` — `static const 이름 = '...';` 리터럴 형태, GoRoute 둘)
- Modify tests: `test/core/modules/module_catalog_test.dart`(`_shippedIds`에 `'schoolbook'`), `test/shared/design_unify_guard_test.dart`(`_tabScreens`·`_emptyStateScreens`에 `schoolbook_screen.dart`)
- Test: `test/features/schoolbook/presentation/schoolbook_connect_test.dart`

**Interfaces:**
- Consumes: Task 2 `parseSchoolCode`, Task 4 `login`, Task 5 `connect`.
- Produces: `class SchoolbookScreen extends ConsumerWidget`(연결 전 `SchoolbookConnectView`, 후 Task 7의 본문), `class SchoolbookSettingsScreen`, `class SchoolbookModuleSummary`(const, 연결됐으면 학교 이름, 아니면 `SchoolbookStrings.summaryNotConnected`).

문구(`SchoolbookStrings`, 스펙 그대로): `tabLabel='장소 예약'` · `title='장소 예약'` · `eyebrow='SCHOOLBOOK'` · `moduleDescription='스쿨북 학교의 장소 예약을 하루씩 보고 예약·취소합니다'` ·
`connectTitle='스쿨북 학교 링크를 붙여 넣어 주세요'` · `connectHint='스쿨북에서 쓰는 학교 주소를 복사해 오면 됩니다'` · `connectButton='연결'` · `connectNotFound='학교를 찾을 수 없어요. 링크를 확인해 주세요'` · `summaryNotConnected='학교를 연결해 주세요'`.
나머지 문구는 각 태스크가 스펙 표의 글자 그대로 더한다.

- [ ] **Step 1: 실패하는 테스트**
  - 연결 화면: 링크 입력 → `연결` → login 성공 → 설정에 저장 + 학교 이름이 보인다. 401 → `connectNotFound`. `parseSchoolCode`가 null이면 요청 없이 같은 문구. 요청 중 버튼 비활성.
  - 등록부 테스트·디자인 가드는 목록에 한 줄 더한 것만으로 새 항목을 검사한다.
- [ ] **Step 2: 실패 확인** — `flutter test test/core/modules test/shared test/features/schoolbook` → FAIL
- [ ] **Step 3: 구현** — 탭 아이콘은 빌더 선택(`Icons.meeting_room_outlined`/`Icons.meeting_room` 권장). 탭 앱바 오른쪽 ⚙: `ButtonSemantics` + `Icon(Icons.settings_outlined, semanticLabel: SchoolbookStrings.settingsShortcut)` → `context.push(AppRoutes.schoolbookSettings)`. 버스 상세처럼 `settings/presentation/widgets/`에는 두지 않는다(`settings_tab_module_rows_test`).
- [ ] **Step 4: 통과 확인** — 위 명령 PASS + `flutter analyze`
- [ ] **Step 5: 커밋** — `feat: 장소 예약 탭 등록 · 학교 연결`

---

### Task 7: 예약 보기 화면 (시안 B)

**Files:**
- Create: `widgets/room_bar.dart`, `widgets/day_nav.dart`, `widgets/period_row_tile.dart`, `widgets/room_picker_sheet.dart`
- Modify: `screens/schoolbook_screen.dart`(연결 후 본문 — `ConsumerStatefulWidget`, 상태: `DateTime _day`, `int? _roomId`, `Set<int> _selected`)
- Test: `test/features/schoolbook/presentation/schoolbook_screen_test.dart`, `test/features/schoolbook/presentation/schoolbook_overflow_test.dart`

**Interfaces:**
- Consumes: Task 2 날짜 함수, Task 3 `buildPeriodRow`, Task 5 provider.
- Produces: `PeriodRowTile({required PeriodRowView view, required bool checked, required ValueChanged<bool> onChecked, required ValueChanged<PersonChip> onPersonTap})` — Task 8이 `onPersonTap`으로 취소 시트를 연다. 예약 버튼 콜백 자리 `VoidCallback? onBook`(Task 8이 채운다; 이 태스크에선 null이면 버튼 숨김).

동작(스펙 「화면」 그대로):
- 처음 날짜 `initialDay(today)`, 교실은 `lastRoomId`가 목록에 있으면 그것, 아니면 첫 교실. 교실을 바꾸면 `setLastRoom`.
- ◀/▶는 `previousWeekday`/`nextWeekday`, ▶가 null이면 비활성. 날짜나 교실이 바뀌면 `_selected` 비움.
- 교시 줄: 이름 · 시각(`09:00`, 없으면 생략) · 사람 칩(고정은 `고정 · 3-2`) · `remainingToShow`가 있으면 `n자리 남음` · 체크칸(`selectable`일 때만).
- 하나 이상 체크하면 아래 `GoldGradientButton` 라벨 `SchoolbookStrings.bookButton(names)` = `'2·4교시 예약하기'`(교시 이름을 `·`로 잇는다 — 이름이 `1교시`면 `1·2교시`, 그 밖이면 이름 그대로 `·`로 잇는다; 규칙은 문자열 함수 하나에).
- 오류 상태는 스펙 「오류 · 빈 상태」 표의 문구 그대로(`network`→`불러오지 못했어요`+`다시 시도`, `unauthorized`→`학교 연결이 끊겼어요`+`다시 연결`(disconnect 후 연결 화면), `noPeriods`, 교실 0개, `notFound`→교실 다시 불러 첫 교실, 교시 0개). 빈 상태는 `EmptyState`.
- 앱으로 돌아왔을 때(`AppLifecycleState.resumed`) 그날 목록을 다시 부른다.

- [ ] **Step 1: 실패하는 테스트**(가짜 클라이언트 = `MockClient` + 픽스처, 날짜 고정을 위해 화면에 `DateTime Function() clock` 주입점)
  - 기억한 교실이 열린다 · 없으면 첫 교실 · 교실 시트에서 과학실을 고르면 과학실 D가 뜨고 `lastRoomId` 저장.
  - 토요일 시계 → 월요일이 뜬다. ▶를 마지막 예약 가능일에서 누를 수 없다.
  - 체육관 D: 1교시 체크칸 없음(고정이 정원을 채움), 2·4교시 체크 → 버튼 `2·4교시 예약하기`. 날짜를 넘기면 체크가 풀리고 버튼이 숨는다.
  - 과학실 D: 3교시 `5-1`·`6-2` 둘 다 보이고 `n자리 남음` 없음(0), 4교시에 `4-2`(취소됨)가 없다.
  - **지난 날짜는 체크할 수 없다**: ◀로 어제 → 체크칸 0개.
  - 오류 표 각 줄(6) 문구 확인.
- [ ] **Step 2: 넘침 테스트** — 320·390·430pt × textScaler 1.0·1.3, 교실 `3층 다목적실 겸 방과후 돌봄교실` + 한 칸 예약자 넷(가짜 응답) → `tester.takeException()`이 null, 교실 이름은 한 줄 말줄임.
- [ ] **Step 3: 실패 확인** — FAIL
- [ ] **Step 4: 구현**
- [ ] **Step 5: 통과 확인** — `flutter test test/features/schoolbook test/shared` PASS(`button_semantics_guard`·`no_tooltip`·`text_field_name` 포함)
- [ ] **Step 6: 커밋** — `feat: 장소 예약 하루 보기 화면(시안 B)`

---

### Task 8: 예약 시트 · 취소 시트

**Files:**
- Create: `widgets/book_sheet.dart`, `widgets/cancel_sheet.dart`
- Modify: `screens/schoolbook_screen.dart`(`onBook`·`onPersonTap` 연결)
- Test: `test/features/schoolbook/presentation/book_sheet_test.dart`, `test/features/schoolbook/presentation/cancel_sheet_test.dart`

**Interfaces:**
- Consumes: Task 4 `book`/`cancel`, Task 5 `setBooker`·`roomDayProvider`, Task 7 `PeriodRowTile`.
- Produces: `Future<BookSheetResult?> showBookSheet(BuildContext context, {required String roomName, required DateTime day, required List<PeriodSlot> periods, required String? initialBooker, required Future<SbResult<void>> Function(String booker, String password) submit})`,
  `Future<CancelSheetResult?> showCancelSheet(BuildContext context, {required String booker, required String periodName, required Future<SbResult<void>> Function(String password) submit})`.
  `enum BookSheetResult { booked, unknown }`, `enum CancelSheetResult { canceled, unknown }` — `unknown` = 네트워크 실패(결과 모름).

동작(스펙 「예약 시트」·「취소 시트」·오류 표):
- 시트 제목 `SheetTitle` — 예약 `'체육관 · 10월 20일(화) 2·4교시'`, 취소 `'5-1 · 3교시 예약 취소'`.
- 예약자 칸에 `initialBooker`, 비밀번호 칸(숫자 4자리, `obscureText`, `keyboardType number`)에 autofocus. 예약자 1~20자 · 비밀번호 4자리가 아니면 버튼 비활성.
- 결과: `ok` → 닫힘(`booked`/`canceled`) · `rejected` → **시트 유지** + 시트 안에 `detail` + 화면은 목록 다시 부르기 · DELETE의 `notFound` → 시트 안 `'이미 취소된 예약이에요'` + 목록 다시 부르기 · `network` → 닫힘(`unknown`).
- 화면: `booked` → `setBooker` + 목록 다시 부르기 + 스낵바 `'2·4교시를 예약했어요'` + 체크 비움 · `canceled` → 스낵바 `'예약을 취소했어요'` · `unknown` → 목록 다시 부르기 + 스낵바 `'결과를 확인하지 못했어요. 목록을 확인해 주세요'`.
- `cancellable == false` 칩은 눌러도 시트가 뜨지 않는다. 확인 창 없음. 스낵바에 비밀번호 없음.
- 시트는 `useSafeArea: true`, 키보드 여백 `math.max(0, MediaQuery.viewInsetsOf(context).bottom)`(리포 규칙).

- [ ] **Step 1: 실패하는 테스트**
  - 예약 성공 → submit 인자 `('체육전담', '1234')`, 스낵바, 저장된 예약자 갱신.
  - **예약 버튼은 요청 중에 다시 눌리지 않는다**: 느린 submit(Completer) 중 두 번 탭 → submit 호출 1회.
  - rejected → 시트가 남고 서버 문구가 보인다. 비밀번호가 3자리면 버튼 비활성.
  - network → 시트 닫힘 + `결과를 확인하지 못했어요…` 스낵바.
  - 취소: 날짜 예약 칩 탭 → 시트, 고정 칩·지난 날 칩 탭 → 시트 없음. 404 → `이미 취소된 예약이에요`.
  - 확인 다이얼로그(`AlertDialog`·`ConfirmDialog`)가 한 번도 뜨지 않는다.
- [ ] **Step 2: 실패 확인** · **Step 3: 구현** · **Step 4: 통과 확인**(`flutter test test/features/schoolbook test/shared`)
- [ ] **Step 5: 커밋** — `feat: 장소 예약 · 취소 시트`

---

### Task 9: 상세 설정 화면 · 요약

**Files:**
- Modify: `screens/schoolbook_settings_screen.dart`, `widgets/schoolbook_module_summary.dart`
- Test: `test/features/schoolbook/presentation/schoolbook_settings_screen_test.dart`

동작: 연결된 학교 이름 한 줄 · `학교 링크 바꾸기`(연결 화면을 이 화면 안에 띄워 새 코드로 `connect`) · `예약자 이름`(입력칸, 저장 시 `setBooker`) · `연결 끊기`(`disconnect` — 확인 창 없음, 지우는 것은 앱의 저장값뿐이고 스쿨북 예약은 그대로라는 한 줄 안내를 아래에 둔다). 스위치는 없다(설정 규칙).

- [ ] **Step 1: 실패하는 테스트** — 연결 끊기 → 요약이 `학교를 연결해 주세요`, 탭이 연결 화면 · 예약자 고치기 → 다음 예약 시트에 새 이름 · 링크 바꾸기 성공 → 학교 이름 바뀜, `lastRoomId` 비워짐.
- [ ] **Step 2~4**: 실패 확인 · 구현 · 통과 확인
- [ ] **Step 5: 커밋** — `feat: 장소 예약 상세 설정`

---

### Task 10: 가드 · 문서 · 개인정보처리방침

**Files:**
- Create: `test/features/schoolbook/schoolbook_guard_test.dart`
- Modify: `docs/privacy_policy.md`, `CLAUDE.md`

- [ ] **Step 1: 가드 테스트**(소스 스캔, `test/helpers/source_scan.dart`의 `libDartFiles()` 활용)
  - **격리**: `guidance_isolation_test`와 같은 방식으로 calendar · today · notifications · google · trash · schedule · import · memo · guidance · `lib/core/app_intents` · `schedule_csv_exporter.dart` 소스에 `schoolbook`이 없다.
  - **부르는 API가 다섯뿐**: `schoolbook_api_client.dart`에 `.put(`·`.patch(`가 없고, 경로 문자열은 `accounts/login/`·`rooms/`·`/bookings/`뿐이다(`timetables`·`periods`·`notices`·`tools`·`register` 없음).
  - **비밀번호 미저장**: `schoolbook_providers.dart`·`schoolbook_settings.dart`에 `password`가 없다.
- [ ] **Step 2: 실행** — `flutter test test/features/schoolbook/schoolbook_guard_test.dart` PASS. 가드가 실제로 잡는지 한 번 회귀를 심어(`schoolbook_settings.dart`에 `password` 주석 한 줄) FAIL을 보고 되돌린다.
- [ ] **Step 3: 개인정보처리방침** — §1 외부 서비스 목록에 스쿨북 · §2 표에 `스쿨북 연결 설정`(학교 코드 · 학교 이름 · 마지막 교실 · 예약자 이름, 기기 내 `shared_preferences`) · §5에 새 절 `§5-5 장소 예약(스쿨북)`(사용자가 켜고 학교를 연결했을 때만, 학교 코드 · 예약자 이름 · 비밀번호를 스쿨북 서버로 보냄, 운영 주체는 스쿨북 운영자, 비밀번호는 기기에 남기지 않음) · §6의 `이 셋이 … 통신 전부입니다` 문장을 넷으로 고침 · §7 · §9 개정 이력(2026-10-17).
- [ ] **Step 4: CLAUDE.md** — 핵심 기능 목록에 16번 `장소 예약(선택 탭)` 한 단락, `### 장소 예약 (선택 탭)` 절(결정 요약 · 비밀번호 미저장 · 재시도 없음 · 테스트 학교 코드는 리포 밖 · 스펙 경로). 테스트 수는 실측값으로 갱신.
- [ ] **Step 5: 전체 검증** — `flutter analyze` 0 issues · `flutter test` 전부 PASS(직전 실패가 알려진 날짜 의존 1건은 main에서도 실패하는지 대조해 보고에 적는다)
- [ ] **Step 6: 커밋** — `docs: 장소 예약 가드 · 처리방침 · CLAUDE.md`

---

### Task 11: 시뮬레이터 · 에뮬레이터 실측

**Files:** 없음(필요하면 `integration_test/`에 시나리오 하나 — 테스트 학교 코드는 `--dart-define`으로만 넣는다)

- [ ] **Step 1: iOS 시뮬레이터** — `flutter run` → 기능 관리에서 `장소 예약` 켜기 → 테스트 학교 링크 연결 → 체육관 D 조회 → 6교시 예약(`체육전담`/`1234`) → 목록에 보임 → 칩 탭 → 취소 → 사라짐. 틀린 비밀번호 · 이미 찬 교시도 한 번씩. `driving-ios-simulator` 스킬로 스냅샷.
- [ ] **Step 2: Android 에뮬레이터** — 같은 흐름. 3버튼 내비게이션에서 시트 버튼이 가려지지 않는지.
- [ ] **Step 3: 스쿨북 웹으로 대조** — 같은 날 웹 화면(https://schoolbook.zzolab.com/<테스트 학교>)에 앱으로 잡은 예약이 같은 교시에 보이고, 취소하면 사라진다.
- [ ] **Step 4: 정리** — 테스트로 만든 예약을 지운다. 보고에 실측 결과(기기 · OS · 확인한 것 · 못 한 것)를 적는다. 실기기(TestFlight · Play internal) 확인은 사용자 몫으로 남긴다.
