import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_filter_bar.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(String title, String date, ScheduleStatus status) async {
    final now = DateTime.now().toIso8601String();
    await repo.insertConfirmedOrPending(Schedule(
      title: title,
      scheduledDate: date,
      status: status,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scheduleRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    // FFI DB 로드 + counts(2차 FutureProvider)가 실제 비동기라 runAsync +
    // "칩에 건수가 붙을 때까지" 조건 대기.
    bool chipHasCount() => find
        .byWidgetPredicate(
            (w) => w is Text && (w.data?.startsWith('검토 대기 ') ?? false))
        .evaluate()
        .isNotEmpty;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !chipHasCount(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  group('일정 검토 단순화 — 대기 중심 뷰', () {
    test('상태 필터 기본값은 검토 대기', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(scheduleStatusFilterProvider),
          ScheduleStatus.pending);
    });

    testWidgets('기본 뷰: 대기만 보이고 확정은 안 보임 + 전체 칩 없음 + 칩 건수', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 행사', '2026-03-02', ScheduleStatus.pending);
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      expect(find.text('대기 행사'), findsOneWidget);
      expect(find.text('확정된 행사'), findsNothing);
      expect(find.text(ScheduleStrings.all), findsNothing,
          reason: '상태 줄에 전체 칩 없음(카테고리 줄은 카테고리 없어서 숨김)');
      expect(find.text('검토 대기 1'), findsOneWidget);
      expect(find.text('확정됨 1'), findsOneWidget);
    });

    testWidgets('대기 뷰 하단 확정 요약 → 탭하면 확정됨 뷰로', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 행사', '2026-03-02', ScheduleStatus.pending);
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      final summary = find.textContaining('확정 1건은 캘린더에 반영됨');
      expect(summary, findsOneWidget);

      await tester.tap(summary);
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && find.text('확정된 행사').evaluate().isEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(find.text('확정된 행사'), findsOneWidget);
      expect(find.text('대기 행사'), findsNothing);
    });

    testWidgets('AppBar에 가져오기 아이콘 상시 노출', (tester) async {
      await pumpScreen(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.file_download_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('완료 상태에 일정 가져오기 골드 CTA 노출', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);
      expect(find.text(ScheduleStrings.goImport), findsOneWidget);
    });

    testWidgets('모두 확정이면 완료 상태 + 확정됨 보기 CTA', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.reviewDoneTitle), findsOneWidget);
      expect(find.text(ScheduleStrings.viewConfirmed(1)), findsOneWidget);

      await tester.tap(find.text(ScheduleStrings.viewConfirmed(1)));
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && find.text('확정된 행사').evaluate().isEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(find.text('확정된 행사'), findsOneWidget);
    });

    testWidgets('완료 상태에선 필터 줄(ScheduleFilterBar)을 숨긴다', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      // 완료 화면이 맞고, 그 위 상태 필터 칩(검토 대기/확정됨)은 숨겨져야 한다.
      expect(find.text(ScheduleStrings.reviewDoneTitle), findsOneWidget);
      expect(find.byType(ScheduleFilterBar), findsNothing);
      expect(find.textContaining('검토 대기 '), findsNothing);
    });

    testWidgets('대기가 남아 있으면 필터 줄을 보여준다', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 행사', '2026-03-02', ScheduleStatus.pending);
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      expect(find.byType(ScheduleFilterBar), findsOneWidget);
    });

    testWidgets('완료 화면의 확정됨 보기는 약한 텍스트 버튼(TextButton)', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 행사', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      final viewConfirmed = find.widgetWithText(
        TextButton,
        ScheduleStrings.viewConfirmed(1),
      );
      expect(viewConfirmed, findsOneWidget);
    });

    testWidgets('일괄 삭제 pill: 대기 있으면 노출', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 A', '2026-03-02', ScheduleStatus.pending);
        await seed('대기 B', '2026-03-03', ScheduleStatus.pending);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.deletePending(2)), findsOneWidget);
      expect(find.text(ScheduleStrings.confirmPending(2)), findsOneWidget);
    });

    testWidgets('일괄 삭제 → 대기는 휴지통으로, 확정은 유지', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 A', '2026-03-02', ScheduleStatus.pending);
        await seed('확정 B', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      // 삭제 pill 탭 → 확인 다이얼로그 → 삭제
      await tester.tap(find.text(ScheduleStrings.deletePending(1)));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.bulkDeleteTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.delete));
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && find.text('대기 A').evaluate().isNotEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      // 대기 A 사라짐(휴지통) → 대기 0 + 확정 1이라 완료 화면 전환.
      // (reviewDoneTitle은 확정>0일 때만 나오므로 확정 B가 유지됐다는 증거)
      expect(find.text('대기 A'), findsNothing);
      expect(find.text(ScheduleStrings.reviewDoneTitle), findsOneWidget);
    });
  });
}
