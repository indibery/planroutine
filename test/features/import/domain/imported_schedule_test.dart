import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/import/domain/imported_schedule.dart';

void main() {
  group('ImportedSchedule', () {
    group('fromCsvRow', () {
      test('모든 필드가 있는 CSV 행을 올바르게 파싱', () {
        final row = {
          '문서번호': 'DOC-2025-001',
          '결재유형': '전자결재',
          '제목': '2025학년도 교육과정 운영 계획',
          '기안(접수)자': '홍길동',
          '등록일자': '2025-03-15',
          '과제명': '교육과정계획',
          '과제카드명': '교육과정 운영',
          '보존기한': '5년',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);

        expect(schedule.documentNumber, 'DOC-2025-001');
        expect(schedule.approvalType, '전자결재');
        expect(schedule.title, '2025학년도 교육과정 운영 계획');
        expect(schedule.drafter, '홍길동');
        expect(schedule.registrationDate, '2025-03-15');
        expect(schedule.category, '교육과정계획');
        expect(schedule.subCategory, '교육과정 운영');
        expect(schedule.retentionPeriod, '5년');
        expect(schedule.sourceYear, 2025);
        expect(schedule.importedAt, isNotNull);
      });

      test('누락/null 필드도 정상 처리', () {
        final row = <String, dynamic>{
          '제목': '간단한 업무',
          '등록일자': '2025-06-01',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);

        expect(schedule.documentNumber, isNull);
        expect(schedule.approvalType, isNull);
        expect(schedule.title, '간단한 업무');
        expect(schedule.drafter, isNull);
        expect(schedule.registrationDate, '2025-06-01');
        expect(schedule.category, isNull);
        expect(schedule.subCategory, isNull);
        expect(schedule.retentionPeriod, isNull);
        expect(schedule.sourceYear, 2025);
      });

      test('등록일자에서 sourceYear 추출', () {
        final row = {
          '제목': '연도 추출 테스트',
          '등록일자': '2024-12-25',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);
        expect(schedule.sourceYear, 2024);
      });

      test('등록일자가 빈 문자열이면 sourceYear가 null', () {
        final row = {
          '제목': '빈 날짜 테스트',
          '등록일자': '',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);
        expect(schedule.sourceYear, isNull);
        expect(schedule.registrationDate, '');
      });

      test('등록일자가 4자 미만이면 sourceYear가 null', () {
        final row = {
          '제목': '짧은 날짜',
          '등록일자': '20',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);
        expect(schedule.sourceYear, isNull);
      });

      test('제목과 등록일자가 null이면 빈 문자열 기본값', () {
        final row = <String, dynamic>{};

        final schedule = ImportedSchedule.fromCsvRow(row);
        expect(schedule.title, '');
        expect(schedule.registrationDate, '');
        expect(schedule.sourceYear, isNull);
      });

      test('필드 앞뒤 공백 제거', () {
        final row = {
          '문서번호': '  DOC-001  ',
          '결재유형': ' 전자결재 ',
          '제목': '  공백 테스트  ',
          '기안(접수)자': ' 김교사 ',
          '등록일자': ' 2025-03-15 ',
          '과제명': ' 일과운영관리 ',
          '과제카드명': ' 일과운영 ',
          '보존기한': ' 3년 ',
        };

        final schedule = ImportedSchedule.fromCsvRow(row);

        expect(schedule.documentNumber, 'DOC-001');
        expect(schedule.approvalType, '전자결재');
        expect(schedule.title, '공백 테스트');
        expect(schedule.drafter, '김교사');
        expect(schedule.registrationDate, '2025-03-15');
        expect(schedule.category, '일과운영관리');
        expect(schedule.subCategory, '일과운영');
        expect(schedule.retentionPeriod, '3년');
      });
    });

    group('fromMap / toMap 라운드트립', () {
      test('모든 필드가 있는 경우 정상 변환', () {
        final map = {
          'id': 1,
          'document_number': 'DOC-2025-001',
          'approval_type': '전자결재',
          'title': '교육과정 운영 계획',
          'drafter': '홍길동',
          'registration_date': '2025-03-15',
          'category': '교육과정계획',
          'sub_category': '교육과정 운영',
          'retention_period': '5년',
          'source_year': 2025,
          'imported_at': '2026-04-09T10:00:00.000',
        };

        final schedule = ImportedSchedule.fromMap(map);
        final result = schedule.toMap();

        expect(result['id'], 1);
        expect(result['document_number'], 'DOC-2025-001');
        expect(result['approval_type'], '전자결재');
        expect(result['title'], '교육과정 운영 계획');
        expect(result['drafter'], '홍길동');
        expect(result['registration_date'], '2025-03-15');
        expect(result['category'], '교육과정계획');
        expect(result['sub_category'], '교육과정 운영');
        expect(result['retention_period'], '5년');
        expect(result['source_year'], 2025);
        expect(result['imported_at'], '2026-04-09T10:00:00.000');
      });

      test('선택 필드가 null인 경우', () {
        final map = {
          'id': null,
          'document_number': null,
          'approval_type': null,
          'title': '간단한 업무',
          'drafter': null,
          'registration_date': '2025-06-01',
          'category': null,
          'sub_category': null,
          'retention_period': null,
          'source_year': null,
          'imported_at': null,
        };

        final schedule = ImportedSchedule.fromMap(map);

        expect(schedule.id, isNull);
        expect(schedule.documentNumber, isNull);
        expect(schedule.title, '간단한 업무');
        expect(schedule.registrationDate, '2025-06-01');
        expect(schedule.sourceYear, isNull);
      });
    });

    group('toMap id 처리', () {
      test('id가 null이면 map에 id 미포함', () {
        final schedule = ImportedSchedule(
          title: '새 일정',
          registrationDate: '2025-04-01',
          importedAt: '2026-04-09T10:00:00.000',
        );

        final map = schedule.toMap();
        expect(map.containsKey('id'), false);
      });

      test('id가 있으면 map에 id 포함', () {
        final schedule = ImportedSchedule(
          id: 42,
          title: '기존 일정',
          registrationDate: '2025-04-01',
          importedAt: '2026-04-09T10:00:00.000',
        );

        final map = schedule.toMap();
        expect(map['id'], 42);
      });
    });

    group('toMap importedAt 기본값', () {
      test('importedAt이 null이면 현재 시각 자동 설정', () {
        final schedule = ImportedSchedule(
          title: '테스트',
          registrationDate: '2025-04-01',
        );

        final map = schedule.toMap();
        expect(map['imported_at'], isNotNull);
        expect(map['imported_at'], isA<String>());
      });

      test('importedAt이 있으면 해당 값 유지', () {
        final schedule = ImportedSchedule(
          title: '테스트',
          registrationDate: '2025-04-01',
          importedAt: '2026-01-01T00:00:00.000',
        );

        final map = schedule.toMap();
        expect(map['imported_at'], '2026-01-01T00:00:00.000');
      });
    });
  });
}
