import 'bus_card_view.dart';

/// 화면에 덧붙일 "그 다음 차"의 분. 붙이지 않을 상황이면 null. **순수 함수.**
///
/// **한 대만 보일 때만 붙인다.** 여러 대가 떠 있으면 목록 자체가 이미 대안을
/// 보여주고 있고, 각 줄에 붙이면 세 대가 여섯 줄이 된다. 한 대뿐일 때가 "놓치면
/// 얼마나 기다리나"가 가장 궁금한 순간이다 — 대안이 화면에 없으니까(실기기 요청
/// 2026-07-30: "버스 한 대만 기다린다면 두 번째 버스도 보이게").
///
/// 2차가 없는 노선이면(실측 A정류장 3/8, B정류장 1/6) 아무것도 붙이지 않는다.
///
/// 이미 지나간 2차(0초)도 붙이지 않는다 — `다음 0분`은 정보가 아니다.
///
/// **두 본문 모양이 같은 함수를 쓴다.** 한쪽에만 두면 모양을 바꾼 사용자만 조용히
/// 정보를 덜 받는다(`BusMoreCount`가 같은 이유로 공유 위젯이다).
int? nextBusSeconds(BusCardView view) {
  if (view.visible.length != 1) return null;

  final sec = view.visible.single.arrSec2;
  if (sec == null || sec <= 0) return null;

  return sec;
}

/// 같은 판정을 분으로. 글자로 쓰는 자리(`간단히`, 축 밖 폴백)가 쓴다.
int? nextBusMinutes(BusCardView view) {
  final sec = nextBusSeconds(view);
  return sec == null ? null : (sec / 60).round();
}

/// 시간 축이 담는 최대 초. `BusBodyAxis.axisRange`(15분)와 짝이다.
///
/// 위젯이 아니라 여기 두는 이유: 축 안/밖 판정이 **도메인 규칙**이고, 두 본문 모양이
/// 같은 함수로 갈라져야 한쪽만 다르게 그리는 일이 없다.
const nextBusAxisRangeSec = 15 * 60;

/// 축 위에 **점으로** 그릴 수 있는 다음 차의 초. 15분을 넘으면 null.
///
/// 넘는 것을 점으로 찍으면 `dotPosition`이 오른쪽 끝(0.97)으로 clamp해 **20분과
/// 40분이 같은 자리**에 서고, 실제로 오는 차(15분 근처)와도 구별되지 않는다.
int? nextBusOnAxis(BusCardView view) {
  final sec = nextBusSeconds(view);
  return (sec != null && sec <= nextBusAxisRangeSec) ? sec : null;
}

/// 축 밖이라 **글자로** 말해야 하는 다음 차의 분. 축 안이면 null.
///
/// [nextBusOnAxis]와 배타적이다 — 점과 글자가 함께 뜨면 같은 사실을 두 번 말한다.
int? nextBusOffAxis(BusCardView view) {
  final sec = nextBusSeconds(view);
  if (sec == null || sec <= nextBusAxisRangeSec) return null;
  return (sec / 60).round();
}
