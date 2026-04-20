import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:csv/csv.dart';

import '../domain/imported_schedule.dart';

/// CSV 문자열을 ImportedSchedule 목록으로 변환
class CsvParser {
  const CsvParser();

  /// CSV 바이트를 문자열로 디코딩
  /// UTF-8 → EUC-KR 순서로 시도
  /// (한국 학교 행정 시스템 CSV는 대부분 EUC-KR, 플랜루틴 export는 UTF-8 BOM)
  Future<String> decodeBytes(List<int> bytes) async {
    // UTF-8 BOM(EF BB BF)이 앞에 있으면 스트립 — 첫 헤더가 "\uFEFF제목"이 되는 것 방지
    final payload = _stripUtf8Bom(bytes);
    try {
      return utf8.decode(payload);
    } on FormatException {
      // UTF-8 실패 시 EUC-KR로 디코딩
      final uint8Bytes = Uint8List.fromList(payload);
      final decoded = await CharsetConverter.decode(
        'euc-kr',
        uint8Bytes,
      );
      return decoded;
    }
  }

  List<int> _stripUtf8Bom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }

  /// CSV 문자열을 파싱하여 ImportedSchedule 목록 반환
  List<ImportedSchedule> parse(String csvContent) {
    // Windows(\r\n) 및 구형 Mac(\r) EOL 정규화
    final normalized = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final converter = const CsvToListConverter(eol: '\n');
    final rows = converter.convert(normalized.trim());

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
