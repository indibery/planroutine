/// 등록된 정류장 1개 — SharedPreferences에 직렬화된다.
class BusStop {
  const BusStop({
    required this.nodeId,
    required this.nodeNm,
    required this.nodeNo,
    required this.cityCode,
    this.regionName,
    this.routeIds = const {},
  });

  /// TAGO 정류장 ID. **방향별로 별개다** — 길 건너 마주보는 정류장은 이름이
  /// 같고 좌표도 60m 차이인데 이 값이 다르다(실측: GGB201000156 / GGB202000003).
  final String nodeId;

  final String nodeNm;

  /// 정류소번호. `2251` 같은 4자리 정수다(하이픈 형식이 아니다).
  final int nodeNo;

  /// 도시코드. **시·도가 아니라 시·군 단위**다(경기도는 31010~31380).
  ///
  /// TAGO 조회에만 쓰인다. GBIS로 찾은 정류장은 이 값이 없어 `0`이고, 그래도 문제가
  /// 없다 — `BusApiClient`가 `nodeId` 접두로 소스를 가르고 GBIS 쿼리에는 도시코드가
  /// 실리지 않는다.
  final int cityCode;

  /// 지역 이름(`군포`·`서울`·`인천`). GBIS 검색 결과에만 있고 TAGO 경로는 null이다.
  ///
  /// **검색 범위가 수도권 전체로 넓어진 뒤로는 없으면 고를 수 없다** — 실측 `장미아파트`
  /// 는 의왕·인천·군포·시흥에 모두 있고 이름도 정류소번호도 화면에서 구별에 도움이
  /// 되지 않는다. TAGO 시절에는 도시를 먼저 골라 검색했으므로 이 정보가 화면 위쪽에
  /// 이미 있었다.
  ///
  /// 저장도 한다 — 설정 탭의 `출발지 · 장미아파트`만으로는 어느 장미아파트인지 알 수
  /// 없다. 옛 데이터에는 없으므로 nullable이다(마이그레이션 없음).
  final String? regionName;

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
      regionName: regionName,
      routeIds: routeIds ?? this.routeIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'nodeNm': nodeNm,
        'nodeNo': nodeNo,
        'cityCode': cityCode,
        // 없으면 키를 넣지 않는다 — TAGO 경로 정류장의 저장 모양을 바꾸지 않는다.
        if (regionName != null) 'regionName': regionName,
        'routeIds': routeIds.toList(),
      };

  factory BusStop.fromJson(Map<String, dynamic> json) {
    final raw = json['routeIds'];
    return BusStop(
      nodeId: json['nodeId'] as String? ?? '',
      nodeNm: json['nodeNm'] as String? ?? '',
      nodeNo: json['nodeNo'] as int? ?? 0,
      cityCode: json['cityCode'] as int? ?? 0,
      regionName: json['regionName'] as String?,
      routeIds: raw is List ? raw.map((e) => e.toString()).toSet() : const {},
    );
  }
}
