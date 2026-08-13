// 눈으로 보면 "괜찮아 보인다"로 끝나는 것을 숫자로 확정하는 수동 검사 도구.
//
//   ① 대비(WCAG contrast ratio) + 색 거리 — 팔레트를 바꿨을 때 무엇이 안 읽히게 되는지
//   ② 폭별 오버플로 — 320pt(화면 확대를 켠 아이폰 · 배포 타깃 iOS 13이 포함하는 SE 1세대)
//      부터 430pt까지. 버스 위젯 한정.
//   ③ 같은 폭 훑기를 **앱 전역**으로 넓힌 것. 오늘·캘린더·입력·설정·시트·정류장 검색 +
//      나머지 화면(탭바·안내 바·가져오기·온보딩·휴지통).
//
// ⚠️ **③만 실제 Pretendard를 올린다(FontLoader).** ②는 `flutter test`의 기본 폴백 폰트로
// 잰다 — 그 폰트는 모든 글자가 1em(고정폭)이라 같은 문자열을 실측보다 **1.76배** 넓게
// 잡는다(③의 첫 테스트가 그 수치를 찍는다). 폭 결론을 뒤집을 수 있는 차이이므로,
// ②에서 나온 오버플로 수치는 실기기 값이 아니라 상한으로 읽어야 한다.
//
// **자동 스위트에 들어가지 않는다** — 파일명에 `_test`가 없어 `flutter test` 스캔에서 제외된다
// (`test/tools/gen_app_icon.dart`와 같은 관례). 색·레이아웃을 손댔을 때 사람이 직접 돌린다:
//
//     flutter test test/tools/visual_check.dart
//
// ⚠️ **이 도구가 스스로 만든 오진을 기록해 둔다(2026-07-29).** ②로 `stale` 카드 제목줄이
// 320pt에서 21px 넘치는 것을 "찾아" 폭 문턱으로 이모지를 떼는 수정까지 넣었는데, ③에서
// 실측 폰트를 올려 다시 재니 **오버플로가 없었다** — 이모지 라벨 65pt, 기준시각 94.3pt로
// 고정 요소 합이 약 195pt(본문 280pt)였다. 폴백 폰트가 그것을 각각 95·150으로 부풀린 것이다.
// 수정과 가드는 되돌렸다. 교훈: **폭 결론은 실측 폰트를 올린 뒤에만 내린다.**
//
// 앱 전역 훑기(2026-07-29, ③): 28지점 × 4폭 = 실기기 폰트 기준 오버플로 **0건**.
// 자세한 표와 판단 근거는 `.superpowers/sdd/2026-07-28-bus-arrival-card/narrow-width-sweep.md`.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_sizes.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/bus_route.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/screens/bus_stop_search_screen.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_stop_confirm_sheet.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_grid.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_slide_hint_bar.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';
import 'package:planroutine/features/calendar/presentation/widgets/month_event_list.dart';
import 'package:planroutine/features/import/presentation/screens/import_screen.dart';
import 'package:planroutine/features/import/presentation/widgets/edufine_guide_section.dart';
import 'package:planroutine/features/import/presentation/widgets/photo_input_hero.dart';
import 'package:planroutine/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_edit_sheet.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_filter_bar.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_tile.dart';
import 'package:planroutine/features/schedule/presentation/widgets/slide_hint_bar.dart';
import 'package:planroutine/features/settings/presentation/widgets/bus_settings_tiles.dart';
import 'package:planroutine/features/settings/presentation/widgets/export_list_tile.dart';
import 'package:planroutine/features/settings/presentation/widgets/notification_settings_tiles.dart';
import 'package:planroutine/features/settings/presentation/widgets/reset_list_tile.dart';
import 'package:planroutine/features/settings/presentation/widgets/settings_section.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_settings_tiles.dart';
import 'package:planroutine/features/settings/presentation/widgets/theme_mode_tile.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/domain/today_view.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';
import 'package:planroutine/features/today/presentation/widgets/today_body.dart';
import 'package:planroutine/features/today/presentation/widgets/today_event_row.dart';
import 'package:planroutine/features/today/presentation/widgets/today_progress_ring.dart';
import 'package:planroutine/features/trash/presentation/screens/trash_screen.dart';
import 'package:planroutine/shared/widgets/confirm_dialog.dart';
import 'package:planroutine/shared/widgets/dismissible_background.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';

import '../helpers/test_database.dart';

