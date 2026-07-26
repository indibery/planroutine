import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/utils/title_year_utils.dart';

void main() {
  group('shiftTitleYears — 제목의 연도를 한 해 민다', () {
    test('학년도 표기를 한 해 뒤로', () {
      final r = shiftTitleYears('2025학년도 겨울방학 운영 계획');
      expect(r.title, '2026학년도 겨울방학 운영 계획');
      expect(r.from, [2025]);
    });

    test('"년" 표기도 이동', () {
      final r = shiftTitleYears('2025년 겨울방학 현수막 품의');
      expect(r.title, '2026년 겨울방학 현수막 품의');
      expect(r.from, [2025]);
    });

    test('올해 연도도 민다 — 12월 업무가 가리키는 2월 졸업식은 한 해 뒤가 된다', () {
      final r = shiftTitleYears('2026 졸업식 행사 협의');
      expect(r.title, '2027 졸업식 행사 협의');
      expect(r.from, [2026]);
    });

    test('미래 연도도 민다 (상대 기준이라 예외를 두지 않는다)', () {
      final r = shiftTitleYears('2027 졸업식 행사 협의');
      expect(r.title, '2028 졸업식 행사 협의');
      expect(r.from, [2027]);
    });

    test('먼 과거·먼 미래도 예외 없이 한 해씩 — 크기에 따른 분기가 없다', () {
      expect(shiftTitleYears('2009 자료').title, '2010 자료');
      expect(shiftTitleYears('2030 로드맵').title, '2031 로드맵');
      // 2100은 매칭 패턴(20\d\d) 밖이지만, 치환은 원본 문자열의 매치(2099)에
      // 대해 한 번만 일어나고 결과 문자열을 다시 정규식으로 스캔하지 않는다.
      // 그래서 출력이 패턴 밖 값이어도 정상 동작이다.
      expect(shiftTitleYears('2099 비전').title, '2100 비전');
    });

    test('연도 없는 제목은 그대로, from은 빈 리스트', () {
      final r = shiftTitleYears('종업식 및 졸업식 안내장');
      expect(r.title, '종업식 및 졸업식 안내장');
      expect(r.from, isEmpty);
    });

    test('한 제목에 두 연도 — 간격이 유지된다', () {
      final r = shiftTitleYears('2025학년도 안건발의서[2026학년도 보결수업 규정 개정]');
      expect(
        r.title,
        '2026학년도 안건발의서[2027학년도 보결수업 규정 개정]',
        reason: '"올해로 맞추기"는 둘 다 2026으로 뭉갰다 — 상대 이동은 1년 간격을 지킨다',
      );
      expect(r.from, [2025, 2026]);
    });

    test('두 해 전 자료는 한 번에 올해가 되지 않는다 (한 번 더 눌러야 함)', () {
      final r = shiftTitleYears('2024학년도 결산 보고');
      expect(r.title, '2025학년도 결산 보고');
      expect(r.from, [2024]);
    });

    test('연도처럼 보이는 비연도 4자리는 건드리지 않음', () {
      final r = shiftTitleYears('1000명 참가 행사 계획');
      expect(r.title, '1000명 참가 행사 계획');
      expect(r.from, isEmpty);
    });

    test('더 긴 숫자열 안의 20xx는 연도로 보지 않음', () {
      final r = shiftTitleYears('문서120250 처리');
      expect(r.title, '문서120250 처리');
      expect(r.from, isEmpty);
    });

    test('맨 끝에 오는 연도도 이동', () {
      final r = shiftTitleYears('2024학년도 결산 2024');
      expect(r.title, '2025학년도 결산 2025');
      expect(r.from, [2024], reason: '같은 연도가 두 번 나와도 from은 중복 없이 1개');
    });

    test('한글에 바로 붙은 앞자리 연도도 이동 (앞이 숫자만 아니면 됨)', () {
      final r = shiftTitleYears('문서2025 처리');
      expect(r.title, '문서2026 처리');
      expect(r.from, [2025]);
    });

    test('세 연도 혼재 — 전부 한 해씩, from은 등장 순서', () {
      final r = shiftTitleYears('2023·2024 계획과 2027 전망');
      expect(r.title, '2024·2025 계획과 2028 전망');
      expect(r.from, [2023, 2024, 2027]);
    });

    test('by를 주면 그만큼 민다', () {
      final r = shiftTitleYears('2024학년도 결산 보고', by: 2);
      expect(r.title, '2026학년도 결산 보고');
      expect(r.from, [2024]);
    });
  });
}
