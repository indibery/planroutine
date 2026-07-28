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

/// 빌드 시 주입되는 인증키. 소스와 git 히스토리에 남지 않는다.
///
/// `--dart-define=TAGO_KEY=...`로 넣는다(`main.dart`의 `SCREENSHOT_MODE`와 같은
/// 패턴). 난독화가 아니라 **히스토리에 남지 않는 것**이 실질 이득이다 — 키는
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
          return _fallback(cached, BusCardState.keyError);
      }
    } on _KeyRejected {
      return _fallback(cached, BusCardState.keyError);
    } catch (_) {
      // 네트워크·타임아웃·JSON 파손. 캐시가 있으면 옛 목록을 보여주고 갱신
      // 실패를 고백한다 — 실시간인 척하면 버스를 놓친 사용자가 앱을 불신한다.
      return _fallback(cached, BusCardState.down);
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

  BusFetch _fallback(_CacheEntry? cached, BusCardState failure) {
    if (cached == null || cached.arrivals.isEmpty) {
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
