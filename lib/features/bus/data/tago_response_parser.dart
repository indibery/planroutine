import '../domain/bus_arrival.dart';
import '../domain/bus_stop.dart';

/// TAGO 응답을 읽은 결과.
enum TagoOutcome {
  /// 정상 — 항목이 하나 이상 있다.
  ok,

  /// 데이터 없음. 막차 후이거나 도시코드를 잘못 골랐다.
  ///
  /// TAGO는 이 경우에도 `resultCode "00"`을 주고 `items`를 **빈 문자열**로 준다
  /// (실측 확인). `resultCode '03'`(NODATA)은 관측되지 않았다.
  empty,

  /// 인증키 문제 등 — `resultCode`가 `"00"`이 아니다.
  keyError,

  /// 응답 껍데기가 예상과 다르다.
  malformed,
}

/// 파싱 결과 — 결과 종류와 항목을 함께 든다.
///
/// **`isOk` 같은 요약 getter를 두지 않는다.** 짧게 쓸 수 있으면 `if (isOk)`로 쓰고
/// 싶어지고 그 순간 `keyError`·`malformed`·`empty`가 하나의 else로 뭉개진다 —
/// 이 셋은 사용자에게 다른 말을 해야 하는 서로 다른 사실이다(§3). 판정은 [outcome]을
/// 열거하는 쪽에서만 한다.
class TagoResult<T> {
  const TagoResult(this.outcome, [this.items = const []]);

  final TagoOutcome outcome;
  final List<T> items;
}

/// 도시코드 1건.
class CityCode {
  const CityCode({required this.code, required this.name});

  /// `citycode` — **int로 온다**(실측). 시·도가 아니라 시·군 단위다.
  final int code;

  final String name;
}

/// 도착정보 응답 → 노선별 1건으로 축약된 목록(빠른 순).
TagoResult<BusArrival> parseArrivals(Map<String, dynamic> json) {
  return _parse(json, (rows) {
    // 같은 노선이 다음 차·그다음 차로 여러 건 온다(실측: 5노선 10항목).
    // 축약하지 않으면 카드에 `92번 10분 · 92번 25분`이 나란히 떠 한 노선이
    // 두 줄을 쓴다.
    // **버리지 않고 2등을 남긴다.** GBIS가 `*2` 짝으로 주는 "그 다음 차"를 TAGO는
    // 별개 행으로 준다 — 축약하면서 그냥 떨어뜨리면 같은 정보를 소스마다 다르게
    // 갖게 된다(카드는 소스를 구별하지 않는다).
    final byRoute = <String, List<BusArrival>>{};
    for (final row in rows) {
      final arrival = _arrival(row);
      (byRoute[arrival.routeId] ??= []).add(arrival);
    }

    final list = byRoute.values.map((rows) {
      rows.sort((a, b) => a.arrSec.compareTo(b.arrSec));
      final first = rows.first;
      return rows.length < 2
          ? first
          : first.copyWith(arrSec2: rows[1].arrSec);
    }).toList()
      ..sort((a, b) => a.arrSec.compareTo(b.arrSec));
    return list;
  });
}

/// 정류장 검색 응답 → 정류장 목록.
///
/// `cityCode`는 응답에 없어 호출자가 넘긴다 — 이후 도착정보 조회에 필요하다.
TagoResult<BusStop> parseStops(
  Map<String, dynamic> json, {
  required int cityCode,
}) {
  return _parse(json, (rows) {
    return rows
        .map((row) => BusStop(
              nodeId: row['nodeid']?.toString() ?? '',
              nodeNm: row['nodenm']?.toString() ?? '',
              nodeNo: _int(row['nodeno']),
              cityCode: cityCode,
            ))
        .where((s) => s.nodeId.isNotEmpty)
        .toList();
  });
}

/// 도시코드 목록 응답.
TagoResult<CityCode> parseCities(Map<String, dynamic> json) {
  return _parse(json, (rows) {
    return rows
        .map((row) => CityCode(
              code: _int(row['citycode']),
              name: row['cityname']?.toString() ?? '',
            ))
        .where((c) => c.code > 0)
        .toList();
  });
}

/// 껍데기 해석 + `items` 세 형태 정규화를 한곳에 모은다.
///
/// 세 엔드포인트가 같은 껍데기를 쓰므로 판정을 복제하지 않는다 — 복제하면
/// 한쪽만 고쳐 어긋난다.
TagoResult<T> _parse<T>(
  Map<String, dynamic> json,
  List<T> Function(List<Map<String, dynamic>> rows) build,
) {
  final response = json['response'];
  if (response is! Map) return const TagoResult(TagoOutcome.malformed);

  final header = response['header'];
  final body = response['body'];
  if (header is! Map || body is! Map) {
    return const TagoResult(TagoOutcome.malformed);
  }

  if (header['resultCode']?.toString() != '00') {
    return const TagoResult(TagoOutcome.keyError);
  }

  final rows = _rows(body['items']);
  if (rows.isEmpty) return const TagoResult(TagoOutcome.empty);

  final built = build(rows);
  if (built.isEmpty) return const TagoResult(TagoOutcome.empty);
  return TagoResult(TagoOutcome.ok, built);
}

/// `items`는 Map(단건) · List(복수) · ""(없음) 세 형태로 온다.
///
/// 빈 문자열이 오는 것이 핵심이다 — `items['item']`으로 바로 들어가면 String에
/// 인덱스 접근이라 파싱이 깨진다.
List<Map<String, dynamic>> _rows(Object? items) {
  if (items is! Map) return const [];
  final item = items['item'];
  if (item is List) {
    return item.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  if (item is Map) return [item.cast<String, dynamic>()];
  return const [];
}

BusArrival _arrival(Map<String, dynamic> row) {
  final seconds = _int(row['arrtime']);
  return BusArrival(
    routeId: row['routeid']?.toString() ?? '',
    // routeno가 int와 String으로 섞여 온다(`92` / `"92-1"`). `as String` 캐스트는
    // 숫자 노선번호에서 크래시하므로 반드시 toString으로 받는다.
    routeNo: row['routeno']?.toString() ?? '',
    // **초를 그대로 넘긴다.** 예전에는 여기서 `ceil`로 분을 만들었는데, 시간 축이
    // 그 격자에 갇혀 점이 30초마다 순간이동했다. 분은 `BusArrival.arrMin`이 만든다.
    arrSec: seconds <= 0 ? 0 : seconds,
    lowFloor: row['vehicletp']?.toString() == '저상버스',
  );
}

/// int로 오는 값이 문자열로 바뀌어도 읽는다(포맷 변경 내성).
int _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
