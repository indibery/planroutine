/// 제목 텍스트의 연도 이동 유틸리티.
///
/// 작년 CSV를 가져오면 날짜(scheduled_date)는 올해로 변환되지만 제목 문자열의
/// 연도("2025학년도 …")는 원본 그대로 남는다. 편집 시 이 연도를 한 해 미는 순수 함수.
///
/// **절대 기준이 아니라 상대 기준이다.** "올해로 맞추기"는 한 제목 안의 서로 다른
/// 연도를 같은 값으로 뭉갠다("2025학년도 안건[2026학년도 개정]" → 둘 다 2026).
/// 한 해씩 밀면 그 간격이 보존된다. 12월 업무 제목의 "2026 졸업식"이 두 달 뒤
/// 2월 졸업식을 가리키는 것처럼, 연도들의 관계는 지켜야 뜻이 남는다.
library;

/// 4자리 연도(20XX)만 매칭한다. 앞뒤가 숫자면 제외(문서번호 등 비연도 차단).
final RegExp _yearPattern = RegExp(r'(?<!\d)20\d\d(?!\d)');

/// [title]의 모든 연도를 [by]년만큼 민다.
///
/// 반환: 이동된 제목과, **중복을 제거한 등장 순서**의 원본 연도 목록([from]).
/// 연도가 없으면 [from]은 빈 리스트. 호출부는 [from]의 길이로 라벨을 고른다
/// (1개면 "2025 → 2026", 2개 이상이면 "연도 모두 +N년").
({String title, List<int> from}) shiftTitleYears(String title, {int by = 1}) {
  final from = <int>[];
  final newTitle = title.replaceAllMapped(_yearPattern, (match) {
    final year = int.parse(match.group(0) ?? '');
    if (!from.contains(year)) from.add(year);
    return (year + by).toString();
  });
  return (title: newTitle, from: from);
}
