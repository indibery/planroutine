# 버스 도착 카드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 오늘 탭 최상단에 출퇴근 버스 실시간 도착시간 카드를 얹는다 — TAGO 공공데이터를 앱이 직접 호출하고, 기본 OFF 옵트인이라 켜지 않은 사용자의 화면은 바뀌지 않는다.

**Architecture:** 순수 함수 3개(`tagoResponseParser` · `resolveBusDisplay` · `buildBusCardView`)가 파싱·시간대 판정·표시 계산을 전부 담당하고, 위젯은 그 결과를 그리기만 한다. 저장은 `shared_preferences` 하나(DB 변경 0), 네트워크는 `bus_api_client` 한 곳. 이 앱의 `buildTodayView`·`computeNotifications`와 같은 계층 구조다.

**Tech Stack:** Flutter 3.x / Riverpod `AsyncNotifierProvider` / `shared_preferences` / `http` (모두 기존 의존성 — **pubspec 변경 없음**)

**설계 스펙:** `docs/superpowers/specs/2026-07-28-bus-arrival-card-design.md` (720줄). 판단 근거는 전부 거기 있다. 이 계획은 그 스펙을 코드로 옮기는 순서다.

## Global Constraints

- **새 의존성 0개.** `pubspec.yaml`을 건드리지 않는다. `http`·`shared_preferences`는 이미 있다.
- **DB 변경 0개.** sqflite 스키마·마이그레이션을 건드리지 않는다. 저장은 `shared_preferences`뿐.
- **기존 테스트 480개 무손상.** `buildTodayView`를 수정하지 않는다 — 버스는 형제 위젯이다.
- **모델은 plain class + 수동 `toJson`/`fromJson`.** freezed는 이 리포에서 **DB 저장 모델 3개**(`Schedule`·`CalendarEvent`·`ImportedSchedule`) 전용이다. 설정·계산결과는 `StampSettings`·`NotificationSettings`·`TodayView`처럼 plain이다.
- **문자열 하드코딩 금지.** 모든 UI 문구는 `lib/core/constants/strings/bus_strings.dart`의 `BusStrings`. 색은 `AppColors`, 크기는 `AppSizes`.
- **`!` 강제 언래핑 금지.**
- **한글 UI, 한글 주석.**
- **TAGO base URL은 `https://apis.data.go.kr`** (실측 확인: TLSv1.3, GlobalSign). ATS 예외를 `Info.plist`에 넣지 않는다.
- **인증키는 `String.fromEnvironment('TAGO_KEY')`.** 소스에 박지 않는다. 로컬 보관은 `~/.planroutine/tago.env`(리포 밖, 이미 생성됨).
- **파일명 snake_case / 클래스명 PascalCase.**
- **위젯 테스트에서 실제 I/O는 `tester.runAsync()` 안에서.** 네트워크는 `MockClient` 주입으로 대체하고 실제 호출을 하지 않는다.
- 각 Task 끝에 `flutter analyze`가 깨끗해야 한다.

## File Structure

**신규 — `lib/features/bus/`**

| 파일 | 책임 |
|---|---|
| `domain/bus_arrival.dart` | 도착 1건 (`routeId`·`routeNo`·`arrMin`·`prevCnt`·`lowFloor`) |
| `domain/bus_stop.dart` | 정류장 1개 (`nodeId`·`nodeNm`·`nodeNo`·`cityCode`·`routeIds`) |
| `domain/commute_direction.dart` | `toWork`/`toHome` enum + 라벨 |
| `domain/bus_card_style.dart` | `text`/`axis` enum — 모양 규칙을 enum이 든다 |
| `domain/time_range.dart` | `TimeRange`(분 단위 시작·종료) + 포함 판정 + 검증 |
| `domain/bus_settings.dart` | 저장되는 전부 — 2슬롯·모양·시간대 2개·override·enabled |
| `domain/bus_display.dart` | 순수 함수 `resolveBusDisplay` — 시간대·override → 방향·펼침 |
| `domain/bus_card_view.dart` | 순수 함수 `buildBusCardView` — 경과 보정·임박·노선 필터·상한 |
| `data/tago_response_parser.dart` | 순수 함수 — TAGO JSON → 모델. `items` 3형태·`routeNo` 타입 혼재·노선 축약 |
| `data/bus_api_client.dart` | HTTP + 키 주입 + 메모리 캐시 + 5상태 |
| `presentation/providers/bus_providers.dart` | `busSettingsProvider`·`busArrivalProvider`·폴링 |
| `presentation/widgets/bus_arrival_card.dart` | 카드 껍데기 + 제목줄(접기) + 방향 토글 |
| `presentation/widgets/bus_body_text.dart` | `간단히` 본문 |
| `presentation/widgets/bus_body_axis.dart` | `시간 축` 본문 |
| `presentation/widgets/bus_empty_state.dart` | 실패 계약 문구 |
| `presentation/screens/bus_stop_search_screen.dart` | 도시 선택 → 이름 검색 → 확인 시트 |

**신규 — 그 밖**

| 파일 | 책임 |
|---|---|
| `lib/core/constants/strings/bus_strings.dart` | 버스 문구 전부 |
| `lib/features/settings/presentation/widgets/bus_settings_tiles.dart` | 설정 섹션 본문 |

**수정**

| 파일 | 무엇 |
|---|---|
| `lib/core/constants/app_colors.dart` | `busSignal*` 4개 × 2 팔레트 **추가**(기존 값 불변) |
| `lib/core/constants/app_strings.dart` | `bus_strings.dart` barrel export |
| `lib/core/router/app_router.dart` | `AppRoutes.busStops = '/bus/stops'` + `GoRoute` |
| `lib/features/settings/presentation/screens/settings_screen.dart` | `완료 도장` 다음에 섹션 1개 |
| `lib/features/today/presentation/widgets/today_body.dart` | 최상단에 카드 조건부 삽입 |
| `ios/fastlane/Fastfile` | `--dart-define=TAGO_KEY` + 키 없으면 레인 실패 |
| `docs/privacy_policy.md` | TAGO 전송 문단 |
| `docs/release_checklist.md` | 호출량 점검 한 줄 |

**Task 의존 순서**

```
1 문구·색 토큰
2 도메인 값 객체 (BusArrival·BusStop·CommuteDirection·BusCardStyle)
3 TimeRange
4 BusSettings (2·3 소비)
5 tagoResponseParser (2 소비)
6 resolveBusDisplay (3·4 소비)
7 buildBusCardView (2·5 소비)
8 busApiClient (2·5 소비)
9 busSettingsProvider (4 소비)
10 본문 위젯 2종 (1·7 소비)
11 BusArrivalCard (10 소비)
12 설정 섹션 (9 소비)
13 정류장 검색 화면 + 확인 시트 (8·9 소비)
14 오늘 탭 배선 + 폴링 + 요청 0 가드 (6·8·9·11 소비)
15 fastlane 키 주입 + 문서
```

---

### Task 1: 문구와 색 토큰

**Files:**
- Create: `lib/core/constants/strings/bus_strings.dart`
- Modify: `lib/core/constants/app_strings.dart` (barrel export 추가)
- Modify: `lib/core/constants/app_colors.dart` (`_Palette` 필드 4개 + `_dark`/`_light` 값 + getter 4개)
- Test: `test/features/bus/bus_tokens_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `BusStrings`(아래 상수 전부), `AppColors.busSignalNear` / `busSignalSoon` / `busSignalFar` / `busSignalOff`

⚠️ `core/constants/`는 전역 영향 구역이다. **기존 값을 바꾸지 않고 추가만** 한다.

- [ ] **Step 1: 가드 테스트를 쓴다**

`test/features/bus/bus_tokens_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';

