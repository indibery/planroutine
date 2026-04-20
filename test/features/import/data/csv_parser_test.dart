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

    test('UTF-8 BOM(EF BB BF)이 붙은 바이트도 투명하게 처리', () async {
      final content = '제목,등록일자\n교육과정 운영,2025-03-15';
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];

      final result = await parser.decodeBytes(bytes);
      // BOM이 문자열 앞에 붙지 않아야 함 — 첫 헤더가 "\uFEFF제목" 이면 parser가 실패
      expect(result.startsWith('제목'), isTrue);
      expect(result, content);
    });

    test('BOM이 붙은 CSV를 parse까지 연결했을 때도 첫 헤더 정상 인식', () async {
      const content = '제목,등록일자\n교육과정 운영,2025-03-15';
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];

      final decoded = await parser.decodeBytes(bytes);
      final result = parser.parse(decoded);

      expect(result.length, 1);
      expect(result[0].title, '교육과정 운영');
    });
  });

  group('CsvParser.parseWithMetadata', () {
    test('"상태" 컬럼이 없으면 원본 포맷으로 판정', () {
      const csv = '제목,등록일자,과제명\n'
          '회의록,2025-03-20,일과운영관리';

      final result = parser.parseWithMetadata(csv);

      expect(result.isPlanRoutineFormat, isFalse);
      expect(result.confirmedTitles, isEmpty);
      expect(result.descriptionsByTitle, isEmpty);
      expect(result.schedules.length, 1);
    });

    test('"상태" 컬럼이 있으면 PlanRoutine export 포맷으로 판정', () {
      const csv = '제목,등록일자,카테고리,설명,상태\n'
          '교육과정 운영,2025-03-15,교육과정,1학기 계획,confirmed\n'
          '직원 연수,2025-04-10,일과운영관리,,pending';

      final result = parser.parseWithMetadata(csv);

      expect(result.isPlanRoutineFormat, isTrue);
      expect(result.schedules.length, 2);
      // confirmedTitles는 '제목|날짜' key 형태
      expect(result.confirmedTitles, contains('교육과정 운영|2025-03-15'));
      expect(result.confirmedTitles, isNot(contains('직원 연수|2025-04-10')));
      // description 매핑
      expect(
        result.descriptionsByTitle['교육과정 운영|2025-03-15'],
        '1학기 계획',
      );
      expect(
        result.descriptionsByTitle.containsKey('직원 연수|2025-04-10'),
        isFalse, // 빈 설명은 맵에 추가되지 않음
      );
    });

    test('"카테고리" 컬럼이 "과제명" alias로 동작해 category 필드 채움', () {
      const csv = '제목,등록일자,카테고리,설명,상태\n'
          '연수,2025-04-10,조직및통계관리,,confirmed';

      final result = parser.parseWithMetadata(csv);

      expect(result.schedules.first.category, '조직및통계관리');
    });

    test('"과제명"과 "카테고리"가 동시에 있으면 과제명이 우선', () {
      const csv = '제목,등록일자,과제명,카테고리\n'
          '연수,2025-04-10,원본값,플랜루틴값';

      final result = parser.parseWithMetadata(csv);

      expect(result.schedules.first.category, '원본값');
    });

    test('상태가 "confirmed"가 아닌 값(archived/unknown)은 confirmedTitles에 포함 안 됨',
        () {
      const csv = '제목,등록일자,상태\n'
          '일정A,2025-01-01,confirmed\n'
          '일정B,2025-01-02,archived\n'
          '일정C,2025-01-03,\n'
          '일정D,2025-01-04,pending';

      final result = parser.parseWithMetadata(csv);

      expect(result.isPlanRoutineFormat, isTrue);
      expect(result.confirmedTitles, {'일정A|2025-01-01'});
    });

    test('빈 CSV도 안전하게 처리 (isPlanRoutineFormat=false)', () {
      final result = parser.parseWithMetadata('');
      expect(result.isPlanRoutineFormat, isFalse);
      expect(result.schedules, isEmpty);
      expect(result.confirmedTitles, isEmpty);
    });
  });
}
