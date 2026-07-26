import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/import/data/ai_schedule_parser.dart';
import 'package:planroutine/features/import/data/ai_schedule_register.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../../helpers/test_database.dart';

/// 입력 경로가 종류를 결정하고, 확정할 때 그 종류가 캘린더로 승계되는지.
///
/// 오늘 탭이 업무만 보여주는 근거가 이 승계다 — 여기서 끊기면 행사가
/// 업무로 둔갑해 오늘 탭에 뜬다.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository schedules;
  late CalendarRepository calendar;

  setUp(() {
    db = freshDatabaseHelper();
    schedules = ScheduleRepository(dbHelper: db);
    calendar = CalendarRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  group('확정 시 종류 승계', () {
    test('행사를 확정하면 캘린더 이벤트도 행사다', () async {
      final id = await schedules.insertConfirmedOrPending(
        const Schedule(
          title: '과학의 달 행사',
          scheduledDate: '2026-04-10',
          kind: EntryKind.event,
        ),
      );

      final eventId = await calendar.createFromSchedule(id);
      expect(eventId, greaterThan(0));

      final events = await calendar.getEventsByDate(DateTime(2026, 4, 10));
      expect(events.single.kind, EntryKind.event);
    });

    test('업무를 확정하면 캘린더 이벤트도 업무다', () async {
      final id = await schedules.insertConfirmedOrPending(
        const Schedule(title: '학급편성 결과 제출', scheduledDate: '2026-03-02'),
      );

      await calendar.createFromSchedule(id);

      final events = await calendar.getEventsByDate(DateTime(2026, 3, 2));
      expect(events.single.kind, EntryKind.task);
    });
  });

  group('입력 경로별 종류', () {
    test('사진 AI로 넣은 것은 행사다', () async {
      await registerAiSchedules(schedules, const [
        AiScheduleItem(title: '운동회', date: '2026-05-15'),
      ]);

      final all = await schedules.getSchedules();
      expect(all.single.kind, EntryKind.event);
    });

    test('작년 CSV(생산문서등록대장)로 넣은 것은 업무다', () async {
      final d = await db.database;
      final importedId = await d.insert(DatabaseHelper.tableImportedSchedules, {
        'title': '1차 학급편성 결과 제출',
        'registration_date': '2025-03-02',
        'category': '교육과정',
        'imported_at': DateTime.now().toIso8601String(),
      });

      await schedules.createFromImported(importedId, DateTime(2026, 3, 2));

      final all = await schedules.getSchedules();
      expect(all.single.kind, EntryKind.task);
    });
  });
}
