import '../../../core/constants/app_strings.dart';

/// 도장 안에 무엇을 그리는지.
///
/// **불린 여러 개(`usesIcon`·`usesPainter`…)로 두지 않는다.** 서로 배타적인 값을 불린
/// 목록으로 표현하면 둘 다 true인 상태가 타입으로 허용되고, 모양을 추가할 때 위젯의
/// 분기를 빠뜨려도 컴파일이 통과한다. enum이면 `switch`가 누락을 잡는다.
enum SealMark {
  /// 한글 두 글자를 그린다.
  ///
  /// **한글 두 글자까지다.** 도장 내부에 글자가 놓일 수 있는 폭은 31.4이고 `완료`는
  /// 13px에서 25다. 영문 4글자(`Good`)는 13px에서 50, 10px에서도 38이라 들어가게
  /// 하려면 8px 이하로 줄여야 해 읽을 수 없다. 새 도장 라벨이 이 폭을 넘으면 글자가
  /// 아니라 그림으로 가야 한다(가드 테스트가 폭을 지킨다).
  text,

  /// 판다 얼굴을 직접 그린다([SealPandaMark]).
  panda,

  /// 도마뱀 — PNG 알파 마스크에 색을 입힌다([SealGeckoMark]).
  ///
  /// 판다처럼 직접 그리지 않는 이유는 그 위젯의 주석에 있다. 요약하면 다리 넷·발가락·
  /// 말린 꼬리가 있는 실루엣은 44px에서 손으로 맞추기 어렵고, 알파 마스크에
  /// `BlendMode.srcIn`으로 색을 입히면 테마 전환도 그대로 따라간다.
  gecko,
}

/// 완료 도장 모양. 설정 탭에서 고른다.
enum SealStyle {
  /// 원형 이중선 + "완료" — 기본. 의미가 정확하고 오해가 없다.
  complete(TodayStrings.sealComplete),

  /// 사각 이중선 + "결재" — 공문 결재란 도장 느낌.
  approve(TodayStrings.sealApprove, isSquare: true),

  /// 원형 이중선 + 판다 얼굴.
  ///
  /// 아이콘으로 못 넣는다 — Material Icons에 판다가 없고, 이모지 `🐼`는 색을 입힐 수
  /// 없어 골드 단색 언어를 깨뜨린다. 그래서 직접 그린다.
  panda(TodayStrings.sealPanda, mark: SealMark.panda),

  /// 원형 이중선 + 도마뱀.
  gecko(TodayStrings.sealGecko, mark: SealMark.gecko);

  const SealStyle(
    this.label, {
    this.isSquare = false,
    this.mark = SealMark.text,
  });

  /// 설정 화면 세그먼트에 표시할 이름. [SealMark.text]에서는 도장에도 찍힌다.
  final String label;

  /// 원형 대신 둥근 사각 테두리로 찍는지.
  final bool isSquare;

  /// 도장 안에 무엇을 그리는지.
  final SealMark mark;
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

  /// 모르는 이름이면 기본 도장으로 폴백한다.
  ///
  /// **없어진 모양도 여기로 온다.** `좋아요`(`like`)를 빼면서 그 값을 고른 사용자의
  /// 저장값은 `"like"`로 남아 있는데, 없어진 모양을 되살릴 방법이 없으므로 기본값으로
  /// 되돌리는 것이 맞다. 조용한 변경이므로 테스트가 이 폴백을 고정한다.
  static SealStyle _decodeStyle(String? raw) {
    return SealStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => SealStyle.complete,
    );
  }
}
