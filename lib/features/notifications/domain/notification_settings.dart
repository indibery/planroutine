/// 알림 설정 — SharedPreferences에 직렬화.
///
/// 마스터 스위치가 OFF이면 [monthStartEnabled], [weeklyEnabled],
/// [dayOfEnabled] 값과 상관없이 모든 알림이 꺼진다.
class NotificationSettings {
  const NotificationSettings({
    this.masterEnabled = false,
    this.monthStartEnabled = true,
    this.weeklyEnabled = true,
    this.dayOfEnabled = true,
    this.hour = 8,
    this.minute = 0,
  });

  final bool masterEnabled;
  final bool monthStartEnabled;

  /// 매주 월요일 아침 '이번 주 종합' 알림. 이전 버전의 이벤트별 '1주 전'을 대체.
  final bool weeklyEnabled;

  /// 이벤트 당일 아침 알림 ('오늘 X 있어요'). 이전 버전의 '1일 전'을 대체.
  final bool dayOfEnabled;

  /// 알림 발송 시각 (로컬 타임존). 기본 08:00 (수업 시작 전 여유).
  final int hour;
  final int minute;

  /// 기본값(사용자가 아직 설정을 안 만졌을 때)
  static const defaults = NotificationSettings();

  NotificationSettings copyWith({
    bool? masterEnabled,
    bool? monthStartEnabled,
    bool? weeklyEnabled,
    bool? dayOfEnabled,
    int? hour,
    int? minute,
  }) {
    return NotificationSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      monthStartEnabled: monthStartEnabled ?? this.monthStartEnabled,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
      dayOfEnabled: dayOfEnabled ?? this.dayOfEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'monthStartEnabled': monthStartEnabled,
        'weeklyEnabled': weeklyEnabled,
        'dayOfEnabled': dayOfEnabled,
        'hour': hour,
        'minute': minute,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      masterEnabled: json['masterEnabled'] as bool? ?? false,
      monthStartEnabled: json['monthStartEnabled'] as bool? ?? true,
      weeklyEnabled: json['weeklyEnabled'] as bool? ?? true,
      dayOfEnabled: json['dayOfEnabled'] as bool? ?? true,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.masterEnabled == masterEnabled &&
      other.monthStartEnabled == monthStartEnabled &&
      other.weeklyEnabled == weeklyEnabled &&
      other.dayOfEnabled == dayOfEnabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(
        masterEnabled,
        monthStartEnabled,
        weeklyEnabled,
        dayOfEnabled,
        hour,
        minute,
      );
}
