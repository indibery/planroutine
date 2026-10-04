import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_trash_screen.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/trash/presentation/screens/trash_screen.dart';

import '../../helpers/test_database.dart';

/// 휴지통 행의 버튼은 **어느 항목의 버튼인지** 이름에 담는다.
///
/// 행마다 `복구`·`영구 삭제`가 같은 이름으로 반복되면 시뮬레이터 자동화가 위치로만 골라야
/// 하고, 잘못 고르면 다른 항목을 영구 삭제한다. 지도 기록의 `삭제한 기록`은 행 제목이
/// 트리에서 빠져 버튼만 보였다(2026-10-04 실측).
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;

  setUp(() => db = freshDatabaseHelper());
  tearDown(() async => db.close());

  Future<void> waitFor(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && f.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();
  }

  testWidgets('공용 휴지통: 복구·영구 삭제 이름에 항목 제목이 붙는다', (tester) async {
    final handle = tester.ensureSemantics();
    final calendar = CalendarRepository(dbHelper: db);
    await tester.runAsync(() async {
      final e = await calendar.createEvent(
        const CalendarEvent(title: '학부모 상담', eventDate: '2026-10-16'),
      );
      await calendar.deleteEvent(e);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(
            ScheduleRepository(dbHelper: db),
          ),
          calendarRepositoryProvider.overrideWithValue(calendar),
          memoRepositoryProvider.overrideWithValue(
            MemoRepository(dbHelper: db),
          ),
        ],
        child: const MaterialApp(home: TrashScreen()),
      ),
    );
    await waitFor(tester, find.text('학부모 상담'));

    for (final action in [TrashStrings.restore, TrashStrings.permanentDelete]) {
      final label = AppStrings.rowAction('학부모 상담', action);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('삭제한 기록: 되살리기·영구 삭제 이름에 기록 제목이 붙는다', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = GuidanceRepository(dbHelper: db);
    await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '복도 다툼'));
      await repo.softDelete(id);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: GuidanceTrashScreen()),
      ),
    );
    await waitFor(tester, find.text('복도 다툼'));

    for (final action in [GuidanceStrings.restore, GuidanceStrings.purge]) {
      final label = AppStrings.rowAction('복도 다툼', action);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });
}
