import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/data/tago_response_parser.dart';

/// TAGO 응답 껍데기 — resultCode는 데이터가 없어도 "00"이다(실측).
///
/// 실제 구조: `body.items`는 `{'item': ...}` 형태의 Map이거나, 데이터가 없을 때
/// 빈 문자열 `''`이다. [inner]에 Map(단건)이나 List(복수)를 주면 `item` 래퍼를
/// 씌우고, `''`를 주면 그대로 둔다.
Map<String, dynamic> _envelope(Object? inner, {String code = '00'}) => {
      'response': {
        'header': {'resultCode': code, 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'items': inner == '' ? '' : {'item': inner},
          'numOfRows': 30,
          'pageNo': 1,
        },
      },
    };

Map<String, dynamic> _arr(Object routeno, String routeid, int arrtime) => {
      'arrprevstationcnt': 7,
      'arrtime': arrtime,
      'nodeid': 'GGB201000156',
      'nodenm': '수원시청.수원일자리센터',
      'routeid': routeid,
      'routeno': routeno,
      'routetp': '일반버스',
      'vehicletp': '저상버스',
    };

void main() {
  group('items의 세 형태', () {
    test('List — 복수 응답', () {
      final r = parseArrivals(_envelope([_arr(92, 'A', 600), _arr('92-1', 'B', 120)]));
      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.length, 2);
    });

    test('Map — 단건 응답이 객체로 온다', () {
      final r = parseArrivals(_envelope(_arr(92, 'A', 600)));
      expect(r.outcome, TagoOutcome.ok);
      expect(r.items.single.routeNo, '92');
    });

    test('빈 문자열 — 데이터 없음. resultCode는 여전히 00이다', () {
      final r = parseArrivals(_envelope(''));
      expect(r.outcome, TagoOutcome.empty);
      expect(r.items, isEmpty);
    });
  });

  group('routeno 타입 혼재 — as String 캐스트는 크래시한다', () {
    test('int와 String이 같은 응답에 섞여도 둘 다 문자열로 나온다', () {
      final r = parseArrivals(_envelope([
        _arr(92, 'A', 600),
        _arr('92-1', 'B', 120),
        _arr(61, 'C', 1860),
      ]));
      expect(r.items.map((e) => e.routeNo).toSet(), {'92', '92-1', '61'});
    });
  });

  group('노선 축약 — routeid별 arrtime 최소만 남긴다', () {
    test('같은 노선 2건이면 빠른 쪽만 남는다', () {
      final r = parseArrivals(_envelope([
        _arr(92, 'A', 1500),
        _arr(92, 'A', 600),
      ]));
      expect(r.items.length, 1);
      expect(r.items.single.arrMin, 10);
    });

    test('실측 형태 — 5노선 10항목이 5건으로 줄고 빠른 순으로 정렬된다', () {
      final r = parseArrivals(_envelope([
        _arr('82-1', 'R1', 480), _arr('82-1', 'R1', 2040),
        _arr(92, 'R2', 600), _arr(92, 'R2', 1500),
        _arr('92-1', 'R3', 600), _arr('92-1', 'R3', 720),
        _arr(81, 'R4', 780), _arr(81, 'R4', 2160),
        _arr(61, 'R5', 1860), _arr(61, 'R5', 2880),
      ]));
      expect(r.items.length, 5);
      expect(r.items.map((e) => e.routeNo).toList(),
          ['82-1', '92', '92-1', '81', '61']);
    });
  });

  group('arrMin 변환', () {
    test('초를 올림해 분으로 만든다', () {
      expect(parseArrivals(_envelope(_arr(1, 'A', 551))).items.single.arrMin, 10);
      expect(parseArrivals(_envelope(_arr(1, 'A', 61))).items.single.arrMin, 2);
    });

    test('0초는 0분(곧 도착)이다', () {
      expect(parseArrivals(_envelope(_arr(1, 'A', 0))).items.single.arrMin, 0);
    });
  });

  test('vehicletp가 저상버스면 lowFloor', () {
    final r = parseArrivals(_envelope(_arr(1, 'A', 600)));
    expect(r.items.single.lowFloor, isTrue);
  });

  group('오류 판정', () {
    test('resultCode가 00이 아니면 keyError', () {
      final r = parseArrivals(_envelope('', code: '30'));
      expect(r.outcome, TagoOutcome.keyError);
    });

    test('껍데기가 다르면 malformed', () {
      expect(parseArrivals(const {'oops': 1}).outcome, TagoOutcome.malformed);
    });
  });

  group('parseStops', () {
    test('정류장 필드를 읽고 cityCode를 채운다', () {
      final r = parseStops(
        _envelope({
          'gpslati': 37.2622667,
          'gpslong': 127.0283833,
          'nodeid': 'GGB201000156',
          'nodenm': '수원시청.수원일자리센터',
          'nodeno': 2251,
        }),
        cityCode: 31010,
      );
      expect(r.items.single.nodeNo, 2251);
      expect(r.items.single.cityCode, 31010);
      expect(r.items.single.routeIds, isEmpty);
    });
  });

  group('parseCities', () {
    test('citycode가 int로 온다', () {
      final r = parseCities(_envelope([
        {'citycode': 31010, 'cityname': '수원시'},
        {'citycode': 31020, 'cityname': '성남시'},
      ]));
      expect(r.items.first.code, 31010);
      expect(r.items.first.name, '수원시');
    });
  });
}
