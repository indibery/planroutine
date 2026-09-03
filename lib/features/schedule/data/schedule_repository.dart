import '../../../core/database/database_helper.dart';
import '../domain/entry_kind.dart';
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
        final title = row['title'] as String;
        final scheduledDate = item.date.toIso8601String().split('T').first;

        // 내용(title+date) 중복 확인 — 같은 CSV 재임포트 시 imported_schedules가
        // 새 id로 쌓여 source_id 검사만으론 못 잡는 중복을 차단. 상태 무관(확정본과도
        // 중복 방지). export 재임포트 경로(insertConfirmedOrPending)와 동일 기준.
        final dupByContent = await txn.query(
          DatabaseHelper.tableSchedules,
          where: 'title = ? AND scheduled_date = ? AND deleted_at IS NULL',
          whereArgs: [title, scheduledDate],
          limit: 1,
        );
        if (dupByContent.isNotEmpty) {
          skipped++;
          continue;
        }

        final now = DateTime.now().toIso8601String();
        final schedule = Schedule(
          title: title,
          scheduledDate: scheduledDate,
          category: row['category'] as String?,
          subCategory: row['sub_category'] as String?,
          sourceId: item.importedId,
          status: ScheduleStatus.pending,
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert(DatabaseHelper.tableSchedules, schedule.toMap());
        created++;
      }
    });

    return (created: created, skipped: skipped);
  }

  /// 상태·종류로 일정 목록 조회 (삭제되지 않은 것만).
  ///
  /// **카테고리 인자는 없다**(2026-09-03). 입력 탭의 카테고리 필터를 없애면서
  /// 유일한 호출부가 사라졌다 — 컬럼과 CSV 내보내기의 카테고리 값은 그대로다.
  Future<List<Schedule>> getSchedules({
    ScheduleStatus? status,
    EntryKind? kind,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>['deleted_at IS NULL'];
    final whereArgs = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      whereArgs.add(status.value);
    }
    if (kind != null) {
      where.add('kind = ?');
      whereArgs.add(kind.dbValue);
    }

    final result = await db.query(
      DatabaseHelper.tableSchedules,
      where: where.join(' AND '),
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
      {'status': status.value, 'updated_at': DateTime.now().toIso8601String()},
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
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endMonth = month == 12 ? 1 : month + 1;
    final endYear = month == 12 ? year + 1 : year;
    final endDate = '$endYear-${endMonth.toString().padLeft(2, '0')}-01';

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

  /// 검토 대기 상태 일정 일괄 확정.
  /// [kind]가 null이면 대기 전체, 값이 있으면 그 종류만 — 입력 탭이 종류별로
  /// 나눠 확정한다.
  Future<int> confirmAllPending({EntryKind? kind}) {
    return _updateAllPending(
      {
        'status': ScheduleStatus.confirmed.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      kind: kind,
    );
  }

  /// 검토 대기 상태 일정 일괄 삭제(soft-delete → 휴지통).
  /// [kind]가 null이면 대기 전체. 확정된 일정(status=confirmed)은 건드리지 않는다.
  /// 반환: 삭제된 건수.
  ///
  /// ⚠️ **[kind]를 넘기는 프로덕션 호출부는 없다**(입력 탭은 대기 전체로만 부른다).
  /// 삭제 pill의 건수가 필터 없는 대기 전체 길이라, 여기에 [kind]를 넘기면
  /// **화면의 수와 지워지는 수가 갈린다** — `행사 4건 삭제`를 눌러 21건이 사라진
  /// 그 버그가 그대로 재현된다. 대칭 자체는 [_updateAllPending]이 구조로 보장하므로
  /// 이 인자는 그 근거가 아니다. 지금은 대칭 가드가 두 경로를 같은 축으로 비교하기
  /// 위해서만 쓴다 — 새 호출부를 만들려면 pill 건수부터 같이 좁혀야 한다.
  Future<int> deleteAllPending({EntryKind? kind}) {
    return _updateAllPending(
      {'deleted_at': DateTime.now().toIso8601String()},
      kind: kind,
    );
  }

  /// 위 둘의 공통 범위. 확정과 삭제가 **같은 항목 집합**을 잡는다는 보장을 산문이
  /// 아니라 코드로 둔다 — 한쪽에만 필터를 추가해 어긋났던 것이 이 버그였다.
  /// 다음 범위 조건(기간 등)도 여기 한 곳만 고치면 양쪽에 동시에 걸린다.
  Future<int> _updateAllPending(
    Map<String, Object?> values, {
    EntryKind? kind,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>['status = ?', 'deleted_at IS NULL'];
    final whereArgs = <dynamic>[ScheduleStatus.pending.value];
    if (kind != null) {
      where.add('kind = ?');
      whereArgs.add(kind.dbValue);
    }
    return db.update(
      DatabaseHelper.tableSchedules,
      values,
      where: where.join(' AND '),
      whereArgs: whereArgs,
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
