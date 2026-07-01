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

    // ── verifier가 스크래치로만 확인했던 엣지들을 리그레션으로 고정 ──

    test('맨 끝에 오는 연도도 치환', () {
      final r = bumpTitleYear('2024학년도 결산 2024', 2026);
      expect(r.title, '2026학년도 결산 2026');
      expect(r.from, 2024);
    });

    test('한글에 바로 붙은 앞자리 연도도 치환 (앞이 숫자만 아니면 됨)', () {
      final r = bumpTitleYear('문서2025 처리', 2026);
      expect(r.title, '문서2026 처리');
      expect(r.from, 2025);
    });

    test('세 연도 혼재 — 옛 연도만 치환, from은 최소 옛 연도', () {
      final r = bumpTitleYear('2023·2024 계획과 2027 전망', 2026);
      expect(r.title, '2026·2026 계획과 2027 전망');
      expect(r.from, 2023);
    });

    test('경계값 — 올해와 같은 연도는 보존', () {
      final r = bumpTitleYear('2026 예산', 2026);
      expect(r.title, '2026 예산');
      expect(r.from, isNull);
    });

    test('경계값 — 먼 미래(2030/2099)는 보존, 먼 과거(2009)는 치환', () {
      expect(bumpTitleYear('2030 로드맵', 2026).from, isNull);
      expect(bumpTitleYear('2099 비전', 2026).from, isNull);
      final past = bumpTitleYear('2009 자료', 2026);
      expect(past.title, '2026 자료');
      expect(past.from, 2009);
    });
  });
}
