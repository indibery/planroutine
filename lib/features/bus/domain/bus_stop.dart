/// 등록된 정류장 1개 — SharedPreferences에 직렬화된다.
class BusStop {
  const BusStop({
    required this.nodeId,
    required this.nodeNm,
    required this.nodeNo,
    required this.cityCode,
    this.routeIds = const {},
  });

  /// TAGO 정류장 ID. **방향별로 별개다** — 길 건너 마주보는 정류장은 이름이
  /// 같고 좌표도 60m 차이인데 이 값이 다르다(실측: GGB201000156 / GGB202000003).
  final String nodeId;

  final String nodeNm;

  /// 정류소번호. `2251` 같은 4자리 정수다(하이픈 형식이 아니다).
  final int nodeNo;

  /// 도시코드. **시·도가 아니라 시·군 단위**다(경기도는 31010~31380).
  final int cityCode;

  /// 사용자가 고른 노선.
  ///
  /// **비어 있으면 "필터 없음"**이고 "고른 게 없음"이 아니다. 전부 체크한 상태를
  /// 열거해 저장하면 "전부"가 "이 다섯 개"로 굳어, 노선이 신설됐을 때 사용자는
  /// 전부를 골랐는데도 새 버스를 못 본다. 빈 집합은 시간이 지나도 뜻이 변하지 않는다.
  final Set<String> routeIds;

  BusStop copyWith({Set<String>? routeIds}) {
    return BusStop(
      nodeId: nodeId,
      nodeNm: nodeNm,
      nodeNo: nodeNo,
      cityCode: cityCode,
      routeIds: routeIds ?? this.routeIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'nodeNm': nodeNm,
        'nodeNo': nodeNo,
        'cityCode': cityCode,
        'routeIds': routeIds.toList(),
      };

  factory BusStop.fromJson(Map<String, dynamic> json) {
    final raw = json['routeIds'];
    return BusStop(
      nodeId: json['nodeId'] as String? ?? '',
      nodeNm: json['nodeNm'] as String? ?? '',
      nodeNo: json['nodeNo'] as int? ?? 0,
      cityCode: json['cityCode'] as int? ?? 0,
      routeIds: raw is List ? raw.map((e) => e.toString()).toSet() : const {},
    );
  }
}
