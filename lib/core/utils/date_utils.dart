/// 날짜 포맷 유틸리티 — 프로젝트 내 중복되던 `_formatDate` 4개를 통합.
library;

/// DateTime을 `YYYY-MM-DD` 문자열로 변환한다.
/// DB(scheduled_date, event_date 등)와 CSV에 쓰이는 표준 형식.
String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
