import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/trash/presentation/screens/trash_screen.dart';

import '../../helpers/test_database.dart';

/// 화면에서도 **최근에 지운 것이 맨 위**이고, 줄마다 무엇인지(종류)를 말한다.
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);

  testWidgets('종류와 상관없이 최근에 지운 것이 위, 줄마다 종류가 보인다', (tester) async {
    final db = freshDatabaseHelper();
    addTearDown(db.close);
    final schedules = ScheduleRepository(dbHelper: db);
    final calendar = CalendarRepository(dbHelper: db);
    final memos = MemoRepository(dbHelper: db);

    Future<void> gap() => Future<void>.delayed(const Duration(milliseconds: 5));
    await tester.runAsync(() async {
      final s = await schedules.insertConfirmedOrPending(
        const Schedule(title: '가장 먼저 지운 일정', scheduledDate: '2026-10-15'),
      );
      await schedules.deleteSchedule(s);
      await gap();
      final e = await calendar.createEvent(
        const CalendarEvent(title: '두 번째로 지운 이벤트', eventDate: '2026-10-16'),
      );
      await calendar.deleteEvent(e);
      await gap();
      final m = await memos.add('마지막에 뗀 쪽지');
      await memos.softDelete(m.id ?? -1);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(schedules),
          calendarRepositoryProvider.overrideWithValue(calendar),
          memoRepositoryProvider.overrideWithValue(memos),
        ],
        child: const MaterialApp(home: TrashScreen()),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && find.text('마지막에 뗀 쪽지').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();

    final memoY = tester.getTopLeft(find.text('마지막에 뗀 쪽지')).dy;
    final eventY = tester.getTopLeft(find.text('두 번째로 지운 이벤트')).dy;
    final scheduleY = tester.getTopLeft(find.text('가장 먼저 지운 일정')).dy;
    expect(memoY, lessThan(eventY));
    expect(eventY, lessThan(scheduleY));

    expect(find.textContaining('${TrashStrings.sectionMemos} · '), findsOneWidget);
    expect(find.textContaining('${TrashStrings.sectionEvents} · '), findsOneWidget);
    expect(find.textContaining('${TrashStrings.sectionSchedules} · '), findsOneWidget);
  });
}
