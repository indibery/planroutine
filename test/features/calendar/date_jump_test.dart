import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/calendar/presentation/date_jump.dart';

void main() {
  // 'YYYY-MM-DD' 키는 사전식 정렬 = 시간순.
  final keys = ['2026-03-02', '2026-03-06', '2026-03-13'];

  group('nextGroupIndexFor — 날짜 점프 대상 인덱스', () {
    test('정확히 일치하는 날짜는 그 인덱스', () {
      expect(nextGroupIndexFor(keys, '2026-03-06'), 1);
      expect(nextGroupIndexFor(keys, '2026-03-02'), 0);
    });

    test('이벤트 없는 날짜는 그 이후 가장 가까운 날짜의 인덱스', () {
      expect(nextGroupIndexFor(keys, '2026-03-04'), 1); // 6일로
      expect(nextGroupIndexFor(keys, '2026-03-01'), 0); // 2일로
    });

    test('모든 날짜보다 뒤면 마지막 인덱스', () {
      expect(nextGroupIndexFor(keys, '2026-03-20'), 2);
    });

    test('빈 목록이면 -1', () {
      expect(nextGroupIndexFor(const [], '2026-03-06'), -1);
    });
  });
}
