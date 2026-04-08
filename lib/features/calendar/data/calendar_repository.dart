import '../../../core/database/database_helper.dart';
import '../domain/calendar_event.dart';

/// 캘린더 이벤트 DB 저장소
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

  /// 이벤트 삭제
  Future<int> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableCalendarEvents,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 특정 날짜의 이벤트 조회
  Future<List<CalendarEvent>> getEventsByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = _formatDate(date);
    final results = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'event_date = ?',
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

  /// 날짜 범위 이벤트 조회
  Future<List<CalendarEvent>> getEventsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final startStr = _formatDate(start);
    final endStr = _formatDate(end);
    final results = await db.query(
      DatabaseHelper.tableCalendarEvents,
      where: 'event_date >= ? AND event_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'event_date ASC, created_at ASC',
    );
    return results.map(CalendarEvent.fromMap).toList();
  }

  /// 확정된 일정에서 캘린더 이벤트 생성
  Future<int> createFromSchedule(int scheduleId) async {
    final db = await _dbHelper.database;
    final scheduleResults = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
    if (scheduleResults.isEmpty) {
      return -1;
    }
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

  /// DateTime을 yyyy-MM-dd 형식 문자열로 변환
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
