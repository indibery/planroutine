import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/calendar/presentation/screens/calendar_screen.dart';

import '../../../helpers/test_database.dart';

/// 캘린더 화면의 **아이콘만 있는 버튼**에 이름이 있어야 한다.
///
/// 이름은 말풍선(`tooltip`)이 아니라 `Icon(semanticLabel:)`로 준다(`no_tooltip_guard_test.dart`).
///
/// 월 이동 `<`·`>`는 이름 없는 `Button`으로, `+` FAB은 `text=""`인 요소로
/// 잡혀 무엇을 하는 버튼인지 알 수 없었다(2026-10-04 실측).
void main() {
  setUpAll(() async {
    setUpFfiForTests();
    await initializeDateFormatting('ko');
  });

  late DatabaseHelper db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
  });

  tearDown(() async => db.close());

  /// DB 조회가 끝날 때까지 실제 시간으로 기다린다 — fake-async에서는 끝나지 않는다.
  Future<void> waitLoaded(WidgetTester tester) async {
    bool loading() =>
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && loading(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(
          CalendarRepository(dbHelper: db),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await waitLoaded(tester);
    return container;
  }

  testWidgets('이름을 말풍선(tooltip)으로 주지 않는다', (tester) async {
    // 말풍선과 label을 함께 주면 `snapshot_ui`에 `이전 달 이전 달`처럼 두 번 붙는다.
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);

    expect(find.byType(Tooltip), findsNothing);
    for (final label in [
      CalendarStrings.prevMonth,
      CalendarStrings.nextMonth,
      CalendarStrings.addEvent,
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, tooltip: ''),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('이전 달·다음 달·일정 추가가 label을 가진 버튼이다', (tester) async {
    // mobile MCP는 `tooltip` 속성을 읽지 않는다 — tooltip만 주면 `snapshot_ui`에는
    // 이름이 보이고 mobile MCP에는 이름 없는 `Button`으로 나왔다(2026-10-04 실측).
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);

    for (final label in [
      CalendarStrings.prevMonth,
      CalendarStrings.nextMonth,
      CalendarStrings.addEvent,
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('다음 달 버튼을 시맨틱스로 누르면 달이 넘어간다', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpScreen(tester);

    final before = container.read(selectedDateProvider);
    tester.semantics.tap(find.semantics.byLabel(CalendarStrings.nextMonth));
    await tester.pump();
    await waitLoaded(tester);
    final after = container.read(selectedDateProvider);
    expect(
      DateTime(after.year, after.month),
      DateTime(before.year, before.month + 1),
    );
    handle.dispose();
  });
}
