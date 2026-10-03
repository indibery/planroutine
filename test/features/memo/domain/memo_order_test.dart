import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/memo/domain/memo_order.dart';

void main() {
  group('moveId — 끌어 놓은 자리로 옮긴 순서', () {
    test('앞의 것을 뒤로', () {
      expect(moveId([1, 2, 3, 4], 1, 2), [2, 3, 1, 4]);
    });
    test('뒤의 것을 앞으로', () {
      expect(moveId([1, 2, 3, 4], 4, 0), [4, 1, 2, 3]);
    });
    test('제자리면 그대로', () {
      expect(moveId([1, 2, 3], 2, 1), [1, 2, 3]);
    });
    test('범위를 넘는 자리는 끝으로', () {
      expect(moveId([1, 2, 3], 1, 99), [2, 3, 1]);
    });
    test('없는 id면 그대로', () {
      expect(moveId([1, 2, 3], 9, 0), [1, 2, 3]);
    });
  });
}
