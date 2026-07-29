import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/bus_arrival.dart';
import '../domain/bus_card_view.dart';
import '../domain/bus_route.dart';
import '../domain/bus_stop.dart';
import 'gbis_response_parser.dart';
import 'tago_response_parser.dart';

/// TAGO 국토교통부 서비스 묶음.
///
/// **https다.** 실측으로 TLSv1.3 + GlobalSign 인증서를 확인했으므로 `Info.plist`에
/// ATS 예외를 넣지 않는다.
const tagoBaseUrl = 'https://apis.data.go.kr/1613000';

/// 경기도 GBIS 정류소 도착정보.
///
/// **TAGO와 같은 호스트·같은 https·같은 인증키다** — ATS 예외도, 키 추가 발급도
/// 필요 없다(실측).
///
/// 경기 정류장에서 TAGO를 쓰지 않는 이유: TAGO의 `cityCode`는 정류장 소속이 아니라
/// **노선 운영 시·군 필터**라 같은 nodeId를 시·군마다 다르게 답한다(실측
/// `GGB225000100`: 군포시 `3030·6501` / 안양시 `15·11-5·87`). 우리는 검색에 쓴
/// cityCode 하나만 저장하므로 구조적으로 일부만 보인다. 게다가 TAGO 도시목록 138개에
/// **서울이 없어** 서울 노선(`5623`·`541`)은 영구히 조회되지 않는다. GBIS는 같은
/// 정류장을 서울 노선까지 한 번에 답한다.
const gbisArrivalUrl =
    'https://apis.data.go.kr/6410000/busarrivalservice/v2/getBusArrivalListv2';

/// 경기도 GBIS 정류소 경유노선 목록.
///
/// 도착정보와 같은 호스트·같은 키지만 **다른 서비스**(`busstationservice`)라 공공데이터
/// 포털 활용신청이 별개다. 미승인이면 403이 오고 [BusApiClient.fetchViaRoutes]가
/// `keyError`로 돌려주므로, 확인 시트는 도착정보 기반 목록으로 폴백한다 — 이 서비스가
/// 없어도 앱은 이전과 똑같이 동작한다.
const gbisViaRouteUrl =
    'https://apis.data.go.kr/6410000/busstationservice/v2/getBusStationViaRouteListv2';

/// 메모리 캐시 수명. 폴링 주기와 같게 두어 방향 토글 왕복과 탭 재진입만 흡수한다.
const busCacheTtl = Duration(seconds: 30);

/// 화면에 띄울 수 있는 목록의 나이 상한. **이 상수 하나가 두 곳을 정의한다** —
/// [BusApiClient._fallback]의 stale 상한과 `BusCardHost._tick`의 표시 드롭.
///
/// 나이 상한이 없으면 통신이 끊긴 뒤 수십 분 묵은 목록이 그대로 남고, 경과 보정이
/// 그 목록의 arrMin을 전부 0으로 깎아 **38분 전에 지나간 버스가 `곧 도착`으로**
/// 뜬다(반증 단서는 10px `07:32 기준 · 갱신 실패` 하나뿐이다). 캐시는
/// `busApiClientProvider`가 autoDispose가 아니라 앱 프로세스 수명만큼 살아 있어
/// "한 시간 뒤 네트워크 없이 오늘 탭 재진입" 한 번으로 재현된다.
///
/// `busCacheTtl`과 다른 값이어야 한다 — 표시 드롭을 TTL과 같게 두면 `fetchedAt`이
/// 요청 **시작** 시각이고 폴링은 응답 **뒤** 30초라 `d+30 > 30`이 구조적으로 항상
/// 참이 되어 정상 폴링마다 목록이 사라진다.
const busMaxDisplayAge = Duration(minutes: 3);

/// 빌드 시 주입되는 인증키. 소스와 git 히스토리에 남지 않는다.
///
/// 넣는 경로는 **`--dart-define-from-file=<tmp>.json` 하나다**(`ios/fastlane/Fastfile`
/// 참고 — 레인이 임시 JSON을 만들고 빌드 후 지운다).
///
/// **`--dart-define=TAGO_KEY=...`로 넣지 않는다**: fastlane의 `sh`가 기본으로 명령
/// 문자열을 echo하므로 argv에 실으면 매 beta 로그에 키가 평문으로 남는다.
///
/// 난독화가 아니라 **히스토리와 로그에 남지 않는 것**이 실질 이득이다 — 키는
/// 어차피 IPA 안에 문자열로 남는다.
const _envKey = String.fromEnvironment('TAGO_KEY');

/// 도착정보 1회 조회 결과.
class BusFetch {
  const BusFetch({
    required this.state,
    required this.arrivals,
    required this.fetchedAt,
  });

  final BusCardState state;
  final List<BusArrival> arrivals;

  /// 이 목록을 실제로 받아온 시각. 캐시 히트면 캐시된 시각이 그대로 온다.
  final DateTime? fetchedAt;
}

class _CacheEntry {
  const _CacheEntry(this.arrivals, this.fetchedAt);

  final List<BusArrival> arrivals;
  final DateTime fetchedAt;
}

