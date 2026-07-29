import 'package:flutter/material.dart';

/// 완료 도장 안에 찍히는 도마뱀.
///
/// **판다와 달리 직접 그리지 않는다 — PNG 알파 마스크다.**
///
/// 도장 마크를 `CustomPainter`로 그려야 했던 이유는 하나뿐이었다: 테마에 따라 색이
/// 바뀌어야 한다(다크 골드 / 라이트 딥골드). 그래서 "색을 못 입히는 PNG·이모지는 안 된다"
/// 고 판단했는데 **그 판단이 절반만 맞았다.** PNG의 **알파 채널만** 쓰고 색은
/// [BlendMode.srcIn]으로 입히면 팔레트를 그대로 따라간다 — 에셋은 **모양만** 담는다.
/// 진짜로 안 되는 것은 이모지 `🦎` 하나다(알파가 아니라 색이 박혀 있다).
///
/// 그 차이가 중요한 이유: 손으로 베지어를 짜면 44px에서 읽히는 실루엣을 맞추기 어렵다.
/// 판다는 얼굴이라 원·타원 몇 개로 됐지만, 다리 넷·발가락·말린 꼬리가 있는 도마뱀은
/// 여섯 번 시도해 전부 애벌레·튜브로 읽혔다. 그림을 그대로 마스크로 쓰면 그 문제가 없다.
///
/// **에셋 준비 규칙**(다음에 마크를 추가할 때 그대로 쓸 것):
/// - 흑백 그림에서 **알파 램프**로 마스크를 뽑는다(어두운 획 = 불투명).
/// - **선을 굵혀야 한다.** 원본 참조 그림의 선폭은 내용 폭의 약 3.7%라 마크 28px에서
///   1.0px 미만이 된다 — 골드가 아니라 흐린 회색으로 뭉갠다. 확장(dilate) 후 축소했다.
/// - 크기는 112px 하나로 둔다. 2.0x/3.0x 변형 폴더를 만들지 않는다 — 마크는 28px
///   고정이라 3배 기기에서도 84px이면 충분하고, 변형이 늘면 어긋날 자리만 생긴다.
///
/// ⚠️ **App Store 제출 전에 에셋을 교체해야 한다.** 원본 그림은 사용자가 제공한 참조
/// 이미지(2026-07-29)이고 **출처가 확실하지 않다** — 상업 사용 라이선스를 확인할 수 없다.
/// TestFlight(내부 테스트)까지만 이 에셋으로 가고, 심사 제출 전 라이선스가 확실한 그림
/// (CC0·구매한 아이콘·직접 그린 것)으로 바꾼다. 위 "에셋 준비 규칙"만 지키면 교체는
/// 파일 하나 갈아 끼우는 일이다 — 이 위젯도 `SealStyle.gecko`도 손댈 필요가 없다.
class SealGeckoMark extends StatelessWidget {
  const SealGeckoMark({super.key, required this.color});

  final Color color;

  /// 마크가 차지하는 한 변. `CompletionSeal.innerWidth`(31.4)보다 작아야 한다 —
  /// 가드 테스트가 지킨다.
  ///
  /// **판다(22)보다 크다.** 판다는 얼굴 하나라 22에서 또렷하지만, 도마뱀은 몸통이
  /// 속 빈 윤곽선이라 22에서는 선이 1px 미만으로 흐려진다(실측). 28이 상한(31.4)
  /// 안에서 선 굵기를 확보하는 크기다.
  static const size = 28.0;

  static const _asset = 'assets/images/seal_gecko.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      width: size,
      height: size,
      // 알파만 쓰고 색은 팔레트가 정한다.
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}
