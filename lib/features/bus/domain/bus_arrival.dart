/// 도착 예정 버스 1건 — TAGO 응답 1항목을 정규화한 결과.
///
/// DB에 저장되지 않는 계산 결과이므로 freezed 없이 plain class로 둔다
/// (`TodayView`·`PendingNotification`과 같은 계열).
class BusArrival {
  const BusArrival({
    required this.routeId,
    required this.routeNo,
    required this.arrMin,
    this.lowFloor = false,
  });

  /// 노선 고유 ID. 노선 축약과 사용자 노선 필터의 기준이다.
  final String routeId;

  /// 화면에 보이는 노선번호.
  ///
  /// TAGO는 이 값을 **int와 String으로 섞어** 준다(`92` / `"92-1"`). 하이픈이 있는
  /// 노선만 문자열이다. 파서가 `.toString()`으로 받아 여기서는 항상 String이다.
  final String routeNo;

  /// 도착까지 남은 분. 0이면 "곧 도착".
  final int arrMin;

  /// 저상버스인지 (`vehicletp == '저상버스'`).
  final bool lowFloor;

  /// 경과 보정에서 [arrMin]만 갈아끼운다.
  BusArrival copyWith({int? arrMin}) {
    return BusArrival(
      routeId: routeId,
      routeNo: routeNo,
      arrMin: arrMin ?? this.arrMin,
      lowFloor: lowFloor,
    );
  }

  @override
  String toString() => 'BusArrival($routeNo, $arrMin분)';
}
