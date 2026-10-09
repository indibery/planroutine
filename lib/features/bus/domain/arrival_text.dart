import '../../../core/constants/app_strings.dart';
import 'bus_card_view.dart';

/// 임박도 세 칸. 색은 위젯이 정하고, 칸을 가르는 규칙은 여기 한 곳에 둔다.
enum BusSignal { near, soon, far }

/// 분으로 임박도를 가른다. **두 본문 모양이 같은 함수를 쓴다.**
///
/// 어떤 분을 넘기는지는 모양이 정한다 — `시간 축`은 반올림한 [BusArrival.arrMin],
/// `간단히`는 화면에 쓴 분([displayedMinutes]). 사용자가 읽는 숫자와 색이 같은 칸에
/// 있어야 한다.
BusSignal busSignalOf(int minutes) {
  if (isUrgent(minutes)) return BusSignal.near;
  if (isSoon(minutes)) return BusSignal.soon;
  return BusSignal.far;
}

/// `간단히` 모양이 화면에 쓰는 분 — **내림**이다. `2분 59초`의 분은 2다.
int displayedMinutes(int arrSec) => arrSec <= 0 ? 0 : arrSec ~/ 60;

/// "2분 14초" / "48초" / "곧 도착". **순수 함수.**
///
/// 남은 시간은 0에서 멈추므로(경과 보정이 음수로 내리지 않는다) 0 이하는 곧 도착이다.
String arrivalClockText(int arrSec) {
  if (arrSec <= 0) return BusStrings.arrivingNow;
  if (arrSec < 60) return BusStrings.seconds(arrSec);
  return BusStrings.minutesSeconds(arrSec ~/ 60, arrSec % 60);
}
