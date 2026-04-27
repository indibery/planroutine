import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/presentation/widgets/page_index_mapping.dart';

void main() {
  group('pageIndexToMonth', () {
    test('baseline은 anchor 월', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 4);
    });

    test('baseline + 1 → anchor 다음 달', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline + 1,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 5);
    });

    test('baseline - 1 → anchor 이전 달', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline - 1,
        anchorYear: 2026,
        anchorMonth: 4,
      );
      expect(m.year, 2026);
      expect(m.month, 3);
    });

    test('12월 → 1월 경계', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline + 1,
        anchorYear: 2026,
        anchorMonth: 12,
      );
      expect(m.year, 2027);
      expect(m.month, 1);
    });

    test('1월 → 12월 경계', () {
      final m = pageIndexToMonth(
        index: kPagerBaseline - 1,
        anchorYear: 2026,
        anchorMonth: 1,
      );
      expect(m.year, 2025);
      expect(m.month, 12);
    });
  });

  group('monthToPageIndex', () {
    test('anchor 월은 baseline', () {
      expect(
        monthToPageIndex(
          year: 2026,
          month: 4,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline,
      );
    });

    test('anchor + 12개월 = baseline + 12', () {
      expect(
        monthToPageIndex(
          year: 2027,
          month: 4,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline + 12,
      );
    });

    test('anchor - 1개월 = baseline - 1 (역방향)', () {
      expect(
        monthToPageIndex(
          year: 2026,
          month: 3,
          anchorYear: 2026,
          anchorMonth: 4,
        ),
        kPagerBaseline - 1,
      );
    });

    test('round-trip: monthToPageIndex(pageIndexToMonth(i)) == i', () {
      for (final delta in [-24, -1, 0, 1, 12, 100]) {
        final m = pageIndexToMonth(
          index: kPagerBaseline + delta,
          anchorYear: 2026,
          anchorMonth: 4,
        );
        expect(
          monthToPageIndex(
            year: m.year,
            month: m.month,
            anchorYear: 2026,
            anchorMonth: 4,
          ),
          kPagerBaseline + delta,
          reason: 'delta=$delta',
        );
      }
    });
  });
}