/// WCAG 2.1 상대 휘도.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// 대비비 1.0(같은 색) ~ 21.0(흑백).
double _contrast(Color fg, Color bg) {
  final a = _luminance(fg), b = _luminance(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// 두 색의 지각 거리 근사(sRGB 가중 유클리드). 나란히 놓고 구별되는지 볼 때 쓴다.
double _distance(Color x, Color y) {
  final dr = (x.r - y.r) * 255, dg = (x.g - y.g) * 255, db = (x.b - y.b) * 255;
  return math.sqrt(2 * dr * dr + 4 * dg * dg + 3 * db * db);
}

/// 카드가 실제로 놓이는 면 = glass를 화면 배경 위에 합성한 색.
Color _cardSurface() => Color.alphaBlend(AppColors.glass, AppColors.background);

BusArrival _a(String id, String no, int min) =>
    BusArrival.fromMinutes(routeId: id, routeNo: no, arrMin: min);

BusCardView _view(BusCardState state, {int hidden = 0}) => BusCardView(
  state: state,
  visible: [_a('A', '82-1', 2), _a('B', '92', 8), _a('C', '720', 14)],
  hiddenCount: hidden,
  fetchedAt: DateTime(2026, 7, 29, 7, 32),
);

// ── ③ 앱 전역 훑기용 픽스처 ───────────────────────────────────────────────
//
// **현실적인 최악**만 쓴다. 존재할 수 없는 200자 제목으로 넘치게 만들면 그것은
// 결함이 아니라 픽스처의 과장이다. 아래 값은 실제 데이터의 상한 근처다:
//   - 제목: 에듀파인 생산문서등록대장의 실제 제목 길이대(34자)
//   - 정류장: 실측으로 두 개가 존재하는 이름(`bus_stop_search_screen.dart` 주석)
//   - 건수: 작년 CSV를 통째로 임포트하면 세 자리가 된다

/// 에듀파인 제목 길이대(34자). 여기서 더 길어지는 제목도 있지만 이 정도면
/// 한 줄 레이아웃의 한계는 이미 드러난다.
const _longTitle = '2025학년도 3학년 교육과정 편성·운영 계획 수립 및 학부모 안내장 발송';

/// 설명 한 줄(ellipsis 대상).
const _longDesc = '교무실 3층 회의실 · 담당 김철수 · 준비물 명부 사본 2부';

/// 실측으로 두 개가 존재하는 정류장 이름.
const _longStop = 'B정류장(길 양쪽)';

final _sweepToday = DateTime(2026, 7, 29);

CalendarEvent _sweepEvent({
  required int id,
  String title = _longTitle,
  String? description,
  DateTime? date,
  bool done = false,
  bool important = false,
  bool imported = false,
  EntryKind kind = EntryKind.task,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    description: description,
    eventDate: formatDate(date ?? _sweepToday),
    completedAt: done ? '2026-07-29T09:00:00.000' : null,
    isImportant: important,
    fromImport: imported,
    kind: kind,
  );
}

Schedule _sweepSchedule({
  required String title,
  required String date,
  ScheduleStatus status = ScheduleStatus.pending,
  EntryKind kind = EntryKind.task,
  String? category,
}) {
  const now = '2026-07-29T08:00:00.000';
  return Schedule(
    title: title,
    scheduledDate: date,
    status: status,
    kind: kind,
    category: category,
    createdAt: now,
    updatedAt: now,
  );
}

/// TAGO 대역 — 도시 목록과 정류장 검색에 **긴 이름**을 돌려준다.
http.Response _sweepTago(http.Request request) {
  Map<String, Object?> envelope(Object? inner) => {
    'response': {
      'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
      'body': {
        'items': inner == null ? '' : {'item': inner},
        'numOfRows': 50,
        'pageNo': 1,
      },
    },
  };
  http.Response json(Object? inner) => http.Response(
    jsonEncode(envelope(inner)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  final path = request.url.path;
  if (path.endsWith('getCtyCodeList')) {
    return json([
      for (var i = 0; i < 24; i++)
        {'citycode': 31010 + i * 10, 'cityname': i == 0 ? '수원시' : '동두천시$i'},
    ]);
  }
  if (path.endsWith('getSttnNoList')) {
    return json([
      for (var i = 0; i < 6; i++)
        {'nodeid': 'GGB20100015$i', 'nodenm': _longStop, 'nodeno': 2251 + i},
    ]);
  }
  return json([
    {
      'arrprevstationcnt': 3,
      'arrtime': 480,
      'nodeid': 'N',
      'nodenm': _longStop,
      'routeid': 'R1',
      'routeno': '720-1',
      'vehicletp': '일반버스',
    },
  ]);
}

void main() {
  // **폭을 재는 모든 검사가 실제 Pretendard를 쓴다.** 기본 테스트 폰트는 모든 글자가
  // 1em(고정폭)이라 숫자·마침표·공백·괄호를 실기기보다 두 배 가까이 넓게 잡는다
  // (같은 문자열 실측 173pt vs 폴백 305pt = 1.76배, ③의 첫 테스트가 그 수치를 찍는다).
  //
  // 이 로더를 ③에만 두었던 동안 ②가 `stale` 제목줄에서 **없는 오버플로 21px**을 만들어
  // 실제로 오진을 하나 낳았다(수정까지 넣고 되돌렸다 — 헤더의 기록 참고). 폭 검사에서
  // 폰트는 픽스처이고, 픽스처를 한 곳만 맞춰두면 나머지가 거짓말한다.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/PretendardVariable.ttf'));
    await loader.load();
  });

  group('① 대비·색 거리', () {
    for (final b in [Brightness.dark, Brightness.light]) {
      test('$b 대비', () {
        AppColors.applyBrightness(b);
        final surface = _cardSurface();
        final chipFill = Color.alphaBlend(
          AppColors.goldFill.withValues(alpha: 0.15),
          AppColors.background,
        );

        final pairs = <String, double>{
          'N개 더·기준시각 (sub / 카드 면)': _contrast(AppColors.sub, surface),
          '본문 (ink / 카드 면)': _contrast(AppColors.ink, surface),
          '선택 칩 라벨 (ink / 칩 면)': _contrast(AppColors.ink, chipFill),
          '선택 칩 테두리 (gold / 배경)': _contrast(
            AppColors.gold,
            AppColors.background,
          ),
          'stale 기준시각 (inkRed / 카드 면)': _contrast(AppColors.inkRed, surface),
        };
        pairs.forEach(
          (k, v) => debugPrint('  [$b] $k → ${v.toStringAsFixed(2)}:1'),
        );

        // 작은 글씨가 3:1 미만이면 읽기 어렵다(AA 큰글씨 기준선).
        pairs.forEach((k, v) => expect(v, greaterThan(3.0), reason: '[$b] $k'));
      });
    }

    test('시간 축 세 점이 서로, 그리고 골드와 구별된다', () {
      for (final b in [Brightness.dark, Brightness.light]) {
        AppColors.applyBrightness(b);
        final near = AppColors.busSignalNear;
        final soon = AppColors.busSignalSoon;
        final far = AppColors.busSignalFar;
        debugPrint(
          '  [$b] near-soon ${_distance(near, soon).toStringAsFixed(0)} / '
          'soon-far ${_distance(soon, far).toStringAsFixed(0)} / '
          'near-far ${_distance(near, far).toStringAsFixed(0)} / '
          'soon-gold ${_distance(soon, AppColors.gold).toStringAsFixed(0)}',
        );
        expect(_distance(near, soon), greaterThan(60), reason: '$b 임박·곧');
        expect(_distance(soon, far), greaterThan(60), reason: '$b 곧·여유');
        expect(_distance(near, far), greaterThan(60), reason: '$b 임박·여유');
        // 스펙 §3이 우려한 지점 — 노랑이 골드와 같으면 골드의 의미가 하나 더 늘어난다.
        expect(
          _distance(soon, AppColors.gold),
          greaterThan(40),
          reason: '$b 곧·골드',
        );
      }
    });
  });

  group('② 폭별 오버플로', () {
    // 320: 화면 확대 켠 390pt 기기 · SE 1세대 / 375: SE 2·3 / 390: 14·15 / 430: Pro Max
    const widths = [320.0, 375.0, 390.0, 430.0];

    Future<void> pumpAt(WidgetTester tester, double w, Widget child) async {
      tester.view.physicalSize = Size(w * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.applyBrightness(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(Brightness.dark),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 카드 5상태 · 축 · 칩 20개', (tester) async {
        for (final st in [
          BusCardState.ok,
          BusCardState.stale,
          BusCardState.closed,
          BusCardState.down,
          BusCardState.noStop,
        ]) {
          await pumpAt(
            tester,
            w,
            BusArrivalCard(
              view: _view(st, hidden: 2),
              style: BusCardStyle.text,
              direction: CommuteDirection.toWork,
              stopName: st == BusCardState.noStop ? '' : 'B정류장(길 양쪽)',
              expanded: true,
              onToggleExpanded: st == BusCardState.noStop ? null : () {},
              onFlipDirection: () {},
              onRetry: () {},
            ),
          );
          final e = tester.takeException();
          debugPrint('  ${w.toInt()}pt ${st.name.padRight(7)} → ${e ?? "OK"}');
          expect(e, isNull, reason: '${w.toInt()}pt ${st.name}');
        }

        await pumpAt(
          tester,
          w,
          BusBodyAxis(view: _view(BusCardState.ok, hidden: 2)),
        );
        expect(tester.takeException(), isNull, reason: '${w.toInt()}pt 시간 축');
        debugPrint(
          '  ${w.toInt()}pt 시간 축 높이 '
          '${tester.getSize(find.byType(BusBodyAxis)).height.toStringAsFixed(1)}pt',
        );

        await pumpAt(
          tester,
          w,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 20; i++)
                PillChip(label: i == 0 ? '수원시' : '도시$i', selected: i == 0),
            ],
          ),
        );
        expect(tester.takeException(), isNull, reason: '${w.toInt()}pt 도시 칩');
        debugPrint(
          '  ${w.toInt()}pt 도시 칩 20개 높이 '
          '${tester.getSize(find.byType(Wrap)).height.toStringAsFixed(1)}pt',
        );
      });
    }

    testWidgets('320pt — 초기화 확인 다이얼로그', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.applyBrightness(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.of(Brightness.dark),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConfirmDialog.show(
                context: context,
                title: SettingsStrings.resetAllConfirmTitle,
                message: SettingsStrings.resetAllConfirmMessage,
                confirmLabel: SettingsStrings.resetAllConfirm,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugPrint('  초기화 문구: ${SettingsStrings.resetAllConfirmMessage}');
    });
  });

  // ── ③ 앱 전역 좁은 폭 훑기 ────────────────────────────────────────────
  //
  // 버스 카드에서 하나(stale 제목줄 21px)가 나왔으니 다른 화면에도 있을 개연성이
  // 크다 — 그것을 확인하는 것이 이 그룹이다. **깨끗하다는 결과도 산출물이다**:
  // 아래 목록이 "무엇을 점검했는가"의 증거이므로, 결함이 없어도 지우지 않는다.
  //
  // 여기서 찾은 것은 각 feature의 `_test.dart`에 영구 가드로 옮긴다(버스와 같은 방식).
  group('③ 앱 전역 좁은 폭', () {
    // 320: 화면 확대 켠 390pt 기기 · SE 1세대(배포 타깃 iOS 13이 포함)
    // 375: SE 2·3 / 390: 14·15 / 430: Pro Max
    const widths = [320.0, 375.0, 390.0, 430.0];

    setUpAll(() async {
      setUpFfiForTests();
      await initializeDateFormatting('ko_KR', null);
    });

    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    void setView(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.applyBrightness(Brightness.dark);
    }

    Widget host(Widget child, {List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.of(Brightness.dark),
          home: Scaffold(body: child),
        ),
      );
    }

    /// 위젯 하나를 폭 [width]에 띄우고 결과를 [into]에 모은다.
    ///
    /// 첫 결함에서 멈추지 않는다 — 한 번 돌려 화면 전체의 상태를 보는 것이 목적이다.
    /// [scroll]은 세로 오버플로만 흡수한다(가로는 그대로 잡힌다). `ListView`처럼
    /// 스스로 스크롤하는 위젯은 false로 둔다.
    Future<void> probe(
      WidgetTester tester,
      double width,
      String label,
      Widget child, {
      List<Override> overrides = const [],
      bool scroll = false,
      required List<String> into,
      Future<void> Function()? interact,
    }) async {
      setView(tester, width);
      await tester.pumpWidget(
        host(
          scroll ? SingleChildScrollView(child: child) : child,
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();
      var error = tester.takeException();
      if (error == null && interact != null) {
        await interact();
        await tester.pumpAndSettle();
        error = tester.takeException();
      }
      debugPrint(
        '  ${width.toInt()}pt ${label.padRight(30)} → ${error ?? 'OK'}',
      );
      if (error != null) into.add('${width.toInt()}pt · $label → $error');
    }

    // ── 폰트가 픽스처다 ──────────────────────────────────────────────
    //
    // **이 그룹에서 가장 값나가는 발견이다.** 폭 검사에서 오버플로 유무를 정하는 것은
    // 위젯 코드가 아니라 글자 폭이고, 글자 폭을 정하는 것은 폰트다. `flutter test`의
    // 기본 폴백 폰트는 모든 글자가 1em(고정폭)이라 숫자·마침표·공백·괄호가 실기기의
    // 두 배 가까이 넓다 — 한글만 1em이 맞고 나머지는 전부 과장된다.
    //
    // 그래서 폰트를 안 올리면 **없는 오버플로가 보인다**: 이 훑기에서 처음 나온
    // 두 건(설정 세그먼트 행 8.3px · 일정 타일 날짜줄 47px)이 실측 폰트를 올리자
    // 그대로 사라졌다(각각 23.3pt·68pt 여유). 아래 수치가 그 배율의 증거다.
    testWidgets('기본 테스트 폰트는 실측 Pretendard보다 훨씬 넓다', (tester) async {
      const sample = '화면 테마 2026.05.05 (화)';
      const style = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(
                  sample,
                  key: Key('real'),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // fontFamily를 비우면 폴백(테스트 폰트)으로 떨어진다.
                Text(sample, key: Key('fallback'), style: style),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final real = tester.getSize(find.byKey(const Key('real'))).width;
      final fallback = tester.getSize(find.byKey(const Key('fallback'))).width;
      debugPrint(
        '  "$sample" 실측=$real 폴백=$fallback '
        '배율=${(fallback / real).toStringAsFixed(2)}x',
      );

      // 1.3배만 넘어도 320pt(본문 288)에서는 결론이 뒤집힌다.
      expect(
        fallback,
        greaterThan(real * 1.3),
        reason:
            '폴백이 실측과 비슷해졌다면 이 그룹의 FontLoader는 필요 없다 — '
            '그때 이 테스트를 지운다',
      );
    });

    // ── 오늘 탭 ──────────────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 오늘 탭', (tester) async {
        final problems = <String>[];

        final view = buildTodayView(
          events: [
            _sweepEvent(id: 1, date: DateTime(2026, 7, 20)),
            _sweepEvent(
              id: 2,
              date: DateTime(2026, 7, 24),
              title: '2025학년도 학교교육계획 심의 요청 및 학교운영위원회 안내',
            ),
            _sweepEvent(id: 3, important: true, description: _longDesc),
            _sweepEvent(id: 4, done: true),
            _sweepEvent(id: 5, title: '출결 마감'),
          ],
          today: _sweepToday,
        );

        await probe(
          tester,
          w,
          'TodayBody (지난 접힘)',
          TodayBody(
            view: view,
            today: _sweepToday,
            onToggle: (_) {},
            onEventTap: (_) {},
          ),
          into: problems,
        );

        await probe(
          tester,
          w,
          'TodayBody (지난 펼침)',
          TodayBody(
            view: view,
            today: _sweepToday,
            onToggle: (_) {},
            onEventTap: (_) {},
          ),
          into: problems,
          interact: () =>
              tester.tap(find.byKey(const Key('today_overdue_header'))),
        );

        await probe(
          tester,
          w,
          'TodayEventRow (지난·완료·중요)',
          Column(
            children: [
              TodayEventRow(
                event: _sweepEvent(id: 10, done: true, imported: true),
                stampSettings: const StampSettings(style: SealStyle.approve),
                showOverdueDate: true,
                onToggle: () {},
                onTap: () {},
              ),
              TodayEventRow(
                event: _sweepEvent(
                  id: 11,
                  important: true,
                  description: _longDesc,
                ),
                onToggle: () {},
                onTap: () {},
              ),
            ],
          ),
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'TodayProgressRing 149/149',
          const TodayProgressRing(done: 149, total: 149),
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'CompletionSeal 3종',
          Row(
            children: [
              for (final style in SealStyle.values)
                CompletionSeal(
                  animation: const AlwaysStoppedAnimation(1),
                  style: style,
                ),
            ],
          ),
          into: problems,
          scroll: true,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 캘린더 탭 ────────────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 캘린더 탭', (tester) async {
        final problems = <String>[];

        // 점 3개 + 중요 ★ + 오늘 셀이 함께 있는 달.
        final eventsMap = <String, List<CalendarEvent>>{
          '2026-07-06': [
            _sweepEvent(id: 20, date: DateTime(2026, 7, 6)),
            _sweepEvent(id: 21, date: DateTime(2026, 7, 6)),
            _sweepEvent(id: 22, date: DateTime(2026, 7, 6)),
            _sweepEvent(id: 23, date: DateTime(2026, 7, 6)),
          ],
          '2026-07-15': [
            _sweepEvent(id: 24, date: DateTime(2026, 7, 15), important: true),
          ],
          '2026-07-29': [_sweepEvent(id: 25, done: true)],
        };

        await probe(
          tester,
          w,
          'CalendarGrid (7월)',
          SizedBox(
            height: AppSizes.calendarGridHeight,
            child: CalendarGrid(
              year: 2026,
              month: 7,
              selectedDate: DateTime(2026, 7, 15),
              eventsMap: eventsMap,
              onDateSelected: (_) {},
            ),
          ),
          into: problems,
        );

        // 목록 한 행에 종류 배지 + ★ + 제목 + `작년` 배지 + 완료 체크가 모인다.
        final rows = [
          _sweepEvent(
            id: 30,
            kind: EntryKind.event,
            important: true,
            imported: true,
          ),
          _sweepEvent(
            id: 31,
            done: true,
            imported: true,
            description: _longDesc,
          ),
          _sweepEvent(
            id: 32,
            kind: EntryKind.event,
            imported: true,
            description: _longDesc,
          ),
        ];

        await probe(
          tester,
          w,
          'EventListSection (배지 총출동)',
          EventListSection(
            selectedDate: _sweepToday,
            events: rows,
            onEventTap: (_) {},
            onEventSaveToGoogle: (_) {},
            onEventToggleCompleted: (_) {},
          ),
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'MonthEventList',
          MonthEventList(
            groupedEntries: [
              MapEntry('2026-07-29', rows),
              MapEntry('2026-07-30', [
                _sweepEvent(id: 33, date: DateTime(2026, 7, 30)),
              ]),
            ],
            selectedDate: _sweepToday,
            onEventTap: (_) {},
            onEventSaveToGoogle: (_) {},
            onEventToggleCompleted: (_) {},
          ),
          into: problems,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 시트·다이얼로그 ─────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 시트', (tester) async {
        final problems = <String>[];

        await probe(
          tester,
          w,
          'EventEditDialog (수정·연도 칩)',
          EventEditDialog(
            initialDate: _sweepToday,
            event: _sweepEvent(id: 40, important: true, description: _longDesc),
          ),
          into: problems,
        );

        await probe(
          tester,
          w,
          'EventEditDialog (신규)',
          EventEditDialog(initialDate: _sweepToday),
          into: problems,
        );

        await probe(
          tester,
          w,
          'ScheduleEditSheet',
          ScheduleEditSheet(
            schedule: _sweepSchedule(title: _longTitle, date: '2026-07-29'),
          ),
          into: problems,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 설정 탭 ──────────────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 설정 탭', (tester) async {
        final problems = <String>[];

        await probe(
          tester,
          w,
          'ThemeModeTile',
          const SettingsSection(
            title: SettingsStrings.appearanceSection,
            child: ThemeModeTile(),
          ),
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'StampSettingsTiles',
          const SettingsSection(
            title: SettingsStrings.stampSection,
            subtitle: SettingsStrings.stampDescription,
            child: StampSettingsTiles(),
          ),
          into: problems,
          scroll: true,
        );

        // 정류장 이름이 긴 채로 켜져 있는 상태 — 실사용의 최악.
        const busPrefs = BusSettings(
          enabled: true,
          departure: BusStop(
            nodeId: 'GGB201000156',
            nodeNm: _longStop,
            nodeNo: 2251,
            cityCode: 31010,
          ),
          arrival: BusStop(
            nodeId: 'GGB202000003',
            nodeNm: _longStop,
            nodeNo: 2252,
            cityCode: 31010,
          ),
        );
        SharedPreferences.setMockInitialValues({
          'bus_settings_v1': jsonEncode(busPrefs.toJson()),
        });
        await probe(
          tester,
          w,
          'BusSettingsTiles (긴 정류장)',
          const SettingsSection(
            title: BusStrings.section,
            subtitle: BusStrings.sectionDescription,
            child: BusSettingsTiles(),
          ),
          into: problems,
          scroll: true,
        );
        SharedPreferences.setMockInitialValues({});

        await probe(
          tester,
          w,
          'NotificationSettingsTiles (고급)',
          const SettingsSection(
            title: NotificationStrings.section,
            subtitle: NotificationStrings.masterDescription,
            child: NotificationSettingsTiles(),
          ),
          into: problems,
          scroll: true,
          interact: () => tester.tap(find.text(NotificationStrings.advanced)),
        );

        await probe(
          tester,
          w,
          '내보내기·초기화·AI 공유',
          const Column(
            children: [
              SettingsSection(
                title: SettingsStrings.exportSection,
                subtitle: SettingsStrings.exportDescription,
                child: ExportListTile(),
              ),
              SettingsSection(
                title: SettingsStrings.dataSection,
                child: ResetListTile(),
              ),
            ],
          ),
          into: problems,
          scroll: true,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 입력 탭 (실제 DB) ────────────────────────────────────────────
    //
    // 접힌 요약 줄·일괄 등록 pill·일괄 삭제 pill의 건수는 전부 DB에서 나온다.
    // 세 자리 건수(`대기 149건 삭제`)를 만들려면 실제로 그만큼 넣어야 한다.
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 입력 탭', (tester) async {
        final problems = <String>[];
        final db = freshDatabaseHelper();
        addTearDown(db.close);
        final scheduleRepo = ScheduleRepository(dbHelper: db);
        final calendarRepo = CalendarRepository(dbHelper: db);
        // 한 테스트 안에서 override 개수가 바뀌면 riverpod이 assert로 죽는다 —
        // 이 테스트의 모든 probe가 같은 목록을 쓴다.
        final overrides = [
          scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ];

        await tester.runAsync(() async {
          for (var i = 0; i < 149; i++) {
            await scheduleRepo.insertConfirmedOrPending(
              _sweepSchedule(
                title: '$_longTitle ${i + 1}',
                date: '2026-${(i % 12 + 1).toString().padLeft(2, '0')}-05',
                kind: i % 7 == 0 ? EntryKind.event : EntryKind.task,
                category: i % 3 == 0 ? '학교행사 및 자율활동 운영' : '교육과정 편성·운영',
              ),
            );
          }
          for (var i = 0; i < 12; i++) {
            await scheduleRepo.insertConfirmedOrPending(
              _sweepSchedule(
                title: '확정된 $_longTitle',
                date: '2026-03-1${i % 10}',
                status: ScheduleStatus.confirmed,
                category: '학교행사 및 자율활동 운영',
              ),
            );
          }
        });

        setView(tester, w);
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              theme: AppTheme.of(Brightness.dark),
              home: const ScheduleScreen(),
            ),
          ),
        );

        // DB future는 fake-async에서 끝나지 않는다 — 요약이 붙을 때까지 폴링한다
        // (`schedule_screen_review_test.dart`와 같은 이유·같은 모양).
        bool ready() =>
            find.byKey(ScheduleFilterBar.summaryKey).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty;
        await tester.runAsync(() async {
          for (var i = 0; i < 200 && !ready(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
        await tester.pump();

        void record(String label) {
          final error = tester.takeException();
          debugPrint(
            '  ${w.toInt()}pt ${label.padRight(30)} → ${error ?? 'OK'}',
          );
          if (error != null) problems.add('${w.toInt()}pt · $label → $error');
        }

        record('ScheduleScreen (필터 접힘)');

        await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
        await tester.pump();
        record('ScheduleScreen (필터 펼침)');

        await probe(
          tester,
          w,
          'PhotoInputHero',
          PhotoInputHero(onOpenCsvImport: () {}),
          overrides: overrides,
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'ScheduleTile (확정·카테고리)',
          Column(
            children: [
              ScheduleTile(
                schedule: _sweepSchedule(
                  title: _longTitle,
                  date: '2026-07-29',
                  status: ScheduleStatus.confirmed,
                  category: '학교행사 및 자율활동 운영',
                ),
                onConfirm: () {},
                onDelete: () {},
                onTap: () {},
              ),
              ScheduleTile(
                schedule: _sweepSchedule(
                  title: _longTitle,
                  date: '2026-07-29',
                  kind: EntryKind.event,
                  category: '교육과정 편성·운영',
                ),
                onConfirm: () {},
                onDelete: () {},
                onTap: () {},
              ),
            ],
          ),
          overrides: overrides,
          into: problems,
          scroll: true,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 나머지 화면·공유 위젯 ────────────────────────────────────────
    //
    // 우선순위 목록(오늘·캘린더·입력·설정·시트·정류장) 밖이지만 "앱 전역"에 든다.
    // 탭바·스테퍼·안내 바처럼 **한 줄에 여러 요소를 늘어놓는 Row**가 여기에도 있다.
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 나머지 화면', (tester) async {
        final problems = <String>[];

        await probe(
          tester,
          w,
          'FloatingTabBar 4탭',
          FloatingTabBar(
            currentIndex: 0,
            tabs: const [
              FloatingTabItem(
                icon: Icons.today_outlined,
                activeIcon: Icons.today,
                label: AppStrings.tabToday,
              ),
              FloatingTabItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: AppStrings.tabCalendar,
              ),
              FloatingTabItem(
                icon: Icons.edit_note_outlined,
                activeIcon: Icons.edit_note,
                label: AppStrings.tabSchedule,
              ),
              FloatingTabItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: SettingsStrings.title,
              ),
            ],
            onTap: (_) {},
          ),
          into: problems,
          scroll: true,
        );

        // 캘린더 안내 바는 target=none이면 통째로 숨는다 — 숨은 것을 재면 검사가 아니다.
        SharedPreferences.setMockInitialValues({'calendar_target': 'device'});
        await probe(
          tester,
          w,
          '스와이프 안내 바 2종',
          const Column(children: [SlideHintBar(), CalendarSlideHintBar()]),
          into: problems,
          scroll: true,
        );
        SharedPreferences.setMockInitialValues({});

        await probe(
          tester,
          w,
          'DismissibleBackground 4종',
          Column(
            children: [
              DismissibleBackground(
                accent: AppColors.inkGreen,
                icon: Icons.check_circle_outline,
                label: ScheduleStrings.confirm,
                alignment: Alignment.centerLeft,
              ),
              DismissibleBackground(
                accent: AppColors.inkRed,
                icon: Icons.delete_outline,
                label: ScheduleStrings.delete,
                alignment: Alignment.centerRight,
              ),
              DismissibleBackground(
                accent: AppColors.inkGreen,
                icon: Icons.cloud_upload,
                label: CalendarIntegrationStrings.swipeSaveDevice,
                alignment: Alignment.centerLeft,
              ),
              DismissibleBackground(
                accent: AppColors.gold,
                icon: Icons.radio_button_unchecked,
                label: CalendarStrings.undoComplete,
                alignment: Alignment.centerRight,
              ),
            ],
          ),
          into: problems,
          scroll: true,
        );

        await probe(
          tester,
          w,
          'ImportSteps + 안내 펼침',
          const Column(
            children: [ImportSteps(activeStep: 1), EdufineGuideSection()],
          ),
          into: problems,
          scroll: true,
          // 접힌 안내는 한 줄뿐이다 — 번호 4단계·스크린샷·팁 박스는 펼쳐야 나온다.
          interact: () => tester.tap(find.byType(ExpansionTile)),
        );

        await probe(
          tester,
          w,
          'OnboardingScreen',
          const OnboardingScreen(),
          into: problems,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 휴지통 (실제 DB) ─────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 휴지통', (tester) async {
        final problems = <String>[];
        final db = freshDatabaseHelper();
        addTearDown(db.close);
        final scheduleRepo = ScheduleRepository(dbHelper: db);
        final calendarRepo = CalendarRepository(dbHelper: db);

        await tester.runAsync(() async {
          for (var i = 0; i < 3; i++) {
            final id = await scheduleRepo.insertConfirmedOrPending(
              _sweepSchedule(
                title: '$_longTitle ${i + 1}',
                date: '2026-07-0${i + 1}',
                category: '학교행사 및 자율활동 운영',
              ),
            );
            await scheduleRepo.deleteSchedule(id);
          }
          for (var i = 0; i < 3; i++) {
            final id = await calendarRepo.createEvent(
              _sweepEvent(id: i + 1, title: '$_longTitle ${i + 1}'),
            );
            await calendarRepo.deleteEvent(id);
          }
        });

        setView(tester, w);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scheduleRepositoryProvider.overrideWithValue(scheduleRepo),
              calendarRepositoryProvider.overrideWithValue(calendarRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.of(Brightness.dark),
              home: const TrashScreen(),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 200 &&
                find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
        await tester.pump();

        final error = tester.takeException();
        debugPrint(
          '  ${w.toInt()}pt ${'TrashScreen (일정3·이벤트3)'.padRight(30)} '
          '→ ${error ?? 'OK'}',
        );
        if (error != null) {
          problems.add('${w.toInt()}pt · TrashScreen → $error');
        }

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    // ── 정류장 검색 화면 ─────────────────────────────────────────────
    for (final w in widths) {
      testWidgets('${w.toInt()}pt — 정류장 검색', (tester) async {
        final problems = <String>[];
        final overrides = [
          busApiClientProvider.overrideWithValue(
            BusApiClient(
              client: MockClient((request) async => _sweepTago(request)),
              serviceKey: 'TESTKEY',
            ),
          ),
        ];

        await probe(
          tester,
          w,
          'BusStopSearchScreen (검색 결과)',
          const BusStopSearchScreen(slot: CommuteDirection.toWork),
          overrides: overrides,
          into: problems,
          interact: () async {
            await tester.enterText(
              find.byKey(BusStopSearchScreen.stopFieldKey),
              'B정류장',
            );
            await tester.testTextInput.receiveAction(TextInputAction.search);
          },
        );

        await probe(
          tester,
          w,
          'BusStopConfirmSheet',
          BusStopConfirmSheet(
            stop: const BusStop(
              nodeId: 'GGB201000156',
              nodeNm: _longStop,
              nodeNo: 2251,
              cityCode: 31010,
            ),
            // 행선지가 붙은 뒤로 이 행이 가장 넓다 — 실측에서 가져온 긴 행선지를
            // 쓴다(`정금마을.방배경찰서(중)`). 마지막 노선은 행선지가 있고 도착
            // 정보가 없는 조합이라, 부제만 있고 우측이 빈 행의 폭도 함께 잰다.
            routes: const [
              BusRoute(
                routeId: 'R1',
                routeNo: '82-1',
                destName: '정금마을.방배경찰서(중)',
              ),
              BusRoute(
                routeId: 'R2',
                routeNo: '720-1',
                destName: '부곡공영차고지(미정차)',
              ),
              BusRoute(routeId: 'R3', routeNo: '1006-1', destName: '금정역'),
              BusRoute(routeId: 'R4', routeNo: '5623', destName: '여의도환승센터'),
            ],
            arrivals: [
              BusArrival.fromMinutes(routeId: 'R1', routeNo: '82-1', arrMin: 2),
              BusArrival.fromMinutes(
                routeId: 'R2',
                routeNo: '720-1',
                arrMin: 8,
              ),
              BusArrival.fromMinutes(
                routeId: 'R3',
                routeNo: '1006-1',
                arrMin: 0,
              ),
            ],
            state: BusCardState.ok,
            slot: CommuteDirection.toHome,
            // 같은 테스트 안에서 override 개수를 바꾸면 riverpod이 assert로 죽는다
            // (결함이 아니라 픽스처의 함정) — 두 probe에 같은 목록을 넘긴다.
          ),
          overrides: overrides,
          into: problems,
          scroll: true,
        );

        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }
  });
}
