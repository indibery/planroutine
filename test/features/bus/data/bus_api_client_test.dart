import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';

/// 실제 구조: `body.items`는 `{'item': ...}` 형태의 Map이거나, 데이터가 없을 때
/// 빈 문자열 `''`이다(Phase 0 실측). `''`를 줄 때만 래퍼를 씌우지 않는다.
String _body(Object? inner, {String code = '00'}) => jsonEncode({
      'response': {
        'header': {'resultCode': code, 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'items': inner == '' ? '' : {'item': inner},
          'numOfRows': 30,
          'pageNo': 1,
        },
      },
    });

Map<String, dynamic> _arr(Object routeno, String routeid, int arrtime) => {
      'arrprevstationcnt': 3,
      'arrtime': arrtime,
      'nodeid': 'GGB201000156',
      'nodenm': '수원시청',
      'routeid': routeid,
      'routeno': routeno,
      'vehicletp': '일반버스',
    };

/// TAGO는 UTF-8 JSON을 준다. content-type을 빼면 package:http가 latin1로
/// 인코딩해 픽스처의 한글(`수원시청`)에서 터진다 — 구현이 아니라 픽스처의 함정이다.
http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// GBIS 실측 응답 파일. **테스트는 실제 네트워크를 부르지 않는다** — GBIS 개발계정의
/// 일일 트래픽이 1,000이다(TAGO는 10,000).
String _gbisFixture(String name) =>
    File('test/fixtures/gbis/$name.json').readAsStringSync();

