import 'bus_card_view.dart';

/// 조회 간격의 상한.
///
/// **`busMaxDisplayAge`(6분)보다 짧아야 한다** — 길면 먼 버스 구간에서 목록이
/// 나이 상한에 걸려 사라졌다 돌아오며 깜빡인다. 가드 테스트가 이 부등식을 지킨다.
const busPollMax = Duration(seconds: 300);

/// 지금 보이는 버스가 지나간 뒤 다시 확인하기까지의 여유.
const busPollAfterArrival = Duration(seconds: 30);

/// 다음 조회까지의 간격. **순수 함수.** null이면 조회를 멈춘다.
///
/// ```
/// ① 막차 확정(closed)          → null (조회 중단)
/// ② 목록이 비었지만 막차는 아님 → 300초
/// ③ 그 밖                      → min(300초, 1차 남은시간 + 30초)
/// ```
///
/// **①의 기준은 `visible.isEmpty`가 아니라 `state == closed`다.** 목록이 비는
/// 경우는 막차 말고도 있다 — 조회 실패(`down`)·키 오류·고른 노선만 안 옴
/// (`filteredOut`). 비었다는 이유로 멈추면 **일시적인 네트워크 오류에 카드가 영구히
/// 얼어붙는다**(수동 새로고침 전까지). 막차만이 "더 물어볼 필요가 없다"가 확정된
/// 상태다. 시뮬레이션은 실패를 모델링하지 않아 이것을 놓쳤고,
/// `bus_card_host_test`의 `재시도 가드는 폴링·복귀 촉발을 막지 않는다`가 잡았다.
///
/// **왜 균등 간격이 아닌가.** 1초 보간이 들어온 뒤로 폴링의 값어치가 달라졌다 —
/// 서버가 "5분 남음"이라고 하면 그 5분을 요청 없이 정확히 그릴 수 있다. 조회가
/// 새로 가져오는 것은 둘뿐이다: **예측 수정**과 **목록 교체**. 후자는 맨 앞 버스가
/// 지나가는 순간에 몰려 있고, 전자는 남은 시간이 짧을수록 작다.
///
/// 그래서 두 힘으로 잡는다.
/// - **`1차 + 30초`**: 지금 뜬 버스가 지나가고 30초 뒤를 겨냥한다. 그 순간 목록이
///   통째로 낡는다(그 차는 떠났고 다음 차를 우리는 모른다). **이 상한이 없으면
///   `arrSec`이 0에서 멈춰 `곧 도착`이 몇 분씩 붙박이가 된다** — 시뮬레이션에서
///   도심 간선 오차 p90이 168초로 튄 것이 정확히 이 현상이다(drift 0에서도).
/// - **`300초`**: 버스가 20분 뒤면 `1차+30초`가 20분 반이 되는 것을 막는다.
///
/// 둘 중 작은 값이라 가까우면 촘촘해지고 멀면 성겨진다 — **분기 없이** 그렇게 된다.
///
/// **기준은 맨 앞 버스 하나다.** 뒤에 몇 대가 더 있든 목록이 낡는 순간은 맨 앞이
/// 지나갈 때다. 임박/대안 여부로 분기하는 5분기 안도 재봤지만 호출이 오히려 늘고
/// 오차는 같았다(근거: `docs/superpowers/specs/2026-07-30-bus-poll-interval-design.md`).
///
/// 실기기에서 조율하려면 위 상수 둘만 바꾸면 된다. 결과 예측은
/// `test/tools/bus_poll_sim.py`로 다시 돌려볼 수 있다.
Duration? busPollIntervalFor(BusCardView view) {
  if (view.state == BusCardState.closed) return null;

  // 실패·필터로 비었을 뿐이다. 회복을 기다리며 가장 성기게 계속 본다.
  if (view.visible.isEmpty) return busPollMax;

  final first = view.visible.first.arrSec;
  final afterArrival = Duration(seconds: first) + busPollAfterArrival;
  return afterArrival < busPollMax ? afterArrival : busPollMax;
}
