import '../../../core/constants/app_strings.dart';

/// 도착 예정 버스 1건 — TAGO/GBIS 응답 1항목을 정규화한 결과.
///
/// DB에 저장되지 않는 계산 결과이므로 freezed 없이 plain class로 둔다
/// (`TodayView`·`PendingNotification`과 같은 계열).
class BusArrival {
  const BusArrival({
    required this.routeId,
    required this.routeNo,
    required this.arrSec,
    this.arrSec2,
    this.vehicleId,
    this.vehicleId2,
    this.lowFloor = false,
  });

  /// 분만 아는 경로용 — GBIS의 `predictTime1` 폴백과 테스트 픽스처.
  ///
  /// 초 필드가 없는 응답이 실재하므로(`predictTimeSec1` 키 없음) 이 경로를 없앨 수
  /// 없다. 분을 초로 올려 두면 이후 계산은 전부 초 하나로 통일된다.
  factory BusArrival.fromMinutes({
    required String routeId,
    required String routeNo,
    required int arrMin,
    int? arrMin2,
    bool lowFloor = false,
  }) =>
      BusArrival(
        routeId: routeId,
        routeNo: routeNo,
        arrSec: arrMin * 60,
        arrSec2: arrMin2 == null ? null : arrMin2 * 60,
        lowFloor: lowFloor,
      );

  /// 노선 고유 ID. 노선 축약과 사용자 노선 필터의 기준이다.
  final String routeId;

  /// 화면에 보이는 노선번호.
  ///
  /// TAGO는 이 값을 **int와 String으로 섞어** 준다(`92` / `"92-1"`). 하이픈이 있는
  /// 노선만 문자열이다. 파서가 `.toString()`으로 받아 여기서는 항상 String이다.
  final String routeNo;

  /// 도착까지 남은 **초**. 진실의 원천.
  ///
  /// 분으로 뭉개지 않는 이유는 시간 축이다 — `5분 59초`와 `6분 1초`가 같은 자리에
  /// 서면 점이 30초마다 한 칸씩 순간이동한다(실기기 신고 2026-07-30). 경과 보정도
  /// 이미 초로 계산하고 있었으므로, 버리던 값을 다시 쓰는 셈이다.
  final int arrSec;

  /// 표시·정렬용 분. 0이면 "곧 도착".
  ///
  /// **`round`다.** `ceil`은 최대 59초를 과대 표시해 사용자가 버스를 놓칠 수 있어
  /// 경과 보정 경로가 이미 거부했던 규칙이다 — 두 경로를 여기 한 곳으로 합쳤다.
  int get arrMin => (arrSec / 60).round();

  /// **그 다음 차**까지 남은 초. 없을 수 있다(모든 노선이 2차를 주지는 않는다 —
  /// 실측 A정류장 5/8, B정류장 5/6).
  ///
  /// **표시 전용이다.** 조회 간격 계산(`busPollIntervalFor`)에는 쓰지 않는다.
  /// 2차 예측은 그 버스가 15~30분 뒤일 때 만들어진 값이라 원래 부정확하고, 그것을
  /// 1차인 것처럼 갈아끼우는 안은 시뮬에서 기각됐다(drift 12%에서 오차 p90 389초).
  ///
  /// 그런데 **`다음 14분`이라고 밝히고 보여주는 것은 다르다** — 사용자가 그 숫자로
  /// 하는 판단은 "뛸까 말까"지 "몇 분에 정확히 온다"가 아니라서, 몇 분 틀려도
  /// 감당된다. 레이블이 부정확함을 감당 가능하게 만든다.
  final int? arrSec2;

  /// 실제 **차량** 식별자(GBIS `vehId1`). 없을 수 있다 — TAGO 응답에는 없다.
  ///
  /// **화면의 점이 무엇인지를 정하는 값이다.** 축의 점은 "노선"이 아니라 "지금
  /// 오고 있는 이 버스"다. 노선으로 묶으면 앞차가 지나가는 순간 같은 위젯의 위치만
  /// 0분에서 8분으로 바뀌어 **점이 시간을 거슬러 오른쪽으로 미끄러진다**
  /// (실기기 신고 2026-07-30). 차량으로 묶으면 지나간 차는 사라지고, 뒤차는
  /// 제자리에서 앞차가 되며, 새 차가 오른쪽에 생긴다.
  final String? vehicleId;

  /// 그 다음 차량(GBIS `vehId2`). [arrSec2]와 짝이다.
  final String? vehicleId2;

  /// 저상버스인지 (`vehicletp == '저상버스'`).
  final bool lowFloor;

  /// 경과 보정에서 [arrSec]·[arrSec2]를 갈아끼운다. 차량 식별자는 보존한다 —
  /// 보정은 같은 버스의 남은 시간만 줄이는 일이다.
  BusArrival copyWith({int? arrSec, int? arrSec2}) {
    return BusArrival(
      routeId: routeId,
      routeNo: routeNo,
      arrSec: arrSec ?? this.arrSec,
      arrSec2: arrSec2 ?? this.arrSec2,
      vehicleId: vehicleId,
      vehicleId2: vehicleId2,
      lowFloor: lowFloor,
    );
  }

  /// 디버그용이지만 분 표기는 화면과 **같은 함수**로 만든다 — 같은 값을 두 방식으로
  /// 조립하면 단위를 바꿀 때 한쪽만 따라간다.
  @override
  String toString() => 'BusArrival($routeNo, ${BusStrings.minutes(arrMin)})';
}
