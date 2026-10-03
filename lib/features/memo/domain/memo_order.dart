/// 보드에서 쪽지 [id]를 끌어 [toIndex]에 놓은 뒤의 id 순서.
///
/// [toIndex]는 **[id]를 뺀 목록** 기준이다. 범위를 넘으면 끝에 둔다. 없는 id면 그대로.
/// 순수 함수로 둬 끌기 위젯과 무관하게 순서 규칙을 고정한다.
List<int> moveId(List<int> ids, int id, int toIndex) {
  if (!ids.contains(id)) return List.of(ids);
  final rest = [for (final x in ids) if (x != id) x];
  final at = toIndex.clamp(0, rest.length);
  return [...rest.sublist(0, at), id, ...rest.sublist(at)];
}
