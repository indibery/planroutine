/// 알림 설정 — SharedPreferences에 직렬화.
///
/// 마스터 스위치가 OFF이면 [monthStartEnabled], [weekBeforeEnabled],
/// [dayBeforeEnabled] 값과 상관없이 모든 알림이 꺼진다.
class NotificationSettings {
  const NotificationSettings({
    this.masterEnabled = false,
    this.monthStartEnabled = true,
    this.weekBeforeEnabled = true,
    this.dayBeforeEnabled = true,
    this.hour = 9,
    this.minute = 0,
  });

  final bool masterEnabled;
  final bool monthStartEnabled;
  final bool weekBeforeEnabled;
  final bool dayBeforeEnabled;

  /// 알림 발송 시각 (로컬 타임존). 기본 09:00.
  final int hour;
  final int minute;

  /// 기본값(사용자가 아직 설정을 안 만졌을 때)
  static const defaults = NotificationSettings();

  NotificationSettings copyWith({
    bool? masterEnabled,
    bool? monthStartEnabled,
    bool? weekBeforeEnabled,
    bool? dayBeforeEnabled,
    int? hour,
    int? minute,
  }) {
    return NotificationSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      monthStartEnabled: monthStartEnabled ?? this.monthStartEnabled,
      weekBeforeEnabled: weekBeforeEnabled ?? this.weekBeforeEnabled,
      dayBeforeEnabled: dayBeforeEnabled ?? this.dayBeforeEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'monthStartEnabled': monthStartEnabled,
        'weekBeforeEnabled': weekBeforeEnabled,
        'dayBeforeEnabled': dayBeforeEnabled,
        'hour': hour,
        'minute': minute,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      masterEnabled: json['masterEnabled'] as bool? ?? false,
      monthStartEnabled: json['monthStartEnabled'] as bool? ?? true,
      weekBeforeEnabled: json['weekBeforeEnabled'] as bool? ?? true,
      dayBeforeEnabled: json['dayBeforeEnabled'] as bool? ?? true,
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.masterEnabled == masterEnabled &&
      other.monthStartEnabled == monthStartEnabled &&
      other.weekBeforeEnabled == weekBeforeEnabled &&
      other.dayBeforeEnabled == dayBeforeEnabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(
        masterEnabled,
        monthStartEnabled,
        weekBeforeEnabled,
        dayBeforeEnabled,
        hour,
        minute,
      );
}
