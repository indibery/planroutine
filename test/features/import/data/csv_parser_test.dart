import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/import/data/csv_parser.dart';

void main() {
  late CsvParser parser;

  setUp(() {
    parser = const CsvParser();
  });

  group('CsvParser.parse', () {
    test('한국어 헤더가 있는 유효한 CSV 파싱', () {
      const csv = '문서번호,결재유형,제목,기안(접수)자,등록일자,과제명,과제카드명,보존기한\n'
          'DOC-001,전자결재,교육과정 운영 계획,홍길동,2025-03-15,교육과정계획,교육과정 운영,5년\n'
          'DOC-002,전자결재,교직원 회의록,김교사,2025-03-20,일과운영관리,일과운영,3년';

      final result = parser.parse(csv);

      expect(result.length, 2);
      expect(result[0].title, '교육과정 운영 계획');
      expect(result[0].documentNumber, 'DOC-001');
      expect(result[0].registrationDate, '2025-03-15');
      expect(result[0].category, '교육과정계획');
      expect(result[1].title, '교직원 회의록');
      expect(result[1].drafter, '김교사');
    });

    test('빈 콘텐츠는 빈 리스트 반환', () {
      final result = parser.parse('');
      expect(result, isEmpty);
    });

    test('헤더만 있는 경우 빈 리스트 반환', () {
      const csv = '문서번호,결재유형,제목,기안(접수)자,등록일자,과제명,과제카드명,보존기한';

      final result = parser.parse(csv);
      expect(result, isEmpty);
    });

    test('제목이 비어있는 행은 건너뛰기', () {
      const csv = '제목,등록일자\n'
          ',2025-03-15\n'
          '유효한 일정,2025-03-20';

      final result = parser.parse(csv);
      expect(result.length, 1);
      expect(result[0].title, '유효한 일정');
    });

    test('등록일자가 비어있는 행은 건너뛰기', () {
      const csv = '제목,등록일자\n'
          '일정 제목,\n'
          '유효한 일정,2025-03-20';

      final result = parser.parse(csv);
      expect(result.length, 1);
      expect(result[0].title, '유효한 일정');
    });

    test('Windows EOL(\\r\\n) 정규화 처리', () {
      const csv = '제목,등록일자\r\n유효한 일정,2025-03-15';

      final result = parser.parse(csv);
      expect(result.length, 1);
      expect(result[0].title, '유효한 일정');
    });

    test('구형 Mac EOL(\\r) 정규화 처리', () {
      const csv = '제목,등록일자\r유효한 일정,2025-04-01';

      final result = parser.parse(csv);
      expect(result.length, 1);
      expect(result[0].title, '유효한 일정');
    });

    test('일부 컬럼이 누락된 CSV 처리', () {
      const csv = '제목,등록일자\n'
          '간단한 업무,2025-06-01';

      final result = parser.parse(csv);
      expect(result.length, 1);
      expect(result[0].title, '간단한 업무');
      expect(result[0].documentNumber, isNull);
      expect(result[0].category, isNull);
    });

    test('여러 행 파싱 후 sourceYear 추출', () {
      const csv = '제목,등록일자\n'
          '1월 업무,2025-01-10\n'
          '6월 업무,2025-06-15\n'
          '12월 업무,2025-12-31';

      final result = parser.parse(csv);
      expect(result.length, 3);
      expect(result[0].sourceYear, 2025);
      expect(result[1].sourceYear, 2025);
      expect(result[2].sourceYear, 2025);
    });
  });

  group('CsvParser.decodeBytes', () {
    test('UTF-8 바이트 디코딩', () async {
      final content = '제목,등록일자\n교육과정 운영,2025-03-15';
      final bytes = utf8.encode(content);

      final result = await parser.decodeBytes(bytes);
      expect(result, content);
    });

    test('순수 ASCII 바이트 디코딩', () async {
      final content = 'title,date\ntest,2025-01-01';
      final bytes = utf8.encode(content);

      final result = await parser.decodeBytes(bytes);
      expect(result, content);
    });
  });
}
