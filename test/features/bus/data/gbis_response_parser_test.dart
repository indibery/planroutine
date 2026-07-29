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
  group('A정류장 실측 10노선 — 이 교체의 존재 이유', () {
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

      expect(r.items.map((e) => e.arrMin).toList(), [3, 4, 4, 4, 4, 6, 8, 19]);
    });

    test('초를 보존한다 — 같은 행의 분 필드보다 초가 정확하다', () {
      final r = parseGbisArrivals(_fixture('arrivals_jangmi_10routes'));

      // 5623: predictTimeSec1 361 · predictTime1 5 → 초를 쓴다(분 필드는 5라 틀렸다).
      expect(_byRouteNo(r.items, '5623').arrSec, 361);
      // 361초 = 6.02분 → 반올림 6분. 예전 ceil은 7분으로 과대 표시했다.
      expect(_byRouteNo(r.items, '5623').arrMin, 6);
      // 87: predictTimeSec1 234 → 3.9분 → 4분(predictTime1도 4).
      expect(_byRouteNo(r.items, '87').arrSec, 234);
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

      // 실측: B정류장 92·92-1의 TAGO routeid가 `GGB200000025`·`GGB200000029`이고
      // GBIS routeId는 `200000025`·`200000029`다. 접두를 빼고 주면
      // `buildBusCardView`의 `routeIds.contains(a.routeId)`가 영구히 어긋나
      // 노선을 골라둔 사용자에게 `고른 노선은 지금 오지 않아요`만 남는다.
      expect(_byRouteNo(r.items, '92').routeId, 'GGB200000025');
      expect(_byRouteNo(r.items, '92-1').routeId, 'GGB200000029');
    });
  });

  group('B정류장 실측 6노선', () {
    test('6건이 모두 읽히고 빠른 순이다', () {
      final r = parseGbisArrivals(_fixture('arrivals_suwoncityhall_6routes'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.length, 6);
      expect(r.items.map((e) => e.arrMin).toList(), [3, 4, 4, 7, 20, 38]);
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

  group('정류소명 검색 — 도시를 묻지 않는 주 경로', () {
    test('이름만으로 수도권을 한 번에 답한다 — 도시코드가 없다', () {
      // TAGO 검색은 `cityCode`가 필수라 화면이 전국 138개 도시 칩을 먼저 보여줘야
      // 했다. 이 응답 하나가 그 단계를 없앤 근거다.
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(13));
      expect(
        r.items.map((s) => s.regionName).toSet(),
        containsAll({'군포', '인천', '시흥', '의왕'}),
      );
    });

    test('서울 정류소도 나온다 — 서울 API 별도 신청이 필요 없다', () {
      final r = parseGbisStops(_fixture('stations_gangnam_seoul'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(16));
      expect(r.items.map((s) => s.regionName).toSet(), {'서울'});
      expect(r.items.first.nodeNm, contains('강남역'));
    });

    test('nodeId에 GGB 접두를 붙인다 — 조회 경로가 이 접두로 갈린다', () {
      final r = parseGbisStops(_fixture('stations_gangnam_seoul'));

      // 서울 정류소는 대응하는 TAGO nodeId가 없다. 접두의 뜻은 "TAGO ID"가 아니라
      // "GBIS로 조회한다"다.
      expect(r.items.first.nodeId, startsWith('GGB'));
      expect(r.items.every((s) => s.nodeId.length > 3), isTrue);
    });

    test('mobileNo의 앞 공백을 벗겨 정류소번호로 읽는다', () {
      // 실측 `" 26044"`. Dart의 int.tryParse는 공백을 허용하지 않아 trim 없이는
      // 전부 0이 된다 — 같은 이름의 정류장을 구별하는 둘째 단서가 조용히 사라진다.
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));
      final gunpo = r.items.firstWhere((s) => s.regionName == '군포');

      expect(gunpo.nodeNo, 26044);
      expect(r.items.every((s) => s.nodeNo > 0), isTrue);
    });

    test('경기·서울은 GBIS로 가고 도시코드를 쓰지 않는다', () {
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));
      final gyeonggi = r.items.where((s) => s.regionName != '인천');

      expect(gyeonggi.every((s) => s.nodeId.startsWith('GGB')), isTrue);
      expect(gyeonggi.every((s) => s.cityCode == 0), isTrue);
    });

    test('인천은 TAGO로 보낸다 — 커버리지가 7배다', () {
      // 실측 인천 A정류장: TAGO `ICB163000044` 7개 노선
      // (5·5-1·46·516·517·518·519) vs GBIS `163000044` 1개(5).
      // GBIS는 경기 버스가 지나는 인천 정류소만 담고 있다 — 경기와 정반대다.
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));
      final incheon = r.items.where((s) => s.regionName == '인천').toList();

      expect(incheon, isNotEmpty, reason: '픽스처에 인천 정류장이 있어야 이 테스트가 의미를 갖는다');
      expect(incheon.every((s) => s.nodeId.startsWith('ICB')), isTrue);
      // TAGO 조회에는 도시코드가 필요하다 — 0이면 빈 응답이 온다.
      expect(incheon.every((s) => s.cityCode == 23), isTrue);
    });

    test('인천 nodeId는 접두만 다르고 숫자는 GBIS stationId와 같다', () {
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));
      final incheon =
          r.items.firstWhere((s) => s.regionName == '인천' && s.nodeNo == 37044);

      expect(incheon.nodeId, 'ICB163000044');
    });

    test('서울 정류장은 부분 목록임을 스스로 밝힌다', () {
      final r = parseGbisStops(_fixture('stations_gangnam_seoul'));

      expect(r.items.every((s) => s.isSeoul), isTrue);
      // GBIS로 가지만(TAGO에 서울이 없다) 시트가 사용자에게 알린다.
      expect(r.items.every((s) => s.nodeId.startsWith('GGB')), isTrue);
    });

    test('한 응답 안에서 세 라우팅이 지역별로 갈린다', () {
      // 실측 `A정류장` 13건의 지역 분포: 인천 5 · 의왕 2 · 시흥 2 · 서울 2 ·
      // 군포 1 · 수원 1. 한 응답에 세 분기가 다 들어 있다.
      final r = parseGbisStops(_fixture('stations_jangmi_capital'));

      final incheon = r.items.where((s) => s.regionName == '인천');
      final seoul = r.items.where((s) => s.isSeoul);
      final gyeonggi = r.items.where((s) => s.regionName != '인천' && !s.isSeoul);

      expect(incheon, hasLength(5));
      expect(seoul, hasLength(2));
      expect(gyeonggi, hasLength(6));

      // 인천만 TAGO로, 나머지는 GBIS로.
      expect(incheon.every((s) => s.nodeId.startsWith(incheonIdPrefix)), isTrue);
      expect(seoul.every((s) => s.nodeId.startsWith(gbisIdPrefix)), isTrue);
      expect(gyeonggi.every((s) => s.nodeId.startsWith(gbisIdPrefix)), isTrue);

      // 도시코드는 TAGO로 가는 인천에만 필요하다.
      expect(incheon.every((s) => s.cityCode == incheonCityCode), isTrue);
      expect(seoul.every((s) => s.cityCode == 0), isTrue);
      expect(gyeonggi.every((s) => s.cityCode == 0), isTrue);
    });

    test('수도권 밖은 empty다 — TAGO 보조 경로가 필요한 이유', () {
      // 실측 `제주공항` → resultCode 4. `서면`은 부산이 아니라 서울·광명·인천의
      // `강서면허시험장` 등을 주므로 0건이 아니다 — 그래서 지역 전환을 자동 폴백으로
      // 만들 수 없고 사용자가 명시해야 한다.
      final r = parseGbisStops(_fixture('stations_none'));

      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });

    test('껍데기가 깨지면 malformed다', () {
      expect(parseGbisStops(const {'nope': 1}).outcome, TagoOutcome.malformed);
    });
  });

  group('단건 응답 — 배열이 아니라 객체로 온다', () {
    test('도착정보가 객체로 와도 1건으로 읽는다 — closed로 뭉개지지 않는다', () {
      // 실측 서울 강남역10번출구. 예전 파서는 여기서 빈 목록을 돌려 카드가
      // `오늘 운행이 끝났어요`를 띄웠다 — 9711번이 5분 후 오는 중이었다.
      final r = parseGbisArrivals(_fixture('arrivals_single_object_seoul'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(1));
      expect(r.items.single.routeNo, '9711');
      // predictTimeSec1 = 331초 → 올림 6분.
      expect(r.items.single.arrMin, 6);
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
    test('A정류장 실측 10노선이 전부 나온다', () {
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

    test('단건이면 객체로 오는데도 1건으로 읽는다', () {
      // 실측 서울 강남역10번출구: 경유노선이 9711 하나여서 `busRouteList`가 배열이
      // 아니라 **객체**로 왔다. 이 분기가 없으면 노선이 하나뿐인 정류장에서 목록이
      // 통째로 비고 확인 시트가 `오는 버스가 없어요`를 띄운다.
      final r = parseGbisViaRoutes(_fixture('viaroutes_single_object_seoul'));

      expect(r.outcome, TagoOutcome.ok);
      expect(r.items, hasLength(1));
      expect(r.items.single.routeNo, '9711');
      expect(r.items.single.destName, '매헌시민의숲.양재꽃시장');
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