void main() {
  var now = DateTime(2026, 7, 28, 7, 32);

  BusApiClient clientWith(
    Future<http.Response> Function(http.Request) handler, {
    String key = 'TESTKEY',
  }) {
    return BusApiClient(
      client: MockClient((req) => handler(req)),
      serviceKey: key,
      clock: () => now,
    );
  }

  setUp(() => now = DateTime(2026, 7, 28, 7, 32));

  group('정상 조회', () {
    // 정류장은 **비경기**(부산 `BSB…`)로 둔다 — 경기 정류장(`GGB…`)은 GBIS로 갈리므로
    // 이 단정(`nodeId`·`_type` 쿼리)은 TAGO 경로에서만 성립한다. 갈림 자체는 아래
    // `정류소 ID 접두로 소스가 갈린다` 그룹이 지킨다.
    test('https로 가고 키가 쿼리에 실린다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return _json(_body([_arr(92, 'A', 600)]));
      });
      final r = await c.fetchArrivals(cityCode: 21, nodeId: 'BSB223000123');

      expect(r.state, BusCardState.ok);
      expect(r.arrivals.single.routeNo, '92');
      expect(seen?.scheme, 'https');
      expect(seen?.host, 'apis.data.go.kr');
      expect(seen?.queryParameters['serviceKey'], 'TESTKEY');
      expect(seen?.queryParameters['nodeId'], 'BSB223000123');
      expect(seen?.queryParameters['_type'], 'json');
    });

    test('fetchedAt은 조회 시각이다', () async {
      final c = clientWith((_) async => _json(_body([_arr(1, 'A', 60)])));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.fetchedAt, DateTime(2026, 7, 28, 7, 32));
    });
  });

  group('정류소 ID 접두로 소스가 갈린다', () {
    test('GGB… 는 GBIS로 간다 — stationId는 접두를 뗀 값이다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return _json(_gbisFixture('arrivals_jangmi_10routes'));
      });
      // 군포 장미아파트. 실기기에서 2개만 보였던 그 정류장이다.
      final r = await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB225000100');

      expect(seen?.scheme, 'https');
      expect(seen?.host, 'apis.data.go.kr');
      expect(seen?.path, '/6410000/busarrivalservice/v2/getBusArrivalListv2');
      expect(seen?.queryParameters['stationId'], '225000100');
      expect(seen?.queryParameters['format'], 'json');
      expect(seen?.queryParameters['serviceKey'], 'TESTKEY');
      // cityCode는 GBIS 쿼리에 실리지 않는다 — 부분집합만 보이던 원인이었다.
      expect(seen?.queryParameters.containsKey('cityCode'), isFalse);

      expect(r.state, BusCardState.ok);
      expect(r.arrivals.length, 8);
      expect(r.arrivals.map((a) => a.routeNo), containsAll({'5623', '541'}));
    });

    test('BSB… 는 TAGO로 간다 — 비경기 동작이 그대로다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return _json(_body([_arr(1001, 'A', 300)]));
      });
      final r = await c.fetchArrivals(cityCode: 21, nodeId: 'BSB223000123');

      expect(seen?.path,
          '/1613000/ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList');
      expect(seen?.queryParameters['cityCode'], '21');
      expect(seen?.queryParameters['nodeId'], 'BSB223000123');
      expect(r.state, BusCardState.ok);
      expect(r.arrivals.single.arrMin, 5);
    });

    test('GBIS 응답도 캐시된다 — 접두가 갈림만 바꾼다', () async {
      final c = clientWith(
        (_) async => _json(_gbisFixture('arrivals_jangmi_10routes')),
      );
      await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB225000100');
      await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB225000100');
      expect(c.requestCount, 1);
    });
  });

  group('GBIS 실패 계약', () {
    test('없는 정류소(resultCode 4)면 closed다', () async {
      final c = clientWith(
        (_) async => _json(_gbisFixture('arrivals_unknown_station')),
      );
      final r = await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB999999999');
      expect(r.state, BusCardState.closed);
      expect(r.arrivals, isEmpty);
    });

    test('HTTP 403이면 keyError다 — 활용신청 미승인이 이 형태다', () async {
      final c = clientWith((_) async => _json('Forbidden', 403));
      final r = await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB225000100');
      expect(r.state, BusCardState.keyError);
    });

    test('TAGO 껍데기가 오면 keyError다 — 조용히 빈 목록이 되지 않는다', () async {
      final c = clientWith((_) async => _json(_body([_arr(92, 'A', 600)])));
      final r = await c.fetchArrivals(cityCode: 31160, nodeId: 'GGB225000100');
      expect(r.state, BusCardState.keyError);
    });
  });

  group('메모리 캐시 — TTL 30초', () {
    test('같은 정류장을 연달아 조회하면 요청이 1회다', () async {
      final c = clientWith((_) async => _json(_body([_arr(1, 'A', 60)])));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 1);
    });

    test('31초 뒤에는 다시 요청한다', () async {
      final c = clientWith((_) async => _json(_body([_arr(1, 'A', 60)])));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      now = now.add(const Duration(seconds: 31));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 2);
    });

    test('다른 정류장은 별 캐시다', () async {
      final c = clientWith((_) async => _json(_body([_arr(1, 'A', 60)])));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N1');
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N2');
      expect(c.requestCount, 2);
    });

    test('invalidate 후에는 다시 요청한다 — 슬롯 교체 경로', () async {
      final c = clientWith((_) async => _json(_body([_arr(1, 'A', 60)])));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      c.invalidate();
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(c.requestCount, 2);
    });
  });

  group('실패 계약', () {
    test('items가 빈 문자열이면 closed', () async {
      final c = clientWith((_) async => _json(_body('')));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.closed);
    });

    test('예외 + 캐시 없음이면 down', () async {
      final c = clientWith((_) async => throw const _Boom());
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.down);
      expect(r.arrivals, isEmpty);
    });

    test('예외 + 캐시 있음이면 stale — 옛 목록과 옛 시각을 준다', () async {
      var fail = false;
      final c = clientWith((_) async {
        if (fail) throw const _Boom();
        return _json(_body([_arr(1, 'A', 240)]));
      });
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      fail = true;
      now = now.add(const Duration(seconds: 31));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      expect(r.state, BusCardState.stale);
      expect(r.arrivals.single.arrMin, 4);
      expect(r.fetchedAt, DateTime(2026, 7, 28, 7, 32));
    });

    test('상한을 넘게 묵은 캐시는 stale로도 쓰지 않는다 — down + 기준시각 없음', () async {
      // 위의 31초 테스트는 arrMin 4가 4로 나오는 무해한 구간만 본다. 나이 상한이
      // 없으면 38분 묵은 목록이 계속 stale로 나가고 경과 보정이 arrMin을 전부 0으로
      // 깎아 **이미 지나간 버스가 `곧 도착`으로** 뜬다.
      var fail = false;
      final c = clientWith((_) async {
        if (fail) throw const _Boom();
        return _json(_body([_arr(1, 'A', 240)]));
      });
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      fail = true;
      now = now.add(const Duration(minutes: 40));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      expect(r.state, BusCardState.down);
      expect(r.arrivals, isEmpty);
      expect(r.fetchedAt, isNull, reason: '기준시각이 남으면 화면이 옛 목록을 그린다');
    });

    test('상한을 넘긴 캐시는 버려진다 — 통신이 돌아와도 되살아나지 않는다', () async {
      var fail = false;
      final c = clientWith((_) async {
        if (fail) throw const _Boom();
        return _json(_body([_arr(1, 'A', 240)]));
      });
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      fail = true;
      now = now.add(const Duration(minutes: 40));
      await c.fetchArrivals(cityCode: 31010, nodeId: 'N');

      // 상한 판정 직후 다시 실패해도 옛 목록이 남아 있지 않아야 한다.
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.down);
      expect(r.arrivals, isEmpty);
    });

    test('HTTP 401이면 keyError', () async {
      final c = clientWith((_) async => _json('Unauthorized', 401));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
    });

    test('resultCode가 00이 아니면 keyError', () async {
      final c = clientWith((_) async => _json(_body('', code: '30')));
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
    });
  });

  group('키가 없으면 요청조차 하지 않는다', () {
    test('빈 키면 keyError이고 requestCount는 0이다', () async {
      final c = clientWith(
        (_) async => _json(_body([_arr(1, 'A', 60)])),
        key: '',
      );
      final r = await c.fetchArrivals(cityCode: 31010, nodeId: 'N');
      expect(r.state, BusCardState.keyError);
      expect(c.requestCount, 0);
      expect(c.hasKey, isFalse);
    });
  });

  group('검색', () {
    test('searchStops는 이름을 인코딩해 넘긴다', () async {
      Uri? seen;
      final c = clientWith((req) async {
        seen = req.url;
        return _json(
          _body({'nodeid': 'N1', 'nodenm': '수원시청', 'nodeno': 2251}),
        );
      });
      final r = await c.searchStops(cityCode: 31010, name: '시청');
      expect(r.items.single.nodeNo, 2251);
      expect(seen?.queryParameters['nodeNm'], '시청');
    });

    test('fetchCities는 도시코드를 int로 읽는다', () async {
      final c = clientWith((_) async => _json(
            _body([{'citycode': 31010, 'cityname': '수원시'}]),
          ));
      final r = await c.fetchCities();
      expect(r.items.single.code, 31010);
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
