import 'dart:convert';

import 'package:csv/csv.dart';

import '../domain/imported_schedule.dart';

/// CSV 문자열을 ImportedSchedule 목록으로 변환
class CsvParser {
  const CsvParser();

  /// CSV 바이트를 문자열로 디코딩
  /// UTF-8을 먼저 시도하고, 실패 시 latin1로 폴백
  /// (EUC-KR은 Dart 기본 지원이 없어 UTF-8/latin1으로 처리.
  ///  향후 euc_kr 패키지 도입 시 EUC-KR 직접 디코딩 가능)
  String decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // UTF-8 디코딩 실패 시 latin1 폴백
      return latin1.decode(bytes);
    }
  }

  /// CSV 문자열을 파싱하여 ImportedSchedule 목록 반환
  List<ImportedSchedule> parse(String csvContent) {
    final converter = const CsvToListConverter(eol: '\n');
    final rows = converter.convert(csvContent.trim());

    if (rows.isEmpty) {
      return [];
    }

    // 첫 번째 행을 헤더로 사용
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final schedules = <ImportedSchedule>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      // 빈 행 건너뛰기
      if (row.isEmpty || (row.length == 1 && row.first.toString().trim().isEmpty)) {
        continue;
      }

      final rowMap = <String, dynamic>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        rowMap[headers[j]] = row[j].toString();
      }

      // 제목과 등록일자가 비어있으면 건너뛰기
      final title = (rowMap['제목'] as String? ?? '').trim();
      final date = (rowMap['등록일자'] as String? ?? '').trim();
      if (title.isEmpty || date.isEmpty) {
        continue;
      }

      schedules.add(ImportedSchedule.fromCsvRow(rowMap));
    }

    return schedules;
  }
}
