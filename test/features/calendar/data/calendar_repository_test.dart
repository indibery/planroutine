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

  group('updateGoogleEventId', () {
    test('Google Calendar 저장 후 반환된 id가 이벤트에 기록된다', () async {
      final id = await repo.createEvent(buildEvent());
      final before = await repo.getEventsByMonth(2026, 5);
      expect(before.first.googleEventId, isNull);

      await repo.updateGoogleEventId(id, 'gcal_abc_123');

      final after = await repo.getEventsByMonth(2026, 5);
      expect(after.first.googleEventId, 'gcal_abc_123');
    });

    test('같은 이벤트를 재저장하면 googleEventId가 갱신된다', () async {
      final id = await repo.createEvent(buildEvent());
      await repo.updateGoogleEventId(id, 'old_id');
      await repo.updateGoogleEventId(id, 'new_id');

      final after = await repo.getEventsByMonth(2026, 5);
      expect(after.first.googleEventId, 'new_id');
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

  group('updateDeviceEventId', () {
    test('지정한 이벤트의 device_event_id 갱신', () async {
      final eventId = await repo.createEvent(buildEvent());

      await repo.updateDeviceEventId(eventId, 'EKE-99999');

      final events = await repo.getEventsByMonth(2026, 5);
      final event = events.firstWhere((e) => e.id == eventId);
      expect(event.deviceEventId, 'EKE-99999');
    });
  });

  group('fromImport — 가져온 자료 판별', () {
    /// schedules 행을 직접 넣는다. source_id가 있으면 에듀파인 CSV 출처다.
    Future<int> insertSchedule({int? sourceId}) async {
      final database = await db.database;
      return database.insert(DatabaseHelper.tableSchedules, {
        'title': '업무',
        'scheduled_date': '2026-05-01',
        'status': 'confirmed',
        'source_id': sourceId,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
    }

    test('CSV 출처(schedule.source_id 있음) 이벤트는 fromImport=true', () async {
      final scheduleId = await insertSchedule(sourceId: 77);
      await repo.createEvent(buildEvent(title: '가져온 업무', scheduleId: scheduleId));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, true);
    });

    test('확정 경로지만 CSV 출처가 아니면 fromImport=false', () async {
      final scheduleId = await insertSchedule();
      await repo.createEvent(buildEvent(title: '사진 AI 일정', scheduleId: scheduleId));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, false);
    });

    test('손으로 넣은 이벤트(scheduleId 없음)는 fromImport=false', () async {
      await repo.createEvent(buildEvent(title: '손입력'));

      final events = await repo.getEventsByDate(DateTime(2026, 5, 1));
      expect(events.single.fromImport, false);
    });

    test('toMap에는 from_import가 없다 — 있으면 insert가 깨진다', () {
      const event = CalendarEvent(
        title: '아무거나',
        eventDate: '2026-05-01',
        fromImport: true,
      );
      expect(event.toMap().containsKey('from_import'), false);
    });
  });

  group('reviewed_at — 검토 상태', () {
    test('저장·조회 라운드트립에서 reviewedAt이 살아남는다', () async {
      final id = await repo.createEvent(buildEvent(title: '검토 대상'));
      final loaded = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(loaded.reviewedAt, isNull, reason: '신규 이벤트는 아직 검토 전');

      await repo.updateEvent(
        loaded.copyWith(id: id, reviewedAt: '2026-07-26T10:00:00.000'),
      );

      final again = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(again.reviewedAt, '2026-07-26T10:00:00.000');
    });

    test('showsImportBadge — 가져온 자료이면서 아직 검토 안 한 것만', () {
      const notImported = CalendarEvent(title: 'a', eventDate: '2026-05-01');
      const importedFresh = CalendarEvent(
        title: 'b',
        eventDate: '2026-05-01',
        fromImport: true,
      );
      const importedReviewed = CalendarEvent(
        title: 'c',
        eventDate: '2026-05-01',
        fromImport: true,
        reviewedAt: '2026-07-26T10:00:00.000',
      );

      expect(notImported.showsImportBadge, false);
      expect(importedFresh.showsImportBadge, true);
      expect(importedReviewed.showsImportBadge, false);
    });

    // 스와이프로 배지가 지워지지 않는다는 구조적 보장을 고정한다.
    // toMap()을 쓰는 경로는 createEvent(insert)와 updateEvent(update) 둘이고,
    // 기존 행의 reviewed_at을 변경할 수 있는 것은 updateEvent 하나다. 나머지
    // (markCompleted·markIncomplete·_updateExternalEventId·deleteEvent·restoreEvent)는
    // 각자 컬럼만 담은 리터럴 맵을 쓴다.
    test('markCompleted·updateGoogleEventId는 reviewed_at을 건드리지 않는다', () async {
      final id = await repo.createEvent(buildEvent(title: '스와이프 대상'));
      final loaded = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      await repo.updateEvent(
        loaded.copyWith(id: id, reviewedAt: '2026-07-26T10:00:00.000'),
      );

      await repo.markCompleted(id);
      await repo.updateGoogleEventId(id, 'g-abc123');

      final after = (await repo.getEventsByDate(DateTime(2026, 5, 1))).single;
      expect(after.reviewedAt, '2026-07-26T10:00:00.000');
      expect(after.completedAt, isNotNull);
      expect(after.googleEventId, 'g-abc123');
    });
  });
}
