import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/title_year_utils.dart';

void main() {
  group('bumpTitleYear — 제목의 이전 연도를 올해로', () {
    test('학년도 표기 이전 연도를 올해로 치환', () {
      final r = bumpTitleYear('2025학년도 겨울방학 운영 계획', 2026);
      expect(r.title, '2026학년도 겨울방학 운영 계획');
      expect(r.from, 2025);
    });

    test('"년" 표기도 치환', () {
      final r = bumpTitleYear('2025년 겨울방학 현수막 품의', 2026);
      expect(r.title, '2026년 겨울방학 현수막 품의');
      expect(r.from, 2025);
    });

    test('올해 이상 연도는 건드리지 않음 (이미 미래 참조)', () {
      final r = bumpTitleYear('2026학년도 본예산요구서 제출', 2026);
      expect(r.title, '2026학년도 본예산요구서 제출');
      expect(r.from, isNull);
    });

    test('미래 연도도 건드리지 않음', () {
      final r = bumpTitleYear('2027 졸업식 행사 협의', 2026);
      expect(r.title, '2027 졸업식 행사 협의');
      expect(r.from, isNull);
    });

    test('연도 없는 제목은 그대로', () {
      final r = bumpTitleYear('종업식 및 졸업식 안내장', 2026);
      expect(r.title, '종업식 및 졸업식 안내장');
      expect(r.from, isNull);
    });

    test('한 제목에 옛 연도+미래 연도 → 옛 연도만 치환, from은 옛 연도', () {
      final r = bumpTitleYear(
        '2025학년도 안건발의서[2026학년도 보결수업 규정 개정]',
        2026,
      );
      expect(r.title, '2026학년도 안건발의서[2026학년도 보결수업 규정 개정]');
      expect(r.from, 2025);
    });

    test('2년 전 데이터도 올해로 (from은 가장 이른 옛 연도)', () {
      final r = bumpTitleYear('2024학년도 결산 보고', 2026);
      expect(r.title, '2026학년도 결산 보고', reason: '2024 < 2026 → 2026');
      expect(r.from, 2024);
    });

    test('연도처럼 보이는 비연도 4자리는 치환하지 않음 (19xx/그 외)', () {
      // 1000명 같은 수치는 연도(20xx)가 아니므로 건드리지 않는다.
      final r = bumpTitleYear('1000명 참가 행사 계획', 2026);
      expect(r.title, '1000명 참가 행사 계획');
      expect(r.from, isNull);
    });

    test('더 긴 숫자열 안의 20xx는 연도로 보지 않음', () {
      final r = bumpTitleYear('문서120250 처리', 2026);
      expect(r.title, '문서120250 처리');
      expect(r.from, isNull);
    });
  });
}
