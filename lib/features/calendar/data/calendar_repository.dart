import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/date_utils.dart';
import '../../schedule/domain/entry_kind.dart';
import '../domain/calendar_event.dart';

/// 캘린더 이벤트 DB 저장소.
///
/// 삭제는 soft-delete: `deleted_at` 컬럼에 삭제 시각을 기록하여
/// 휴지통에서 복구 가능. 모든 활성 조회는 `deleted_at IS NULL` 필터를 적용한다.
class CalendarRepository {
  final DatabaseHelper _dbHelper;

  CalendarRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 이벤트 생성
  Future<int> createEvent(CalendarEvent event) async {
    final db = await _dbHelper.database;
    return db.insert(DatabaseHelper.tableCalendarEvents, event.toMap());
  }

  /// 이벤트 수정
  Future<int> updateEvent(CalendarEvent event) async {
    if (event.id == null) return 0;
    final db = await _dbHelper.database;
    final map = event.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      map,
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// 이벤트 soft-delete (휴지통으로 이동).
  ///
  /// 연결된 원본 일정(`schedules`) 행도 **함께** 내려보낸다. 원본을 남겨두면
  /// 중복 판정(`title + scheduled_date`, `deleted_at IS NULL` 기준)이 그 행에
  /// 걸려 **캘린더에서 지운 행사를 다시 넣을 수 없다** — 사용자에게는 캘린더가
  /// 비어 있는데 "이미 있다"며 조용히 스킵되는 것으로 보인다(실기기 신고
  /// 2026-09-11). 원본은 작년 일정을 참조하기 위한 내부 기록일 뿐이므로
  /// 화면에 보이는 캘린더가 기준이 된다.
  Future<int> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      await _applyToLinkedSchedule(txn, id, {'deleted_at': now});
      return txn.update(
        DatabaseHelper.tableCalendarEvents,
        {'deleted_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// 이벤트 완료 표시 (completed_at에 현재 시각 기록)
  Future<int> markCompleted(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 이벤트 완료 취소 (completed_at을 null로)
  Future<int> markIncomplete(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {'completed_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 외부 캘린더(Google/기기) 저장 후 받은 id를 해당 컬럼에 기록.
  /// 재저장 스와이프에서 update로 처리해 중복 생성 방지.
  Future<int> _updateExternalEventId(
    int id,
    String column,
    String externalId,
  ) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {column: externalId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateGoogleEventId(int id, String googleEventId) =>
      _updateExternalEventId(id, 'google_event_id', googleEventId);

  Future<int> updateDeviceEventId(int id, String deviceEventId) =>
      _updateExternalEventId(id, 'device_event_id', deviceEventId);

  /// 이벤트 복구 — 함께 내려갔던 원본 일정도 같이 되살린다([deleteEvent]의 역).
  Future<int> restoreEvent(int id) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      await _applyToLinkedSchedule(txn, id, {'deleted_at': null});
      return txn.update(
        DatabaseHelper.tableCalendarEvents,
        {'deleted_at': null},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// 이벤트 영구 삭제 (DB row 제거) — 원본 일정 행도 함께 지운다.
  ///
  /// 짝만 지우면 휴지통 목록에서 숨겨져 있던 원본이 **고아가 되어 다시 나타난다**
  /// (`visibleTrashSchedules`가 삭제된 이벤트를 기준으로 숨기기 때문).
  Future<int> permanentDeleteEvent(int id) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final scheduleId = await _linkedScheduleId(txn, id);
      if (scheduleId != null) {
        await txn.delete(
          DatabaseHelper.tableSchedules,
          where: 'id = ?',
          whereArgs: [scheduleId],
        );
      }
      return txn.delete(
        DatabaseHelper.tableCalendarEvents,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// [eventId]에 연결된 원본 일정의 id. 손입력 이벤트는 `schedule_id`가 없어 null.
  Future<int?> _linkedScheduleId(DatabaseExecutor txn, int eventId) async {
    final rows = await txn.query(
      DatabaseHelper.tableCalendarEvents,
      columns: ['schedule_id'],
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['schedule_id'] as int?;
  }

  /// 연결된 원본 일정이 있으면 [values]를 그 행에 적용한다.
  Future<void> _applyToLinkedSchedule(
    DatabaseExecutor txn,
    int eventId,
    Map<String, Object?> values,
  ) async {
    final scheduleId = await _linkedScheduleId(txn, eventId);
    if (scheduleId == null) return;
    await txn.update(
      DatabaseHelper.tableSchedules,
      values,
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  /// 휴지통 이벤트 목록 (최근 삭제 순)
  Future<List<CalendarEvent>> getDeletedEvents() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return results.map(CalendarEvent.fromMap).toList();
  }

  /// 특정 날짜의 이벤트 조회 (삭제되지 않은 것만).
  /// `from_import` 조인을 함께 태우도록 [getEventsByDateRange]에 위임한다.
  Future<List<CalendarEvent>> getEventsByDate(DateTime date) =>
      getEventsByDateRange(date, date);

  /// 특정 월의 모든 이벤트 조회
  Future<List<CalendarEvent>> getEventsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return getEventsByDateRange(start, end);
  }

  /// 날짜 범위 이벤트 조회 (삭제되지 않은 것만).
  ///
  /// `from_import`는 컬럼이 아니라 조인으로 만드는 파생 값이다 — 출처의 진실은
  /// `schedules.source_id` 한 곳에만 두고, calendar_events에 복제하지 않는다.
  Future<List<CalendarEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final results = await db.rawQuery(
      '''
      SELECT e.*, (s.source_id IS NOT NULL) AS from_import
      FROM ${DatabaseHelper.tableCalendarEvents} e
      LEFT JOIN ${DatabaseHelper.tableSchedules} s ON s.id = e.schedule_id
      WHERE e.event_date >= ? AND e.event_date <= ? AND e.deleted_at IS NULL
      ORDER BY e.event_date ASC, e.created_at ASC
      ''',
      [startStr, endStr],
    );
    return results.map(CalendarEvent.fromMap).toList();
  }

  /// 확정된 일정에서 캘린더 이벤트 생성.
  ///
  /// 같은 [scheduleId]에 대한 활성(삭제되지 않은) 이벤트가 이미 존재하면
  /// -1 반환 (중복 생성 방지).
  Future<int> createFromSchedule(int scheduleId) async {
    final db = await _dbHelper.database;

    // 중복 체크 (활성 이벤트 기준)
    final existing = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'schedule_id = ? AND deleted_at IS NULL',
      whereArgs: [scheduleId],
      limit: 1,
    );
    if (existing.isNotEmpty) return -1;

    final scheduleResults = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
    if (scheduleResults.isEmpty) return -1;

    final schedule = scheduleResults.first;
    final now = DateTime.now().toIso8601String();
    final event = CalendarEvent(
      title: schedule['title'] as String,
      description: schedule['description'] as String?,
      eventDate: schedule['scheduled_date'] as String,
      scheduleId: scheduleId,
      createdAt: now,
      updatedAt: now,
      // 종류를 승계한다 — 끊기면 행사가 업무로 둔갑해 오늘 탭에 뜬다.
      kind: EntryKind.fromValue(schedule['kind'] as String?),
    );
    return createEvent(event);
  }

  /// [cutoff]보다 오래 전에 soft-delete된 이벤트를 영구 삭제.
  /// 반환: 영구 삭제된 건수.
  Future<int> purgeOlderThan(DateTime cutoff) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableCalendarEvents,
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }
}
