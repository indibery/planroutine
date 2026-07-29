import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/data/gbis_response_parser.dart';
import 'package:planroutine/features/bus/data/tago_response_parser.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';

/// 실측 응답 파일을 그대로 읽는다. **응답 JSON을 손으로 적지 않는다** —
/// `int`/`''`(빈 문자열)/키 없음이 같은 필드에 섞이는 형태는 사람이 재현하지 못하고,
/// 이 작업에서 손으로 쓴 픽스처가 현실과 달라 세 번 어긋났다.
Map<String, dynamic> _fixture(String name) => jsonDecode(
      File('test/fixtures/gbis/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// 픽스처의 원본 행 목록. 실측 값을 한 곳만 비틀어 보는 테스트가 쓴다.
List<Map<String, dynamic>> _rows(Map<String, dynamic> json) {
  final body = (json['response'] as Map)['msgBody'] as Map;
  return (body['busArrivalList'] as List)
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList();
}

/// `routeName`으로 행을 찾는다 — 인덱스로 찾으면 픽스처 순서에 묶인다.
Map<String, dynamic> _rowOf(Map<String, dynamic> json, String routeName) =>
    _rows(json).firstWhere((r) => r['routeName'].toString() == routeName);

Set<String> _routeNos(List<BusArrival> items) =>
    items.map((e) => e.routeNo).toSet();

BusArrival _byRouteNo(List<BusArrival> items, String routeNo) =>
    items.firstWhere((e) => e.routeNo == routeNo);

void main() {
  group('장미아파트 실측 10노선 — 이 교체의 존재 이유', () {
    test('서울 노선이 목록에 들어온다 — TAGO로는 영구히 조회 불가였다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      expect(r.outcome, TagoOutcome.ok);
      // TAGO 도시목록 138개에 서울이 없어 이 둘은 어떤 cityCode로도 나오지 않았다.
      expect(_routeNos(r.items), containsAll({'5623', '541'}));
    });

    test('도착 정보가 없는 2노선을 뺀 8건이 나온다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      expect(r.items.length, 8, reason: '10행 중 정보없음 2행이 빠진다');
      // 정보없음 행(`predictTime1: ""` + `predictTimeSec1` 없음)의 노선번호다.
      // 0분(곧 도착)으로 뭉개면 이 둘이 목록 맨 위에 올라온다.
      expect(_routeNos(r.items), isNot(contains('9')));
      expect(_routeNos(r.items), isNot(contains('3030')));
    });

    test('routeName이 int인 행과 String인 행이 모두 읽힌다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      // `5623`·`15`는 int, `'11-5'`는 String으로 **한 응답에** 섞여 온다.
      expect(_routeNos(r.items), containsAll({'5623', '15', '11-5'}));
    });

    test('빠른 순으로 정렬된다 — 응답 순서는 도착 순서가 아니다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      expect(r.items.map((e) => e.arrMin).toList(), [4, 4, 4, 5, 5, 7, 9, 20]);
    });

    test('초를 올림해 분을 만든다 — 같은 행의 분 필드보다 초가 정확하다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      // 5623: predictTimeSec1 361(=6.02분) · predictTime1 5 → 초 기준 올림 7분.
      expect(_byRouteNo(r.items, '5623').arrMin, 7);
      // 87: predictTimeSec1 234 → 4분(predictTime1도 4).
      expect(_byRouteNo(r.items, '87').arrMin, 4);
    });

    test('lowPlate1로 저상 여부를 읽는다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      expect(_byRouteNo(r.items, '5623').lowFloor, isTrue);
      expect(_byRouteNo(r.items, '6501').lowFloor, isFalse);
    });
  });

  group('노선 ID — 저장된 노선 필터와 계속 맞물려야 한다', () {
    test('GGB 접두를 되붙인다 — TAGO 형식과 같은 문자열이 된다', () {
      final r = parseGbisArrivals(_fixture('arrivals_suwoncityhall_6routes'));

      // 실측: 수원시청 92·92-1의 TAGO routeid가 `GGB200000025`·`GGB200000029`이고
      // GBIS routeId는 `200000025`·`200000029`다. 접두를 빼고 주면
      // `buildBusCardView`의 `routeIds.contains(a.routeId)`가 영구히 어긋나
      // 노선을 골라둔 사용자에게 `고른 노선은 지금 오지 않아요`만 남는다.
      expect(_byRouteNo(r.items, '92').routeId, 'GGB200000025');
      expect(_byRouteNo(r.items, '92-1').routeId, 'GGB200000029');
    });
  });

  group('수원시청 실측 6노선', () {
    test('6건이 모두 읽히고 빠른 순이다', () {
      final r = parseGbisArrivals(_fixture('arrivals_suwoncityhall_6routes'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.length, 6);
      expect(r.items.map((e) => e.arrMin).toList(), [3, 4, 4, 7, 21, 38]);
      expect(_routeNos(r.items), containsAll({'92-1', '82-1', '201'}));
    });
  });

  group('실패 계약', () {
    test('없는 정류소 — msgBody 키가 아예 없고 resultCode 4다 → empty', () {
      final json = _fixture('arrivals_unknown_station');

      // 예외로 새면 클라이언트가 `down`(갱신 실패)으로 읽어 실제 사실(도착 정보
      // 없음)과 다른 말을 한다.
      final r = parseGbisArrivals(json);
      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });

    test('모르는 resultCode는 malformed다', () {
      final json = _fixture('arrivals_jangmi_10routes');
      ((json['response'] as Map)['msgHeader'] as Map)['resultCode'] = 8;

      expect(parseGbisArrivals(json).outcome, TagoOutcome.malformed);
    });

    test('껍데기가 다르면 malformed다', () {
      expect(parseGbisArrivals(const {'oops': 1}).outcome,
          TagoOutcome.malformed);
      // TAGO 껍데기(`response.header`/`response.body`)를 GBIS 파서에 주는 실수는
      // 조용히 빈 목록이 되면 안 된다.
      expect(
        parseGbisArrivals(const {
          'response': {'header': {'resultCode': '00'}, 'body': {'items': ''}},
        }).outcome,
        TagoOutcome.malformed,
      );
    });

    test('정보없음만 온 응답은 empty다 — ok + 빈 목록이 되면 안 된다', () {
      final json = _fixture('arrivals_jangmi_10routes');
      final body = (json['response'] as Map)['msgBody'] as Map;
      // 실측 정보없음 행(routeName 9)만 남긴다.
      body['busArrivalList'] = [_rowOf(json, '9')];

      final r = parseGbisArrivals(json);
      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });
  });

  group('타입 혼재 — 초가 빠진 행', () {
    test('predictTimeSec1이 없으면 predictTime1(분)으로 읽는다', () {
      final json = _fixture('arrivals_jangmi_10routes');
      // 실측 행에서 초만 떼어낸다(분은 5). 초를 지웠다고 노선이 사라지면
      // 이번 버그와 같은 종류의 조용한 누락이 된다.
      _rowOf(json, '5623').remove('predictTimeSec1');

      final r = parseGbisArrivals(json);
      expect(r.items.length, 8);
      expect(_byRouteNo(r.items, '5623').arrMin, 5);
    });
  });

  group('경유노선 목록 — 확인 시트의 선택 목록이 여기서 나온다', () {
    test('장미아파트 실측 10노선이 전부 나온다', () {
      // 같은 정류장·같은 시각에 도착정보로는 8노선이었다(위 그룹). 등록하는 시각이
      // 고를 수 있는 노선을 결정하던 것이 실기기 버그의 원인이다.
      final r = parseGbisViaRoutes(_fixture('viaroutes_jangmi_10routes'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(10));
      expect(
        r.items.map((e) => e.routeNo).toSet(),
        {'3030', '6501', '11-5', '15', '541', '5623', '87', '917', '6', '9'},
      );
    });

    test('routeId에 GGB 접두를 되붙인다 — 도착정보 파서와 같은 규칙', () {
      final r = parseGbisViaRoutes(_fixture('viaroutes_jangmi_10routes'));

      // 실측 GBIS routeId 208000027(3030번). 접두를 빼면 사용자가 고른 노선이
      // 카드에서 전부 걸러진다(`routeIds.contains(a.routeId)`가 문자열 비교다).
      expect(
        r.items.firstWhere((e) => e.routeNo == '3030').routeId,
        'GGB208000027',
      );
    });

    test('행선지가 들어온다 — 길 양쪽 정류장을 가르는 단서', () {
      final r = parseGbisViaRoutes(_fixture('viaroutes_jangmi_10routes'));

      expect(
        r.items.firstWhere((e) => e.routeNo == '3030').destName,
        '신사역(중)',
      );
      expect(
        r.items.firstWhere((e) => e.routeNo == '5623').destName,
        '여의도환승센터(1번승강장)',
      );
    });

    test('routeName이 int로 와도 문자열이 된다', () {
      // 실측: `9`·`5623`은 int, `'11-5'`는 String으로 **한 응답에 섞여** 온다.
      final r = parseGbisViaRoutes(_fixture('viaroutes_jangmi_10routes'));

      expect(r.items.map((e) => e.routeNo), everyElement(isA<String>()));
      expect(r.items.map((e) => e.routeNo), contains('9'));
    });

    test('수원 실측 5노선도 그대로 나온다', () {
      final r = parseGbisViaRoutes(_fixture('viaroutes_suwon_5routes'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(5));
    });

    test('없는 정류소는 empty다 — msgBody 키 자체가 없다', () {
      final r = parseGbisViaRoutes(_fixture('viaroutes_unknown_station'));

      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });

    test('껍데기가 깨지면 malformed다', () {
      expect(parseGbisViaRoutes(const {'oops': 1}).outcome,
          TagoOutcome.malformed);
      expect(
        parseGbisViaRoutes(const {
          'response': {
            'msgHeader': {'resultCode': 99},
          },
        }).outcome,
        TagoOutcome.malformed,
      );
    });

    test('정렬하지 않는다 — 표시 순서는 buildRouteChoices가 정한다', () {
      // 카드는 빠른 순, 시트는 번호순이다. 파서가 한쪽 순서로 고정하면 다른 쪽이
      // 그것을 다시 뒤집어야 한다.
      final json = _fixture('viaroutes_jangmi_10routes');
      final rows = ((json['response'] as Map)['msgBody'] as Map)['busRouteList']
          as List;
      final apiOrder =
          rows.map((r) => (r as Map)['routeName'].toString()).toList();

      final r = parseGbisViaRoutes(json);
      expect(r.items.map((e) => e.routeNo), apiOrder);
    });
  });
}
