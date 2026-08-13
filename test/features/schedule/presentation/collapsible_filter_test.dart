import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_filter_bar.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';

import '../../../helpers/test_database.dart';

/// 필터를 요약 한 줄로 접는다(3안).
///
/// **기본은 접힘.** 넣기(히어로)와 검토 목록에 높이를 내주는 것이 이 탭의 목적이고,
/// 필터를 쓰는 순간은 그보다 드물다. 접힌 줄이 현재 필터를 말해주므로 정보 손실도 없다.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  late CalendarRepository calendarRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    calendarRepo = CalendarRepository(dbHelper: db);
  });

  tearDown(() async => db.close());

  Future<void> seed(
    String title,
    String date, {
    ScheduleStatus status = ScheduleStatus.pending,
    EntryKind kind = EntryKind.task,
  }) async {
    final now = DateTime.now().toIso8601String();
    await repo.insertConfirmedOrPending(
      Schedule(
        title: title,
        scheduledDate: date,
        status: status,
        kind: kind,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ScheduleStatus status = ScheduleStatus.pending,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
          scheduleStatusFilterProvider.overrideWith((ref) => status),
        ],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    // counts(2차 FutureProvider)까지 실제 DB를 타므로, 요약이 붙고 로딩 스피너가
    // 사라질 때까지 runAsync에서 기다린다. 스피너가 남은 채 pumpAndSettle하면
    // fake-async가 DB future를 끝내지 못해 영원히 안 멎는다.
    bool ready() =>
        find.byKey(ScheduleFilterBar.summaryKey).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !ready(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  group('확정본을 열람할 때 (대기 0)', () {
    testWidgets('필터는 요약 한 줄로 접혀 있다', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 업무', '2026-03-03', status: ScheduleStatus.confirmed);
        await seed(
          '확정된 일정',
          '2026-04-10',
          status: ScheduleStatus.confirmed,
          kind: EntryKind.event,
        );
      });
      await pumpScreen(tester, status: ScheduleStatus.confirmed);

      expect(find.byKey(ScheduleFilterBar.summaryKey), findsOneWidget);
      expect(find.text('확정됨 2'), findsOneWidget);
      expect(
        find.byKey(ScheduleFilterBar.chipRowsKey),
        findsNothing,
        reason: '칩 3줄은 접혀 있어야 한다',
      );
    });

    testWidgets('요약 줄을 탭하면 칩이 펼쳐진다', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 업무', '2026-03-03', status: ScheduleStatus.confirmed);
      });
      await pumpScreen(tester, status: ScheduleStatus.confirmed);

      await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleFilterBar.chipRowsKey), findsOneWidget);
      // 배지도 '업무'라 칩으로 한정한다.
      expect(
        find.descendant(
          of: find.byType(PillChip),
          matching: find.text(EntryKind.task.label),
        ),
        findsOneWidget,
      );
    });
  });

  group('검토할 것이 있을 때', () {
    testWidgets('대기가 있어도 칩은 접혀 있다 (기본 접힘)', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02');
      });
      await pumpScreen(tester);

      expect(find.byKey(ScheduleFilterBar.chipRowsKey), findsNothing);
      expect(
        find.text(ScheduleStrings.chipPending(1)),
        findsOneWidget,
        reason: '접힌 줄이 대기 건수를 말한다',
      );
    });

    testWidgets('접으면 요약이 현재 필터를 말한다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02');
        await seed('과학의 달 행사', '2026-04-10', kind: EntryKind.event);
      });
      await pumpScreen(tester);

      // 펼쳐서 행사로 좁힌 뒤 다시 접는다.
      await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ScheduleFilterBar.kindEventKey));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 &&
              (find.text('과학의 달 행사').evaluate().isEmpty ||
                  find.byType(CircularProgressIndicator).evaluate().isNotEmpty);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
      await tester.pumpAndSettle();

      expect(find.byKey(ScheduleFilterBar.chipRowsKey), findsNothing);
      expect(
        find.text('검토 대기 1 · ${EntryKind.event.label}'),
        findsOneWidget,
        reason: '접어도 무엇으로 걸러졌는지 남아야 한다 — 건수는 좁힌 목록(행사 1건) 기준',
      );
    });

    testWidgets('일괄 삭제 pill은 접힌 줄에 함께 있다', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 A', '2026-03-02');
        await seed('대기 B', '2026-03-03');
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.deletePending(2)), findsOneWidget);
    });
  });

  group('중복 금지', () {
    testWidgets('펼치면 요약 문구가 사라져 상태 칩과 겹치지 않는다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02');
      });
      await pumpScreen(tester);
      await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
      await tester.pumpAndSettle();

      // 펼친 상태 — 줄 라벨은 '필터', 건수는 칩만 말한다.
      expect(find.byKey(ScheduleFilterBar.chipRowsKey), findsOneWidget);
      expect(find.text(ScheduleStrings.filter), findsOneWidget);
      expect(
        find.text(ScheduleStrings.chipPending(1)),
        findsOneWidget,
        reason: '건수를 말하는 곳은 상태 칩 한 군데뿐',
      );
    });
  });

  group('높이 가드', () {
    testWidgets('접힌 필터 영역은 60px을 넘지 않는다', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 업무', '2026-03-03', status: ScheduleStatus.confirmed);
      });
      await pumpScreen(tester, status: ScheduleStatus.confirmed);

      final height = tester.getSize(find.byType(ScheduleFilterBar)).height;
      expect(
        height,
        lessThanOrEqualTo(60),
        reason: '접었을 때 한 줄 — 히어로와 목록에 높이를 내준다',
      );
    });
  });
}
