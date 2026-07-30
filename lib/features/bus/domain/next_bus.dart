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
int? nextBusMinutes(BusCardView view) {
  if (view.visible.length != 1) return null;

  final sec = view.visible.single.arrSec2;
  if (sec == null || sec <= 0) return null;

  return (sec / 60).round();
}
