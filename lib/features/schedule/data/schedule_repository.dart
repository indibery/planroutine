import '../../../core/database/database_helper.dart';
import '../domain/schedule.dart';

/// 일정 데이터 관리 리포지토리.
///
/// 삭제는 soft-delete: `deleted_at` 컬럼에 삭제 시각을 기록하여
/// 휴지통에서 복구 가능. 모든 활성 조회는 `deleted_at IS NULL` 필터를 적용.
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

    // 중복 확인 (활성 기준 — 휴지통 항목은 재임포트 가능)
    final existing = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'source_id = ? AND deleted_at IS NULL',
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
        // 이미 등록된 source_id인지 확인 (활성 기준)
        final existing = await txn.query(
          DatabaseHelper.tableSchedules,
          where: 'source_id = ? AND deleted_at IS NULL',
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

  /// 필터 조건으로 일정 목록 조회 (삭제되지 않은 것만)
  Future<List<Schedule>> getSchedules({
    ScheduleStatus? status,
    String? category,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>['deleted_at IS NULL'];
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
      where: where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'scheduled_date ASC',
    );

    return result.map(Schedule.fromMap).toList();
  }

  /// 활성 일정에서 사용 중인 카테고리를 빈도 내림차순으로 반환.
  /// NULL/빈 문자열은 제외. 휴지통 항목은 제외.
  Future<List<String>> getDistinctCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT category, COUNT(*) AS cnt FROM ${DatabaseHelper.tableSchedules} '
      "WHERE deleted_at IS NULL AND category IS NOT NULL AND category != '' "
      'GROUP BY category '
      'ORDER BY cnt DESC, category ASC',
    );
    return result.map((row) => row['category'] as String).toList();
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

  /// 일정 soft-delete (휴지통으로 이동)
  Future<int> deleteSchedule(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableSchedules,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 일정 복구
  Future<int> restoreSchedule(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableSchedules,
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 일정 영구 삭제 (DB row 제거)
  Future<int> permanentDeleteSchedule(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableSchedules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 플랜루틴 export CSV 재임포트용 — Schedule을 주어진 상태 그대로 삽입.
  ///
  /// 같은 (title, scheduled_date) 조합의 활성 일정이 이미 있으면 스킵하고 -1 반환.
  /// 성공 시 새 row id 반환.
  Future<int> insertConfirmedOrPending(Schedule schedule) async {
    final db = await _dbHelper.database;
    final existing = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'title = ? AND scheduled_date = ? AND deleted_at IS NULL',
      whereArgs: [schedule.title, schedule.scheduledDate],
      limit: 1,
    );
    if (existing.isNotEmpty) return -1;
    return db.insert(DatabaseHelper.tableSchedules, schedule.toMap());
  }

  /// 휴지통 일정 목록 (최근 삭제 순)
  Future<List<Schedule>> getDeletedSchedules() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tableSchedules,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return results.map(Schedule.fromMap).toList();
  }

  /// 월별 일정 조회 (삭제되지 않은 것만)
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
      where:
          'scheduled_date >= ? AND scheduled_date < ? AND deleted_at IS NULL',
      whereArgs: [startDate, endDate],
      orderBy: 'scheduled_date ASC',
    );

    return result.map(Schedule.fromMap).toList();
  }

  /// 전체 일정 삭제 (설정의 "전체 데이터 초기화"에서 사용 — hard delete)
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
      where: 'status = ? AND deleted_at IS NULL',
      whereArgs: [ScheduleStatus.pending.value],
    );
  }

  /// [cutoff]보다 오래 전에 soft-delete된 일정을 영구 삭제.
  /// 반환: 영구 삭제된 건수.
  Future<int> purgeOlderThan(DateTime cutoff) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableSchedules,
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }
}
