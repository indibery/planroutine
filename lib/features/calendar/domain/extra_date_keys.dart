/// 목록 묶음에 [keys] 중 없는 날짜를 빈 목록으로 더한다 — 일정 없이 쪽지만 있는 날도
/// 섹션이 생겨야 쪽지를 그릴 자리가 있다(`mergeHolidayKeys`와 같은 이유). 날짜순 정렬.
List<MapEntry<String, List<T>>> mergeExtraDateKeys<T>(
  List<MapEntry<String, List<T>>> entries,
  Iterable<String> keys,
) {
  final merged = <String, List<T>>{for (final e in entries) e.key: e.value};
  for (final k in keys) {
    merged.putIfAbsent(k, () => <T>[]);
  }
  return merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
}