/// TAGO를 직접 호출한다. 프록시는 보류다(스펙 §2·§5).
class BusApiClient {
  BusApiClient({
    http.Client? client,
    String? serviceKey,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _serviceKey = serviceKey ?? _envKey,
        _now = clock ?? DateTime.now;

  final http.Client _client;
  final String _serviceKey;
  final DateTime Function() _now;

  final _cache = <String, _CacheEntry>{};

  /// 실제로 나간 HTTP 요청 수. **테스트가 "요청 0회"를 검사하는 수단이다.**
  ///
  /// 접힘·시간대 밖에서 요청이 나가지 않는다는 것을 화면으로 검증하면 약하다 —
  /// 접힘에서는 어차피 화면이 안 바뀌므로 요청이 나가도 통과한다. 횟수를 세야 잡힌다.
  int get requestCount => _requestCount;
  int _requestCount = 0;

  /// 키가 주입됐는지. false면 기능을 명시적으로 끈다(무한 로딩 금지).
  bool get hasKey => _serviceKey.isNotEmpty;

  /// 캐시를 버린다. 슬롯이 교체되면 옛 정류장 값을 쓰지 않도록 호출한다.
  void invalidate() => _cache.clear();

  Future<BusFetch> fetchArrivals({
    required int cityCode,
    required String nodeId,
  }) async {
    final key = '$cityCode:$nodeId';
    final cached = _cache[key];
    final now = _now();

    if (cached != null && now.difference(cached.fetchedAt) < busCacheTtl) {
      return BusFetch(
        state: BusCardState.ok,
        arrivals: cached.arrivals,
        fetchedAt: cached.fetchedAt,
      );
    }

    if (!hasKey) {
      return const BusFetch(
        state: BusCardState.keyError,
        arrivals: [],
        fetchedAt: null,
      );
    }

    try {
      final result = await _arrivals(cityCode: cityCode, nodeId: nodeId);

      switch (result.outcome) {
        case TagoOutcome.ok:
          _cache[key] = _CacheEntry(result.items, now);
          return BusFetch(
            state: BusCardState.ok,
            arrivals: result.items,
            fetchedAt: now,
          );
        case TagoOutcome.empty:
          _cache[key] = _CacheEntry(const [], now);
          return BusFetch(
            state: BusCardState.closed,
            arrivals: const [],
            fetchedAt: now,
          );
        case TagoOutcome.keyError:
        case TagoOutcome.malformed:
          return _fallback(key, cached, BusCardState.keyError);
      }
    } on _KeyRejected {
      return _fallback(key, cached, BusCardState.keyError);
    } catch (_) {
      // 네트워크·타임아웃·JSON 파손. 캐시가 있으면 옛 목록을 보여주고 갱신
      // 실패를 고백한다 — 실시간인 척하면 버스를 놓친 사용자가 앱을 불신한다.
      return _fallback(key, cached, BusCardState.down);
    }
  }

  /// 도착정보 1회 조회 — **정류소 ID 접두로 소스를 가른다.**
  ///
  /// 경기 정류장([gbisIdPrefix])만 GBIS로 보내고 나머지는 TAGO를 그대로 쓴다. GBIS는
  /// 경기도 전용이라 비경기 nodeId(부산 `BSB…`·제주 `JEB…`)로는 답이 없다.
  ///
  /// 저장된 [BusStop]은 손대지 않는다 — `nodeId`에서 접두만 떼면 GBIS `stationId`다
  /// (실측 3건 검증). 그래서 이 교체에 마이그레이션이 없다.
  ///
  /// `cityCode`는 TAGO 경로에만 넘어간다. GBIS는 정류소 ID만 보므로 잘못된 시·군을
  /// 골라 저장한 사용자도 경기 안이면 정상 조회된다.
  Future<TagoResult<BusArrival>> _arrivals({
    required int cityCode,
    required String nodeId,
  }) async {
    if (nodeId.startsWith(gbisIdPrefix)) {
      return parseGbisArrivals(await _gbis(gbisArrivalUrl, nodeId));
    }

    final json = await _get(
      'ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList',
      {'cityCode': '$cityCode', 'nodeId': nodeId, 'numOfRows': '30'},
    );
    return parseArrivals(json);
  }

  /// 정류장을 지나는 노선 **전체**. 확인 시트의 선택 목록이 여기서 나온다.
  ///
  /// **등록할 때 한 번만** 부른다 — 폴링 경로가 아니므로 캐시하지 않는다(재사용 창이
  /// 없다). 일일 트래픽도 도착정보와 별도로 배정돼(각 1,000) 병목이 아니다.
  ///
  /// 경기 정류장이 아니면 **요청을 보내지 않고** 빈 결과를 준다. GBIS는 경기도 전용이라
  /// 부산 `BSB…`·제주 `JEB…`로는 답이 없고, 헛요청은 트래픽만 쓴다. 호출부는 빈 결과를
  /// 실패로 읽지 않고 도착정보 기반 목록으로 폴백한다.
  ///
  /// 실패(키 거부·네트워크·파손)도 예외를 던지지 않고 outcome으로 돌려준다 —
  /// 선택 목록을 못 받은 것이 등록 자체를 막을 이유는 아니다.
  Future<TagoResult<BusRoute>> fetchViaRoutes({required String nodeId}) async {
    if (!nodeId.startsWith(gbisIdPrefix)) {
      return const TagoResult(TagoOutcome.empty);
    }
    if (!hasKey) return const TagoResult(TagoOutcome.keyError);

    try {
      return parseGbisViaRoutes(await _gbis(gbisViaRouteUrl, nodeId));
    } on _KeyRejected {
      return const TagoResult(TagoOutcome.keyError);
    } catch (_) {
      return const TagoResult(TagoOutcome.malformed);
    }
  }

  /// GBIS 엔드포인트 하나를 부른다 — 정류소 ID로 조회하는 두 서비스가 쿼리 규약을
  /// 공유한다(`serviceKey`·`stationId`·`format`. TAGO의 `_type`·`pageNo`는 없다).
  ///
  /// `nodeId`에서 접두를 떼는 규칙도 여기 한 곳에 둔다 — 두 곳에 흩어져 있으면 한쪽만
  /// 고쳐 접두가 붙은 채 나가고, GBIS는 그것을 없는 정류소(`resultCode: 4`)로 답한다.
  Future<Map<String, dynamic>> _gbis(String url, String nodeId) {
    return _send(Uri.parse(url).replace(queryParameters: {
      'serviceKey': _serviceKey,
      'stationId': nodeId.substring(gbisIdPrefix.length),
      'format': 'json',
    }));
  }

  Future<TagoResult<BusStop>> searchStops({
    required int cityCode,
    required String name,
  }) async {
    if (!hasKey) return const TagoResult(TagoOutcome.keyError);
    try {
      final json = await _get(
        'BusSttnInfoInqireService/getSttnNoList',
        {'cityCode': '$cityCode', 'nodeNm': name, 'numOfRows': '50'},
      );
      return parseStops(json, cityCode: cityCode);
    } on _KeyRejected {
      return const TagoResult(TagoOutcome.keyError);
    } catch (_) {
      return const TagoResult(TagoOutcome.malformed);
    }
  }

  Future<TagoResult<CityCode>> fetchCities() async {
    if (!hasKey) return const TagoResult(TagoOutcome.keyError);
    try {
      final json = await _get(
        'ArvlInfoInqireService/getCtyCodeList',
        {'numOfRows': '300'},
      );
      return parseCities(json);
    } on _KeyRejected {
      return const TagoResult(TagoOutcome.keyError);
    } catch (_) {
      return const TagoResult(TagoOutcome.malformed);
    }
  }

  /// 조회가 실패했을 때 캐시로 버틸지, 실패를 그대로 말할지 고른다.
  ///
  /// `cached.arrivals.isEmpty` 절은 **load-bearing이다.** 빼면 '막차 후(closed로
  /// 빈 목록이 캐시됨) → 다음 폴링 실패'에서 `down`/`keyError`가 fetchedAt 있는
  /// `stale`로 잘못 승격돼, 본문은 `지금 정보를 못 받았어요`인데 제목줄은
  /// `07:32 기준 · 갱신 실패`를 붉게 쓰는 부정확한 조합이 된다.
  BusFetch _fallback(String key, _CacheEntry? cached, BusCardState failure) {
    if (cached == null ||
        cached.arrivals.isEmpty ||
        _now().difference(cached.fetchedAt) > busMaxDisplayAge) {
      // 나이 상한을 넘긴 엔트리는 버린다 — 남겨두면 폴링마다 같은 판정을 되풀이하고,
      // 통신이 돌아오기 전까지 프로세스 수명 내내 메모리에 남는다.
      _cache.remove(key);
      return BusFetch(state: failure, arrivals: const [], fetchedAt: null);
    }
    return BusFetch(
      state: BusCardState.stale,
      arrivals: cached.arrivals,
      fetchedAt: cached.fetchedAt,
    );
  }

  /// TAGO 엔드포인트 하나를 부른다. 공통 쿼리(`serviceKey`·`_type`·`pageNo`)를 여기
  /// 한 곳에서 붙인다 — GBIS는 쿼리 규약이 달라 [_gbis]가 따로 있다.
  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) {
    return _send(Uri.parse('$tagoBaseUrl/$path').replace(queryParameters: {
      'serviceKey': _serviceKey,
      '_type': 'json',
      'pageNo': '1',
      ...query,
    }));
  }

  /// HTTP 한 번 + 실패 판정. **두 소스가 같은 계약을 쓴다** — 401/403은 키 거부,
  /// 그 밖의 비200은 예외다(캐시 폴백으로 간다). GBIS 게이트웨이의 활용신청 미승인도
  /// 401/403으로 온다.
  Future<Map<String, dynamic>> _send(Uri uri) async {
    _requestCount++;
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const _KeyRejected();
    }
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

/// 키가 거부됐다 — 재시도해도 같으므로 캐시 폴백 뒤 keyError로 간다.
class _KeyRejected implements Exception {
  const _KeyRejected();
}
