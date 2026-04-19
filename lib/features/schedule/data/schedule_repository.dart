import '../../../core/database/database_helper.dart';
import '../domain/schedule.dart';

/// 일정 데이터 관리 리포지토리
class ScheduleRepository {
  final DatabaseHelper _dbHelper;

  ScheduleRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 가져온 일정에서 새 일정 생성 (중복 source_id 스킵, -1 반환)
  Future<int> createFromImported(
    int importedScheduleId,
    DateTime scheduledDate,
  ) async {
    final db = await _dbHelper.database;

    // 중복 확인
    final existing = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'source_id = ?',
      whereArgs: [importedScheduleId],
      limit: 1,
    );
    if (existing.isNotEmpty) return -1;

    final imported = await db.query(
      DatabaseHelper.tableImportedSchedules,
      where: 'id = ?',
      whereArgs: [importedScheduleId],
    );

    if (imported.isEmpty) {
      throw Exception('가져온 일정을 찾을 수 없습니다: $importedScheduleId');
    }

    final row = imported.first;
    final now = DateTime.now().toIso8601String();
    final schedule = Schedule(
      title: row['title'] as String,
      scheduledDate: scheduledDate.toIso8601String().split('T').first,
      category: row['category'] as String?,
      subCategory: row['sub_category'] as String?,
      sourceId: importedScheduleId,
      status: ScheduleStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    return db.insert(DatabaseHelper.tableSchedules, schedule.toMap());
  }

  /// 여러 가져온 일정에서 일괄 생성 (중복 source_id 스킵)
  /// 반환: (등록 건수, 스킵 건수)
  Future<({int created, int skipped})> createBulkFromImported(
    List<({int importedId, DateTime date})> items,
  ) async {
    final db = await _dbHelper.database;
    var created = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      for (final item in items) {
        // 이미 등록된 source_id인지 확인
        final existing = await txn.query(
          DatabaseHelper.tableSchedules,
          where: 'source_id = ?',
          whereArgs: [item.importedId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          skipped++;
          continue;
        }

        final imported = await txn.query(
          DatabaseHelper.tableImportedSchedules,
          where: 'id = ?',
          whereArgs: [item.importedId],
        );

        if (imported.isEmpty) continue;

        final row = imported.first;
        final now = DateTime.now().toIso8601String();
        final schedule = Schedule(
          title: row['title'] as String,
          scheduledDate: item.date.toIso8601String().split('T').first,
          category: row['category'] as String?,
          subCategory: row['sub_category'] as String?,
          sourceId: item.importedId,
          status: ScheduleStatus.pending,
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert(
          DatabaseHelper.tableSchedules,
          schedule.toMap(),
        );
        created++;
      }
    });

    return (created: created, skipped: skipped);
  }

  /// 필터 조건으로 일정 목록 조회
  Future<List<Schedule>> getSchedules({
    ScheduleStatus? status,
    String? category,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      whereArgs.add(status.value);
    }
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }

    final result = await db.query(
      DatabaseHelper.tableSchedules,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'scheduled_date ASC',
    );

    return result.map(Schedule.fromMap).toList();
  }

  /// 일정 상태 변경
  Future<int> updateStatus(int id, ScheduleStatus status) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableSchedules,
      {
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 일정 정보 수정
  Future<int> updateSchedule(
    int id, {
    String? title,
    DateTime? date,
    String? description,
  }) async {
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (title != null) updates['title'] = title;
    if (date != null) {
      updates['scheduled_date'] = date.toIso8601String().split('T').first;
    }
    if (description != null) updates['description'] = description;

    return db.update(
      DatabaseHelper.tableSchedules,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 일정 삭제
  Future<int> deleteSchedule(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableSchedules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 월별 일정 조회
  Future<List<Schedule>> getSchedulesByMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final startDate =
        '$year-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final endDate =
        '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

    final result = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'scheduled_date >= ? AND scheduled_date < ?',
      whereArgs: [startDate, endDate],
      orderBy: 'scheduled_date ASC',
    );

    return result.map(Schedule.fromMap).toList();
  }

  /// 전체 일정 삭제 (테스트용)
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return db.delete(DatabaseHelper.tableSchedules);
  }

  /// 검토 대기 상태 일정 일괄 확정
  Future<int> confirmAllPending() async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableSchedules,
      {
        'status': ScheduleStatus.confirmed.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [ScheduleStatus.pending.value],
    );
  }
}
