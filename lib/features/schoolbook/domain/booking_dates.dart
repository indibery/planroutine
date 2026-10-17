// 스쿨북의 예약 가능한 날 규칙(`BackEnd/schoolBook/booking_window.py`)을 그대로 옮겼다.
// 서버가 다시 검사하므로 이 판정은 화면에서 미리 막는 용도다.

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isWeekday(DateTime d) => d.weekday <= DateTime.friday;

/// 예약 가능한 마지막 날 — 다음 해 2월 말일. 3월에 새 학년도가 시작한다.
DateTime lastBookableDate(DateTime today) =>
    DateTime(today.year + 1, 3, 0); // 3월 0일 = 2월 말일

/// 오늘 ~ 다음 해 2월 말일의 평일.
bool isBookableDate(DateTime day, DateTime today) {
  final d = _dateOnly(day);
  return !d.isBefore(_dateOnly(today)) &&
      !d.isAfter(lastBookableDate(today)) &&
      _isWeekday(d);
}

/// 처음 열 때의 날짜 — 오늘이 주말이면 다음 월요일.
DateTime initialDay(DateTime today) {
  var d = _dateOnly(today);
  while (!_isWeekday(d)) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

/// 다음 평일. 예약 가능한 마지막 날을 넘으면 null(▶가 멈춘다).
DateTime? nextWeekday(DateTime day, DateTime today) {
  var d = _dateOnly(day);
  do {
    d = DateTime(d.year, d.month, d.day + 1);
  } while (!_isWeekday(d));
  return d.isAfter(lastBookableDate(today)) ? null : d;
}

/// 이전 평일. 지난 날은 조회만 하므로 하한이 없다.
DateTime previousWeekday(DateTime day) {
  var d = _dateOnly(day);
  do {
    d = DateTime(d.year, d.month, d.day - 1);
  } while (!_isWeekday(d));
  return d;
}
