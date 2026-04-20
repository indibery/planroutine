import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late CalendarRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = CalendarRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  CalendarEvent buildEvent({
    String title = '테스트 이벤트',
    String date = '2026-05-01',
    String? description,
    int? scheduleId,
  }) {
    return CalendarEvent(
      title: title,
      description: description,
      eventDate: date,
      scheduleId: scheduleId,
    );
  }

  group('createEvent / getEventsByDate', () {
    test('이벤트 생성 후 해당 날짜 조회로 돌아온다', () async {
      final id = await repo.createEvent(buildEvent(title: '첫 이벤트'));
      expect(id, greaterThan(0));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.length, 1);
      expect(events.first.title, '첫 이벤트');
    });

    test('다른 날짜 이벤트는 조회되지 않음', () async {
      await repo.createEvent(buildEvent(date: '2026-05-01'));
      await repo.createEvent(buildEvent(date: '2026-05-02'));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.length, 1);
    });
  });

  group('getEventsByMonth / DateRange', () {
    test('월 전체 이벤트를 반환', () async {
      await repo.createEvent(buildEvent(date: '2026-05-01'));
      await repo.createEvent(buildEvent(date: '2026-05-15'));
      await repo.createEvent(buildEvent(date: '2026-05-31'));
      await repo.createEvent(buildEvent(date: '2026-06-01')); // 다른 달

      final events = await repo.getEventsByMonth(2026, 5);
      expect(events.length, 3);
    });
  });

  group('soft-delete / restore / permanentDelete', () {
    test('deleteEvent는 soft-delete라 활성 목록에서 제외', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.deleteEvent(id);

      final active = await repo.getEventsByMonth(2026, 5);
      expect(active, isEmpty);

      final deleted = await repo.getDeletedEvents();
      expect(deleted.length, 1);
      expect(deleted.first.deletedAt, isNotNull);
    });

    test('restoreEvent로 deleted_at 초기화 후 활성 목록에 다시 등장', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.deleteEvent(id);
      await repo.restoreEvent(id);

      final active = await repo.getEventsByMonth(2026, 5);
      expect(active.length, 1);
      expect(active.first.deletedAt, isNull);
    });

    test('permanentDeleteEvent는 DB에서 완전 제거', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.deleteEvent(id);
      await repo.permanentDeleteEvent(id);

      final deleted = await repo.getDeletedEvents();
      expect(deleted, isEmpty);
    });
  });

  group('markCompleted / markIncomplete', () {
    test('markCompleted는 completed_at을 기록, isCompleted=true', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.markCompleted(id);

      final events = await repo.getEventsByMonth(2026, 5);
      expect(events.first.isCompleted, isTrue);
      expect(events.first.completedAt, isNotNull);
    });

    test('markIncomplete는 completed_at을 null로 되돌림', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.markCompleted(id);
      await repo.markIncomplete(id);

      final events = await repo.getEventsByMonth(2026, 5);
      expect(events.first.isCompleted, isFalse);
      expect(events.first.completedAt, isNull);
    });
  });

  group('createFromSchedule 중복 체크', () {
    Future<int> insertSchedule(DatabaseHelper helper) async {
      final database = await helper.database;
      return database.insert(DatabaseHelper.tableSchedules, {
        'title': '확정 일정',
        'scheduled_date': '2026-05-10',
        'status': 'confirmed',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    test('활성 이벤트가 없으면 createFromSchedule 성공', () async {
      final scheduleId = await insertSchedule(db);
      final eventId = await repo.createFromSchedule(scheduleId);
      expect(eventId, greaterThan(0));
    });

    test('같은 scheduleId의 활성 이벤트가 있으면 -1 반환 (중복 생성 차단)', () async {
      final scheduleId = await insertSchedule(db);
      await repo.createFromSchedule(scheduleId);
      final second = await repo.createFromSchedule(scheduleId);
      expect(second, -1);
    });

    test('기존 이벤트가 soft-delete되면 다시 createFromSchedule 가능', () async {
      final scheduleId = await insertSchedule(db);
      final first = await repo.createFromSchedule(scheduleId);
      await repo.deleteEvent(first);

      final second = await repo.createFromSchedule(scheduleId);
      expect(second, greaterThan(0));
      expect(second, isNot(first));
    });

    test('존재하지 않는 scheduleId는 -1 반환', () async {
      final eventId = await repo.createFromSchedule(9999);
      expect(eventId, -1);
    });
  });

  group('purgeOlderThan', () {
    test('cutoff보다 오래 전 soft-delete된 이벤트만 영구 삭제', () async {
      // 오래된 deleted_at 수동 주입
      final database = await db.database;
      final oldId = await repo.createEvent(buildEvent(title: '오래된 삭제'));
      await database.update(
        DatabaseHelper.tableCalendarEvents,
        {'deleted_at': '2025-01-01T00:00:00.000Z'},
        where: 'id = ?',
        whereArgs: [oldId],
      );

      final recentId = await repo.createEvent(buildEvent(title: '최근 삭제'));
      await repo.deleteEvent(recentId); // 현재 시각

      final cutoff = DateTime(2025, 6, 1);
      final purged = await repo.purgeOlderThan(cutoff);

      expect(purged, 1);
      final remaining = await repo.getDeletedEvents();
      expect(remaining.length, 1);
      expect(remaining.first.title, '최근 삭제');
    });

    test('soft-delete 안 된 활성 이벤트는 purge 대상 아님', () async {
      await repo.createEvent(buildEvent());
      final purged = await repo.purgeOlderThan(DateTime(2099, 1, 1));
      expect(purged, 0);
    });
  });
}