void main() {
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  group('busSignal 토큰 — 두 팔레트에 모두 있고 서로 구별된다', () {
    for (final brightness in Brightness.values) {
      test('$brightness 에서 4색이 모두 다르다', () {
        AppColors.applyBrightness(brightness);
        final colors = {
          AppColors.busSignalNear,
          AppColors.busSignalSoon,
          AppColors.busSignalFar,
          AppColors.busSignalOff,
        };
        expect(colors.length, 4, reason: '같은 색이 섞이면 축 위 점이 구별되지 않는다');
      });
    }

    test('라이트의 soon은 라이트 gold와 다른 값이다', () {
      AppColors.applyBrightness(Brightness.light);
      expect(AppColors.busSignalSoon, isNot(AppColors.gold));
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_tokens_test.dart`
Expected: 컴파일 실패 — `busSignalNear` 등이 `AppColors`에 없다.

- [ ] **Step 3: `_Palette`에 필드 4개를 추가한다**

`lib/core/constants/app_colors.dart` — `_Palette` 클래스의 생성자와 필드에 추가한다. 기존 필드 뒤에 붙인다.

생성자 파라미터(기존 `required this.categoryCurriculum,` 다음 줄):

```dart
    required this.busSignalNear,
    required this.busSignalSoon,
    required this.busSignalFar,
    required this.busSignalOff,
```

필드 선언(기존 `final Color categoryCurriculum;` 다음 줄):

```dart
  /// 버스 도착 신호색 — `시간 축` 카드 모양에서만 쓰인다.
  ///
  /// 기본 모양(`간단히`)은 이 토큰을 하나도 참조하지 않는다. 이름에 `bus`를 박은
  /// 이유가 있다 — 이 색들은 축 위 위치가 문맥을 줄 때만 유효하고, 다른 곳에서
  /// 강조색으로 갖다 쓰면 골드·붉은색·파랑이 이미 포화된 팔레트가 무너진다.
  final Color busSignalNear;
  final Color busSignalSoon;
  final Color busSignalFar;

  /// 시간 축의 레일 색.
  final Color busSignalOff;
```

- [ ] **Step 4: 두 팔레트에 값을 넣는다**

`_dark`의 `categoryCurriculum: ...` 다음 줄:

```dart
  busSignalNear: Color(0xFFEF5F52),
  busSignalSoon: Color(0xFFF2B23C),
  busSignalFar: Color(0xFF5FC98A),
  busSignalOff: Color(0x33F0EAD9),
```

`_light`의 `categoryCurriculum: ...` 다음 줄:

```dart
  // 라이트 노랑은 흰 배경 대비가 없어 딥 앰버로 잡는다. 라이트 gold(#9A7415)와
  // 색상이 인접하지만 축 위 위치가 문맥을 주므로 수용한다(실기기 확인 완료).
  busSignalNear: Color(0xFFCF3A2A),
  busSignalSoon: Color(0xFFC98A0E),
  busSignalFar: Color(0xFF1E9E63),
  busSignalOff: Color(0xFFD4DBE6),
```

- [ ] **Step 5: getter 4개를 추가한다**

`AppColors` 클래스의 `static Color get categoryCurriculum => ...` 다음 줄:

```dart
  static Color get busSignalNear => _current.busSignalNear;
  static Color get busSignalSoon => _current.busSignalSoon;
  static Color get busSignalFar => _current.busSignalFar;
  static Color get busSignalOff => _current.busSignalOff;
```

- [ ] **Step 6: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_tokens_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: `BusStrings`를 만든다**

`lib/core/constants/strings/bus_strings.dart`:

```dart
/// 버스 도착 카드 문자열.
class BusStrings {
  BusStrings._();

  // ── 설정 섹션 ──────────────────────────────────────────────
  static const section = '버스 도착';
  static const sectionDescription = '오늘 탭 맨 위에 출퇴근 버스 도착시간을 보여줍니다';
  static const showTitle = '표시';
  static const showSubtitleOn = '지정한 시간대에만 펼쳐집니다';
  static const showSubtitleOff = '꺼져 있어 오늘 탭이 지금과 같습니다';
  static const slotDeparture = '출발지';
  static const slotDepartureHint = '집 근처에서 타는 정류장';
  static const slotArrival = '도착지';
  static const slotArrivalHint = '학교 근처에서 타는 정류장';
  static const slotEmpty = '정류장 선택';
  static const cardStyle = '카드 모양';
  static const cardStyleHint = '도착시간을 어떻게 보여줄지';
  static const rangeToWork = '출근 시간대';
  static const rangeToHome = '퇴근 시간대';
  static const rangeHintToWork = '이 시간에만 출근 버스가 펼쳐집니다';
  static const rangeHintToHome = '이 시간에만 퇴근 버스가 펼쳐집니다';
  static const rangeOverlap = '출근과 퇴근 시간대가 겹칩니다';
  static const rangeInverted = '시작이 종료보다 빠르게 두세요';

  // ── 카드 ───────────────────────────────────────────────────
  static const routeToWork = '🏠→🏫 출근';
  static const routeToHome = '🏫→🏠 퇴근';
  static const seeToWork = '출근 보기';
  static const seeToHome = '퇴근 보기';
  static const collapse = '접기';
  static const expand = '펼치기';

  /// "07:32 기준" — 캐시 신선도를 감추지 않고 고백한다.
  static String basedOn(String hhmm) => '$hhmm 기준';

  /// 갱신에 실패해 캐시된 값을 보여줄 때.
  static String basedOnStale(String hhmm) => '$hhmm 기준 · 갱신 실패';

  /// "3개 더" — 필터를 걸지 않아 3개로 자른 뒤 남은 수.
  static String moreCount(int n) => '$n개 더';

  static String minutes(int n) => '$n분';
  static const arrivingNow = '곧 도착';
  static const lowFloor = '저상';

  // ── 실패 계약 5상태 (§3) ───────────────────────────────────
  static const emptyClosed = '오늘 운행이 끝났어요';
  static const emptyDown = '지금 정보를 못 받았어요';
  static const emptyDownAction = '다시 시도';
  static const emptyKey = '버스 정보를 불러올 수 없어요';
  static const emptyKeyHint = '잠시 뒤 다시 열어주세요';
  static const emptyNoStop = '정류장을 등록하면 도착시간이 보여요';
  static const emptyNoStopAction = '정류장 등록';

  // ── 검색 화면 ──────────────────────────────────────────────
  static const searchTitle = '정류장 찾기';
  static const cityLabel = '도시';
  static const citySearchHint = '시·군 이름 (예: 수원)';
  static const stopSearchHint = '정류장 이름 (예: 시청)';
  static const searchEmpty = '검색 결과가 없어요';
  static const searchPrompt = '정류장 이름을 입력해 주세요';

  // ── 확인 시트 (§4) ─────────────────────────────────────────
  static const confirmTitle = '이 정류장이 맞나요?';
  static const confirmRoutesTitle = '타는 버스만 남겨주세요';
  static const confirmNoRoutes = '지금 이 정류장에 오는 버스가 없어요';
  static const confirmReject = '아니에요';
  static const confirmAccept = '맞아요';
  static const confirmNeedRoute = '버스를 하나 이상 남겨주세요';
}
```

- [ ] **Step 8: barrel export에 추가한다**

`lib/core/constants/app_strings.dart`의 export 목록에 알파벳 순서에 맞춰 한 줄 추가한다:

```dart
export 'strings/bus_strings.dart';
```

- [ ] **Step 9: analyze가 깨끗한지 본다**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add lib/core/constants/strings/bus_strings.dart \
        lib/core/constants/app_strings.dart \
        lib/core/constants/app_colors.dart \
        test/features/bus/bus_tokens_test.dart
git commit -m "feat(bus): 버스 문구와 시간 축 신호색 토큰을 추가한다

busSignal* 4색을 두 팔레트에 추가한다. 기존 값은 건드리지 않는다.
이 색은 시간 축 모양에서만 쓰이고 기본 모양(간단히)은 하나도
참조하지 않는다 — 가드 테스트가 라이트 soon과 gold가 다른 값임을
지킨다(두 색상이 인접해 실기기 확인이 필요했던 지점)."
```

---

### Task 2: 도메인 값 객체 4개

**Files:**
- Create: `lib/features/bus/domain/bus_arrival.dart`
- Create: `lib/features/bus/domain/bus_stop.dart`
- Create: `lib/features/bus/domain/commute_direction.dart`
- Create: `lib/features/bus/domain/bus_card_style.dart`
- Test: `test/features/bus/domain/bus_stop_test.dart`

**Interfaces:**
- Consumes: `BusStrings` (Task 1)
- Produces:
  - `class BusArrival { final String routeId; final String routeNo; final int arrMin; final int prevCnt; final bool lowFloor; const BusArrival({required ...}); BusArrival copyWith({int? arrMin}); }`
  - `class BusStop { final String nodeId, nodeNm; final int nodeNo, cityCode; final Set<String> routeIds; const BusStop({required ...}); Map<String,dynamic> toJson(); factory BusStop.fromJson(Map<String,dynamic>); }`
  - `enum CommuteDirection { toWork, toHome }` with `String get label`, `String get otherLabel`, `CommuteDirection get flipped`
  - `enum BusCardStyle { text, axis }` with `String get label`, `bool get usesSignalColors`

- [ ] **Step 1: `BusStop` 직렬화 테스트를 쓴다**

`test/features/bus/domain/bus_stop_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';

void main() {
  group('BusStop 직렬화', () {
    test('routeIds가 비어 있으면 왕복해도 비어 있다 — 필터 없음을 뜻한다', () {
      const stop = BusStop(
        nodeId: 'GGB201000156',
        nodeNm: '수원시청.수원일자리센터',
        nodeNo: 2251,
        cityCode: 31010,
      );
      final back = BusStop.fromJson(stop.toJson());
      expect(back.routeIds, isEmpty);
      expect(back.nodeId, 'GGB201000156');
      expect(back.nodeNo, 2251);
      expect(back.cityCode, 31010);
    });

    test('골라둔 routeIds는 그대로 살아 돌아온다', () {
      const stop = BusStop(
        nodeId: 'GGB201000156',
        nodeNm: '수원시청',
        nodeNo: 2251,
        cityCode: 31010,
        routeIds: {'GGB200000025', 'GGB200000029'},
      );
      final back = BusStop.fromJson(stop.toJson());
      expect(back.routeIds, {'GGB200000025', 'GGB200000029'});
    });

    test('routeIds 키가 없는 옛 값도 빈 집합으로 읽힌다', () {
      final back = BusStop.fromJson({
        'nodeId': 'GGB201000156',
        'nodeNm': '수원시청',
        'nodeNo': 2251,
        'cityCode': 31010,
      });
      expect(back.routeIds, isEmpty);
    });
  });

  group('CommuteDirection', () {
    test('flipped는 서로를 가리킨다', () {
      expect(CommuteDirection.toWork.flipped, CommuteDirection.toHome);
      expect(CommuteDirection.toHome.flipped, CommuteDirection.toWork);
    });

    test('otherLabel은 반대 방향을 보라고 말한다', () {
      expect(CommuteDirection.toWork.otherLabel, '퇴근 보기');
      expect(CommuteDirection.toHome.otherLabel, '출근 보기');
    });
  });

  group('BusCardStyle', () {
    test('기본 모양은 신호색을 쓰지 않는다', () {
      expect(BusCardStyle.text.usesSignalColors, isFalse);
      expect(BusCardStyle.axis.usesSignalColors, isTrue);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/domain/bus_stop_test.dart`
Expected: 컴파일 실패 — 파일이 없다.

- [ ] **Step 3: `BusArrival`을 만든다**

`lib/features/bus/domain/bus_arrival.dart`:

```dart
/// 도착 예정 버스 1건 — TAGO 응답 1항목을 정규화한 결과.
///
/// DB에 저장되지 않는 계산 결과이므로 freezed 없이 plain class로 둔다
/// (`TodayView`·`PendingNotification`과 같은 계열).
class BusArrival {
  const BusArrival({
    required this.routeId,
    required this.routeNo,
    required this.arrMin,
    this.prevCnt = 0,
    this.lowFloor = false,
  });

  /// 노선 고유 ID. 노선 축약과 사용자 노선 필터의 기준이다.
  final String routeId;

  /// 화면에 보이는 노선번호.
  ///
  /// TAGO는 이 값을 **int와 String으로 섞어** 준다(`92` / `"92-1"`). 하이픈이 있는
  /// 노선만 문자열이다. 파서가 `.toString()`으로 받아 여기서는 항상 String이다.
  final String routeNo;

  /// 도착까지 남은 분. 0이면 "곧 도착".
  final int arrMin;

  /// 남은 정류장 수.
  final int prevCnt;

  /// 저상버스인지 (`vehicletp == '저상버스'`).
  final bool lowFloor;

  /// 경과 보정에서 [arrMin]만 갈아끼운다.
  BusArrival copyWith({int? arrMin}) {
    return BusArrival(
      routeId: routeId,
      routeNo: routeNo,
      arrMin: arrMin ?? this.arrMin,
      prevCnt: prevCnt,
      lowFloor: lowFloor,
    );
  }

  @override
  String toString() => 'BusArrival($routeNo, ${arrMin}분)';
}
```

- [ ] **Step 4: `BusStop`을 만든다**

`lib/features/bus/domain/bus_stop.dart`:

```dart
/// 등록된 정류장 1개 — SharedPreferences에 직렬화된다.
class BusStop {
  const BusStop({
    required this.nodeId,
    required this.nodeNm,
    required this.nodeNo,
    required this.cityCode,
    this.routeIds = const {},
  });

  /// TAGO 정류장 ID. **방향별로 별개다** — 길 건너 마주보는 정류장은 이름이
  /// 같고 좌표도 60m 차이인데 이 값이 다르다(실측: GGB201000156 / GGB202000003).
  final String nodeId;

  final String nodeNm;

  /// 정류소번호. `2251` 같은 4자리 정수다(하이픈 형식이 아니다).
  final int nodeNo;

  /// 도시코드. **시·도가 아니라 시·군 단위**다(경기도는 31010~31380).
  final int cityCode;

  /// 사용자가 고른 노선.
  ///
  /// **비어 있으면 "필터 없음"**이고 "고른 게 없음"이 아니다. 전부 체크한 상태를
  /// 열거해 저장하면 "전부"가 "이 다섯 개"로 굳어, 노선이 신설됐을 때 사용자는
  /// 전부를 골랐는데도 새 버스를 못 본다. 빈 집합은 시간이 지나도 뜻이 변하지 않는다.
  final Set<String> routeIds;

  BusStop copyWith({Set<String>? routeIds}) {
    return BusStop(
      nodeId: nodeId,
      nodeNm: nodeNm,
      nodeNo: nodeNo,
      cityCode: cityCode,
      routeIds: routeIds ?? this.routeIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'nodeNm': nodeNm,
        'nodeNo': nodeNo,
        'cityCode': cityCode,
        'routeIds': routeIds.toList(),
      };

  factory BusStop.fromJson(Map<String, dynamic> json) {
    final raw = json['routeIds'];
    return BusStop(
      nodeId: json['nodeId'] as String? ?? '',
      nodeNm: json['nodeNm'] as String? ?? '',
      nodeNo: json['nodeNo'] as int? ?? 0,
      cityCode: json['cityCode'] as int? ?? 0,
      routeIds: raw is List ? raw.map((e) => e.toString()).toSet() : const {},
    );
  }
}
```

- [ ] **Step 5: `CommuteDirection`을 만든다**

`lib/features/bus/domain/commute_direction.dart`:

```dart
import '../../../core/constants/app_strings.dart';

/// 카드가 지금 보여주는 방향.
enum CommuteDirection {
  /// 집 → 학교. 출발지 슬롯을 본다.
  toWork(BusStrings.routeToWork, BusStrings.seeToHome),

  /// 학교 → 집. 도착지 슬롯을 본다.
  toHome(BusStrings.routeToHome, BusStrings.seeToWork);

  const CommuteDirection(this.label, this.otherLabel);

  /// 카드 제목줄에 쓰는 이름.
  final String label;

  /// 반대 방향으로 넘어가는 링크 문구.
  final String otherLabel;

  CommuteDirection get flipped =>
      this == CommuteDirection.toWork ? CommuteDirection.toHome : CommuteDirection.toWork;
}
```

- [ ] **Step 6: `BusCardStyle`을 만든다**

`lib/features/bus/domain/bus_card_style.dart`:

```dart
/// 카드 본문 모양. 설정 탭에서 고른다.
///
/// `SealStyle`과 같은 구조다 — 모양 규칙을 enum이 들고 위젯은 enum만 보고 그린다.
enum BusCardStyle {
  /// 간단히 — 한 줄에 노선을 나열하고 임박을 굵기·크기로만 낸다. **기본값.**
  ///
  /// 새 색 토큰이 0개고, 가장 낮고, 노선 수·배차 간격 어떤 조건에서도 깨지지 않는다.
  text('간단히'),

  /// 시간 축 — 0~15분 축에 점으로. 간격이 공간으로 보인다.
  ///
  /// 두 버스가 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에
  /// 몰리므로 조건이 맞는 사람이 고르는 선택지다.
  axis('시간 축', usesSignalColors: true);

  const BusCardStyle(this.label, {this.usesSignalColors = false});

  /// 설정 화면 세그먼트에 표시할 이름.
  final String label;

  /// `AppColors.busSignal*`을 참조하는 모양인지.
  ///
  /// 기본값(`text`)이 false라 켜지 않은 사용자와 기본 모양 사용자에게 팔레트는
  /// 지금과 완전히 같다. 가드 테스트가 이 사실을 지킨다.
  final bool usesSignalColors;
}
```

- [ ] **Step 6: 테스트가 통과한다**

Run: `flutter test test/features/bus/domain/bus_stop_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 8: 커밋**

```bash
git add lib/features/bus/domain/ test/features/bus/domain/bus_stop_test.dart
git commit -m "feat(bus): 도메인 값 객체 4개를 만든다

BusArrival·BusStop·CommuteDirection·BusCardStyle. DB에 저장되지 않으므로
freezed 대신 plain class + 수동 toJson으로 둔다(StampSettings 계열).

BusStop.routeIds가 비어 있으면 '필터 없음'이고 '고른 게 없음'이 아니다.
전부 체크한 상태를 열거해 저장하면 노선이 신설됐을 때 전부를 골랐는데도
새 버스를 못 보게 된다 — 테스트가 왕복 후에도 빈 집합임을 지킨다."
```

---

### Task 3: `TimeRange` — 시간대 한 구간

**Files:**
- Create: `lib/features/bus/domain/time_range.dart`
- Test: `test/features/bus/domain/time_range_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `class TimeRange { final int startMinutes, endMinutes; const TimeRange(...); const TimeRange.hm(int sh, int sm, int eh, int em); bool contains(DateTime); bool get isValid; bool overlaps(TimeRange); String get label; Map<String,dynamic> toJson(); factory TimeRange.fromJson(...); }`

자정을 넘는 구간은 지원하지 않는다. 시작 < 종료여야 유효하다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/domain/time_range_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 7, 28, hour, minute);

void main() {
  const toWork = TimeRange.hm(7, 0, 8, 30);

  group('contains — 경계', () {
    test('시작 정각은 포함, 1분 전은 제외', () {
      expect(toWork.contains(_at(7, 0)), isTrue);
      expect(toWork.contains(_at(6, 59)), isFalse);
    });

    test('종료 정각은 포함, 1분 후는 제외', () {
      expect(toWork.contains(_at(8, 30)), isTrue);
      expect(toWork.contains(_at(8, 31)), isFalse);
    });
  });

  group('isValid', () {
    test('시작이 종료보다 빠르면 유효하다', () {
      expect(const TimeRange.hm(7, 0, 8, 30).isValid, isTrue);
    });

    test('시작과 종료가 같거나 뒤집히면 무효다 — 자정 넘김은 지원하지 않는다', () {
      expect(const TimeRange.hm(8, 30, 8, 30).isValid, isFalse);
      expect(const TimeRange.hm(22, 0, 2, 0).isValid, isFalse);
    });
  });

  group('overlaps', () {
    test('기본값 두 시간대는 겹치지 않는다', () {
      expect(toWork.overlaps(const TimeRange.hm(16, 0, 18, 0)), isFalse);
    });

    test('한쪽 끝이 맞물리면 겹친 것으로 본다', () {
      expect(toWork.overlaps(const TimeRange.hm(8, 30, 10, 0)), isTrue);
    });

    test('완전히 품으면 겹친다', () {
      expect(toWork.overlaps(const TimeRange.hm(6, 0, 20, 0)), isTrue);
    });
  });

  test('label은 설정 타일에 쓰는 07:00 – 08:30 형식이다', () {
    expect(toWork.label, '07:00 – 08:30');
  });

  test('직렬화 왕복', () {
    final back = TimeRange.fromJson(toWork.toJson());
    expect(back.startMinutes, toWork.startMinutes);
    expect(back.endMinutes, toWork.endMinutes);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/domain/time_range_test.dart`
Expected: 컴파일 실패 — `time_range.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/domain/time_range.dart`:

```dart
/// 하루 안의 한 구간 — 자정 기준 분으로 센다.
///
/// 자정을 넘는 구간은 지원하지 않는다(야간 근무 미대응). 그래야 [contains]가
/// 단순 비교로 끝나고 [overlaps] 판정에 예외 분기가 생기지 않는다.
class TimeRange {
  const TimeRange({required this.startMinutes, required this.endMinutes});

  /// 시·분으로 쓰는 편의 생성자.
  const TimeRange.hm(int startHour, int startMinute, int endHour, int endMinute)
      : startMinutes = startHour * 60 + startMinute,
        endMinutes = endHour * 60 + endMinute;

  /// 자정부터 몇 분째에 시작하는지.
  final int startMinutes;

  /// 자정부터 몇 분째에 끝나는지. **경계 포함**이다.
  final int endMinutes;

  /// [now]의 시·분이 이 구간에 드는지. 날짜는 보지 않는다.
  bool contains(DateTime now) {
    final m = now.hour * 60 + now.minute;
    return m >= startMinutes && m <= endMinutes;
  }

  /// 시작이 종료보다 빠른지.
  bool get isValid => startMinutes < endMinutes;

  /// 두 구간이 한 지점이라도 공유하는지.
  ///
  /// 겹치면 방향 판정이 모호해지므로 저장을 거부하는 근거가 된다.
  bool overlaps(TimeRange other) {
    return startMinutes <= other.endMinutes && other.startMinutes <= endMinutes;
  }

  /// `07:00 – 08:30` — 설정 타일의 trailing 문구.
  String get label => '${_hhmm(startMinutes)} – ${_hhmm(endMinutes)}';

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startMinutes: json['startMinutes'] as int? ?? 0,
      endMinutes: json['endMinutes'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/domain/time_range_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/domain/time_range.dart test/features/bus/domain/time_range_test.dart
git commit -m "feat(bus): 시간대 한 구간을 TimeRange로 모델링한다

자정 기준 분으로 세고 자정 넘김은 지원하지 않는다 — 그래야 contains가
단순 비교로 끝나고 overlaps에 예외 분기가 안 생긴다. 경계는 양끝 포함이고
overlaps는 한 점만 맞물려도 겹친 것으로 본다(겹치면 방향 판정이 모호해져
저장을 거부해야 한다)."
```

---

### Task 4: `BusSettings` — 저장되는 전부

**Files:**
- Create: `lib/features/bus/domain/bus_settings.dart`
- Test: `test/features/bus/domain/bus_settings_test.dart`

**Interfaces:**
- Consumes: `BusStop`·`BusCardStyle` (Task 2), `TimeRange` (Task 3)
- Produces:
  - `class BusSettings { final bool enabled; final BusStop? departure, arrival; final BusCardStyle style; final TimeRange toWorkRange, toHomeRange; final DateTime? overrideAt; final bool overrideExpanded; static const defaults; BusSettings copyWith({...}); BusStop? stopFor(CommuteDirection); bool get rangesValid; Map<String,dynamic> toJson(); factory BusSettings.fromJson(...); }`

기본값: `enabled: false`, `style: BusCardStyle.text`, `toWorkRange: 07:00–08:30`, `toHomeRange: 16:00–18:00`.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/domain/bus_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
  nodeNo: 2251,
  cityCode: 31010,
);

void main() {
  group('기본값 — 조용한 쪽이 기본이다', () {
    test('표시는 꺼져 있고 모양은 간단히다', () {
      expect(BusSettings.defaults.enabled, isFalse);
      expect(BusSettings.defaults.style, BusCardStyle.text);
    });

    test('시간대 기본값은 교사 일과 기준이고 겹치지 않는다', () {
      expect(BusSettings.defaults.toWorkRange.label, '07:00 – 08:30');
      expect(BusSettings.defaults.toHomeRange.label, '16:00 – 18:00');
      expect(BusSettings.defaults.rangesValid, isTrue);
    });
  });

  group('stopFor', () {
    test('방향에 맞는 슬롯을 준다', () {
      final s = BusSettings.defaults.copyWith(departure: _stop);
      expect(s.stopFor(CommuteDirection.toWork)?.nodeId, 'GGB201000156');
      expect(s.stopFor(CommuteDirection.toHome), isNull);
    });
  });

  group('rangesValid', () {
    test('겹치면 무효다', () {
      final s = BusSettings.defaults
          .copyWith(toHomeRange: const TimeRange.hm(8, 0, 18, 0));
      expect(s.rangesValid, isFalse);
    });

    test('뒤집히면 무효다', () {
      final s = BusSettings.defaults
          .copyWith(toWorkRange: const TimeRange.hm(9, 0, 7, 0));
      expect(s.rangesValid, isFalse);
    });
  });

  group('직렬화', () {
    test('전부 채운 값이 왕복한다', () {
      final s = BusSettings.defaults.copyWith(
        enabled: true,
        departure: _stop.copyWith(routeIds: {'A'}),
        arrival: _stop,
        style: BusCardStyle.axis,
        overrideAt: DateTime(2026, 7, 28, 8, 35),
        overrideExpanded: true,
      );
      final back = BusSettings.fromJson(s.toJson());
      expect(back.enabled, isTrue);
      expect(back.departure?.routeIds, {'A'});
      expect(back.style, BusCardStyle.axis);
      expect(back.overrideAt, DateTime(2026, 7, 28, 8, 35));
      expect(back.overrideExpanded, isTrue);
    });

    test('빈 맵이면 기본값으로 읽힌다', () {
      final back = BusSettings.fromJson(const {});
      expect(back.enabled, isFalse);
      expect(back.style, BusCardStyle.text);
      expect(back.departure, isNull);
      expect(back.toWorkRange.label, '07:00 – 08:30');
    });

    test('모르는 모양 이름이면 기본 모양으로 폴백한다', () {
      final back = BusSettings.fromJson(const {'style': 'hologram'});
      expect(back.style, BusCardStyle.text);
    });

    test('clearOverride는 두 값을 함께 지운다', () {
      final s = BusSettings.defaults.copyWith(
        overrideAt: DateTime(2026, 7, 28, 8, 35),
        overrideExpanded: true,
      );
      final cleared = s.clearOverride();
      expect(cleared.overrideAt, isNull);
      expect(cleared.overrideExpanded, isFalse);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/domain/bus_settings_test.dart`
Expected: 컴파일 실패 — `bus_settings.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/domain/bus_settings.dart`:

```dart
import 'bus_card_style.dart';
import 'bus_stop.dart';
import 'commute_direction.dart';
import 'time_range.dart';

/// 버스 도착 카드 설정 — SharedPreferences에 직렬화되는 전부.
///
/// DB 변경 없이 이 클래스 하나에 담는다. 기기를 바꾸면 사라진다 — 이 앱의
/// 일정·이벤트도 이미 로컬 전용이라 정류장만 클라우드에 두면 오히려 어긋난다.
class BusSettings {
  const BusSettings({
    this.enabled = false,
    this.departure,
    this.arrival,
    this.style = BusCardStyle.text,
    this.toWorkRange = const TimeRange.hm(7, 0, 8, 30),
    this.toHomeRange = const TimeRange.hm(16, 0, 18, 0),
    this.overrideAt,
    this.overrideExpanded = false,
  });

  /// 오늘 탭에 카드를 그리는지. **기본 꺼짐** — 켜지 않은 사용자의 화면은 안 바뀐다.
  final bool enabled;

  /// 출근 방향에서 볼 정류장(집 근처).
  final BusStop? departure;

  /// 퇴근 방향에서 볼 정류장(학교 근처).
  final BusStop? arrival;

  final BusCardStyle style;

  /// 이 구간에 들면 출근 방향이 펼쳐진다.
  final TimeRange toWorkRange;

  /// 이 구간에 들면 퇴근 방향이 펼쳐진다.
  final TimeRange toHomeRange;

  /// 사용자가 접기·펼치기를 누른 시각. null이면 시간대 판정을 그대로 쓴다.
  final DateTime? overrideAt;

  /// 그 누름이 펼치기였는지(true) 접기였는지(false).
  final bool overrideExpanded;

  static const defaults = BusSettings();

  /// 두 시간대가 각자 유효하고 서로 겹치지 않는지.
  bool get rangesValid =>
      toWorkRange.isValid && toHomeRange.isValid && !toWorkRange.overlaps(toHomeRange);

  BusStop? stopFor(CommuteDirection direction) =>
      direction == CommuteDirection.toWork ? departure : arrival;

  TimeRange rangeFor(CommuteDirection direction) =>
      direction == CommuteDirection.toWork ? toWorkRange : toHomeRange;

  BusSettings copyWith({
    bool? enabled,
    BusStop? departure,
    BusStop? arrival,
    BusCardStyle? style,
    TimeRange? toWorkRange,
    TimeRange? toHomeRange,
    DateTime? overrideAt,
    bool? overrideExpanded,
  }) {
    return BusSettings(
      enabled: enabled ?? this.enabled,
      departure: departure ?? this.departure,
      arrival: arrival ?? this.arrival,
      style: style ?? this.style,
      toWorkRange: toWorkRange ?? this.toWorkRange,
      toHomeRange: toHomeRange ?? this.toHomeRange,
      overrideAt: overrideAt ?? this.overrideAt,
      overrideExpanded: overrideExpanded ?? this.overrideExpanded,
    );
  }

  /// override 두 값을 함께 지운다.
  ///
  /// `copyWith(overrideAt: null)`은 null 병합 때문에 지워지지 않으므로 전용
  /// 메서드를 둔다 — 한쪽만 남으면 만료 판정이 흔들린다.
  BusSettings clearOverride() {
    return BusSettings(
      enabled: enabled,
      departure: departure,
      arrival: arrival,
      style: style,
      toWorkRange: toWorkRange,
      toHomeRange: toHomeRange,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'departure': departure?.toJson(),
        'arrival': arrival?.toJson(),
        'style': style.name,
        'toWorkRange': toWorkRange.toJson(),
        'toHomeRange': toHomeRange.toJson(),
        'overrideAt': overrideAt?.toIso8601String(),
        'overrideExpanded': overrideExpanded,
      };

  factory BusSettings.fromJson(Map<String, dynamic> json) {
    return BusSettings(
      enabled: json['enabled'] as bool? ?? false,
      departure: _stop(json['departure']),
      arrival: _stop(json['arrival']),
      style: _style(json['style'] as String?),
      toWorkRange: _range(json['toWorkRange'], const TimeRange.hm(7, 0, 8, 30)),
      toHomeRange: _range(json['toHomeRange'], const TimeRange.hm(16, 0, 18, 0)),
      overrideAt: DateTime.tryParse(json['overrideAt'] as String? ?? ''),
      overrideExpanded: json['overrideExpanded'] as bool? ?? false,
    );
  }

  static BusStop? _stop(Object? raw) =>
      raw is Map<String, dynamic> ? BusStop.fromJson(raw) : null;

  static TimeRange _range(Object? raw, TimeRange fallback) =>
      raw is Map<String, dynamic> ? TimeRange.fromJson(raw) : fallback;

  /// 모르는 이름(구버전·손상)이면 기본 모양으로 폴백한다.
  static BusCardStyle _style(String? raw) {
    return BusCardStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => BusCardStyle.text,
    );
  }
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/domain/bus_settings_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/bus/domain/bus_settings.dart test/features/bus/domain/bus_settings_test.dart
git commit -m "feat(bus): 저장되는 설정을 BusSettings 하나에 모은다

DB 변경 0으로 shared_preferences에 담는다. 기본값은 조용한 쪽이다 —
enabled false, 모양 간단히, 시간대 07:00-08:30 / 16:00-18:00.

clearOverride를 따로 둔 이유: copyWith(overrideAt: null)은 null 병합
때문에 지워지지 않는다. overrideAt과 overrideExpanded 중 한쪽만 남으면
만료 판정이 흔들리므로 둘을 함께 지우는 경로를 강제한다."
```

---

### Task 5: `tagoResponseParser` — 실측으로 확인된 함정 3개를 막는다

**Files:**
- Create: `lib/features/bus/data/tago_response_parser.dart`
- Test: `test/features/bus/data/tago_response_parser_test.dart`

**Interfaces:**
- Consumes: `BusArrival`·`BusStop` (Task 2)
- Produces:
  - `enum TagoOutcome { ok, empty, keyError, malformed }`
  - `class TagoResult<T> { final TagoOutcome outcome; final List<T> items; const TagoResult(...); bool get isOk; }`
  - `TagoResult<BusArrival> parseArrivals(Map<String, dynamic> json)`
  - `TagoResult<BusStop> parseStops(Map<String, dynamic> json, {required int cityCode})`
  - `TagoResult<CityCode> parseCities(Map<String, dynamic> json)`
  - `class CityCode { final int code; final String name; }`

**실측으로 확인된 것(2026-07-28) — 이 셋이 이 Task의 존재 이유다:**

1. `items`가 **세 형태**로 온다 — `Map`(단건) · `List`(복수) · `""`(없음). 빈 문자열은 Map도 List도 아니다.
2. `routeno`가 **int와 String으로 섞여** 온다 — `92`(int) / `"92-1"`(String).
3. **같은 노선이 여러 건** 온다 — 다음 차와 그다음 차. 실측 고유 5노선 / 항목 10개.

그리고 `resultCode '03'`(NODATA)는 **오지 않는다.** 데이터가 없어도 `"00"`이다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/data/tago_response_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/data/tago_response_parser.dart';

/// TAGO 응답 껍데기 — resultCode는 데이터가 없어도 "00"이다(실측).
Map<String, dynamic> _envelope(Object? items, {String code = '00'}) => {
      'response': {
        'header': {'resultCode': code, 'resultMsg': 'NORMAL SERVICE.'},
        'body': {'items': items, 'numOfRows': 30, 'pageNo': 1},
      },
    };

Map<String, dynamic> _arr(Object routeno, String routeid, int arrtime) => {
      'arrprevstationcnt': 7,
      'arrtime': arrtime,
      'nodeid': 'GGB201000156',
      'nodenm': '수원시청.수원일자리센터',
      'routeid': routeid,
      'routeno': routeno,
      'routetp': '일반버스',
      'vehicletp': '저상버스',
    };

void main() {
  group('items의 세 형태', () {
    test('List — 복수 응답', () {
      final r = parseArrivals(_envelope([_arr(92, 'A', 600), _arr('92-1', 'B', 120)]));
      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.length, 2);
    });

    test('Map — 단건 응답이 객체로 온다', () {
      final r = parseArrivals(_envelope(_arr(92, 'A', 600)));
      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.single.routeNo, '92');
    });

    test('빈 문자열 — 데이터 없음. resultCode는 여전히 00이다', () {
      final r = parseArrivals(_envelope(''));
      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });
  });

  group('routeno 타입 혼재 — as String 캐스트는 크래시한다', () {
    test('int와 String이 같은 응답에 섞여도 둘 다 문자열로 나온다', () {
      final r = parseArrivals(_envelope([
        _arr(92, 'A', 600),
        _arr('92-1', 'B', 120),
        _arr(61, 'C', 1860),
      ]));
      expect(r.items.map((e) => e.routeNo).toSet(), {'92', '92-1', '61'});
    });
  });

  group('노선 축약 — routeid별 arrtime 최소만 남긴다', () {
    test('같은 노선 2건이면 빠른 쪽만 남는다', () {
      final r = parseArrivals(_envelope([
        _arr(92, 'A', 1500),
        _arr(92, 'A', 600),
      ]));
      expect(r.items.length, 1);
      expect(r.items.single.arrMin, 10);
    });

    test('실측 형태 — 5노선 10항목이 5건으로 줄고 빠른 순으로 정렬된다', () {
      final r = parseArrivals(_envelope([
        _arr('82-1', 'R1', 480), _arr('82-1', 'R1', 2040),
        _arr(92, 'R2', 600), _arr(92, 'R2', 1500),
        _arr('92-1', 'R3', 600), _arr('92-1', 'R3', 720),
        _arr(81, 'R4', 780), _arr(81, 'R4', 2160),
        _arr(61, 'R5', 1860), _arr(61, 'R5', 2880),
      ]));
      expect(r.items.length, 5);
      expect(r.items.map((e) => e.routeNo).toList(),
          ['82-1', '92', '92-1', '81', '61']);
    });
  });

  group('arrMin 변환', () {
    test('초를 올림해 분으로 만든다', () {
      expect(parseArrivals(_envelope(_arr(1, 'A', 551))).items.single.arrMin, 10);
      expect(parseArrivals(_envelope(_arr(1, 'A', 61))).items.single.arrMin, 2);
    });

    test('0초는 0분(곧 도착)이다', () {
      expect(parseArrivals(_envelope(_arr(1, 'A', 0))).items.single.arrMin, 0);
    });
  });

  test('vehicletp가 저상버스면 lowFloor', () {
    final r = parseArrivals(_envelope(_arr(1, 'A', 600)));
    expect(r.items.single.lowFloor, isTrue);
  });

  group('오류 판정', () {
    test('resultCode가 00이 아니면 keyError', () {
      final r = parseArrivals(_envelope('', code: '30'));
      expect(r.outcome, TagoOutcome.keyError);
    });

    test('껍데기가 다르면 malformed', () {
      expect(parseArrivals(const {'oops': 1}).outcome, TagoOutcome.malformed);
    });
  });

  group('parseStops', () {
    test('정류장 필드를 읽고 cityCode를 채운다', () {
      final r = parseStops(
        _envelope({
          'gpslati': 37.2622667,
          'gpslong': 127.0283833,
          'nodeid': 'GGB201000156',
          'nodenm': '수원시청.수원일자리센터',
          'nodeno': 2251,
        }),
        cityCode: 31010,
      );
      expect(r.items.single.nodeNo, 2251);
      expect(r.items.single.cityCode, 31010);
      expect(r.items.single.routeIds, isEmpty);
    });
  });

  group('parseCities', () {
    test('citycode가 int로 온다', () {
      final r = parseCities(_envelope([
        {'citycode': 31010, 'cityname': '수원시'},
        {'citycode': 31020, 'cityname': '성남시'},
      ]));
      expect(r.items.first.code, 31010);
      expect(r.items.first.name, '수원시');
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/data/tago_response_parser_test.dart`
Expected: 컴파일 실패 — `tago_response_parser.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/data/tago_response_parser.dart`:

```dart
import '../domain/bus_arrival.dart';
import '../domain/bus_stop.dart';

/// TAGO 응답을 읽은 결과.
enum TagoOutcome {
  /// 정상 — 항목이 하나 이상 있다.
  ok,

  /// 데이터 없음. 막차 후이거나 도시코드를 잘못 골랐다.
  ///
  /// TAGO는 이 경우에도 `resultCode "00"`을 주고 `items`를 **빈 문자열**로 준다
  /// (실측 확인). `resultCode '03'`(NODATA)은 관측되지 않았다.
  empty,

  /// 인증키 문제 등 — `resultCode`가 `"00"`이 아니다.
  keyError,

  /// 응답 껍데기가 예상과 다르다.
  malformed,
}

/// 파싱 결과 — 결과 종류와 항목을 함께 든다.
class TagoResult<T> {
  const TagoResult(this.outcome, [this.items = const []]);

  final TagoOutcome outcome;
  final List<T> items;

  bool get isOk => outcome == TagoOutcome.ok;
}

/// 도시코드 1건.
class CityCode {
  const CityCode({required this.code, required this.name});

  /// `citycode` — **int로 온다**(실측). 시·도가 아니라 시·군 단위다.
  final int code;

  final String name;
}

/// 도착정보 응답 → 노선별 1건으로 축약된 목록(빠른 순).
TagoResult<BusArrival> parseArrivals(Map<String, dynamic> json) {
  return _parse(json, (rows) {
    // 같은 노선이 다음 차·그다음 차로 여러 건 온다(실측: 5노선 10항목).
    // 축약하지 않으면 카드에 `92번 10분 · 92번 25분`이 나란히 떠 한 노선이
    // 두 줄을 쓴다.
    final fastest = <String, BusArrival>{};
    for (final row in rows) {
      final arrival = _arrival(row);
      final prev = fastest[arrival.routeId];
      if (prev == null || arrival.arrMin < prev.arrMin) {
        fastest[arrival.routeId] = arrival;
      }
    }
    final list = fastest.values.toList()
      ..sort((a, b) => a.arrMin.compareTo(b.arrMin));
    return list;
  });
}

/// 정류장 검색 응답 → 정류장 목록.
///
/// `cityCode`는 응답에 없어 호출자가 넘긴다 — 이후 도착정보 조회에 필요하다.
TagoResult<BusStop> parseStops(
  Map<String, dynamic> json, {
  required int cityCode,
}) {
  return _parse(json, (rows) {
    return rows
        .map((row) => BusStop(
              nodeId: row['nodeid']?.toString() ?? '',
              nodeNm: row['nodenm']?.toString() ?? '',
              nodeNo: _int(row['nodeno']),
              cityCode: cityCode,
            ))
        .where((s) => s.nodeId.isNotEmpty)
        .toList();
  });
}

/// 도시코드 목록 응답.
TagoResult<CityCode> parseCities(Map<String, dynamic> json) {
  return _parse(json, (rows) {
    return rows
        .map((row) => CityCode(
              code: _int(row['citycode']),
              name: row['cityname']?.toString() ?? '',
            ))
        .where((c) => c.code > 0)
        .toList();
  });
}

/// 껍데기 해석 + `items` 세 형태 정규화를 한곳에 모은다.
///
/// 세 엔드포인트가 같은 껍데기를 쓰므로 판정을 복제하지 않는다 — 복제하면
/// 한쪽만 고쳐 어긋난다.
TagoResult<T> _parse<T>(
  Map<String, dynamic> json,
  List<T> Function(List<Map<String, dynamic>> rows) build,
) {
  final response = json['response'];
  if (response is! Map) return const TagoResult(TagoOutcome.malformed);

  final header = response['header'];
  final body = response['body'];
  if (header is! Map || body is! Map) {
    return const TagoResult(TagoOutcome.malformed);
  }

  if (header['resultCode']?.toString() != '00') {
    return const TagoResult(TagoOutcome.keyError);
  }

  final rows = _rows(body['items']);
  if (rows.isEmpty) return const TagoResult(TagoOutcome.empty);

  final built = build(rows);
  if (built.isEmpty) return const TagoResult(TagoOutcome.empty);
  return TagoResult(TagoOutcome.ok, built);
}

/// `items`는 Map(단건) · List(복수) · ""(없음) 세 형태로 온다.
///
/// 빈 문자열이 오는 것이 핵심이다 — `items['item']`으로 바로 들어가면 String에
/// 인덱스 접근이라 파싱이 깨진다.
List<Map<String, dynamic>> _rows(Object? items) {
  if (items is! Map) return const [];
  final item = items['item'];
  if (item is List) {
    return item.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  if (item is Map) return [item.cast<String, dynamic>()];
  return const [];
}

BusArrival _arrival(Map<String, dynamic> row) {
  final seconds = _int(row['arrtime']);
  return BusArrival(
    routeId: row['routeid']?.toString() ?? '',
    // routeno가 int와 String으로 섞여 온다(`92` / `"92-1"`). `as String` 캐스트는
    // 숫자 노선번호에서 크래시하므로 반드시 toString으로 받는다.
    routeNo: row['routeno']?.toString() ?? '',
    arrMin: seconds <= 0 ? 0 : (seconds / 60).ceil(),
    prevCnt: _int(row['arrprevstationcnt']),
    lowFloor: row['vehicletp']?.toString() == '저상버스',
  );
}

/// int로 오는 값이 문자열로 바뀌어도 읽는다(포맷 변경 내성).
int _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/data/tago_response_parser_test.dart`
Expected: PASS (13 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/data/tago_response_parser.dart \
        test/features/bus/data/tago_response_parser_test.dart
git commit -m "feat(bus): TAGO 응답 파서 — 실측으로 확인된 함정 3개를 막는다

전부 정상 상황에서는 안 보이는 곳이라 스펙만 읽고 구현하면 사용자가 실제로
버스를 놓치는 순간에 깨진다.

1. items가 세 형태로 온다 — Map(단건) / List(복수) / \"\"(없음).
   빈 문자열이 핵심이다. items['item']으로 바로 들어가면 String 인덱스
   접근이라 깨진다. resultCode '03'(NODATA)은 오지 않는다 — 데이터가
   없어도 \"00\"이다.
2. routeno가 int와 String으로 섞여 온다(92 / \"92-1\"). as String 캐스트는
   숫자 노선번호에서 크래시한다 — toString으로 받는다.
3. 같은 노선이 여러 건 온다(실측 5노선 10항목). routeid별 arrtime 최소만
   남기지 않으면 카드에 '92번 10분 · 92번 25분'이 나란히 뜬다.

껍데기 판정을 _parse 하나에 모았다 — 세 엔드포인트가 같은 껍데기를 쓰므로
복제하면 한쪽만 고쳐 어긋난다."
```

---

### Task 6: `resolveBusDisplay` — 시간대와 override 수명

**Files:**
- Create: `lib/features/bus/domain/bus_display.dart`
- Test: `test/features/bus/domain/bus_display_test.dart`

**Interfaces:**
- Consumes: `BusSettings`·`TimeRange`·`CommuteDirection` (Task 2·3·4)
- Produces:
  - `const expandOverrideLifetime = Duration(minutes: 30);`
  - `class BusDisplay { final CommuteDirection direction; final bool expanded; const BusDisplay(...); }`
  - `BusDisplay resolveBusDisplay({required DateTime now, required BusSettings settings})`

**규칙(스펙 §1):**

| 상황 | 방향 | 펼침 |
|---|---|---|
| 출근 시간대 안 | `toWork` | true |
| 퇴근 시간대 안 | `toHome` | true |
| 시간대 밖 | **다음에 올 시간대**의 방향 | false |

override가 유효하면 `expanded`를 덮는다. 수명은 **접기 = 그 시간대가 끝날 때까지 / 펼치기 = 30분**.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/domain/bus_display_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_display.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 7, 28, hour, minute);

/// 기본 시간대: 출근 07:00–08:30 / 퇴근 16:00–18:00.
const _s = BusSettings.defaults;

BusDisplay _resolve(DateTime now, {BusSettings settings = _s}) =>
    resolveBusDisplay(now: now, settings: settings);

void main() {
  group('시간대 안 — 펼침 + 그 시간대의 방향', () {
    test('출근 시간대 정각에 열린다', () {
      final d = _resolve(_at(7, 0));
      expect(d.direction, CommuteDirection.toWork);
      expect(d.expanded, isTrue);
    });

    test('출근 시간대 종료 정각까지 펼쳐져 있다', () {
      expect(_resolve(_at(8, 30)).expanded, isTrue);
    });

    test('퇴근 시간대 안이면 퇴근 방향이다', () {
      final d = _resolve(_at(16, 30));
      expect(d.direction, CommuteDirection.toHome);
      expect(d.expanded, isTrue);
    });
  });

  group('시간대 밖 — 접힘 + 다음에 올 시간대의 방향', () {
    test('출근 시간대 1분 전은 접혀 있고 출근을 가리킨다', () {
      final d = _resolve(_at(6, 59));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toWork);
    });

    test('일과시간(10:20)은 접혀 있고 다음은 퇴근이다', () {
      final d = _resolve(_at(10, 20));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toHome);
    });

    test('퇴근 시간대가 끝난 밤에는 다음이 내일 출근이다', () {
      final d = _resolve(_at(21, 0));
      expect(d.expanded, isFalse);
      expect(d.direction, CommuteDirection.toWork);
    });

    test('자정 직후도 다음은 출근이다', () {
      expect(_resolve(_at(0, 10)).direction, CommuteDirection.toWork);
    });
  });

  group('override — 접기는 그 시간대가 끝날 때까지', () {
    test('출근 시간대에 접으면 같은 시간대 안에서는 접힌 채 있다', () {
      final s = _s.copyWith(overrideAt: _at(7, 10), overrideExpanded: false);
      expect(_resolve(_at(8, 20), settings: s).expanded, isFalse);
    });

    test('그 시간대가 끝나면 만료된다 — 퇴근 시간대에는 다시 펼쳐진다', () {
      final s = _s.copyWith(overrideAt: _at(7, 10), overrideExpanded: false);
      expect(_resolve(_at(16, 30), settings: s).expanded, isTrue);
    });

    test('다음 날 같은 시각에는 만료돼 있다', () {
      final s = _s.copyWith(
        overrideAt: DateTime(2026, 7, 28, 7, 10),
        overrideExpanded: false,
      );
      final tomorrow = DateTime(2026, 7, 29, 7, 30);
      expect(resolveBusDisplay(now: tomorrow, settings: s).expanded, isTrue);
    });
  });

  group('override — 펼치기는 30분', () {
    test('시간대 밖에서 펼치면 29분 뒤에도 펼쳐져 있다', () {
      final s = _s.copyWith(overrideAt: _at(8, 35), overrideExpanded: true);
      expect(_resolve(_at(9, 4), settings: s).expanded, isTrue);
    });

    test('31분 뒤에는 접힘으로 돌아온다 — 일과시간 누수를 막는 지점', () {
      final s = _s.copyWith(overrideAt: _at(8, 35), overrideExpanded: true);
      expect(_resolve(_at(9, 6), settings: s).expanded, isFalse);
    });

    test('기본값에서 08:31 펼침은 09:02에 만료된다', () {
      final s = _s.copyWith(overrideAt: _at(8, 31), overrideExpanded: true);
      expect(_resolve(_at(9, 2), settings: s).expanded, isFalse);
    });
  });

  group('시간대가 무효면 판정을 시도하지 않는다', () {
    test('두 시간대가 겹치면 접힘으로 둔다', () {
      final s = BusSettings.defaults.copyWith(
        toHomeRange: _s.toWorkRange,
      );
      expect(_resolve(_at(7, 30), settings: s).expanded, isFalse);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/domain/bus_display_test.dart`
Expected: 컴파일 실패 — `bus_display.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/domain/bus_display.dart`:

```dart
import 'bus_settings.dart';
import 'commute_direction.dart';

/// 시간대 밖에서 사용자가 펼친 뒤 유지되는 시간.
///
/// 30분인 이유: 기본 출근 시간대 종료(08:30) + 30분 = 09:00으로, 일과시간이
/// 시작될 때 자동으로 접힌다. 별도 `일과시간` 설정을 두면 사용자가 출근 시간대를
/// 바꿨을 때 어긋나므로 시간대에서 파생시킨다.
const expandOverrideLifetime = Duration(minutes: 30);

/// 카드가 지금 어느 방향을 어떤 상태로 보여야 하는지.
class BusDisplay {
  const BusDisplay({required this.direction, required this.expanded});

  final CommuteDirection direction;

  /// 펼쳐져 있는지. **false면 TAGO 요청을 보내지 않는다**(스펙 §6 조건 3).
  final bool expanded;
}

/// 시간대와 override로 방향·펼침을 정한다. **순수 함수.**
///
/// 접기와 펼치기의 수명이 다르다 — 겉보기에 같은 토글이지만 뜻이 다르다.
/// 시간대 안에서 접기는 "오늘 아침 볼일 끝"이라 그 시간대가 끝날 때까지 살고,
/// 시간대 밖에서 펼치기는 "지금 잠깐 예외로 필요"라 30분만 산다. 같은 수명을
/// 주면 둘 중 하나가 반드시 틀린다.
BusDisplay resolveBusDisplay({
  required DateTime now,
  required BusSettings settings,
}) {
  // 시간대가 겹치거나 뒤집혔으면 방향 판정이 모호하다. 접힌 채로 두면 요청도
  // 나가지 않아 안전하다(설정 화면이 저장을 막지만 옛 저장값이 있을 수 있다).
  if (!settings.rangesValid) {
    return const BusDisplay(
      direction: CommuteDirection.toWork,
      expanded: false,
    );
  }

  final inToWork = settings.toWorkRange.contains(now);
  final inToHome = settings.toHomeRange.contains(now);

  final CommuteDirection direction;
  final bool byRange;
  if (inToWork) {
    direction = CommuteDirection.toWork;
    byRange = true;
  } else if (inToHome) {
    direction = CommuteDirection.toHome;
    byRange = true;
  } else {
    // 다음에 올 시간대의 방향 — 밤 9시에 보여줄 것은 내일 출근 버스이고
    // 오전 10시에 보여줄 것은 오늘 퇴근 버스다.
    direction = _nextDirection(now, settings);
    byRange = false;
  }

  final override = _overrideValue(now: now, settings: settings, byRange: byRange);
  return BusDisplay(direction: direction, expanded: override ?? byRange);
}

/// 시간대 밖일 때, 시간 순으로 다음에 열릴 시간대의 방향.
CommuteDirection _nextDirection(DateTime now, BusSettings settings) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes < settings.toWorkRange.startMinutes) {
    return CommuteDirection.toWork;
  }
  if (minutes < settings.toHomeRange.startMinutes) {
    return CommuteDirection.toHome;
  }
  // 퇴근 시간대까지 지났으면 다음은 내일 출근이다.
  return CommuteDirection.toWork;
}

/// 아직 유효한 override의 값. 없거나 만료면 null.
bool? _overrideValue({
  required DateTime now,
  required BusSettings settings,
  required bool byRange,
}) {
  final at = settings.overrideAt;
  if (at == null) return null;
  if (at.isAfter(now)) return null; // 기기 시계가 뒤로 갔다 — 무시한다

  if (settings.overrideExpanded) {
    // 펼치기 — 30분.
    return now.difference(at) < expandOverrideLifetime
        ? true
        : null;
  }

  // 접기 — 누른 그 시간대가 끝날 때까지. 같은 날이면서, 누른 시각과 지금이
  // 같은 시간대 안에 있어야 한다.
  if (!_sameDay(at, now) || !byRange) return null;
  final range = settings.toWorkRange.contains(at)
      ? settings.toWorkRange
      : settings.toHomeRange;
  return range.contains(at) && range.contains(now) ? false : null;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/domain/bus_display_test.dart`
Expected: PASS (14 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/domain/bus_display.dart test/features/bus/domain/bus_display_test.dart
git commit -m "feat(bus): 시간대와 override로 방향·펼침을 정하는 순수 함수

접기와 펼치기의 수명이 다르다. 시간대 안에서 접기는 '오늘 아침 볼일 끝'이라
그 시간대가 끝날 때까지, 시간대 밖에서 펼치기는 '지금 잠깐 예외'라 30분.
같은 수명을 주면 둘 중 하나가 반드시 틀린다 — 펼치기를 시간대 끝까지로 하면
늦은 날 8시 35분에 펼친 카드가 일과시간 7시간 내내 폴링한다.

30분은 임의값이 아니다: 기본 출근 시간대 종료(08:30) + 30분 = 09:00으로
일과시간 시작과 맞물린다. 별도 '일과시간' 설정을 두면 사용자가 출근 시간대를
바꿨을 때 어긋나므로 시간대에서 파생시킨다.

시간대 밖에서는 '다음에 올 시간대'의 방향을 쓴다 — 밤 9시엔 내일 출근,
오전 10시엔 오늘 퇴근이 사용자가 궁금한 것이다."
```

---

### Task 7: `buildBusCardView` — 경과 보정·노선 필터·표시 상한

**Files:**
- Create: `lib/features/bus/domain/bus_card_view.dart`
- Test: `test/features/bus/domain/bus_card_view_test.dart`

**Interfaces:**
- Consumes: `BusArrival`·`BusStop` (Task 2), `TagoOutcome` (Task 5)
- Produces:
  - `enum BusCardState { ok, stale, closed, down, keyError, noStop }`
  - `class BusCardView { final BusCardState state; final List<BusArrival> visible; final int hiddenCount; final DateTime? fetchedAt; const BusCardView(...); bool get hasRows; }`
  - `const busUrgentMinutes = 3; const busSoonMinutes = 7; const busUnfilteredLimit = 3;`
  - `BusCardView buildBusCardView({required BusCardState state, required List<BusArrival> arrivals, required DateTime? fetchedAt, required DateTime now, Set<String> routeIds = const {}})`
  - `bool isUrgent(int arrMin)` / `bool isSoon(int arrMin)`

**계산 순서가 중요하다:** 경과 보정 → 노선 필터 → 정렬 → 상한. 보정을 나중에 하면 상한이 옛 순서로 잘린다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/domain/bus_card_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';

DateTime _at(int hour, int minute, [int second = 0]) =>
    DateTime(2026, 7, 28, hour, minute, second);

BusArrival _a(String routeId, String routeNo, int arrMin) =>
    BusArrival(routeId: routeId, routeNo: routeNo, arrMin: arrMin);

BusCardView _build({
  required List<BusArrival> arrivals,
  DateTime? fetchedAt,
  DateTime? now,
  Set<String> routeIds = const {},
  BusCardState state = BusCardState.ok,
}) {
  return buildBusCardView(
    state: state,
    arrivals: arrivals,
    fetchedAt: fetchedAt ?? _at(7, 32),
    now: now ?? _at(7, 32),
    routeIds: routeIds,
  );
}

void main() {
  group('경과 보정 — 캐시가 묵은 만큼 차감한다', () {
    test('50초 지나면 4분이 3분으로 나간다', () {
      final v = _build(
        arrivals: [_a('A', '720', 4)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 32, 50),
      );
      expect(v.visible.single.arrMin, 3);
    });

    test('보정으로 0분 아래가 되면 0분(곧 도착)에서 멈춘다', () {
      final v = _build(
        arrivals: [_a('A', '720', 1)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 35, 0),
      );
      expect(v.visible.single.arrMin, 0);
    });

    test('fetchedAt이 없으면 보정하지 않는다', () {
      final v = _build(arrivals: [_a('A', '720', 4)], fetchedAt: null);
      expect(v.visible.single.arrMin, 4);
    });
  });

  group('노선 필터', () {
    test('routeIds가 비면 전부 통과한다 — 필터 없음을 뜻한다', () {
      final v = _build(arrivals: [_a('A', '1', 2), _a('B', '2', 5)]);
      expect(v.visible.length, 2);
    });

    test('골라두면 그것만 통과한다', () {
      final v = _build(
        arrivals: [_a('A', '1', 2), _a('B', '2', 5), _a('C', '3', 8)],
        routeIds: {'A', 'C'},
      );
      expect(v.visible.map((e) => e.routeNo).toList(), ['1', '3']);
    });

    test('골라둔 노선이 지금 안 오면 운행 종료로 읽힌다', () {
      final v = _build(arrivals: [_a('A', '1', 2)], routeIds: {'Z'});
      expect(v.state, BusCardState.closed);
      expect(v.visible, isEmpty);
    });
  });

  group('표시 상한 — 필터를 걸었는지에 따라 다르다', () {
    final five = [
      _a('R1', '82-1', 8), _a('R2', '92', 10), _a('R3', '92-1', 10),
      _a('R4', '81', 13), _a('R5', '61', 31),
    ];

    test('필터 없으면 3개만 보이고 남은 수를 센다', () {
      final v = _build(arrivals: five);
      expect(v.visible.length, 3);
      expect(v.hiddenCount, 2);
    });

    test('골라두면 5개도 전부 보인다 — 자기가 고른 것을 자르지 않는다', () {
      final v = _build(arrivals: five, routeIds: {'R1','R2','R3','R4','R5'});
      expect(v.visible.length, 5);
      expect(v.hiddenCount, 0);
    });

    test('보정 후 순서로 자른다 — 옛 순서로 자르지 않는다', () {
      // 조회 시점엔 A(2) B(3) C(4) D(5)였지만 A는 이미 지나갔고
      // 보정 뒤에도 순서는 같다. 상한은 보정된 목록에서 앞 3개다.
      final v = _build(
        arrivals: [_a('A','1',2), _a('B','2',3), _a('C','3',4), _a('D','4',5)],
        fetchedAt: _at(7, 32, 0),
        now: _at(7, 34, 0),
      );
      expect(v.visible.map((e) => e.routeNo).toList(), ['1', '2', '3']);
      expect(v.visible.first.arrMin, 0);
    });
  });

  group('임박 판정', () {
    test('3분 미만은 임박, 3분은 임박이 아니다', () {
      expect(isUrgent(2), isTrue);
      expect(isUrgent(0), isTrue);
      expect(isUrgent(3), isFalse);
    });

    test('3~7분은 soon, 8분은 아니다', () {
      expect(isSoon(3), isTrue);
      expect(isSoon(7), isTrue);
      expect(isSoon(8), isFalse);
      expect(isSoon(2), isFalse);
    });
  });

  group('상태 전달', () {
    test('빈 목록이면 closed로 바뀐다', () {
      final v = _build(arrivals: const []);
      expect(v.state, BusCardState.closed);
    });

    test('down은 목록이 없어도 그대로 유지된다 — 막차와 구별해야 한다', () {
      final v = _build(arrivals: const [], state: BusCardState.down);
      expect(v.state, BusCardState.down);
    });

    test('stale은 목록을 유지한다', () {
      final v = _build(arrivals: [_a('A', '1', 4)], state: BusCardState.stale);
      expect(v.state, BusCardState.stale);
      expect(v.hasRows, isTrue);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/domain/bus_card_view_test.dart`
Expected: 컴파일 실패 — `bus_card_view.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/domain/bus_card_view.dart`:

```dart
import 'bus_arrival.dart';

/// 3분 미만이면 임박. 두 모양 모두 이 값으로 강조를 정한다.
const busUrgentMinutes = 3;

/// 3~7분 구간. `시간 축`의 가운데 색이 여기다.
const busSoonMinutes = 7;

/// 노선 필터를 걸지 않았을 때 보여주는 최대 개수.
///
/// 월 그리드가 이벤트 점을 3개로 자르는 것과 같은 값이다.
const busUnfilteredLimit = 3;

bool isUrgent(int arrMin) => arrMin < busUrgentMinutes;

bool isSoon(int arrMin) => arrMin >= busUrgentMinutes && arrMin <= busSoonMinutes;

/// 카드가 그릴 상태 — 스펙 §3의 실패 계약 5상태 + 슬롯 미설정.
enum BusCardState {
  ok,

  /// 갱신에 실패했지만 캐시된 목록은 있다. 목록 + "07:30 기준 · 갱신 실패".
  stale,

  /// 오는 버스가 없다. 막차 후이거나 고른 노선이 지금 안 온다.
  closed,

  /// 조회 실패 + 캐시 없음.
  down,

  /// 인증키 문제. 사용자에게 키 이야기를 하지 않는다.
  keyError,

  /// 정류장 슬롯이 비었다. 등록 유도를 띄운다(무한 로딩 금지).
  noStop,
}

/// 카드가 그릴 것 전부 — [buildBusCardView]의 출력.
class BusCardView {
  const BusCardView({
    required this.state,
    required this.visible,
    required this.hiddenCount,
    required this.fetchedAt,
  });

  final BusCardState state;

  /// 화면에 그릴 목록. 보정·필터·정렬·상한이 모두 적용된 결과.
  final List<BusArrival> visible;

  /// 상한 때문에 감춘 개수. 0이면 `N개 더`를 그리지 않는다.
  final int hiddenCount;

  /// 마지막 조회 시각. `07:32 기준` 문구의 근거이고 null이면 감춘다.
  final DateTime? fetchedAt;

  bool get hasRows => visible.isNotEmpty;
}

/// 조회 결과를 화면 상태로 바꾼다. **순수 함수.**
///
/// 계산 순서가 중요하다 — 경과 보정 → 노선 필터 → 정렬 → 상한. 보정을 나중에
/// 하면 상한이 옛 순서로 잘려 방금 지나간 버스가 목록에 남는다.
BusCardView buildBusCardView({
  required BusCardState state,
  required List<BusArrival> arrivals,
  required DateTime? fetchedAt,
  required DateTime now,
  Set<String> routeIds = const {},
}) {
  // 1) 경과 보정 — 캐시가 묵은 만큼 차감한다. 서버가 "4분"이라고 준 값이 50초
  //    묵었으면 화면에는 3분으로 나가야 한다.
  final elapsed = fetchedAt == null ? 0 : now.difference(fetchedAt).inSeconds;
  final adjusted = arrivals.map((a) {
    if (elapsed <= 0) return a;
    final remaining = a.arrMin * 60 - elapsed;
    return a.copyWith(arrMin: remaining <= 0 ? 0 : (remaining / 60).ceil());
  });

  // 2) 노선 필터 — 비어 있으면 "필터 없음"이라 전부 통과한다.
  final filtered = routeIds.isEmpty
      ? adjusted.toList()
      : adjusted.where((a) => routeIds.contains(a.routeId)).toList();

  // 3) 정렬 — 보정으로 순서가 바뀔 수 있다.
  filtered.sort((a, b) => a.arrMin.compareTo(b.arrMin));

  // 4) 상한 — 필터를 걸었다면 자르지 않는다. 자기가 고른 것을 감추면 안 된다.
  final limited = routeIds.isEmpty && filtered.length > busUnfilteredLimit
      ? filtered.sublist(0, busUnfilteredLimit)
      : filtered;
  final hidden = filtered.length - limited.length;

  // 빈 목록은 closed로 바꾼다. 다만 장애·키 오류는 막차와 구별해야 하므로
  // 그대로 남긴다 — 정류장에서 기다릴지 택시를 부를지가 갈린다.
  final resolved = limited.isEmpty && state == BusCardState.ok
      ? BusCardState.closed
      : state;

  return BusCardView(
    state: resolved,
    visible: limited,
    hiddenCount: hidden,
    fetchedAt: fetchedAt,
  );
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/domain/bus_card_view_test.dart`
Expected: PASS (15 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/domain/bus_card_view.dart test/features/bus/domain/bus_card_view_test.dart
git commit -m "feat(bus): 카드가 그릴 것을 계산하는 순수 함수

계산 순서가 중요하다 — 경과 보정 → 노선 필터 → 정렬 → 상한. 보정을 나중에
하면 상한이 옛 순서로 잘려 방금 지나간 버스가 목록에 남는다.

경과 보정이 캐시 TTL의 대가를 지운다. '4분'으로 받은 값이 50초 묵었으면
화면에는 3분으로 나간다.

표시 상한은 필터를 걸었는지에 따라 다르다. 필터 없음이면 3개 + N개 더,
골라뒀으면 전부 — 자기가 고른 것을 감추면 안 된다.

빈 목록은 closed로 바꾸지만 down·keyError는 그대로 남긴다. 막차 끝남과
앱 고장을 뭉개면 정류장에서 기다릴지 택시를 부를지 판단할 수 없다."
```

---

### Task 8: `BusApiClient` — HTTP + 키 주입 + 메모리 캐시

**Files:**
- Create: `lib/features/bus/data/bus_api_client.dart`
- Test: `test/features/bus/data/bus_api_client_test.dart`

**Interfaces:**
- Consumes: `tagoResponseParser` 전부 (Task 5), `BusArrival`·`BusStop` (Task 2), `BusCardState` (Task 7)
- Produces:
  - `const tagoBaseUrl = 'https://apis.data.go.kr/1613000';`
  - `const busCacheTtl = Duration(seconds: 30);`
  - `class BusFetch { final BusCardState state; final List<BusArrival> arrivals; final DateTime? fetchedAt; }`
  - `class BusApiClient { BusApiClient({http.Client? client, String? serviceKey, DateTime Function()? clock}); Future<BusFetch> fetchArrivals({required int cityCode, required String nodeId}); Future<TagoResult<BusStop>> searchStops({required int cityCode, required String name}); Future<TagoResult<CityCode>> fetchCities(); void invalidate(); int get requestCount; bool get hasKey; }`

`requestCount`는 테스트가 **요청 0회**를 검사하는 수단이다(스펙 §8 가드 4개).

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/data/bus_api_client_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';

String _body(Object? items, {String code = '00'}) => jsonEncode({
      'response': {
        'header': {'resultCode': code, 'resultMsg': 'NORMAL SERVICE.'},
        'body': {'items': items, 'numOfRows': 30, 'pageNo': 1},
      },
    });

Map<String, dynamic> _arr(Object routeno, String routeid, int arrtime) => {
      'arrprevstationcnt': 3,
      'arrtime': arrtime,
      'nodeid': 'GGB201000156',
      'nodenm': '수원시청',
      'routeid': routeid,
      'routeno': routeno,
      'vehicletp': '일반버스',
    };

void main() {
  var now = DateTime(2026, 7, 28, 7, 32);

  BusApiClient clientWith(
    Future<http.Response> Function(http.Request) handler, {
    String key = 'TESTKEY',
  }) {
    return BusApiClient(
      client: MockClient((req) => handler(req)),
      serviceKey: key,
      clock: () => now,
    );
  }

  setUp(() => now = DateTime(2026, 7, 28, 7, 32));

  group('정상 조회', () {
    test('https로 가고 키가 쿼리에 실린다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return http.Response(_body([_arr(92, 'A', 600)]), 200);
      });
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'GGB201000156');

      expect(r.state, BusCardState.ok);
      expect(r.arrivals.single.routeNo, '92');
      expect(seen?.scheme, 'https');
      expect(seen?.host, 'apis.data.go.kr');
      expect(seen?.queryParameters['serviceKey'], 'TESTKEY');
      expect(seen?.queryParameters['nodeId'], 'GGB201000156');
      expect(seen?.queryParameters['_type'], 'json');
    });

    test('fetchedAt은 조회 시각이다', () async {
      final c = clientWith((_) async => http.Response(_body([_arr(1, 'A', 60)]), 200));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.fetchedAt, DateTime(2026, 7, 28, 7, 32));
    });
  });

  group('메모리 캐시 — TTL 30초', () {
    test('같은 정류장을 연달아 조회하면 요청이 1회다', () async {
      final c = clientWith((_) async => http.Response(_body([_arr(1, 'A', 60)]), 200));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 1);
    });

    test('31초 뒤에는 다시 요청한다', () async {
      final c = clientWith((_) async => http.Response(_body([_arr(1, 'A', 60)]), 200));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      now = now.add(const Duration(seconds: 31));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 2);
    });

    test('다른 정류장은 별 캐시다', () async {
      final c = clientWith((_) async => http.Response(_body([_arr(1, 'A', 60)]), 200));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N1');
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N2');
      expect(c.requestCount, 2);
    });

    test('invalidate 후에는 다시 요청한다 — 슬롯 교체 경로', () async {
      final c = clientWith((_) async => http.Response(_body([_arr(1, 'A', 60)]), 200));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      c.invalidate();
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 2);
    });
  });

  group('실패 계약', () {
    test('items가 빈 문자열이면 closed', () async {
      final c = clientWith((_) async => http.Response(_body(''), 200));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.closed);
    });

    test('예외 + 캐시 없음이면 down', () async {
      final c = clientWith((_) async => throw const _Boom());
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.down);
      expect(r.arrivals, isEmpty);
    });

    test('예외 + 캐시 있음이면 stale — 옛 목록과 옛 시각을 준다', () async {
      var fail = false;
      final c = clientWith((_) async {
        if (fail) throw const _Boom();
        return http.Response(_body([_arr(1, 'A', 240)]), 200);
      });
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      fail = true;
      now = now.add(const Duration(seconds: 31));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      expect(r.state, BusCardState.stale);
      expect(r.arrivals.single.arrMin, 4);
      expect(r.fetchedAt, DateTime(2026, 7, 28, 7, 32));
    });

    test('HTTP 401이면 keyError', () async {
      final c = clientWith((_) async => http.Response('Unauthorized', 401));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
    });

    test('resultCode가 00이 아니면 keyError', () async {
      final c = clientWith((_) async => http.Response(_body('', code: '30'), 200));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
    });
  });

  group('키가 없으면 요청조차 하지 않는다', () {
    test('빈 키면 keyError이고 requestCount는 0이다', () async {
      final c = clientWith(
        (_) async => http.Response(_body([_arr(1, 'A', 60)]), 200),
        key: '',
      );
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
      expect(c.requestCount, 0);
      expect(c.hasKey, isFalse);
    });
  });

  group('검색', () {
    test('searchStops는 이름을 인코딩해 넘긴다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return http.Response(
          _body({'nodeid': 'N1', 'nodenm': '수원시청', 'nodeno': 2251}),
          200,
        );
      });
      final r = await c.searchStops(cityCode: 31010, name: '시청');
      expect(r.items.single.nodeNo, 2251);
      expect(seen?.queryParameters['nodeNm'], '시청');
    });

    test('fetchCities는 도시코드를 int로 읽는다', () async {
      final c = clientWith((_) async => http.Response(
            _body([{'citycode': 31010, 'cityname': '수원시'}]),
            200,
          ));
      final r = await c.fetchCities();
      expect(r.items.single.code, 31010);
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/data/bus_api_client_test.dart`
Expected: 컴파일 실패 — `bus_api_client.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/data/bus_api_client.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/bus_arrival.dart';
import '../domain/bus_card_view.dart';
import '../domain/bus_stop.dart';
import 'tago_response_parser.dart';

/// TAGO 국토교통부 서비스 묶음.
///
/// **https다.** 실측으로 TLSv1.3 + GlobalSign 인증서를 확인했으므로 `Info.plist`에
/// ATS 예외를 넣지 않는다.
const tagoBaseUrl = 'https://apis.data.go.kr/1613000';

/// 메모리 캐시 수명. 폴링 주기와 같게 두어 방향 토글 왕복과 탭 재진입만 흡수한다.
const busCacheTtl = Duration(seconds: 30);

/// 빌드 시 주입되는 인증키. 소스와 git 히스토리에 남지 않는다.
///
/// `--dart-define=TAGO_KEY=...`로 넣는다(`main.dart`의 `SCREENSHOT_MODE`와 같은
/// 패턴). 난독화가 아니라 **히스토리에 남지 않는 것**이 실질 이득이다 — 키는
/// 어차피 IPA 안에 문자열로 남는다.
const _envKey = String.fromEnvironment('TAGO_KEY');

/// 도착정보 1회 조회 결과.
class BusFetch {
  const BusFetch({
    required this.state,
    required this.arrivals,
    required this.fetchedAt,
  });

  final BusCardState state;
  final List<BusArrival> arrivals;

  /// 이 목록을 실제로 받아온 시각. 캐시 히트면 캐시된 시각이 그대로 온다.
  final DateTime? fetchedAt;
}

class _CacheEntry {
  const _CacheEntry(this.arrivals, this.fetchedAt);

  final List<BusArrival> arrivals;
  final DateTime fetchedAt;
}

/// TAGO를 직접 호출한다. 프록시는 보류다(스펙 §2·§5).
class BusApiClient {
  BusApiClient({
    http.Client? client,
    String? serviceKey,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _serviceKey = serviceKey ?? _envKey,
        _now = clock ?? DateTime.now;

  final http.Client _client;
  final String _serviceKey;
  final DateTime Function() _now;

  final _cache = <String, _CacheEntry>{};

  /// 실제로 나간 HTTP 요청 수. **테스트가 "요청 0회"를 검사하는 수단이다.**
  ///
  /// 접힘·시간대 밖에서 요청이 나가지 않는다는 것을 화면으로 검증하면 약하다 —
  /// 접힘에서는 어차피 화면이 안 바뀌므로 요청이 나가도 통과한다. 횟수를 세야 잡힌다.
  int get requestCount => _requestCount;
  int _requestCount = 0;

  /// 키가 주입됐는지. false면 기능을 명시적으로 끈다(무한 로딩 금지).
  bool get hasKey => _serviceKey.isNotEmpty;

  /// 캐시를 버린다. 슬롯이 교체되면 옛 정류장 값을 쓰지 않도록 호출한다.
  void invalidate() => _cache.clear();

  Future<BusFetch> fetchArrivals({
    required int cityCode,
    required String nodeId,
  }) async {
    final key = '$cityCode:$nodeId';
    final cached = _cache[key];
    final now = _now();

    if (cached != null && now.difference(cached.fetchedAt) < busCacheTtl) {
      return BusFetch(
        state: BusCardState.ok,
        arrivals: cached.arrivals,
        fetchedAt: cached.fetchedAt,
      );
    }

    if (!hasKey) {
      return const BusFetch(
        state: BusCardState.keyError,
        arrivals: [],
        fetchedAt: null,
      );
    }

    try {
      final json = await _get(
        'ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList',
        {'cityCode': '$cityCode', 'nodeId': nodeId, 'numOfRows': '30'},
      );
      final result = parseArrivals(json);

      switch (result.outcome) {
        case TagoOutcome.ok:
          _cache[key] = _CacheEntry(result.items, now);
          return BusFetch(
            state: BusCardState.ok,
            arrivals: result.items,
            fetchedAt: now,
          );
        case TagoOutcome.empty:
          _cache[key] = _CacheEntry(const [], now);
          return BusFetch(
            state: BusCardState.closed,
            arrivals: const [],
            fetchedAt: now,
          );
        case TagoOutcome.keyError:
        case TagoOutcome.malformed:
          return _fallback(cached, BusCardState.keyError);
      }
    } on _KeyRejected {
      return _fallback(cached, BusCardState.keyError);
    } catch (_) {
      // 네트워크·타임아웃·JSON 파손. 캐시가 있으면 옛 목록을 보여주고 갱신
      // 실패를 고백한다 — 실시간인 척하면 버스를 놓친 사용자가 앱을 불신한다.
      return _fallback(cached, BusCardState.down);
    }
  }

  Future<TagoResult<BusStop>> searchStops({
    required int cityCode,
    required String name,
  }) async {
    if (!hasKey) return const TagoResult(TagoOutcome.keyError);
    try {
      final json = await _get(
        'BusSttnInfoInqireService/getSttnNoList',
        {'cityCode': '$cityCode', 'nodeNm': name, 'numOfRows': '50'},
      );
      return parseStops(json, cityCode: cityCode);
    } on _KeyRejected {
      return const TagoResult(TagoOutcome.keyError);
    } catch (_) {
      return const TagoResult(TagoOutcome.malformed);
    }
  }

  Future<TagoResult<CityCode>> fetchCities() async {
    if (!hasKey) return const TagoResult(TagoOutcome.keyError);
    try {
      final json = await _get(
        'ArvlInfoInqireService/getCtyCodeList',
        {'numOfRows': '300'},
      );
      return parseCities(json);
    } on _KeyRejected {
      return const TagoResult(TagoOutcome.keyError);
    } catch (_) {
      return const TagoResult(TagoOutcome.malformed);
    }
  }

  BusFetch _fallback(_CacheEntry? cached, BusCardState failure) {
    if (cached == null || cached.arrivals.isEmpty) {
      return BusFetch(state: failure, arrivals: const [], fetchedAt: null);
    }
    return BusFetch(
      state: BusCardState.stale,
      arrivals: cached.arrivals,
      fetchedAt: cached.fetchedAt,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$tagoBaseUrl/$path').replace(queryParameters: {
      'serviceKey': _serviceKey,
      '_type': 'json',
      'pageNo': '1',
      ...query,
    });

    _requestCount++;
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const _KeyRejected();
    }
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

/// 키가 거부됐다 — 재시도해도 같으므로 캐시 폴백 뒤 keyError로 간다.
class _KeyRejected implements Exception {
  const _KeyRejected();
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/data/bus_api_client_test.dart`
Expected: PASS (13 tests)

- [ ] **Step 5: analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/bus/data/bus_api_client.dart test/features/bus/data/bus_api_client_test.dart
git commit -m "feat(bus): TAGO 직접 호출 클라이언트 — 키 주입 + 메모리 캐시

https로 간다. 실측으로 TLSv1.3 + GlobalSign을 확인했으므로 Info.plist에
ATS 예외를 넣지 않는다.

키는 String.fromEnvironment('TAGO_KEY'). 난독화가 아니라 git 히스토리에
남지 않는 것이 실질 이득이다 — 키는 어차피 IPA 안에 문자열로 남는다.
키가 비면 요청조차 하지 않고 keyError로 끝낸다(무한 로딩 금지).

requestCount를 노출한 이유: 접힘·시간대 밖에서 요청이 0회임을 화면으로
검증하면 약하다. 접힘에서는 어차피 화면이 안 바뀌므로 요청이 나가도
통과한다. 횟수를 세야 잡힌다.

장애 시 캐시가 있으면 stale로 옛 목록과 옛 시각을 준다 — 실시간인 척하면
버스를 놓친 사용자가 앱을 불신한다."
```

---

### Task 9: `busSettingsProvider` — shared_preferences 배선

**Files:**
- Create: `lib/features/bus/presentation/providers/bus_providers.dart`
- Test: `test/features/bus/bus_settings_provider_test.dart`

**Interfaces:**
- Consumes: `BusSettings`·`BusStop`·`BusCardStyle`·`TimeRange`·`CommuteDirection` (Task 2·3·4), `BusApiClient` (Task 8)
- Produces:
  - `final busSettingsProvider = AsyncNotifierProvider<BusSettingsNotifier, BusSettings>(BusSettingsNotifier.new);`
  - `class BusSettingsNotifier extends AsyncNotifier<BusSettings>` with `setEnabled(bool)` · `setStyle(BusCardStyle)` · `setStop(CommuteDirection, BusStop)` · `setRange(CommuteDirection, TimeRange)` · `setOverride({required bool expanded, required DateTime at})` · `clearOverride()`
  - `final busApiClientProvider = Provider<BusApiClient>((ref) => BusApiClient());` — **`autoDispose`가 아니다**(캐시가 탭 이동에도 살아남아야 한다)

`stampSettingsProvider`와 같은 구조다(`AsyncNotifierProvider` + `jsonEncode`).

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_settings_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/domain/time_range.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
  nodeNo: 2251,
  cityCode: 31010,
  routeIds: {'R1'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, BusSettingsNotifier)> boot() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(busSettingsProvider.future);
    return (container, container.read(busSettingsProvider.notifier));
  }

  test('처음에는 기본값이다 — 꺼져 있고 모양은 간단히', () async {
    final (container, _) = await boot();
    final s = container.read(busSettingsProvider).requireValue;
    expect(s.enabled, isFalse);
    expect(s.style, BusCardStyle.text);
  });

  test('슬롯을 저장하면 방향별로 들어간다', () async {
    final (container, notifier) = await boot();
    await notifier.setStop(CommuteDirection.toHome, _stop);

    final s = container.read(busSettingsProvider).requireValue;
    expect(s.arrival?.nodeId, 'GGB201000156');
    expect(s.arrival?.routeIds, {'R1'});
    expect(s.departure, isNull);
  });

  test('저장한 값이 새 컨테이너에서도 읽힌다', () async {
    final (_, notifier) = await boot();
    await notifier.setEnabled(true);
    await notifier.setStyle(BusCardStyle.axis);

    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    final s = await fresh.read(busSettingsProvider.future);
    expect(s.enabled, isTrue);
    expect(s.style, BusCardStyle.axis);
  });

  test('겹치는 시간대는 저장되지 않는다', () async {
    final (container, notifier) = await boot();
    final before = container.read(busSettingsProvider).requireValue.toHomeRange;

    await notifier.setRange(
      CommuteDirection.toHome,
      const TimeRange.hm(8, 0, 18, 0), // 출근 07:00-08:30과 겹친다
    );

    final after = container.read(busSettingsProvider).requireValue.toHomeRange;
    expect(after.label, before.label, reason: '겹치면 이전 값을 유지한다');
  });

  test('뒤집힌 시간대는 저장되지 않는다', () async {
    final (container, notifier) = await boot();
    await notifier.setRange(CommuteDirection.toWork, const TimeRange.hm(9, 0, 7, 0));
    expect(
      container.read(busSettingsProvider).requireValue.toWorkRange.label,
      '07:00 – 08:30',
    );
  });

  test('override는 저장되고 지워진다', () async {
    final (container, notifier) = await boot();
    final at = DateTime(2026, 7, 28, 8, 35);

    await notifier.setOverride(expanded: true, at: at);
    var s = container.read(busSettingsProvider).requireValue;
    expect(s.overrideAt, at);
    expect(s.overrideExpanded, isTrue);

    await notifier.clearOverride();
    s = container.read(busSettingsProvider).requireValue;
    expect(s.overrideAt, isNull);
    expect(s.overrideExpanded, isFalse);
  });

  test('손상된 값이면 기본값으로 폴백한다', () async {
    SharedPreferences.setMockInitialValues({'bus_settings_v1': '{ not json'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final s = await container.read(busSettingsProvider.future);
    expect(s.enabled, isFalse);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_settings_provider_test.dart`
Expected: 컴파일 실패 — `bus_providers.dart`가 없다.

- [ ] **Step 3: 구현한다**

`lib/features/bus/presentation/providers/bus_providers.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/bus_api_client.dart';
import '../../domain/bus_card_style.dart';
import '../../domain/bus_settings.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../../domain/time_range.dart';

const _prefsKey = 'bus_settings_v1';

/// TAGO 클라이언트 — **`autoDispose`가 아니다.**
///
/// 메모리 캐시를 이 인스턴스가 들고 있어서, 탭을 옮겼다 오늘 탭으로 돌아올 때
/// 빈 카드가 깜빡이지 않게 하려면 살아남아야 한다. 카드 provider만 autoDispose다.
final busApiClientProvider = Provider<BusApiClient>((ref) => BusApiClient());

/// 버스 설정 — 오늘 탭이 소비하고 설정 탭이 변경한다. SharedPreferences 저장.
final busSettingsProvider =
    AsyncNotifierProvider<BusSettingsNotifier, BusSettings>(
  BusSettingsNotifier.new,
);

class BusSettingsNotifier extends AsyncNotifier<BusSettings> {
  @override
  Future<BusSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return BusSettings.defaults;
    try {
      return BusSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 손상된 값이면 기본값으로
      return BusSettings.defaults;
    }
  }

  BusSettings get _current => state.valueOrNull ?? BusSettings.defaults;

  Future<void> setEnabled(bool value) => _save(_current.copyWith(enabled: value));

  Future<void> setStyle(BusCardStyle style) =>
      _save(_current.copyWith(style: style));

  /// 슬롯 교체 — 저장과 동시에 캐시를 버린다.
  ///
  /// 캐시를 남기면 카드가 옛 정류장 값을 최대 30초 더 보여준다. `/bus/stops`는
  /// push 라우트라 pop 후 stale이 되기 쉬운 경로다(CLAUDE.md의 push 함정).
  Future<void> setStop(CommuteDirection direction, BusStop stop) {
    ref.read(busApiClientProvider).invalidate();
    return _save(direction == CommuteDirection.toWork
        ? _current.copyWith(departure: stop)
        : _current.copyWith(arrival: stop));
  }

  /// 시간대 변경. **겹치거나 뒤집히면 저장하지 않는다.**
  Future<void> setRange(CommuteDirection direction, TimeRange range) {
    final next = direction == CommuteDirection.toWork
        ? _current.copyWith(toWorkRange: range)
        : _current.copyWith(toHomeRange: range);
    if (!next.rangesValid) return Future<void>.value();
    return _save(next);
  }

  Future<void> setOverride({required bool expanded, required DateTime at}) =>
      _save(_current.copyWith(overrideAt: at, overrideExpanded: expanded));

  Future<void> clearOverride() => _save(_current.clearOverride());

  Future<void> _save(BusSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }
}
```

- [ ] **Step 4: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_settings_provider_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/bus/presentation/providers/bus_providers.dart \
        test/features/bus/bus_settings_provider_test.dart
git commit -m "feat(bus): 설정 provider를 shared_preferences에 배선한다

stampSettingsProvider와 같은 구조(AsyncNotifierProvider + jsonEncode).

busApiClientProvider는 autoDispose가 아니다 — 메모리 캐시를 이 인스턴스가
들고 있어서 탭을 옮겼다 돌아올 때 빈 카드가 깜빡이지 않으려면 살아남아야
한다. 카드 provider만 autoDispose다.

setStop은 저장과 동시에 캐시를 버린다. 남기면 카드가 옛 정류장 값을 최대
30초 더 보여준다 — /bus/stops는 push 라우트라 pop 후 stale이 되기 쉽다.

setRange는 겹치거나 뒤집히면 저장하지 않는다. 겹치면 방향 판정이 모호해진다."
```

---

### Task 10: 본문 위젯 2종 — `간단히` / `시간 축`

**Files:**
- Create: `lib/features/bus/presentation/widgets/bus_body_text.dart`
- Create: `lib/features/bus/presentation/widgets/bus_body_axis.dart`
- Test: `test/features/bus/bus_body_test.dart`

**Interfaces:**
- Consumes: `BusCardView`·`isUrgent`·`isSoon`·`busSoonMinutes` (Task 7), `BusStrings`·`AppColors` (Task 1)
- Produces:
  - `class BusBodyText extends StatelessWidget { const BusBodyText({super.key, required this.view}); static const urgentKeyPrefix = 'bus_urgent_'; }`
  - `class BusBodyAxis extends StatelessWidget { const BusBodyAxis({super.key, required this.view}); static const axisRange = 15; static double dotPosition(int arrMin); }`

`dotPosition`은 순수 함수로 노출해 위젯을 띄우지 않고도 clamp를 검사한다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_body_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

BusArrival _a(String routeId, String routeNo, int arrMin) =>
    BusArrival(routeId: routeId, routeNo: routeNo, arrMin: arrMin);

BusCardView _view(List<BusArrival> items, {int hidden = 0}) => BusCardView(
      state: BusCardState.ok,
      visible: items,
      hiddenCount: hidden,
      fetchedAt: DateTime(2026, 7, 28, 7, 32),
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SizedBox(width: 340, child: child)),
  ));
}

void main() {
  group('BusBodyText — 색을 쓰지 않고 굵기·크기로만 위계를 만든다', () {
    testWidgets('노선번호와 분이 모두 보인다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])));
      expect(find.text('720번'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('150번'), findsOneWidget);
      expect(find.text('5분'), findsOneWidget);
    });

    testWidgets('0분은 곧 도착으로 쓴다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '15', 0)])));
      expect(find.text('곧 도착'), findsOneWidget);
    });

    testWidgets('임박한 행만 w800 18px ink, 나머지는 w600 14px sub', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])));

      final urgent = tester.widget<Text>(find.text('2분'));
      final normal = tester.widget<Text>(find.text('5분'));
      expect(urgent.style?.fontWeight, FontWeight.w800);
      expect(urgent.style?.fontSize, 18);
      expect(urgent.style?.color, AppColors.ink);
      expect(normal.style?.fontWeight, FontWeight.w600);
      expect(normal.style?.fontSize, 14);
      expect(normal.style?.color, AppColors.sub);
    });

    testWidgets('감춘 개수가 있으면 N개 더를 그린다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '1', 2)], hidden: 2)));
      expect(find.text('2개 더'), findsOneWidget);
    });

    testWidgets('감춘 개수가 0이면 더 보기가 없다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '1', 2)])));
      expect(find.textContaining('개 더'), findsNothing);
    });
  });

  group('BusBodyAxis.dotPosition — 0~15분을 3~97%로 clamp한다', () {
    test('0분은 왼쪽 끝(3%)이다', () {
      expect(BusBodyAxis.dotPosition(0), closeTo(0.03, 0.001));
    });

    test('15분은 오른쪽 끝(97%)이다', () {
      expect(BusBodyAxis.dotPosition(15), closeTo(0.97, 0.001));
    });

    test('15분을 넘겨도 97%를 넘지 않는다', () {
      expect(BusBodyAxis.dotPosition(48), closeTo(0.97, 0.001));
    });

    test('중간값은 비례한다', () {
      expect(BusBodyAxis.dotPosition(5), closeTo(1 / 3, 0.01));
    });
  });

  group('BusBodyAxis 렌더', () {
    testWidgets('눈금과 노선번호를 그린다 — 노선번호에 번은 붙이지 않는다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));
      expect(find.text('지금'), findsOneWidget);
      expect(find.text('15분'), findsOneWidget);
      expect(find.text('720'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_body_test.dart`
Expected: 컴파일 실패 — 두 위젯 파일이 없다.

- [ ] **Step 3: `BusBodyText`를 만든다**

`lib/features/bus/presentation/widgets/bus_body_text.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';

/// `간단히` 본문 — 한 줄에 노선을 나열한다. **기본 모양.**
///
/// 새 색 토큰을 하나도 참조하지 않는다. 임박은 굵기·크기로만 낸다 — 요일 헤더를
/// `본문색 + w700`으로 해결한 것과 같은 수법이다. 가드 테스트가 이 위젯이
/// `AppColors.busSignal*`을 쓰지 않는다는 사실을 지킨다.
class BusBodyText extends StatelessWidget {
  const BusBodyText({super.key, required this.view});

  final BusCardView view;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.spacing16,
      runSpacing: AppSizes.spacing4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ...view.visible.map(_entry),
        if (view.hiddenCount > 0)
          Text(
            BusStrings.moreCount(view.hiddenCount),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
      ],
    );
  }

  Widget _entry(BusArrival arrival) {
    final urgent = isUrgent(arrival.arrMin);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${arrival.routeNo}번',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: urgent ? FontWeight.w700 : FontWeight.w600,
            color: urgent ? AppColors.ink : AppColors.sub,
          ),
        ),
        const SizedBox(width: AppSizes.spacing4),
        Text(
          arrival.arrMin == 0
              ? BusStrings.arrivingNow
              : BusStrings.minutes(arrival.arrMin),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: urgent ? 18 : 14,
            fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: urgent ? -0.4 : 0,
            color: urgent ? AppColors.ink : AppColors.sub,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: `BusBodyAxis`를 만든다**

`lib/features/bus/presentation/widgets/bus_body_axis.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_card_view.dart';

/// `시간 축` 본문 — 0~15분 축에 버스를 점으로 놓는다.
///
/// 간격이 공간으로 보여 "이거 놓치면 6분 더"가 숫자 없이 읽힌다. 대신 두 버스가
/// 3분 안으로 붙으면 점과 라벨이 겹치고 15분 넘는 버스는 오른쪽 끝에 몰린다 —
/// 그래서 기본값이 아니라 선택지다.
class BusBodyAxis extends StatelessWidget {
  const BusBodyAxis({super.key, required this.view});

  /// 축이 담는 최대 분.
  static const axisRange = 15;

  static const _minFraction = 0.03;
  static const _maxFraction = 0.97;

  final BusCardView view;

  /// 축 위 위치를 0~1로. **양 끝에서 점이 반쯤 잘리지 않게 clamp한다.**
  static double dotPosition(int arrMin) {
    final raw = arrMin / axisRange;
    return raw.clamp(_minFraction, _maxFraction);
  }

  static Color _dotColor(int arrMin) {
    if (isUrgent(arrMin)) return AppColors.busSignalNear;
    if (isSoon(arrMin)) return AppColors.busSignalSoon;
    return AppColors.busSignalFar;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _scale(),
        const SizedBox(height: 2),
        SizedBox(height: 14, child: _rail()),
        const SizedBox(height: 2),
        SizedBox(height: 15, child: _labels()),
      ],
    );
  }

  Widget _scale() {
    TextStyle style() => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          color: AppColors.faint,
        );
    return Row(
      children: [
        Text('지금', style: style()),
        const Spacer(),
        Text('5분', style: style()),
        const Spacer(),
        Text('10분', style: style()),
        const Spacer(),
        Text('15분', style: style()),
      ],
    );
  }

  Widget _rail() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.busSignalOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ...view.visible.map((a) => _dot(a, width)),
          ],
        );
      },
    );
  }

  Widget _dot(BusArrival arrival, double width) {
    const size = 12.0;
    return Positioned(
      left: (dotPosition(arrival.arrMin) * width) - (size / 2),
      top: 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _dotColor(arrival.arrMin),
          // 카드 배경색으로 테두리를 둘러 레일과 겹칠 때 형태가 유지된다.
          border: Border.all(color: AppColors.background, width: 2),
        ),
      ),
    );
  }

  Widget _labels() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: view.visible.map((a) {
            final urgent = isUrgent(a.arrMin);
            return Positioned(
              left: (dotPosition(a.arrMin) * width) - 14,
              top: 0,
              width: 28,
              child: Text(
                a.routeNo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: urgent ? AppColors.ink : AppColors.sub,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

- [ ] **Step 5: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_body_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: 기본 모양이 신호색을 안 쓴다는 가드를 붙인다**

`test/features/bus/bus_body_test.dart`의 `main()` 끝에 추가한다:

```dart
  test('가드 — 기본 모양 소스가 busSignal 토큰을 참조하지 않는다', () {
    // 기본 경험의 팔레트 불변을 소스 수준에서 지킨다. 위젯 렌더로는 "색을 쓰지
    // 않았음"을 증명하기 어렵다.
    final source = File(
      'lib/features/bus/presentation/widgets/bus_body_text.dart',
    ).readAsStringSync();
    expect(source.contains('busSignal'), isFalse,
        reason: '간단히 모양은 신호색을 쓰지 않는다 — 팔레트 충돌을 기본값에서 없앤다');
  });
```

파일 상단 import에 `import 'dart:io';`를 추가한다.

- [ ] **Step 6: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_body_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 8: 커밋**

```bash
git add lib/features/bus/presentation/widgets/bus_body_text.dart \
        lib/features/bus/presentation/widgets/bus_body_axis.dart \
        test/features/bus/bus_body_test.dart
git commit -m "feat(bus): 카드 본문 두 모양을 만든다 — 간단히 / 시간 축

간단히(기본)는 새 색 토큰을 하나도 참조하지 않는다. 임박을 굵기·크기로만
낸다 — 요일 헤더를 본문색 + w700으로 해결한 것과 같은 수법이다. 소스에
busSignal 문자열이 없다는 가드를 붙였다: 위젯 렌더로는 '색을 쓰지 않았음'을
증명하기 어렵다.

시간 축은 dotPosition을 순수 static으로 노출해 위젯을 띄우지 않고 clamp를
검사한다. 0~15분을 3~97%로 clamp해 양 끝에서 점이 반쯤 잘리지 않게 하고,
점에 카드 배경색 테두리를 둘러 레일과 겹칠 때 형태가 유지되게 한다."
```

---

### Task 11: `BusArrivalCard` — 제목줄 접기 + 빈 상태

**Files:**
- Create: `lib/features/bus/presentation/widgets/bus_empty_state.dart`
- Create: `lib/features/bus/presentation/widgets/bus_arrival_card.dart`
- Test: `test/features/bus/bus_arrival_card_test.dart`

**Interfaces:**
- Consumes: `BusCardView`·`BusCardState` (Task 7), `BusBodyText`·`BusBodyAxis` (Task 10), `BusCardStyle`·`CommuteDirection`·`BusStop` (Task 2)
- Produces:
  - `class BusEmptyState extends StatelessWidget { const BusEmptyState({super.key, required this.state, this.onRetry, this.onRegister}); }`
  - `class BusArrivalCard extends StatelessWidget { const BusArrivalCard({super.key, required this.view, required this.style, required this.direction, required this.stopName, required this.expanded, required this.onToggleExpanded, required this.onFlipDirection, this.onRetry, this.onRegister}); static const headerKey = Key('bus_card_header'); static const flipKey = Key('bus_card_flip'); }`

**접기 규칙(스펙 §1):** 제목줄 전체가 탭 대상이고 chevron은 오른쪽 끝에 고정된다. 접으면 본문·하단·기준시각이 사라지고 방향·정류장·chevron은 남는다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_arrival_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

BusCardView _view({
  BusCardState state = BusCardState.ok,
  List<BusArrival>? items,
  int hidden = 0,
  DateTime? fetchedAt,
}) {
  return BusCardView(
    state: state,
    visible: items ?? [const BusArrival(routeId: 'A', routeNo: '720', arrMin: 2)],
    hiddenCount: hidden,
    fetchedAt: fetchedAt ?? DateTime(2026, 7, 28, 7, 32),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required BusCardView view,
  BusCardStyle style = BusCardStyle.text,
  bool expanded = true,
  VoidCallback? onToggle,
  VoidCallback? onFlip,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BusArrivalCard(
        view: view,
        style: style,
        direction: CommuteDirection.toWork,
        stopName: '수원시청',
        expanded: expanded,
        onToggleExpanded: onToggle ?? () {},
        onFlipDirection: onFlip ?? () {},
      ),
    ),
  ));
}

void main() {
  group('펼침', () {
    testWidgets('방향·정류장·기준시각·본문·방향토글이 모두 보인다', (tester) async {
      await _pump(tester, view: _view());
      expect(find.text('🏠→🏫 출근'), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(find.byType(BusBodyText), findsOneWidget);
      expect(find.textContaining('퇴근 보기'), findsOneWidget);
    });

    testWidgets('모양이 axis면 축 본문을 그린다', (tester) async {
      await _pump(tester, view: _view(), style: BusCardStyle.axis);
      expect(find.byType(BusBodyAxis), findsOneWidget);
      expect(find.byType(BusBodyText), findsNothing);
    });
  });

  group('접힘 — 사라지는 것과 남는 것', () {
    testWidgets('본문·기준시각·방향토글이 사라지고 방향·정류장은 남는다', (tester) async {
      await _pump(tester, view: _view(), expanded: false);

      expect(find.byType(BusBodyText), findsNothing);
      expect(find.text('07:32 기준'), findsNothing);
      expect(find.textContaining('퇴근 보기'), findsNothing);

      expect(find.text('🏠→🏫 출근'), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
    });

    testWidgets('도착 분이 남지 않는다 — 안 보이게 하는 것이 목적이다', (tester) async {
      await _pump(tester, view: _view(), expanded: false);
      expect(find.text('2분'), findsNothing);
      expect(find.text('720번'), findsNothing);
    });
  });

  group('제목줄이 같은 칸에서 토글된다', () {
    testWidgets('펼침에서 제목줄을 누르면 콜백이 온다', (tester) async {
      var tapped = 0;
      await _pump(tester, view: _view(), onToggle: () => tapped++);
      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      expect(tapped, 1);
    });

    testWidgets('접힘에서도 같은 키를 누른다 — 표적이 움직이지 않는다', (tester) async {
      var tapped = 0;
      await _pump(tester, view: _view(), expanded: false, onToggle: () => tapped++);
      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      expect(tapped, 1);
    });

    testWidgets('접힘과 펼침에서 제목줄의 y좌표가 같다', (tester) async {
      await _pump(tester, view: _view());
      final expandedY = tester.getTopLeft(find.byKey(BusArrivalCard.headerKey)).dy;

      await _pump(tester, view: _view(), expanded: false);
      final collapsedY = tester.getTopLeft(find.byKey(BusArrivalCard.headerKey)).dy;

      expect(collapsedY, expandedY);
    });
  });

  testWidgets('방향 토글은 별 콜백이다', (tester) async {
    var flipped = 0;
    await _pump(tester, view: _view(), onFlip: () => flipped++);
    await tester.tap(find.byKey(BusArrivalCard.flipKey));
    expect(flipped, 1);
  });

  group('실패 계약 — 다섯 상태가 서로 다르게 읽힌다', () {
    testWidgets('closed / down / keyError / noStop 문구가 각각 다르다', (tester) async {
      await _pump(tester, view: _view(state: BusCardState.closed, items: const []));
      expect(find.text('오늘 운행이 끝났어요'), findsOneWidget);

      await _pump(tester, view: _view(state: BusCardState.down, items: const []));
      expect(find.text('지금 정보를 못 받았어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);

      await _pump(tester, view: _view(state: BusCardState.keyError, items: const []));
      expect(find.text('버스 정보를 불러올 수 없어요'), findsOneWidget);

      await _pump(tester, view: _view(state: BusCardState.noStop, items: const []));
      expect(find.text('정류장을 등록하면 도착시간이 보여요'), findsOneWidget);
    });

    testWidgets('stale은 목록을 유지하고 갱신 실패를 고백한다', (tester) async {
      await _pump(tester, view: _view(state: BusCardState.stale));
      expect(find.byType(BusBodyText), findsOneWidget);
      expect(find.text('07:32 기준 · 갱신 실패'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_arrival_card_test.dart`
Expected: 컴파일 실패 — 두 위젯 파일이 없다.

- [ ] **Step 3: `BusEmptyState`를 만든다**

`lib/features/bus/presentation/widgets/bus_empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_card_view.dart';

/// 실패 계약의 비정상 상태 문구 (스펙 §3).
///
/// 네 상태가 **서로 다르게 읽혀야 한다.** 막차 끝남과 앱 고장을 같은 문구로
/// 뭉개면 사용자가 정류장에서 기다릴지 택시를 부를지 판단할 수 없다.
class BusEmptyState extends StatelessWidget {
  const BusEmptyState({
    super.key,
    required this.state,
    this.onRetry,
    this.onRegister,
  });

  final BusCardState state;
  final VoidCallback? onRetry;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final (title, hint, action, onAction) = switch (state) {
      BusCardState.closed => (BusStrings.emptyClosed, null, null, null),
      BusCardState.down => (
          BusStrings.emptyDown,
          null,
          BusStrings.emptyDownAction,
          onRetry,
        ),
      BusCardState.keyError => (
          BusStrings.emptyKey,
          BusStrings.emptyKeyHint,
          null,
          null,
        ),
      BusCardState.noStop => (
          BusStrings.emptyNoStop,
          null,
          BusStrings.emptyNoStopAction,
          onRegister,
        ),
      _ => (BusStrings.emptyClosed, null, null, null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: AppColors.sub,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSizes.spacing4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Text(
              action,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: `BusArrivalCard`를 만든다**

`lib/features/bus/presentation/widgets/bus_arrival_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/bus_card_style.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/commute_direction.dart';
import 'bus_body_axis.dart';
import 'bus_body_text.dart';
import 'bus_empty_state.dart';

/// 오늘 탭 최상단 버스 카드.
///
/// **제목줄 전체가 접기/펼치기다.** chevron을 오른쪽 끝에 고정해 접든 펼치든
/// 표적이 움직이지 않는다 — `_overdueHeader`(`기한이 지난`)와 같은 구조다.
/// 접힌 상태를 별도 pill로 만들지 않는 이유도 여기다: 컨테이너가 모양을 바꾸면
/// 제목줄이 미묘하게 이동해 "같은 칸"이 깨진다.
class BusArrivalCard extends StatelessWidget {
  const BusArrivalCard({
    super.key,
    required this.view,
    required this.style,
    required this.direction,
    required this.stopName,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onFlipDirection,
    this.onRetry,
    this.onRegister,
  });

  static const headerKey = Key('bus_card_header');
  static const flipKey = Key('bus_card_flip');

  final BusCardView view;
  final BusCardStyle style;
  final CommuteDirection direction;
  final String stopName;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onFlipDirection;
  final VoidCallback? onRetry;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing12,
        AppSizes.pagePadding,
        AppSizes.spacing8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing12,
        vertical: AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (expanded) ...[
            const SizedBox(height: AppSizes.spacing8),
            _body(),
            if (view.hasRows) ...[
              const SizedBox(height: AppSizes.spacing4),
              _flip(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      key: headerKey,
      behavior: HitTestBehavior.opaque,
      onTap: onToggleExpanded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            direction.label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          Expanded(
            child: Text(
              '· $stopName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: AppColors.sub,
              ),
            ),
          ),
          // 접히면 기준시각도 사라진다 — 폴링을 멈추니 신선도를 말할 근거가 없다.
          if (expanded && _stamp() != null) ...[
            Text(
              _stamp() ?? '',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                color: view.state == BusCardState.stale
                    ? AppColors.inkRed
                    : AppColors.faint,
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
          ],
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: AppSizes.iconSmall,
            color: AppColors.gold,
            semanticLabel: expanded ? BusStrings.collapse : BusStrings.expand,
          ),
        ],
      ),
    );
  }

  /// `07:32 기준` — 캐시 신선도를 감추지 않고 고백한다.
  String? _stamp() {
    final at = view.fetchedAt;
    if (at == null) return null;
    final hhmm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return view.state == BusCardState.stale
        ? BusStrings.basedOnStale(hhmm)
        : BusStrings.basedOn(hhmm);
  }

  Widget _body() {
    if (!view.hasRows) {
      return BusEmptyState(
        state: view.state,
        onRetry: onRetry,
        onRegister: onRegister,
      );
    }
    return switch (style) {
      BusCardStyle.text => BusBodyText(view: view),
      BusCardStyle.axis => BusBodyAxis(view: view),
    };
  }

  Widget _flip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        key: flipKey,
        behavior: HitTestBehavior.opaque,
        onTap: onFlipDirection,
        child: Text(
          '${direction.otherLabel} ⌄',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_arrival_card_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/features/bus/presentation/widgets/bus_arrival_card.dart \
        lib/features/bus/presentation/widgets/bus_empty_state.dart \
        test/features/bus/bus_arrival_card_test.dart
git commit -m "feat(bus): 카드를 조립한다 — 제목줄 접기 + 실패 계약 5상태

제목줄 전체가 접기/펼치기이고 chevron은 오른쪽 끝에 고정된다. 접기를 카드
하단에, 펼치기를 별도 줄에 두면 누를 때마다 표적이 위아래로 움직인다 —
_overdueHeader(기한이 지난)와 같은 구조로 맞췄다. 접힘·펼침에서 제목줄
y좌표가 같다는 테스트가 이것을 지킨다.

접으면 본문·방향토글과 함께 기준시각도 사라진다 — 폴링을 멈추니 신선도를
말할 근거가 없다. 도착 분이 남지 않는다는 테스트를 따로 뒀다(안 보이게
하는 것이 접기의 목적이다).

빈 상태 네 문구가 서로 달라야 한다. 막차 끝남과 앱 고장을 뭉개면 사용자가
정류장에서 기다릴지 택시를 부를지 판단할 수 없다."
```

---

### Task 12: 설정 탭 섹션

**Files:**
- Create: `lib/features/settings/presentation/widgets/bus_settings_tiles.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart` (`완료 도장` 섹션 다음에 1개 삽입)
- Modify: `lib/core/router/app_router.dart` (`AppRoutes.busStops` + `GoRoute`)
- Test: `test/features/bus/bus_settings_tiles_test.dart`

**Interfaces:**
- Consumes: `busSettingsProvider` (Task 9), `BusStrings` (Task 1), `BusCardStyle`·`CommuteDirection`·`TimeRange` (Task 2·3)
- Produces:
  - `class BusSettingsTiles extends ConsumerWidget { static const switchKey = Key('bus_show_switch'); static const departureKey = Key('bus_slot_departure'); static const arrivalKey = Key('bus_slot_arrival'); static const styleKey = Key('bus_style_row'); static const rangeToWorkKey = Key('bus_range_to_work'); static const rangeToHomeKey = Key('bus_range_to_home'); }`
  - `AppRoutes.busStops == '/bus/stops'`

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_settings_tiles_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: Scaffold(body: BusSettingsTiles())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('기본은 꺼짐이고 나머지 줄이 감춰져 있다', (tester) async {
    await _pump(tester);

    expect(find.byKey(BusSettingsTiles.switchKey), findsOneWidget);
    expect(find.text('꺼져 있어 오늘 탭이 지금과 같습니다'), findsOneWidget);

    expect(find.byKey(BusSettingsTiles.departureKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.styleKey), findsNothing);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsNothing);
  });

  testWidgets('켜면 다섯 줄이 나타난다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

    expect(find.text('지정한 시간대에만 펼쳐집니다'), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.departureKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.arrivalKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.styleKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToWorkKey), findsOneWidget);
    expect(find.byKey(BusSettingsTiles.rangeToHomeKey), findsOneWidget);
  });

  testWidgets('시간대 기본값이 라벨로 보인다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

    expect(find.text('07:00 – 08:30'), findsOneWidget);
    expect(find.text('16:00 – 18:00'), findsOneWidget);
  });

  testWidgets('슬롯이 비면 선택 안내가 보인다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();
    expect(find.text('정류장 선택'), findsNWidgets(2));
  });

  testWidgets('카드 모양 기본은 간단히이고 눌러 바꿀 수 있다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(BusSettingsTiles.switchKey));
    await tester.pumpAndSettle();

    expect(find.text('간단히'), findsOneWidget);

    await tester.tap(find.text('시간 축'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusSettingsTiles)),
    );
    expect(
      container.read(busSettingsProvider).requireValue.style.label,
      '시간 축',
    );
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_settings_tiles_test.dart`
Expected: 컴파일 실패 — `bus_settings_tiles.dart`가 없다.

- [ ] **Step 3: `AppRoutes`에 경로를 추가한다**

`lib/core/router/app_router.dart` — `static const import = '/import';` 다음 줄:

```dart
  static const busStops = '/bus/stops';
```

`GoRoute(path: AppRoutes.import, ...)` 블록 다음에 추가한다(import 문도 함께 추가):

```dart
            GoRoute(
              path: AppRoutes.busStops,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: BusStopSearchScreen(),
              ),
            ),
```

파일 상단 import에 추가:

```dart
import '../../features/bus/presentation/screens/bus_stop_search_screen.dart';
```

> Task 13에서 `BusStopSearchScreen`을 만든다. **이 Step은 Task 13과 함께 커밋한다** — 지금 넣으면 컴파일이 깨진다. Task 12에서는 `AppRoutes.busStops` 상수만 추가하고 `GoRoute`와 import는 Task 13에서 붙인다.

- [ ] **Step 4: `BusSettingsTiles`를 만든다**

`lib/features/settings/presentation/widgets/bus_settings_tiles.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../bus/domain/bus_card_style.dart';
import '../../../bus/domain/bus_settings.dart';
import '../../../bus/domain/commute_direction.dart';
import '../../../bus/domain/time_range.dart';
import '../../../bus/presentation/providers/bus_providers.dart';

/// `설정 > 버스 도착` 섹션 본문.
///
/// 스위치가 꺼져 있으면 나머지 줄을 감춘다 — 기본이 꺼짐이라 이 기능을 쓰지 않는
/// 사용자에게 설정 탭도 지금과 거의 같게 보인다.
class BusSettingsTiles extends ConsumerWidget {
  const BusSettingsTiles({super.key});

  static const switchKey = Key('bus_show_switch');
  static const departureKey = Key('bus_slot_departure');
  static const arrivalKey = Key('bus_slot_arrival');
  static const styleKey = Key('bus_style_row');
  static const rangeToWorkKey = Key('bus_range_to_work');
  static const rangeToHomeKey = Key('bus_range_to_home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(busSettingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();

    final notifier = ref.read(busSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: switchKey,
          value: settings.enabled,
          onChanged: notifier.setEnabled,
          activeColor: AppColors.goldFill,
          title: Text(BusStrings.showTitle, style: _titleStyle),
          subtitle: Text(
            settings.enabled
                ? BusStrings.showSubtitleOn
                : BusStrings.showSubtitleOff,
            style: _subStyle,
          ),
        ),
        if (settings.enabled) ...[
          _slotTile(
            context,
            key: departureKey,
            title: BusStrings.slotDeparture,
            hint: BusStrings.slotDepartureHint,
            value: settings.departure?.nodeNm,
            direction: CommuteDirection.toWork,
          ),
          _slotTile(
            context,
            key: arrivalKey,
            title: BusStrings.slotArrival,
            hint: BusStrings.slotArrivalHint,
            value: settings.arrival?.nodeNm,
            direction: CommuteDirection.toHome,
          ),
          _styleRow(settings, notifier),
          _rangeTile(
            context,
            key: rangeToWorkKey,
            title: BusStrings.rangeToWork,
            hint: BusStrings.rangeHintToWork,
            range: settings.toWorkRange,
            direction: CommuteDirection.toWork,
            notifier: notifier,
          ),
          _rangeTile(
            context,
            key: rangeToHomeKey,
            title: BusStrings.rangeToHome,
            hint: BusStrings.rangeHintToHome,
            range: settings.toHomeRange,
            direction: CommuteDirection.toHome,
            notifier: notifier,
          ),
        ],
      ],
    );
  }

  TextStyle get _titleStyle => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  TextStyle get _subStyle => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        color: AppColors.sub,
      );

  Widget _slotTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String hint,
    required String? value,
    required CommuteDirection direction,
  }) {
    return ListTile(
      key: key,
      title: Text(title, style: _titleStyle),
      subtitle: Text(hint, style: _subStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value ?? BusStrings.slotEmpty,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: value == null ? AppColors.faint : AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
        ],
      ),
      onTap: () => context.push('${AppRoutes.busStops}?slot=${direction.name}'),
    );
  }

  Widget _styleRow(BusSettings settings, BusSettingsNotifier notifier) {
    return Padding(
      key: styleKey,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing8,
        AppSizes.pagePadding,
        AppSizes.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BusStrings.cardStyle, style: _titleStyle),
          Text(BusStrings.cardStyleHint, style: _subStyle),
          const SizedBox(height: AppSizes.spacing8),
          SegmentedButton<BusCardStyle>(
            segments: BusCardStyle.values
                .map((s) => ButtonSegment(value: s, label: Text(s.label)))
                .toList(),
            selected: {settings.style},
            showSelectedIcon: false,
            onSelectionChanged: (set) => notifier.setStyle(set.first),
          ),
        ],
      ),
    );
  }

  Widget _rangeTile(
    BuildContext context, {
    required Key key,
    required String title,
    required String hint,
    required TimeRange range,
    required CommuteDirection direction,
    required BusSettingsNotifier notifier,
  }) {
    return ListTile(
      key: key,
      title: Text(title, style: _titleStyle),
      subtitle: Text(hint, style: _subStyle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            range.label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
        ],
      ),
      onTap: () => _pickRange(context, range, direction, notifier),
    );
  }

  /// 시작·종료를 차례로 고른다. 겹치거나 뒤집히면 `setRange`가 저장을 거부하고
  /// 스낵바로 알린다.
  Future<void> _pickRange(
    BuildContext context,
    TimeRange current,
    CommuteDirection direction,
    BusSettingsNotifier notifier,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.startMinutes ~/ 60,
        minute: current.startMinutes % 60,
      ),
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.endMinutes ~/ 60,
        minute: current.endMinutes % 60,
      ),
    );
    if (end == null || !context.mounted) return;

    final next = TimeRange.hm(start.hour, start.minute, end.hour, end.minute);
    if (!next.isValid) {
      _toast(context, BusStrings.rangeInverted);
      return;
    }
    await notifier.setRange(direction, next);
    if (!context.mounted) return;

    // setRange가 겹침을 거부했으면 값이 그대로다 — 사용자에게 알린다.
    final saved = notifier.state.valueOrNull;
    final applied = saved == null
        ? false
        : saved.rangeFor(direction).label == next.label;
    if (!applied) _toast(context, BusStrings.rangeOverlap);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
```

- [ ] **Step 5: 설정 화면에 섹션을 끼운다**

`lib/features/settings/presentation/screens/settings_screen.dart` — `완료 도장` 섹션(`SettingsStrings.stampSection`) **다음**, `현재 일정 내보내기` **앞**에 삽입한다:

```dart
          const SettingsSection(
            title: BusStrings.section,
            subtitle: BusStrings.sectionDescription,
            child: BusSettingsTiles(),
          ),
```

import 추가:

```dart
import '../widgets/bus_settings_tiles.dart';
```

> `완료 도장` 다음에 두는 이유: 둘 다 오늘 탭의 표시를 바꾸는 설정이라 붙여두면 찾기 쉽다.

- [ ] **Step 6: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_settings_tiles_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 7: 기존 테스트가 안 깨졌는지 본다**

Run: `flutter test`
Expected: 기존 480개 + 신규 전부 PASS

- [ ] **Step 8: 커밋**

```bash
git add lib/features/settings/presentation/widgets/bus_settings_tiles.dart \
        lib/features/settings/presentation/screens/settings_screen.dart \
        lib/core/router/app_router.dart \
        test/features/bus/bus_settings_tiles_test.dart
git commit -m "feat(bus): 설정 탭에 버스 도착 섹션을 넣는다

완료 도장 다음에 둔다 — 둘 다 오늘 탭의 표시를 바꾸는 설정이라 붙여두면
찾기 쉽다.

스위치가 꺼져 있으면 나머지 다섯 줄을 감춘다. 기본이 꺼짐이라 이 기능을
쓰지 않는 사용자에게는 설정 탭도 지금과 거의 같게 보인다.

시간대 피커는 시작·종료를 차례로 고른다. 겹치면 setRange가 저장을 거부하고
스낵바로 알린다 — 조용히 무시하면 사용자는 저장된 줄 안다."
```

---

### Task 13: 정류장 검색 화면 + 확인 시트

**Files:**
- Create: `lib/features/bus/presentation/screens/bus_stop_search_screen.dart`
- Modify: `lib/core/router/app_router.dart` (`GoRoute` + import — Task 12에서 상수만 넣었다)
- Test: `test/features/bus/bus_stop_search_test.dart`

**Interfaces:**
- Consumes: `BusApiClient`·`busSettingsProvider` (Task 8·9), `BusStop`·`CommuteDirection` (Task 2), `BusStrings` (Task 1)
- Produces:
  - `class BusStopSearchScreen extends ConsumerStatefulWidget { const BusStopSearchScreen({super.key, this.slot}); static const cityFieldKey = Key('bus_city_field'); static const stopFieldKey = Key('bus_stop_field'); static const confirmAcceptKey = Key('bus_confirm_accept'); }`
  - `class BusStopConfirmSheet extends StatefulWidget { static Future<BusStop?> show(BuildContext, {required BusStop stop, required List<BusArrival> arrivals}); }`

**핵심(스펙 §4):** 정류장을 탭하면 바로 저장하지 않고 **그 정류장에 오는 버스를 조회해** 보여준다. 방향은 이름·좌표로 판별 불가하고(실측: 같은 이름 두 개, 좌표 60m 차이) 사용자는 자기가 타는 노선 번호를 안다. 같은 시트에서 노선도 고른다 — **전부 체크면 빈 집합으로 저장**한다.

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_stop_search_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/presentation/screens/bus_stop_search_screen.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청.수원일자리센터',
  nodeNo: 2251,
  cityCode: 31010,
);

final _arrivals = [
  const BusArrival(routeId: 'R1', routeNo: '82-1', arrMin: 8),
  const BusArrival(routeId: 'R2', routeNo: '92', arrMin: 10),
  const BusArrival(routeId: 'R3', routeNo: '92-1', arrMin: 10),
];

/// 확인 시트만 띄워 노선 선택 규칙을 검사한다.
Future<BusStop?> _showSheet(
  WidgetTester tester, {
  List<BusArrival>? arrivals,
}) async {
  BusStop? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await BusStopConfirmSheet.show(
              context,
              stop: _stop,
              arrivals: arrivals ?? _arrivals,
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('확인 시트 — 방향을 노선 번호로 판별하게 한다', () {
    testWidgets('정류장 이름·번호와 오는 버스를 보여준다', (tester) async {
      await _showSheet(tester);
      expect(find.text('이 정류장이 맞나요?'), findsOneWidget);
      expect(find.textContaining('수원시청.수원일자리센터'), findsOneWidget);
      expect(find.textContaining('2251'), findsOneWidget);
      expect(find.text('82-1번'), findsOneWidget);
      expect(find.text('92-1번'), findsOneWidget);
    });

    testWidgets('기본은 전부 체크다 — 방향만 확인하려는 사람을 막지 않는다', (tester) async {
      await _showSheet(tester);
      final boxes = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(boxes.length, 3);
      expect(boxes.every((b) => b.value == true), isTrue);
    });

    testWidgets('전부 체크한 채 맞아요를 누르면 routeIds가 빈 집합이다', (tester) async {
      final saved = await _tapAccept(tester);
      expect(saved?.routeIds, isEmpty,
          reason: '전부를 열거해 저장하면 신설 노선이 영구히 안 보인다');
    });

    testWidgets('일부만 체크하면 그것만 저장된다', (tester) async {
      final saved = await _tapAccept(tester, uncheck: ['92번']);
      expect(saved?.routeIds, {'R1', 'R3'});
    });

    testWidgets('전부 해제하면 저장이 막힌다', (tester) async {
      final saved = await _tapAccept(
        tester,
        uncheck: ['82-1번', '92번', '92-1번'],
        expectBlocked: true,
      );
      expect(saved, isNull);
      expect(find.text('버스를 하나 이상 남겨주세요'), findsOneWidget);
    });

    testWidgets('오는 버스가 없으면 안내하고 노선 없이 저장할 수 있다', (tester) async {
      final saved = await _tapAccept(tester, arrivals: const []);
      expect(find.text('지금 이 정류장에 오는 버스가 없어요'), findsOneWidget);
      expect(saved?.routeIds, isEmpty);
    });
  });
}

/// 시트를 띄우고 필요한 체크를 해제한 뒤 `맞아요`를 누른다.
Future<BusStop?> _tapAccept(
  WidgetTester tester, {
  List<String> uncheck = const [],
  List<BusArrival>? arrivals,
  bool expectBlocked = false,
}) async {
  BusStop? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await BusStopConfirmSheet.show(
              context,
              stop: _stop,
              arrivals: arrivals ?? _arrivals,
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();

  for (final label in uncheck) {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(BusStopSearchScreen.confirmAcceptKey));
  await tester.pumpAndSettle();
  return result;
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_stop_search_test.dart`
Expected: 컴파일 실패 — `bus_stop_search_screen.dart`가 없다.

- [ ] **Step 3: 화면과 시트를 만든다**

`lib/features/bus/presentation/screens/bus_stop_search_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/tago_response_parser.dart';
import '../../domain/bus_arrival.dart';
import '../../domain/bus_stop.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';

/// 도시 선택 → 정류장 이름 검색 → 확인 시트 → 슬롯 저장.
///
/// GPS 근접 검색을 쓰지 않는다. 슬롯을 **교체**하는 순간(전근·이사)에는 대상
/// 정류장 근처에 없는 것이 기본값이라 GPS가 못 쓰인다 — 이름 검색만 항상 작동한다.
class BusStopSearchScreen extends ConsumerStatefulWidget {
  const BusStopSearchScreen({super.key, this.slot});

  /// 채울 슬롯. `/bus/stops?slot=toWork` 쿼리로 넘어온다.
  final CommuteDirection? slot;

  static const cityFieldKey = Key('bus_city_field');
  static const stopFieldKey = Key('bus_stop_field');
  static const confirmAcceptKey = Key('bus_confirm_accept');

  @override
  ConsumerState<BusStopSearchScreen> createState() =>
      _BusStopSearchScreenState();
}

class _BusStopSearchScreenState extends ConsumerState<BusStopSearchScreen> {
  final _cityFilter = TextEditingController();
  final _stopQuery = TextEditingController();

  List<CityCode> _cities = const [];
  CityCode? _city;
  List<BusStop> _results = const [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _cityFilter.dispose();
    _stopQuery.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() => _loading = true);
    final result = await ref.read(busApiClientProvider).fetchCities();
    if (!mounted) return;
    setState(() {
      _cities = result.items;
      _loading = false;
      // 마지막으로 쓴 도시를 기본 선택으로 — 교체할 때 다시 고르지 않는다.
      final saved = ref.read(busSettingsProvider).valueOrNull;
      final code = saved?.departure?.cityCode ?? saved?.arrival?.cityCode;
      final matched = _cities.where((c) => c.code == code).toList();
      _city = matched.isEmpty ? null : matched.first;
    });
  }

  Future<void> _search() async {
    final city = _city;
    final name = _stopQuery.text.trim();
    if (city == null || name.isEmpty) return;

    setState(() => _loading = true);
    final result = await ref
        .read(busApiClientProvider)
        .searchStops(cityCode: city.code, name: name);
    if (!mounted) return;
    setState(() {
      _results = result.items;
      _loading = false;
      _searched = true;
    });
  }

  /// 정류장을 탭했을 때 — 바로 저장하지 않고 오는 버스를 조회해 확인받는다.
  Future<void> _pick(BusStop stop) async {
    setState(() => _loading = true);
    final fetch = await ref
        .read(busApiClientProvider)
        .fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId);
    if (!mounted) return;
    setState(() => _loading = false);

    final confirmed = await BusStopConfirmSheet.show(
      context,
      stop: stop,
      arrivals: fetch.arrivals,
    );
    if (confirmed == null || !mounted) return;

    final slot = widget.slot ?? CommuteDirection.toWork;
    await ref.read(busSettingsProvider.notifier).setStop(slot, confirmed);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cities = _cityFilter.text.trim().isEmpty
        ? _cities
        : _cities
            .where((c) => c.name.contains(_cityFilter.text.trim()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(BusStrings.searchTitle, style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing48),
        children: [
          _cityPicker(cities),
          const Divider(height: 1),
          _stopSearchField(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSizes.spacing24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._resultRows(),
        ],
      ),
    );
  }

  /// 도시코드는 시·군 단위로 전국 138개다 — 스크롤만으로 고르게 하면 마찰이 크므로
  /// 검색 필드를 둔다.
  Widget _cityPicker(List<CityCode> cities) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BusStrings.cityLabel, style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSizes.spacing8),
          TextField(
            key: BusStopSearchScreen.cityFieldKey,
            controller: _cityFilter,
            decoration: InputDecoration(hintText: BusStrings.citySearchHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing4,
            children: cities.take(20).map((c) {
              final selected = c.code == _city?.code;
              return ChoiceChip(
                label: Text(c.name),
                selected: selected,
                onSelected: (_) => setState(() => _city = c),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _stopSearchField() {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: TextField(
        key: BusStopSearchScreen.stopFieldKey,
        controller: _stopQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: BusStrings.stopSearchHint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  List<Widget> _resultRows() {
    if (!_searched) {
      return [_notice(BusStrings.searchPrompt)];
    }
    if (_results.isEmpty) {
      return [_notice(BusStrings.searchEmpty)];
    }
    return _results
        .map((stop) => ListTile(
              title: Text(stop.nodeNm),
              subtitle: Text('${stop.nodeNo}'),
              trailing: Icon(Icons.chevron_right, color: AppColors.faint),
              onTap: () => _pick(stop),
            ))
        .toList();
  }

  Widget _notice(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing24,
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }
}

/// 저장 직전 확인 — 방향이 조용히 틀리는 것을 막는다.
///
/// 실측: `수원시청.수원일자리센터`가 `GGB201000156`과 `GGB202000003` 두 개이고
/// 좌표 차이는 약 60m다. 이름으로도 좌표로도 사람이 고를 수 없지만 **자기가 타는
/// 버스 번호는 안다.** 잘못 고르면 화면에는 버스가 정상적으로 뜨는데 전부 반대
/// 방향이라, 사용자는 앱이 고장 났다고 생각하지 않고 자기가 늦었다고 생각한다.
class BusStopConfirmSheet extends StatefulWidget {
  const BusStopConfirmSheet({
    super.key,
    required this.stop,
    required this.arrivals,
  });

  final BusStop stop;
  final List<BusArrival> arrivals;

  static Future<BusStop?> show(
    BuildContext context, {
    required BusStop stop,
    required List<BusArrival> arrivals,
  }) {
    return showModalBottomSheet<BusStop>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BusStopConfirmSheet(stop: stop, arrivals: arrivals),
    );
  }

  @override
  State<BusStopConfirmSheet> createState() => _BusStopConfirmSheetState();
}

class _BusStopConfirmSheetState extends State<BusStopConfirmSheet> {
  late Set<String> _checked;

  @override
  void initState() {
    super.initState();
    // 기본은 전부 체크 — 방향만 확인하려는 사람이 `맞아요`만 눌러도 되게.
    _checked = widget.arrivals.map((a) => a.routeId).toSet();
  }

  void _accept() {
    if (widget.arrivals.isNotEmpty && _checked.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text(BusStrings.confirmNeedRoute)));
      return;
    }

    // 전부 체크된 상태는 **빈 집합**으로 저장한다. 열거해 저장하면 "전부"가
    // "이 다섯 개"로 굳어 노선이 신설됐을 때 영구히 안 보인다.
    final all = widget.arrivals.map((a) => a.routeId).toSet();
    final selected = _checked.length == all.length ? <String>{} : _checked;

    Navigator.of(context).pop(widget.stop.copyWith(routeIds: selected));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(BusStrings.confirmTitle, style: AppTextStyles.heading),
            const SizedBox(height: AppSizes.spacing8),
            Text(
              '${widget.stop.nodeNm}  ${widget.stop.nodeNo}',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            if (widget.arrivals.isEmpty)
              Text(
                BusStrings.confirmNoRoutes,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.sub,
                ),
              )
            else ...[
              Text(BusStrings.confirmRoutesTitle,
                  style: AppTextStyles.eyebrow),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.arrivals.map(_routeTile).toList(),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(BusStrings.confirmReject),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: ElevatedButton(
                    key: BusStopSearchScreen.confirmAcceptKey,
                    onPressed: _accept,
                    child: const Text(BusStrings.confirmAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeTile(BusArrival arrival) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _checked.contains(arrival.routeId),
      onChanged: (on) => setState(() {
        if (on ?? false) {
          _checked.add(arrival.routeId);
        } else {
          _checked.remove(arrival.routeId);
        }
      }),
      title: Text('${arrival.routeNo}번'),
      secondary: Text(
        arrival.arrMin == 0
            ? BusStrings.arrivingNow
            : '${BusStrings.minutes(arrival.arrMin)} 후',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          color: AppColors.sub,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 라우터에 `GoRoute`를 붙인다**

`lib/core/router/app_router.dart` — `GoRoute(path: AppRoutes.import, ...)` 다음에 추가한다:

```dart
            GoRoute(
              path: AppRoutes.busStops,
              pageBuilder: (context, state) => NoTransitionPage(
                child: BusStopSearchScreen(
                  slot: _busSlot(state.uri.queryParameters['slot']),
                ),
              ),
            ),
```

`AppRoutes` 클래스 **밖**, 파일 하단에 헬퍼를 둔다. `firstOrNull`은 `package:collection`의
확장이라 `pubspec.yaml`에 직접 선언이 없으면 `depend_on_referenced_packages` lint가 걸린다 —
쓰지 않는다.

```dart
/// `?slot=toWork` 쿼리를 방향으로. 모르는 값이면 null(화면이 기본 슬롯을 쓴다).
CommuteDirection? _busSlot(String? raw) {
  for (final direction in CommuteDirection.values) {
    if (direction.name == raw) return direction;
  }
  return null;
}
```

import 두 줄 추가:

```dart
import '../../features/bus/domain/commute_direction.dart';
import '../../features/bus/presentation/screens/bus_stop_search_screen.dart';
```

- [ ] **Step 5: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_stop_search_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/features/bus/presentation/screens/bus_stop_search_screen.dart \
        lib/core/router/app_router.dart \
        test/features/bus/bus_stop_search_test.dart
git commit -m "feat(bus): 정류장 검색과 확인 시트 — 반대 방향을 막는다

정류장을 탭하면 바로 저장하지 않고 오는 버스를 조회해 확인받는다. 실측으로
같은 이름 두 개(GGB201000156 / GGB202000003, 좌표 60m 차이)를 확인했다 —
이름으로도 좌표로도 사람이 고를 수 없지만 자기가 타는 버스 번호는 안다.
잘못 고르면 화면에는 버스가 정상적으로 뜨는데 전부 반대 방향이라, 사용자는
앱이 고장 났다고 생각하지 않고 자기가 늦었다고 생각한다.

같은 시트에서 노선도 고른다 — 단계가 늘지 않는다. 기본 전부 체크이고,
전부 체크된 상태는 빈 집합으로 저장한다(열거하면 '전부'가 '이 다섯 개'로
굳어 신설 노선이 영구히 안 보인다).

도시코드는 시·군 단위로 전국 138개라 검색 필드를 뒀다. GPS 근접 검색은
쓰지 않는다 — 슬롯을 교체하는 순간(전근·이사)에는 대상 정류장 근처에 없는
것이 기본값이라 못 쓰인다."
```

---

### Task 14: 오늘 탭 배선 + 폴링 + 요청 0 가드

**Files:**
- Modify: `lib/features/bus/presentation/providers/bus_providers.dart` (`busCardProvider` 추가)
- Create: `lib/features/bus/presentation/widgets/bus_card_host.dart`
- Modify: `lib/features/today/presentation/widgets/today_body.dart` (최상단에 1줄)
- Test: `test/features/bus/bus_card_host_test.dart`

**Interfaces:**
- Consumes: `resolveBusDisplay` (Task 6), `buildBusCardView` (Task 7), `BusApiClient` (Task 8), `busSettingsProvider`·`busApiClientProvider` (Task 9), `BusArrivalCard` (Task 11)
- Produces:
  - `const busPollInterval = Duration(seconds: 30);`
  - `class BusCardHost extends ConsumerStatefulWidget { const BusCardHost({super.key, this.clock}); }`
  - `TodayBody`에 `showBusCard` 파라미터를 **추가하지 않는다** — `BusCardHost`가 스스로 `enabled`를 보고 `SizedBox.shrink()`를 낸다.

**요청이 나가는 조건 여섯 개(스펙 §6) — 이 Task의 핵심이다. 하나라도 거짓이면 요청 0:**

1. `settings.enabled`
2. 그 방향의 슬롯이 있다
3. `display.expanded`
4. 오늘 탭이 화면에 있다(`BusCardHost`가 마운트됨)
5. 앱이 포그라운드다
6. 캐시 미스 (`BusApiClient`가 판정)

- [ ] **Step 1: 실패 테스트를 쓴다**

`test/features/bus/bus_card_host_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_card_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청',
  nodeNo: 2251,
  cityCode: 31010,
);

String _body() => jsonEncode({
      'response': {
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'items': {
            'item': [
              {
                'arrprevstationcnt': 3,
                'arrtime': 120,
                'nodeid': 'GGB201000156',
                'nodenm': '수원시청',
                'routeid': 'R1',
                'routeno': 720,
                'vehicletp': '일반버스',
              }
            ]
          },
          'numOfRows': 30,
          'pageNo': 1,
        },
      },
    });

/// 지정한 시각으로 고정한 채 카드를 띄우고, 나간 요청 수를 돌려준다.
Future<int> _pumpHost(
  WidgetTester tester, {
  required DateTime now,
  required BusSettings settings,
}) async {
  SharedPreferences.setMockInitialValues({
    'bus_settings_v1': jsonEncode(settings.toJson()),
  });

  var count = 0;
  final client = BusApiClient(
    client: MockClient((_) async {
      count++;
      return http.Response(_body(), 200);
    }),
    serviceKey: 'TESTKEY',
    clock: () => now,
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [busApiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      home: Scaffold(body: BusCardHost(clock: () => now)),
    ),
  ));
  await tester.pumpAndSettle();
  return count;
}

void main() {
  // 기본 시간대: 출근 07:00–08:30 / 퇴근 16:00–18:00.
  final inRange = DateTime(2026, 7, 28, 7, 32);
  final outOfRange = DateTime(2026, 7, 28, 10, 20);

  final onWithStop = BusSettings.defaults.copyWith(
    enabled: true,
    departure: _stop,
    arrival: _stop,
  );

  group('가드 — 조건이 하나라도 거짓이면 요청 0회', () {
    testWidgets('스위치가 꺼져 있으면 카드가 없고 요청도 0이다', (tester) async {
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: BusSettings.defaults,
      );
      expect(find.byType(BusArrivalCard), findsNothing);
      expect(n, 0);
    });

    testWidgets('슬롯이 비면 등록 유도가 뜨고 요청은 0이다 — 무한 로딩 금지', (tester) async {
      final n = await _pumpHost(
        tester,
        now: inRange,
        settings: BusSettings.defaults.copyWith(enabled: true),
      );
      expect(find.text('정류장을 등록하면 도착시간이 보여요'), findsOneWidget);
      expect(n, 0);
    });

    testWidgets('시간대 밖이면 접힌 채 그려지고 첫 조회조차 나가지 않는다', (tester) async {
      final n = await _pumpHost(tester, now: outOfRange, settings: onWithStop);
      expect(find.byType(BusArrivalCard), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
      expect(find.text('720번'), findsNothing);
      expect(n, 0);
    });
  });

  group('시간대 안 — 펼쳐지고 조회한다', () {
    testWidgets('목록과 기준시각이 보인다', (tester) async {
      final n = await _pumpHost(tester, now: inRange, settings: onWithStop);
      expect(find.text('720번'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(n, 1);
    });
  });

  group('제목줄 탭 — override 저장', () {
    testWidgets('시간대 안에서 접으면 본문이 사라지고 추가 요청이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return http.Response(_body(), 200);
        }),
        serviceKey: 'TESTKEY',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      await tester.pumpAndSettle();

      expect(find.text('720번'), findsNothing);
      expect(find.text('07:32 기준'), findsNothing);
      expect(count, 1, reason: '접힘 상태에서는 요청이 늘지 않는다');
    });

    testWidgets('시간대 밖에서 펼치면 그때 조회한다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return http.Response(_body(), 200);
        }),
        serviceKey: 'TESTKEY',
        clock: () => outOfRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => outOfRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 0);

      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      await tester.pumpAndSettle();

      expect(count, 1);
      expect(find.text('720번'), findsOneWidget);
    });
  });

  group('키가 없으면 기능이 명시적으로 꺼진다', () {
    testWidgets('키 문구가 뜨고 요청은 0이다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return http.Response(_body(), 200);
        }),
        serviceKey: '',
        clock: () => inRange,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(home: Scaffold(body: BusCardHost(clock: () => inRange))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('버스 정보를 불러올 수 없어요'), findsOneWidget);
      expect(count, 0);
    });
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

Run: `flutter test test/features/bus/bus_card_host_test.dart`
Expected: 컴파일 실패 — `bus_card_host.dart`가 없다.

- [ ] **Step 3: `BusCardHost`를 만든다**

`lib/features/bus/presentation/widgets/bus_card_host.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/bus_api_client.dart';
import '../../domain/bus_card_view.dart';
import '../../domain/bus_display.dart';
import '../../domain/bus_settings.dart';
import '../../domain/commute_direction.dart';
import '../providers/bus_providers.dart';
import 'bus_arrival_card.dart';

/// 폴링 주기. 서버 캐시가 없으니 이 값이 곧 호출 주기다.
const busPollInterval = Duration(seconds: 30);

/// 오늘 탭 최상단에 카드를 얹는 호스트.
///
/// **요청이 나가는 조건 여섯 개를 이 한곳에서 판정한다**(스펙 §6). 조건을 여러 곳에
/// 흩어 놓으면 촉발 지점을 추가할 때 한쪽을 빠뜨려 새는 구멍이 생긴다.
///
/// 1) 표시 ON  2) 그 방향 슬롯 있음  3) 펼침  4) 이 위젯이 마운트됨
/// 5) 포그라운드  6) 캐시 미스([BusApiClient]가 판정)
class BusCardHost extends ConsumerStatefulWidget {
  const BusCardHost({super.key, this.clock});

  /// 테스트가 시각을 고정하기 위한 주입점.
  final DateTime Function()? clock;

  @override
  ConsumerState<BusCardHost> createState() => _BusCardHostState();
}

class _BusCardHostState extends ConsumerState<BusCardHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  BusFetch? _fetch;

  /// 방향 토글은 **화면 수명**이다 — 저장하지 않는다.
  CommuteDirection? _flipped;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 복귀 시 즉시 1회 — **단 여섯 조건을 통과할 때만.** 접힌 채 복귀하면
      // 화면은 아무것도 안 바뀌는데 조회가 나가는, 눈에 안 보이는 구멍이 된다.
      _tick();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 조건을 통과하면 조회하고 타이머를 유지한다. 아니면 타이머를 끈다.
  Future<void> _tick() async {
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;

    final display = _display(settings);
    final stop = settings.stopFor(display.direction);

    final shouldPoll = settings.enabled && stop != null && display.expanded;
    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final fetch = await ref
        .read(busApiClientProvider)
        .fetchArrivals(cityCode: stop.cityCode, nodeId: stop.nodeId);
    if (!mounted) return;
    setState(() => _fetch = fetch);

    _timer ??= Timer.periodic(busPollInterval, (_) => _tick());
  }

  /// 시간대 판정 + 화면 수명 방향 토글.
  BusDisplay _display(BusSettings settings) {
    final resolved = resolveBusDisplay(now: _now(), settings: settings);
    final direction = _flipped ?? resolved.direction;
    return BusDisplay(direction: direction, expanded: resolved.expanded);
  }

  Future<void> _toggleExpanded(BusDisplay display) async {
    final notifier = ref.read(busSettingsProvider.notifier);
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;

    final wantExpanded = !display.expanded;
    final byRange = resolveBusDisplay(
      now: _now(),
      settings: settings.clearOverride(),
    ).expanded;

    // override는 항상 "시간대 판정의 반대"만 담는다. 같은 방향이면 저장할 이유가
    // 없어 지운다 — 상태가 스스로 정리된다.
    if (wantExpanded == byRange) {
      await notifier.clearOverride();
    } else {
      await notifier.setOverride(expanded: wantExpanded, at: _now());
    }
    if (mounted) await _tick();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(busSettingsProvider).valueOrNull;
    if (settings == null || !settings.enabled) return const SizedBox.shrink();

    final display = _display(settings);
    final stop = settings.stopFor(display.direction);

    if (stop == null) {
      return BusArrivalCard(
        view: const BusCardView(
          state: BusCardState.noStop,
          visible: [],
          hiddenCount: 0,
          fetchedAt: null,
        ),
        style: settings.style,
        direction: display.direction,
        stopName: '',
        expanded: true,
        onToggleExpanded: () {},
        onFlipDirection: _flip,
        onRegister: () => context.push(AppRoutes.busStops),
      );
    }

    final fetch = _fetch;
    final view = buildBusCardView(
      state: fetch?.state ?? BusCardState.ok,
      arrivals: fetch?.arrivals ?? const [],
      fetchedAt: fetch?.fetchedAt,
      now: _now(),
      routeIds: stop.routeIds,
    );

    return BusArrivalCard(
      view: view,
      style: settings.style,
      direction: display.direction,
      stopName: stop.nodeNm,
      expanded: display.expanded,
      onToggleExpanded: () => _toggleExpanded(display),
      onFlipDirection: _flip,
      onRetry: _tick,
      onRegister: () => context.push(AppRoutes.busStops),
    );
  }

  void _flip() {
    final settings = ref.read(busSettingsProvider).valueOrNull;
    if (settings == null) return;
    setState(() {
      _flipped = _display(settings).direction.flipped;
      _fetch = null;
    });
    _tick();
  }
}
```

- [ ] **Step 4: 오늘 탭에 얹는다**

`lib/features/today/presentation/widgets/today_body.dart`의 `ListView` `children` **첫 줄**에 추가한다:

```dart
        const BusCardHost(),
```

import 추가:

```dart
import '../../../bus/presentation/widgets/bus_card_host.dart';
```

> `buildTodayView`와 `TodayView`는 건드리지 않는다. 카드는 형제 위젯이고, 꺼져 있으면 `SizedBox.shrink()`라 기존 레이아웃이 1픽셀도 안 바뀐다.

- [ ] **Step 5: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_card_host_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: 백그라운드 복귀 가드를 추가한다**

이 구멍은 **테스트 없이는 다시 열린다.** 접힌 채 앱을 내렸다 올리면 화면은 아무것도
바뀌지 않는데 조회가 한 번 나가는, 눈에 안 보이는 누수다. 화면으로는 잡히지 않는다.

`test/features/bus/bus_card_host_test.dart`의 `main()` 끝에 추가한다:

```dart
  group('가드 — 백그라운드 복귀 (§6의 새는 구멍)', () {
    testWidgets('접힌 채 복귀하면 요청이 0회다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return http.Response(_body(), 200);
        }),
        serviceKey: 'TESTKEY',
        clock: () => outOfRange, // 시간대 밖 → 접힘
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => outOfRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 0);

      // 백그라운드 → 복귀
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count, 0,
          reason: '접힘에서는 복귀해도 조회하지 않는다 — 화면이 안 바뀌므로 '
              '화면 검증으로는 잡히지 않는 누수다');
    });

    testWidgets('펼친 채 복귀하면 캐시가 살아 있어 1회를 넘지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'bus_settings_v1': jsonEncode(onWithStop.toJson()),
      });
      var count = 0;
      final client = BusApiClient(
        client: MockClient((_) async {
          count++;
          return http.Response(_body(), 200);
        }),
        serviceKey: 'TESTKEY',
        clock: () => inRange, // 시간대 안 → 펼침
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [busApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(body: BusCardHost(clock: () => inRange)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(count, 1);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count, 1, reason: '30초 캐시가 복귀 조회를 흡수한다');
    });
  });
```

- [ ] **Step 7: 테스트가 통과한다**

Run: `flutter test test/features/bus/bus_card_host_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 8: 오늘 탭 기존 테스트가 안 깨졌는지 본다**

Run: `flutter test test/features/today/`
Expected: 기존 오늘 탭 테스트 전부 PASS (카드가 기본 OFF라 렌더되지 않는다)

- [ ] **Step 9: 전체 테스트 + analyze**

Run: `flutter test && flutter analyze`
Expected: 전부 PASS, `No issues found!`

- [ ] **Step 10: 커밋**

```bash
git add lib/features/bus/presentation/widgets/bus_card_host.dart \
        lib/features/bus/presentation/providers/bus_providers.dart \
        lib/features/today/presentation/widgets/today_body.dart \
        test/features/bus/bus_card_host_test.dart
git commit -m "feat(bus): 오늘 탭에 카드를 얹고 요청 조건을 한곳에서 판정한다

요청이 나가는 조건 여섯 개를 _tick 하나에서 본다 — 표시 ON, 슬롯 있음,
펼침, 마운트됨, 포그라운드, 캐시 미스. 조건을 여러 곳에 흩어 놓으면 촉발
지점을 추가할 때 한쪽을 빠뜨린다(직전 스펙 리비전이 '복귀 시 즉시 1회 조회'에
접힘 조건을 안 붙여 접힌 채 복귀하면 조회가 나가는 구멍이 있었다).

가드는 MockClient 호출 횟수로 검사한다. 화면으로 검증하면 약하다 —
접힘에서는 어차피 화면이 안 바뀌므로 요청이 나가도 통과한다.

buildTodayView와 TodayView는 건드리지 않는다. 카드는 형제 위젯이고 꺼져
있으면 SizedBox.shrink()라 기존 레이아웃이 1픽셀도 안 바뀐다.

override는 항상 '시간대 판정의 반대'만 담는다. 같은 방향으로 누르면 지워
상태가 스스로 정리된다."
```

---

### Task 15: 키 주입 + 문서

**Files:**
- Modify: `ios/fastlane/Fastfile` (`beta` 레인의 `flutter build ipa`)
- Modify: `docs/privacy_policy.md`
- Modify: `docs/release_checklist.md`
- Test: 없음 (배포 스크립트 — `beta` 레인 실행이 검증이다)

**Interfaces:**
- Consumes: `~/.planroutine/tago.env`의 `TAGO_KEY_DECODING`
- Produces: `--dart-define=TAGO_KEY=<키>`가 실린 IPA

- [ ] **Step 1: Fastfile에 키 읽기 헬퍼를 추가한다**

`ios/fastlane/Fastfile`의 `reset_ios_caches` 정의 **앞**에 추가한다:

```ruby
# TAGO 인증키를 리포 밖에서 읽는다.
#
# 키를 못 읽으면 레인을 실패시킨다 — 키 없이 빌드하면 버스 기능이 조용히 죽은
# 앱이 스토어에 올라간다. 화면에는 "버스 정보를 불러올 수 없어요"만 뜨고
# 사용자는 원인을 알 수 없다.
def tago_key
  path = File.expand_path("~/.planroutine/tago.env")
  UI.user_error!("TAGO 키 파일이 없습니다: #{path}") unless File.exist?(path)

  key = File.readlines(path)
           .map(&:strip)
           .find { |l| l.start_with?("TAGO_KEY_DECODING=") }
           &.split("=", 2)
           &.last
           &.strip

  if key.nil? || key.empty?
    UI.user_error!("TAGO_KEY_DECODING 이 비어 있습니다: #{path}")
  end
  key
end
```

- [ ] **Step 2: 빌드 명령에 주입한다**

`Fastfile:272` 부근의 `sh("flutter", "build", "ipa", ...)`를 고친다:

```ruby
    # Flutter 빌드
    key = tago_key
    UI.message("TAGO 키: #{key.length}자 주입")
    Dir.chdir("..") do
      sh("flutter", "build", "ipa",
        "--release",
        "--build-number=#{new_build_number}",
        "--dart-define=TAGO_KEY=#{key}",
      )
    end
```

> `UI.message`는 **길이만** 찍는다. 키 자체를 로그에 남기면 fastlane 로그 파일에 평문으로 남는다.

- [ ] **Step 3: 키 없이 레인이 실패하는지 확인한다**

```bash
mv ~/.planroutine/tago.env ~/.planroutine/tago.env.bak
./ios/bin/fastlane.sh beta   # 즉시 실패해야 한다
mv ~/.planroutine/tago.env.bak ~/.planroutine/tago.env
```

Expected: `TAGO 키 파일이 없습니다: ...`로 빌드 시작 전에 중단된다.

- [ ] **Step 4: 개인정보 처리방침에 문단을 추가한다**

`docs/privacy_policy.md`의 적절한 항목에 추가한다:

```markdown
### 버스 도착 정보 조회

버스 도착 카드를 켠 경우, 조회 시점에 등록한 정류장 ID와 도시코드가
국토교통부 국가대중교통정보센터(TAGO) 서버로 전송됩니다. 앱은 이용자를
식별하는 정보를 함께 보내지 않으며, 조회 결과를 별도 서버에 저장하지
않습니다. 정류장 설정은 기기 안에만 보관됩니다.

버스 도착 카드는 기본적으로 꺼져 있으며, 켜지 않으면 어떤 통신도
발생하지 않습니다.
```

- [ ] **Step 5: 릴리즈 체크리스트에 호출량 점검을 추가한다**

`docs/release_checklist.md`에 한 줄 추가한다:

```markdown
- [ ] **TAGO 일일 호출량 확인** — data.go.kr 마이페이지 → 오픈API → 활용 현황.
      6,000회/일(개발계정 10,000의 60%)을 넘긴 날이 있으면 프록시 승격을
      검토한다(스펙 §5). 기억에 의존하면 점검하지 않으므로 여기 둔다.
```

- [ ] **Step 6: 시뮬레이터로 실제 동작을 확인한다**

```bash
flutter run --dart-define=TAGO_KEY=$(grep TAGO_KEY_DECODING ~/.planroutine/tago.env | cut -d= -f2)
```

확인할 것:
1. `설정 > 버스 도착`이 **꺼져 있고** 오늘 탭이 지금과 같다
2. 켜면 슬롯 2줄 + 카드 모양 + 시간대 2줄이 나타난다
3. 출발지를 탭 → 도시 검색 `수원` → 정류장 `시청` → **확인 시트에 실제 버스가 뜬다**
4. 전부 체크한 채 `맞아요` → 오늘 탭 최상단에 카드가 뜬다
5. 제목줄을 눌러 접힘/펼침이 **같은 자리에서** 토글된다
6. `카드 모양`을 `시간 축`으로 바꾸면 점이 축 위에 뜨고, **밝게 팔레트에서 세 점이 구별된다**
7. `퇴근 보기`를 누르면 제목줄까지 함께 바뀐다

- [ ] **Step 7: 커밋**

```bash
git add ios/fastlane/Fastfile docs/privacy_policy.md docs/release_checklist.md
git commit -m "chore(bus): 빌드 시 TAGO 키를 주입하고 없으면 레인을 실패시킨다

키를 못 읽으면 빌드 시작 전에 중단한다. 키 없이 빌드하면 버스 기능이 조용히
죽은 앱이 스토어에 올라가고, 화면에는 '버스 정보를 불러올 수 없어요'만 떠
사용자는 원인을 알 수 없다.

로그에는 키 길이만 찍는다 — 키 자체를 남기면 fastlane 로그 파일에 평문으로
남는다.

개인정보 처리방침에 TAGO 전송 문단을 넣었다. 이 기능은 앱의 첫 네트워크
사용이지만 우리 서버가 없어 '데이터 수집 없음'은 유지된다.

릴리즈 체크리스트에 일일 호출량 점검을 넣었다. 서버가 없으니 자동으로 볼
방법이 없고 기억에 의존하면 점검하지 않는다."
```

---

## 완료 후

전체 검증:

```bash
flutter analyze && flutter test
```

그다음 `document-release` 스킬로 CLAUDE.md·README에 버스 기능을 반영하고 옵시디언 작업 로그를 남긴다. CLAUDE.md에 추가할 항목:

- 프로젝트 구조에 `features/bus/`
- 주요 설계 결정에 **요청이 나가는 조건 여섯 개**와 **접기/펼치기 수명 비대칭** (둘 다 다시 흔들리기 쉬운 지점)
- 용어에 `시간대 안` / `시간대 밖`
- `AppColors`의 `busSignal*`은 `시간 축`에서만 쓰인다는 규칙

배포는 `deploy` 스킬(`./ios/bin/fastlane.sh beta`)로 하되, **시뮬레이터 검증(Task 15 Step 6)을 먼저 통과**해야 한다.

