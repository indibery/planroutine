import '../../../core/database/database_helper.dart';
import '../../../core/utils/date_utils.dart';
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

  /// 이벤트 soft-delete (휴지통으로 이동)
  Future<int> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Google Calendar에 저장된 이벤트의 [googleEventId]를 기록.
  /// 다음 "Google 저장" 스와이프에서 update로 처리해 중복 생성 방지.
  Future<int> updateGoogleEventId(int id, String googleEventId) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {
        'google_event_id': googleEventId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 기기 캘린더에 저장된 이벤트의 [deviceEventId]를 기록.
  /// 다음 "기기 저장" 스와이프에서 update로 처리해 중복 생성 방지.
  Future<int> updateDeviceEventId(int id, String deviceEventId) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {
        'device_event_id': deviceEventId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 이벤트 복구
  Future<int> restoreEvent(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableCalendarEvents,
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 이벤트 영구 삭제 (DB row 제거)
  Future<int> permanentDeleteEvent(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableCalendarEvents,
      where: 'id = ?',
      whereArgs: [id],
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

  /// 특정 날짜의 이벤트 조회 (삭제되지 않은 것만)
  Future<List<CalendarEvent>> getEventsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = formatDate(date);
    final results = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'event_date = ? AND deleted_at IS NULL',
      whereArgs: [dateStr],
      orderBy: 'created_at ASC',
    );
    return results.map(CalendarEvent.fromMap).toList();
  }

  /// 특정 월의 모든 이벤트 조회
  Future<List<CalendarEvent>> getEventsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return getEventsByDateRange(start, end);
  }

  /// 날짜 범위 이벤트 조회 (삭제되지 않은 것만)
  Future<List<CalendarEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final results = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'event_date >= ? AND event_date <= ? AND deleted_at IS NULL',
      whereArgs: [startStr, endStr],
      orderBy: 'event_date ASC, created_at ASC',
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
