import '../domain/bus_arrival.dart';
import '../domain/bus_route.dart';
import 'tago_response_parser.dart';

/// 경기도 식별자 접두. **`TAGO nodeId` = `'GGB'` + `GBIS stationId`**이고 노선 ID도
/// 같은 규칙이다(실측: TAGO `GGB200000025`·`GGB200000029` ↔ GBIS `200000025`·
/// `200000029` = 수원시청 92·92-1번).
///
/// 이 상수가 두 가지를 정의한다.
/// 1. **소스 분기** — `BusApiClient.fetchArrivals`가 이 접두로 GBIS/TAGO를 가른다.
///    비경기 정류장은 접두가 다르다(부산 `BSB…`, 제주 `JEB…`).
/// 2. **노선 ID 복원** — 파서가 GBIS `routeId`에 이 접두를 **되붙인다**. 사용자가
///    이미 골라둔 `BusStop.routeIds`는 TAGO 형식으로 저장돼 있고
///    `buildBusCardView`가 `routeIds.contains(a.routeId)`로 **문자열 그대로**
///    비교하므로, 접두를 빼고 주면 노선을 골라둔 사용자에게 `고른 노선은 지금
///    오지 않아요`가 영구히 뜬다. 되붙이면 마이그레이션이 필요 없다.
const gbisIdPrefix = 'GGB';

/// `resultCode` — 정상 처리.
const _gbisOk = 0;

/// `resultCode` — `결과가 존재하지 않습니다`. 없는 정류소이거나 도착 정보가 없다.
/// 이때 응답에는 **`msgBody` 키가 아예 없다**(실측 `arrivals_unknown_station.json`).
const _gbisNoResult = 4;

/// 경기도 GBIS 정류소 도착정보 응답 → 노선 목록(빠른 순).
///
/// TAGO의 [TagoResult]·[TagoOutcome]을 **그대로 재사용한다** — 이름은 소스명(TAGO)에
/// 묶여 있지만 클라이언트의 상태 판정(ok/empty/keyError/malformed → 카드 5상태)이
/// 소스와 무관하게 한 곳에 있어야 한다. 이름 정리는 별건이다.
///
/// **도착 시각이 없는 노선은 목록에서 뺀다.** GBIS는 그런 노선도 행으로 주고
/// (`predictTime1: ""` + `predictTimeSec1` 없음, 실측 장미아파트 10행 중 2행)
/// 지도 앱은 그것을 `정보없음`으로 **보여준다.** 우리가 조용히 빼면 사용자는 "그
/// 노선이 안 온다"로 읽는다 — 이 카드가 처음 어긋난 방식(군포 장미아파트에서 9개 중
/// 2개만 보였다)의 축소판이다. 그런데도 지금 빼는 이유는 화면이 아니라 타입이다:
/// [BusArrival.arrMin]이 non-nullable이고 nullable로 바꾸면 정렬·경과 보정·표시
/// 상한·카드·확인 시트가 전부 영향받는다(스펙 개정 라운드 몫).
///
/// **1차 도착만 읽는다.** GBIS는 1차·2차를 한 행에 담아 주는데(`*1`/`*2` 짝) TAGO는
/// 두 행으로 줬다 — 파서 구조가 다른 지점이다. 카드는 노선당 한 줄이라 `*2`는 이번
/// 범위 밖이다.
///
/// **노선 축약(같은 `routeId` 여러 건 → 빠른 것 하나)은 하지 않는다.** 1차·2차가 한
/// 행에 오므로 실측 응답은 노선당 1행이다(장미 10노선 10행 · 수원시청 6노선 6행).
TagoResult<BusArrival> parseGbisArrivals(Map<String, dynamic> json) {
  final failure = _envelopeFailure(json);
  if (failure != null) return TagoResult(failure);

  final list = <BusArrival>[];
  for (final row in _rows(json, 'busArrivalList')) {
    final arrival = _arrival(row);
    if (arrival != null) list.add(arrival);
  }
  if (list.isEmpty) return const TagoResult(TagoOutcome.empty);

  list.sort((a, b) => a.arrMin.compareTo(b.arrMin));
  return TagoResult(TagoOutcome.ok, list);
}

/// 경유노선 목록 응답 → 이 정류장을 지나는 노선 **전체**(도착 여부 무관).
///
/// 도착정보와 별개 엔드포인트인 것이 요점이다 — 확인 시트의 선택 목록이 등록하는
/// **시각**에 좌우되지 않는다([BusRoute] 문서 참고). 심야에 등록해도 같은 목록이
/// 나오고, 도착 조회가 실패해도 행선지로 방향을 확인할 수 있다.
///
/// **정렬하지 않는다.** 표시 순서는 `buildRouteChoices`가 번호순으로 정한다
/// (카드는 빠른 순, 시트는 번호순 — 목적이 다르다).
TagoResult<BusRoute> parseGbisViaRoutes(Map<String, dynamic> json) {
  final failure = _envelopeFailure(json);
  if (failure != null) return TagoResult(failure);

  final list = _rows(json, 'busRouteList').map(_route).toList();
  if (list.isEmpty) return const TagoResult(TagoOutcome.empty);
  return TagoResult(TagoOutcome.ok, list);
}

