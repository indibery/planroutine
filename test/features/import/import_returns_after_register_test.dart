import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/import/data/import_repository.dart';
import 'package:planroutine/features/import/domain/imported_schedule.dart';
import 'package:planroutine/features/import/presentation/providers/import_providers.dart';
import 'package:planroutine/features/import/presentation/screens/import_screen.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../helpers/test_database.dart';

/// 등록이 끝나면 가져오기 화면에 머물지 않고 **입력 탭으로 돌아간다.**
///
/// 등록 완료 화면에는 할 일이 없다 — 대기 건수는 입력 탭의 `검토 대기 N`이
/// 이미 말해주고, 사용자가 다음에 할 일은 그 목록에서 확정하는 것이다.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ImportRepository importRepo;

  setUp(() {
    db = freshDatabaseHelper();
    importRepo = ImportRepository(databaseHelper: db);
  });

  tearDown(() async => db.close());

  testWidgets('전체 등록 후 입력 탭으로 돌아가고 건수를 스낵바로 알린다', (tester) async {
    late ProviderContainer container;

    final router = GoRouter(
      initialLocation: AppRoutes.schedule,
      routes: [
        GoRoute(
          path: AppRoutes.schedule,
          builder: (_, _) => const Scaffold(body: Text('INPUT TAB')),
        ),
        GoRoute(
          path: AppRoutes.import,
          builder: (_, _) => const ImportScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importRepositoryProvider.overrideWithValue(importRepo),
          scheduleRepositoryProvider
              .overrideWithValue(ScheduleRepository(dbHelper: db)),
          calendarRepositoryProvider
              .overrideWithValue(CalendarRepository(dbHelper: db)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 입력 탭 → 작년 업무 가져오기 화면
    router.push(AppRoutes.import);
    await tester.pumpAndSettle();
    expect(find.text(ImportStrings.screenTitle), findsOneWidget);

    // 실제 등록 경로를 태운다 (imported_schedules → schedules).
    await tester.runAsync(() async {
      final d = await db.database;
      final id = await d.insert(DatabaseHelper.tableImportedSchedules, {
        'title': '학급편성 결과 제출',
        'registration_date': '2025-03-02',
        'category': '학생학적',
        'source_year': 2025,
        'imported_at': DateTime.now().toIso8601String(),
      });
      await container.read(importStateProvider.notifier).registerAllAsSchedules(
        [
          ImportedSchedule(
            id: id,
            title: '학급편성 결과 제출',
            registrationDate: '2025-03-02',
            category: '학생학적',
          ),
        ],
        2025,
      );
    });
    await tester.pumpAndSettle();

    // 가져오기 화면은 닫히고 입력 탭이 보인다.
    expect(find.text('INPUT TAB'), findsOneWidget);
    expect(find.text(ImportStrings.screenTitle), findsNothing);
    expect(find.text(ImportStrings.registeredSnack(1, 0)), findsOneWidget);

    await tester.pump(const Duration(seconds: 5)); // 스낵바 타이머 소진
  });
}
