import '../../../core/database/database_helper.dart';
import '../domain/imported_schedule.dart';
import 'csv_parser.dart';

/// 가져오기 기능의 데이터 접근 계층
class ImportRepository {
  ImportRepository({
    DatabaseHelper? databaseHelper,
    CsvParser? csvParser,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _csvParser = csvParser ?? const CsvParser();

  final DatabaseHelper _databaseHelper;
  final CsvParser _csvParser;

  /// CSV 콘텐츠를 파싱하여 DB에 일괄 저장
  Future<List<ImportedSchedule>> importFromCsv(String csvContent) async {
    final schedules = _csvParser.parse(csvContent);
    if (schedules.isEmpty) {
      return [];
    }

    final db = await _databaseHelper.database;
    final batch = db.batch();

    for (final schedule in schedules) {
      batch.insert(
        DatabaseHelper.tableImportedSchedules,
        schedule.toMap(),
      );
    }

    await batch.commit(noResult: true);
    return schedules;
  }

  /// 저장된 일정 조회 (연도/카테고리 필터)
  Future<List<ImportedSchedule>> getImportedSchedules({
    int? year,
    String? category,
  }) async {
    final db = await _databaseHelper.database;
    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (year != null) {
      where.add('source_year = ?');
      whereArgs.add(year);
    }
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }

    final results = await db.query(
      DatabaseHelper.tableImportedSchedules,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'registration_date DESC',
    );

    return results.map(ImportedSchedule.fromMap).toList();
  }

  /// 저장된 연도 목록 조회
  Future<List<int>> getImportedYears() async {
    final db = await _databaseHelper.database;
    final results = await db.query(
      DatabaseHelper.tableImportedSchedules,
      distinct: true,
      columns: ['source_year'],
      where: 'source_year IS NOT NULL',
      orderBy: 'source_year DESC',
    );

    return results
        .map((row) => row['source_year'] as int)
        .toList();
  }

  /// 특정 연도의 모든 일정 삭제
  Future<int> deleteImportedYear(int year) async {
    final db = await _databaseHelper.database;
    return db.delete(
      DatabaseHelper.tableImportedSchedules,
      where: 'source_year = ?',
      whereArgs: [year],
    );
  }

  /// 특정 연도의 카테고리별 건수 집계
  Future<Map<String, int>> getCategorySummary(int year) async {
    final db = await _databaseHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT category, COUNT(*) as count
      FROM ${DatabaseHelper.tableImportedSchedules}
      WHERE source_year = ?
      GROUP BY category
      ORDER BY count DESC
      ''',
      [year],
    );

    final summary = <String, int>{};
    for (final row in results) {
      final category = row['category'] as String? ?? '미분류';
      final count = row['count'] as int;
      summary[category] = count;
    }
    return summary;
  }
}
