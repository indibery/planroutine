import 'bus_card_style.dart';
import 'bus_stop.dart';
import 'commute_direction.dart';
import 'time_range.dart';

/// 버스 도착 카드 설정 — SharedPreferences에 직렬화되는 전부.
///
/// DB 변경 없이 이 클래스 하나에 담는다. 기기를 바꾸면 사라진다 — 이 앱의
/// 일정·이벤트도 이미 로컬 전용이라 정류장만 클라우드에 두면 오히려 어긋난다.
class BusSettings {
  const BusSettings({
    this.enabled = false,
    this.departure,
    this.arrival,
    this.style = BusCardStyle.text,
    this.toWorkRange = const TimeRange.hm(7, 0, 8, 30),
    this.toHomeRange = const TimeRange.hm(16, 0, 18, 0),
    this.overrideAt,
    this.overrideExpanded = false,
  });

  /// 오늘 탭에 카드를 그리는지. **기본 꺼짐** — 켜지 않은 사용자의 화면은 안 바뀐다.
  final bool enabled;

  /// 출근 방향에서 볼 정류장(집 근처).
  final BusStop? departure;

  /// 퇴근 방향에서 볼 정류장(학교 근처).
  final BusStop? arrival;

  final BusCardStyle style;

  /// 이 구간에 들면 출근 방향이 펼쳐진다.
  final TimeRange toWorkRange;

  /// 이 구간에 들면 퇴근 방향이 펼쳐진다.
  final TimeRange toHomeRange;

  /// 사용자가 접기·펼치기를 누른 시각. null이면 시간대 판정을 그대로 쓴다.
  final DateTime? overrideAt;

  /// 그 누름이 펼치기였는지(true) 접기였는지(false).
  final bool overrideExpanded;

  static const defaults = BusSettings();

  /// 두 시간대가 각자 유효하고 서로 겹치지 않는지.
  bool get rangesValid =>
      toWorkRange.isValid && toHomeRange.isValid && !toWorkRange.overlaps(toHomeRange);

  BusStop? stopFor(CommuteDirection direction) =>
      direction == CommuteDirection.toWork ? departure : arrival;

  BusSettings copyWith({
    bool? enabled,
    BusStop? departure,
    BusStop? arrival,
    BusCardStyle? style,
    TimeRange? toWorkRange,
    TimeRange? toHomeRange,
    DateTime? overrideAt,
    bool? overrideExpanded,
  }) {
    return BusSettings(
      enabled: enabled ?? this.enabled,
      departure: departure ?? this.departure,
      arrival: arrival ?? this.arrival,
      style: style ?? this.style,
      toWorkRange: toWorkRange ?? this.toWorkRange,
      toHomeRange: toHomeRange ?? this.toHomeRange,
      overrideAt: overrideAt ?? this.overrideAt,
      overrideExpanded: overrideExpanded ?? this.overrideExpanded,
    );
  }

  /// override 두 값을 함께 지운다.
  ///
  /// `copyWith(overrideAt: null)`은 null 병합 때문에 지워지지 않으므로 전용
  /// 메서드를 둔다 — 한쪽만 남으면 만료 판정이 흔들린다.
  BusSettings clearOverride() {
    return BusSettings(
      enabled: enabled,
      departure: departure,
      arrival: arrival,
      style: style,
      toWorkRange: toWorkRange,
      toHomeRange: toHomeRange,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'departure': departure?.toJson(),
        'arrival': arrival?.toJson(),
        'style': style.name,
        'toWorkRange': toWorkRange.toJson(),
        'toHomeRange': toHomeRange.toJson(),
        'overrideAt': overrideAt?.toIso8601String(),
        'overrideExpanded': overrideExpanded,
      };

  factory BusSettings.fromJson(Map<String, dynamic> json) {
    return BusSettings(
      enabled: json['enabled'] as bool? ?? false,
      departure: _stop(json['departure']),
      arrival: _stop(json['arrival']),
      style: _style(json['style'] as String?),
      toWorkRange: _range(json['toWorkRange'], const TimeRange.hm(7, 0, 8, 30)),
      toHomeRange: _range(json['toHomeRange'], const TimeRange.hm(16, 0, 18, 0)),
      overrideAt: DateTime.tryParse(json['overrideAt'] as String? ?? ''),
      overrideExpanded: json['overrideExpanded'] as bool? ?? false,
    );
  }

  static BusStop? _stop(Object? raw) =>
      raw is Map<String, dynamic> ? BusStop.fromJson(raw) : null;

  static TimeRange _range(Object? raw, TimeRange fallback) =>
      raw is Map<String, dynamic> ? TimeRange.fromJson(raw) : fallback;

  /// 모르는 이름(구버전·손상)이면 기본 모양으로 폴백한다.
  static BusCardStyle _style(String? raw) {
    return BusCardStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => BusCardStyle.text,
    );
  }
}
