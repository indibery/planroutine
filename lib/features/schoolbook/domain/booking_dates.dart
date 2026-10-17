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

DateTime _mondayOf(DateTime day) {
  final d = _dateOnly(day);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// 그 날이 든 주의 월~금(주간 날짜 띠).
List<DateTime> weekOf(DateTime day) {
  final monday = _mondayOf(day);
  return [for (var i = 0; i < 5; i++) DateTime(monday.year, monday.month, monday.day + i)];
}

/// 지난주의 같은 요일. 지난 날은 조회만 하므로 하한이 없다.
DateTime previousWeek(DateTime day) {
  final d = _dateOnly(day);
  return DateTime(d.year, d.month, d.day - 7);
}

/// 다음 주의 같은 요일. 그 주가 통째로 예약 가능 범위 밖이면 null(▶가 멈춘다).
/// 같은 요일만 범위를 넘으면 그 주의 마지막 예약 가능일로 당긴다.
DateTime? nextWeek(DateTime day, DateTime today) {
  final last = lastBookableDate(today);
  final monday = DateTime(_mondayOf(day).year, _mondayOf(day).month, _mondayOf(day).day + 7);
  if (monday.isAfter(last)) return null;
  final d = _dateOnly(day);
  var next = DateTime(d.year, d.month, d.day + 7);
  while (next.isAfter(last) || !_isWeekday(next)) {
    next = DateTime(next.year, next.month, next.day - 1);
  }
  return next;
}
