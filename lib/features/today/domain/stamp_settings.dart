import '../../../core/constants/app_strings.dart';

/// 완료 도장 모양. 설정 탭에서 고른다.
enum SealStyle {
  /// 원형 이중선 + "완료" — 기본. 의미가 정확하고 오해가 없다.
  complete(TodayStrings.sealComplete),

  /// 사각 이중선 + "결재" — 공문 결재란 도장 느낌.
  approve(TodayStrings.sealApprove, isSquare: true),

  /// 원형 이중선 + 엄지 아이콘 — "좋아요". 네 글자는 도장에 안 들어가 아이콘으로 찍는다.
  like(TodayStrings.sealLike, usesIcon: true);

  const SealStyle(this.label, {this.isSquare = false, this.usesIcon = false});

  /// 설정 화면 세그먼트에 표시할 이름.
  final String label;

  /// 원형 대신 둥근 사각 테두리로 찍는지.
  final bool isSquare;

  /// 글자 대신 아이콘으로 찍는지.
  final bool usesIcon;
}

/// 완료 도장 설정 — SharedPreferences에 직렬화.
class StampSettings {
  const StampSettings({
    this.style = SealStyle.complete,
    this.dimPreviousStamps = true,
  });

  final SealStyle style;

  /// 화면에 들어왔을 때 이미 찍혀 있던 도장을 흐리게 찍는지.
  ///
  /// 방금 누른 도장은 진하게, 지난 도장은 잔상처럼 남겨 목록이 시끄러워지지 않게 한다.
  final bool dimPreviousStamps;

  static const defaults = StampSettings();

  StampSettings copyWith({SealStyle? style, bool? dimPreviousStamps}) {
    return StampSettings(
      style: style ?? this.style,
      dimPreviousStamps: dimPreviousStamps ?? this.dimPreviousStamps,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style.name,
        'dimPreviousStamps': dimPreviousStamps,
      };

  factory StampSettings.fromJson(Map<String, dynamic> json) {
    return StampSettings(
      style: _decodeStyle(json['style'] as String?),
      dimPreviousStamps: json['dimPreviousStamps'] as bool? ?? true,
    );
  }

  /// 모르는 이름(구버전·손상)이면 기본 도장으로 폴백한다.
  static SealStyle _decodeStyle(String? raw) {
    return SealStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => SealStyle.complete,
    );
  }
}
