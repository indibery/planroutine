import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:csv/csv.dart';

import '../domain/imported_schedule.dart';

/// 파싱 결과 — 플랜루틴 자체 export CSV는 상태별 재import용 추가 필드 포함
class ParsedCsv {
  const ParsedCsv({
    required this.schedules,
    required this.isPlanRoutineFormat,
    required this.confirmedTitles,
    required this.descriptionsByTitle,
  });

  final List<ImportedSchedule> schedules;

  /// 헤더에 "상태" 컬럼이 있으면 플랜루틴 자체 export 포맷으로 간주
  final bool isPlanRoutineFormat;

  /// 상태=confirmed인 제목+날짜 키셋 (자동 확정에 사용)
  final Set<String> confirmedTitles;

  /// 제목+날짜 → 설명 맵 (원본 CSV엔 설명 필드가 없음)
  final Map<String, String> descriptionsByTitle;
}

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

  /// CSV 문자열을 파싱하여 ImportedSchedule 목록 반환 (역호환)
  List<ImportedSchedule> parse(String csvContent) {
    return parseWithMetadata(csvContent).schedules;
  }

  /// CSV를 파싱하고 포맷 메타데이터까지 함께 반환.
  /// "상태" 컬럼이 있으면 플랜루틴 자체 export로 간주해
  /// 자동 확정 플로우로 분기할 수 있게 한다.
  ParsedCsv parseWithMetadata(String csvContent) {
    final normalized = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final converter = const CsvToListConverter(eol: '\n');
    final rows = converter.convert(normalized.trim());

    if (rows.isEmpty) {
      return const ParsedCsv(
        schedules: [],
        isPlanRoutineFormat: false,
        confirmedTitles: {},
        descriptionsByTitle: {},
      );
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final hasStatus = headers.contains('상태');

    final schedules = <ImportedSchedule>[];
    final confirmedTitles = <String>{};
    final descriptionsByTitle = <String, String>{};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty ||
          (row.length == 1 && row.first.toString().trim().isEmpty)) {
        continue;
      }

      final rowMap = <String, dynamic>{};
      for (var j = 0; j < headers.length && j < row.length; j++) {
        rowMap[headers[j]] = row[j].toString();
      }

      final title = (rowMap['제목'] as String? ?? '').trim();
      final date = (rowMap['등록일자'] as String? ?? '').trim();
      if (title.isEmpty || date.isEmpty) continue;

      // 플랜루틴 export는 "카테고리" 컬럼을 쓰므로 "과제명"으로 alias
      // (과제명 미존재 + 카테고리 존재일 때만 복사해 원본 테스트 호환 유지)
      if (!rowMap.containsKey('과제명') && rowMap.containsKey('카테고리')) {
        rowMap['과제명'] = rowMap['카테고리'];
      }

      schedules.add(ImportedSchedule.fromCsvRow(rowMap));

      final key = '$title|$date';
      final status = (rowMap['상태'] as String? ?? '').trim();
      if (status == 'confirmed') confirmedTitles.add(key);
      final desc = (rowMap['설명'] as String? ?? '').trim();
      if (desc.isNotEmpty) descriptionsByTitle[key] = desc;
    }

    return ParsedCsv(
      schedules: schedules,
      isPlanRoutineFormat: hasStatus,
      confirmedTitles: confirmedTitles,
      descriptionsByTitle: descriptionsByTitle,
    );
  }
}
