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
