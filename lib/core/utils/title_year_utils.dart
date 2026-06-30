/// 제목 텍스트의 연도 치환 유틸리티.
///
/// 작년 CSV를 가져오면 날짜(scheduled_date)는 올해로 변환되지만 제목 문자열의
/// 연도("2025학년도 …")는 원본 그대로 남는다. 편집 시 이 연도를 올해로 바꾸기
/// 위한 순수 함수. UI와 분리해 학년도·다중연도·미래연도 엣지를 유닛 테스트로 고정한다.
library;

/// 4자리 연도(20XX)만 매칭한다. 앞뒤가 숫자면 제외(문서번호 등 비연도 차단).
final RegExp _yearPattern = RegExp(r'(?<!\d)20\d\d(?!\d)');

/// [title]에서 [currentYear]보다 이전인 연도를 모두 [currentYear]로 치환한다.
///
/// 올해 이상(이미 미래를 가리키는) 연도는 건드리지 않는다.
/// 반환: 치환된 제목과 감지된 가장 이른 옛 연도([from]). 바꿀 게 없으면 [from]은 null.
({String title, int? from}) bumpTitleYear(String title, int currentYear) {
  int? from;
  final newTitle = title.replaceAllMapped(_yearPattern, (match) {
    final matched = match.group(0)!;
    final year = int.parse(matched);
    if (year < currentYear) {
      if (from == null || year < from!) from = year;
      return currentYear.toString();
    }
    return matched;
  });
  return (title: newTitle, from: from);
}
