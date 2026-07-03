/// 날짜별로 정렬된 그룹 키 목록에서, [selectedKey]가 가리켜야 할 그룹 인덱스.
///
/// - 정확히 일치하는 날짜가 있으면 그 인덱스.
/// - 없으면 그 이후 가장 가까운 날짜(다음 그룹)의 인덱스.
/// - 모든 날짜보다 뒤면 마지막 인덱스.
/// - 목록이 비어 있으면 -1(스크롤 대상 없음).
///
/// [sortedKeys]는 'YYYY-MM-DD' 문자열이 오름차순 정렬돼 있다고 가정한다
/// (사전식 정렬 = 시간순).
int nextGroupIndexFor(List<String> sortedKeys, String selectedKey) {
  if (sortedKeys.isEmpty) return -1;
  for (var i = 0; i < sortedKeys.length; i++) {
    if (sortedKeys[i].compareTo(selectedKey) >= 0) return i;
  }
  return sortedKeys.length - 1;
}
