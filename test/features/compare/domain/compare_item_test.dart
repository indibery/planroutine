import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/compare/domain/compare_item.dart';

void main() {
  group('MatchType', () {
    test('4개 매칭 유형 존재', () {
      expect(MatchType.values.length, 4);
      expect(MatchType.values, contains(MatchType.exact));
      expect(MatchType.values, contains(MatchType.similar));
      expect(MatchType.values, contains(MatchType.onlyLastYear));
      expect(MatchType.values, contains(MatchType.onlyThisYear));
    });
  });

  group('ImportedScheduleData', () {
    test('fromMap으로 생성', () {
      final map = {
        'id': 1,
        'title': '교직원 회의',
        'registration_date': '2025-03-15',
        'category': '일과운영관리',
        'sub_category': '일과운영',
        'source_year': 2025,
      };

      final data = ImportedScheduleData.fromMap(map);

      expect(data.id, 1);
      expect(data.title, '교직원 회의');
      expect(data.registrationDate, '2025-03-15');
      expect(data.category, '일과운영관리');
      expect(data.subCategory, '일과운영');
      expect(data.sourceYear, 2025);
    });

    test('선택 필드가 null인 경우', () {
      final map = {
        'id': 2,
        'title': '간단 업무',
        'registration_date': '2025-06-01',
        'category': null,
        'sub_category': null,
        'source_year': null,
      };

      final data = ImportedScheduleData.fromMap(map);

      expect(data.category, isNull);
      expect(data.subCategory, isNull);
      expect(data.sourceYear, isNull);
    });
  });

  group('ScheduleData', () {
    test('fromMap으로 생성', () {
      final map = {
        'id': 1,
        'title': '교육과정 운영 계획',
        'scheduled_date': '2026-03-15',
        'category': '교육과정계획',
        'sub_category': '교육과정 운영',
        'status': 'confirmed',
      };

      final data = ScheduleData.fromMap(map);

      expect(data.id, 1);
      expect(data.title, '교육과정 운영 계획');
      expect(data.scheduledDate, '2026-03-15');
      expect(data.category, '교육과정계획');
      expect(data.subCategory, '교육과정 운영');
      expect(data.status, 'confirmed');
    });

    test('status가 null이면 pending 기본값', () {
      final map = {
        'id': 2,
        'title': '일정',
        'scheduled_date': '2026-04-01',
        'status': null,
      };

      final data = ScheduleData.fromMap(map);
      expect(data.status, 'pending');
    });
  });

  group('CompareItem', () {
    final lastYearItem = ImportedScheduleData(
      id: 1,
      title: '교직원 회의',
      registrationDate: '2025-03-15',
      category: '일과운영관리',
      sourceYear: 2025,
    );

    final thisYearItem = ScheduleData(
      id: 10,
      title: '교직원 회의',
      scheduledDate: '2026-03-15',
      status: 'confirmed',
    );

    test('exact 매칭: 작년과 올해 항목 모두 존재', () {
      final item = CompareItem(
        lastYearItem: lastYearItem,
        thisYearItem: thisYearItem,
        matchType: MatchType.exact,
        sortMonth: 3,
      );

      expect(item.lastYearItem, isNotNull);
      expect(item.thisYearItem, isNotNull);
      expect(item.matchType, MatchType.exact);
      expect(item.sortMonth, 3);
    });

    test('similar 매칭', () {
      final item = CompareItem(
        lastYearItem: lastYearItem,
        thisYearItem: thisYearItem,
        matchType: MatchType.similar,
        sortMonth: 3,
      );

      expect(item.matchType, MatchType.similar);
    });

    test('onlyLastYear: 작년 항목만 존재', () {
      final item = CompareItem(
        lastYearItem: lastYearItem,
        matchType: MatchType.onlyLastYear,
        sortMonth: 3,
      );

      expect(item.lastYearItem, isNotNull);
      expect(item.thisYearItem, isNull);
      expect(item.matchType, MatchType.onlyLastYear);
    });

    test('onlyThisYear: 올해 항목만 존재', () {
      final item = CompareItem(
        thisYearItem: thisYearItem,
        matchType: MatchType.onlyThisYear,
        sortMonth: 3,
      );

      expect(item.lastYearItem, isNull);
      expect(item.thisYearItem, isNotNull);
      expect(item.matchType, MatchType.onlyThisYear);
    });

    test('sortMonth 필드 정렬용 검증', () {
      final jan = CompareItem(
        lastYearItem: lastYearItem,
        matchType: MatchType.onlyLastYear,
        sortMonth: 1,
      );
      final dec = CompareItem(
        thisYearItem: thisYearItem,
        matchType: MatchType.onlyThisYear,
        sortMonth: 12,
      );

      expect(jan.sortMonth, lessThan(dec.sortMonth));
    });

    test('다양한 월의 CompareItem 정렬', () {
      final items = [
        CompareItem(
          lastYearItem: lastYearItem,
          matchType: MatchType.onlyLastYear,
          sortMonth: 9,
        ),
        CompareItem(
          thisYearItem: thisYearItem,
          matchType: MatchType.onlyThisYear,
          sortMonth: 3,
        ),
        CompareItem(
          lastYearItem: lastYearItem,
          thisYearItem: thisYearItem,
          matchType: MatchType.exact,
          sortMonth: 1,
        ),
      ];

      items.sort((a, b) => a.sortMonth.compareTo(b.sortMonth));

      expect(items[0].sortMonth, 1);
      expect(items[1].sortMonth, 3);
      expect(items[2].sortMonth, 9);
    });
  });
}
