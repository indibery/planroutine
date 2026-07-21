/// 알림 설정 — SharedPreferences에 직렬화.
///
/// 마스터 스위치가 OFF이면 [monthStartEnabled], [weekBeforeEnabled],
/// [dayOfEnabled] 값과 상관없이 모든 알림이 꺼진다.
class NotificationSettings {
  const NotificationSettings({
    this.masterEnabled = false,
    this.monthStartEnabled = true,
    this.weekBeforeEnabled = true,
    this.dayOfEnabled = true,
    this.hour = 8,
    this.minute = 0,
  });

  final bool masterEnabled;
  final bool monthStartEnabled;
  final bool weekBeforeEnabled;

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
    bool? weekBeforeEnabled,
    bool? dayOfEnabled,
    int? hour,
    int? minute,
  }) {
    return NotificationSettings(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      monthStartEnabled: monthStartEnabled ?? this.monthStartEnabled,
      weekBeforeEnabled: weekBeforeEnabled ?? this.weekBeforeEnabled,
      dayOfEnabled: dayOfEnabled ?? this.dayOfEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'monthStartEnabled': monthStartEnabled,
        'weekBeforeEnabled': weekBeforeEnabled,
        'dayOfEnabled': dayOfEnabled,
        'hour': hour,
        'minute': minute,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      masterEnabled: json['masterEnabled'] as bool? ?? false,
      monthStartEnabled: json['monthStartEnabled'] as bool? ?? true,
      weekBeforeEnabled: json['weekBeforeEnabled'] as bool? ?? true,
      // 역호환: 옛 키 'dayBeforeEnabled'를 폴백으로 읽어 기존 사용자의
      // 토글 상태(특히 OFF)를 잃지 않는다.
      dayOfEnabled: json['dayOfEnabled'] as bool? ??
          json['dayBeforeEnabled'] as bool? ??
          true,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.masterEnabled == masterEnabled &&
      other.monthStartEnabled == monthStartEnabled &&
      other.weekBeforeEnabled == weekBeforeEnabled &&
      other.dayOfEnabled == dayOfEnabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(
        masterEnabled,
        monthStartEnabled,
        weekBeforeEnabled,
        dayOfEnabled,
        hour,
        minute,
      );
}
