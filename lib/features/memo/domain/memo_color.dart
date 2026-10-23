import 'dart:math' as math;

/// 쪽지 색. [dbValue]는 **저장값**이라 바꾸지 않는다 — 바꾸면 그 색 쪽지가 노랑으로 돌아간다.
enum MemoColor {
  yellow('yellow'),
  green('green'),
  blue('blue'),
  pink('pink');

  const MemoColor(this.dbValue);

  final String dbValue;

  /// 모르는 값·null은 노랑 — `EntryKind.fromValue`와 같은 폴백.
  static MemoColor fromValue(String? value) => MemoColor.values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => MemoColor.yellow,
  );
}

/// 새 쪽지 색 — [last](맨 앞 쪽지 색)를 뺀 색 중 무작위. 없으면 네 색 중 무작위.
/// 완전 무작위면 같은 색이 연달아 나와 보드가 한 색으로 몰린다(사용자 결정 2026-10-23).
MemoColor nextMemoColor(MemoColor? last, math.Random rng) {
  final pool = [for (final c in MemoColor.values) if (c != last) c];
  return pool[rng.nextInt(pool.length)];
}
