/// PageView 가상 인덱스의 baseline. 이 인덱스가 anchor 월에 대응.
/// ±100년 (±1200개월) 범위를 충분히 커버.
const int kPagerBaseline = 1200;

/// 페이지 인덱스 → (year, month) 1일 기준 DateTime.
/// anchor는 페이저가 생성된 시점의 기준 월.
DateTime pageIndexToMonth({
  required int index,
  required int anchorYear,
  required int anchorMonth,
}) {
  final delta = index - kPagerBaseline;
  return DateTime(anchorYear, anchorMonth + delta, 1);
}

/// (year, month) → 페이지 인덱스.
/// DateTime 산술 보정이 필요 없도록 직접 12개월 단위 계산.
int monthToPageIndex({
  required int year,
  required int month,
  required int anchorYear,
  required int anchorMonth,
}) {
  return kPagerBaseline + (year - anchorYear) * 12 + (month - anchorMonth);
}
