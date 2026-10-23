import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/memo/domain/memo_color.dart';

// 새 쪽지 색 — 맨 앞 쪽지와 다른 색 중 무작위(사용자 결정 2026-10-23). 완전 무작위면 같은 색이
// 연달아 나와 보드가 한 색으로 몰린다.
void main() {
  test('직전 색은 다시 나오지 않는다', () {
    for (final last in MemoColor.values) {
      final rng = math.Random(7);
      for (var i = 0; i < 50; i++) {
        expect(nextMemoColor(last, rng), isNot(last));
      }
    }
  });

  test('직전 색이 없으면 네 색 어느 것이든 나온다', () {
    final rng = math.Random(3);
    final seen = {for (var i = 0; i < 200; i++) nextMemoColor(null, rng)};
    expect(seen, MemoColor.values.toSet());
  });

  test('직전 색을 뺀 세 색이 모두 나온다 — 한 색으로 몰리지 않는다', () {
    final rng = math.Random(11);
    final seen = {for (var i = 0; i < 200; i++) nextMemoColor(MemoColor.yellow, rng)};
    expect(seen, {MemoColor.green, MemoColor.blue, MemoColor.pink});
  });
}
