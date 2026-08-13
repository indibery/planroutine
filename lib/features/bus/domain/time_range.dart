/// 하루 안의 한 구간 — 자정 기준 분으로 센다.
///
/// 자정을 넘는 구간은 지원하지 않는다(야간 근무 미대응). 그래야 [contains]가
/// 단순 비교로 끝나고 [overlaps] 판정에 예외 분기가 생기지 않는다.
class TimeRange {
  const TimeRange({required this.startMinutes, required this.endMinutes});

  /// 시·분으로 쓰는 편의 생성자.
  const TimeRange.hm(int startHour, int startMinute, int endHour, int endMinute)
    : startMinutes = startHour * 60 + startMinute,
      endMinutes = endHour * 60 + endMinute;

  /// 자정부터 몇 분째에 시작하는지.
  final int startMinutes;

  /// 자정부터 몇 분째에 끝나는지. **경계 포함**이다.
  final int endMinutes;

  /// [now]의 시·분이 이 구간에 드는지. 날짜는 보지 않는다.
  bool contains(DateTime now) {
    final m = now.hour * 60 + now.minute;
    return m >= startMinutes && m <= endMinutes;
  }

  /// 시작이 종료보다 빠른지.
  bool get isValid => startMinutes < endMinutes;

  /// 두 구간이 한 지점이라도 공유하는지.
  ///
  /// 겹치면 방향 판정이 모호해지므로 저장을 거부하는 근거가 된다.
  bool overlaps(TimeRange other) {
    return startMinutes <= other.endMinutes && other.startMinutes <= endMinutes;
  }

  /// `07:00 – 08:30` — 설정 타일의 trailing 문구.
  String get label => '${_hhmm(startMinutes)} – ${_hhmm(endMinutes)}';

  static String _hhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startMinutes: json['startMinutes'] as int? ?? 0,
      endMinutes: json['endMinutes'] as int? ?? 0,
    );
  }
}
