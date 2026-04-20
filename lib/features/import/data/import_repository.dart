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

  /// CSV 콘텐츠를 파싱하여 DB에 일괄 저장 (ID 포함 반환)
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

    final results = await batch.commit();

    // 삽입된 ID를 반영한 목록 반환
    return List.generate(schedules.length, (i) {
      return schedules[i].copyWith(id: results[i] as int);
    });
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
      final count = (row['count'] as num).toInt();
      summary[category] = count;
    }
    return summary;
  }
}
