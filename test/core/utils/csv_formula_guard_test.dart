import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/csv_formula_guard.dart';

void main() {
  group('escapeCsvFormula — 스프레드시트 수식 인젝션 무해화', () {
    test('수식 시작 문자(= + - @)는 앞에 작은따옴표', () {
      expect(escapeCsvFormula('=SUM(A1)'), "'=SUM(A1)");
      expect(escapeCsvFormula('+1'), "'+1");
      expect(escapeCsvFormula('-2차 회의'), "'-2차 회의");
      expect(escapeCsvFormula('@handle'), "'@handle");
      expect(escapeCsvFormula('=HYPERLINK("http://evil.kr","총회")'),
          '\'=HYPERLINK("http://evil.kr","총회")');
    });

    test('탭/CR/LF 시작도 무해화(선행 공백 트릭 차단)', () {
      expect(escapeCsvFormula('\t=x'), "'\t=x");
      expect(escapeCsvFormula('\r=x'), "'\r=x");
    });

    test('일반 텍스트는 그대로', () {
      expect(escapeCsvFormula('3월 학부모총회'), '3월 학부모총회');
      expect(escapeCsvFormula('2026학년도 입학식'), '2026학년도 입학식');
      expect(escapeCsvFormula(''), '');
    });

    test('이미 무해화된(작은따옴표 시작) 셀은 재export해도 누적 안 됨', () {
      expect(escapeCsvFormula("'=SUM"), "'=SUM");
    });
  });
}
