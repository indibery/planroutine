import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/bus_arrival.dart';
import '../domain/bus_card_view.dart';
import '../domain/bus_stop.dart';
import 'tago_response_parser.dart';

/// TAGO 국토교통부 서비스 묶음.
///
/// **https다.** 실측으로 TLSv1.3 + GlobalSign 인증서를 확인했으므로 `Info.plist`에
/// ATS 예외를 넣지 않는다.
const tagoBaseUrl = 'https://apis.data.go.kr/1613000';

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
      final json = await _get(
        'ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList',
        {'cityCode': '$cityCode', 'nodeId': nodeId, 'numOfRows': '30'},
      );
      final result = parseArrivals(json);

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

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$tagoBaseUrl/$path').replace(queryParameters: {
      'serviceKey': _serviceKey,
      '_type': 'json',
      'pageNo': '1',
      ...query,
    });

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