/// 두 GBIS 응답이 공유하는 껍데기·`resultCode` 판정. **null이면 정상이다.**
///
/// 도착정보와 경유노선이 같은 계약을 쓰므로 한 곳에 둔다 — 복사해 두면 GBIS가
/// 코드를 하나 추가할 때 한쪽만 따라간다.
TagoOutcome? _envelopeFailure(Map<String, dynamic> json) {
  final response = json['response'];
  if (response is! Map) return TagoOutcome.malformed;

  final header = response['msgHeader'];
  if (header is! Map) return TagoOutcome.malformed;

  final code = _intOrNull(header['resultCode']);
  if (code == _gbisNoResult) return TagoOutcome.empty;
  if (code != _gbisOk) return TagoOutcome.malformed;
  return null;
}

/// `msgBody.<key>` 배열의 각 행.
///
/// `resultCode`가 정상인데 목록이 없는 형태는 관측되지 않았다. 와도 호출부가
/// `empty`로 돌린다 — 껍데기가 깨진 것이 아니라 담긴 건수가 0인 것과 구별할 수단이
/// 없다.
///
/// **단건일 때 배열이 아니라 객체로 오는 형태는 다루지 않는다**(TAGO의
/// `items: {'item': …}`에 해당하는 것). 그런 응답을 관측하지 못해 모양을 모르는데,
/// 추측으로 분기를 넣으면 검증할 수 없는 코드가 남는다. 만약 그렇게 온다면 빈 목록
/// → `empty`로 떨어져, 확인 시트는 도착정보 기반 목록으로 폴백한다(크래시가 아니다).
Iterable<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) {
  final response = json['response'];
  final body = response is Map ? response['msgBody'] : null;
  final rows = body is Map ? body[key] : null;

  return rows is List
      ? rows.whereType<Map>().map((r) => r.cast<String, dynamic>())
      : const [];
}

/// 한 행 → 경유노선 1건.
BusRoute _route(Map<String, dynamic> row) {
  return BusRoute(
    // 도착정보 파서와 **같은 규칙**으로 접두를 되붙인다 — 시트에서 고른 routeId가
    // 곧 `BusStop.routeIds`이고, 카드는 그것을 도착정보의 routeId와 문자열로
    // 비교한다. 한쪽만 접두를 붙이면 고른 노선이 카드에서 전부 걸러진다.
    routeId: '$gbisIdPrefix${_intOrNull(row['routeId']) ?? 0}',
    routeNo: row['routeName']?.toString() ?? '',
    destName: row['routeDestName']?.toString() ?? '',
  );
}

/// 한 행 → 도착 1건. 도착 시각이 없는 행이면 null(위 doc 참고).
BusArrival? _arrival(Map<String, dynamic> row) {
  final arrMin = _arrMin(row['predictTimeSec1'], row['predictTime1']);
  if (arrMin == null) return null;

  return BusArrival(
    routeId: '$gbisIdPrefix${_intOrNull(row['routeId']) ?? 0}',
    // routeName은 **int와 String이 한 응답에 섞여** 온다(실측: `9`·`5623`은 int,
    // `'11-5'`는 String). `as String` 캐스트는 숫자 노선번호에서 크래시한다.
    routeNo: row['routeName']?.toString() ?? '',
    arrMin: arrMin,
    lowFloor: _intOrNull(row['lowPlate1']) == 1,
  );
}

/// 도착까지 남은 분.
///
/// **초가 있으면 초를 쓴다** — 같은 행의 분 필드보다 정확하다(실측: `predictTimeSec1
/// 361`인 버스의 `predictTime1`이 `5`). 올림 규칙은 TAGO 경로
/// (`tago_response_parser`의 `arrtime`)와 같은 `ceil`로 둔다 — 두 소스가 다른
/// 규칙을 쓰면 같은 정류장을 경기/비경기로 옮겨 볼 때 표시가 어긋난다.
///
/// 둘 다 비어 있으면(`''`·키 없음) 도착 정보가 없는 노선이다 → null.
int? _arrMin(Object? sec, Object? min) {
  final seconds = _intOrNull(sec);
  if (seconds != null) return seconds <= 0 ? 0 : (seconds / 60).ceil();

  final minutes = _intOrNull(min);
  if (minutes == null) return null;
  return minutes < 0 ? 0 : minutes;
}

/// GBIS는 같은 필드를 `int` · `''`(빈 문자열) · 키 없음(null)으로 **섞어** 준다.
///
/// 빈 값을 0으로 뭉개지 않는 것이 핵심이다 — `predictTime1: ''`을 0분으로 읽으면
/// 도착 정보가 없는 노선이 `곧 도착`으로 목록 맨 위에 올라온다.
int? _intOrNull(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
