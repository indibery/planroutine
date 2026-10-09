import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';

void main() {
  group('BusStop 직렬화', () {
    test('정류소번호는 문자열이라 앞자리 0을 지킨다', () {
      // 숫자로 두던 판본은 `02004`(서울역버스환승센터)를 `2004`로 저장하고 보였다.
      const stop = BusStop(
        nodeId: 'GGB101000004',
        nodeNm: '서울역버스환승센터',
        nodeNo: '02004',
        cityCode: 0,
      );
      expect(stop.toJson()['nodeNo'], '02004');
      expect(BusStop.fromJson(stop.toJson()).nodeNo, '02004');
    });

    test('옛 저장값(숫자)의 수도권 번호는 다섯 자리로 0을 되살린다', () {
      // GBIS 정류소번호는 실측 응답에서 모두 다섯 자리다(`" 02897"`·`" 22173"`).
      final back = BusStop.fromJson({
        'nodeId': 'GGB101000004',
        'nodeNm': '서울역버스환승센터',
        'nodeNo': 2004,
        'cityCode': 0,
      });
      expect(back.nodeNo, '02004');
    });

    test('수도권 밖(TAGO) 옛 숫자는 자릿수 규칙을 몰라 그대로 둔다', () {
      final back = BusStop.fromJson({
        'nodeId': 'BSB164270201',
        'nodeNm': '서면',
        'nodeNo': 2004,
        'cityCode': 21,
      });
      expect(back.nodeNo, '2004');
    });

    test('번호가 없던 옛 값(0)은 빈 문자열이다', () {
      final back = BusStop.fromJson({
        'nodeId': 'GGB101000004',
        'nodeNm': 'X',
        'nodeNo': 0,
        'cityCode': 0,
      });
      expect(back.nodeNo, '');
    });

    test('routeIds가 비어 있으면 왕복해도 비어 있다 — 필터 없음을 뜻한다', () {
      const stop = BusStop(
        nodeId: 'GGB201000156',
        nodeNm: 'B정류장(길 양쪽)',
        nodeNo: '2251',
        cityCode: 31010,
      );
      final back = BusStop.fromJson(stop.toJson());
      expect(back.routeIds, isEmpty);
      expect(back.nodeId, 'GGB201000156');
      expect(back.nodeNo, '2251');
      expect(back.cityCode, 31010);
    });

    test('골라둔 routeIds는 그대로 살아 돌아온다', () {
      const stop = BusStop(
        nodeId: 'GGB201000156',
        nodeNm: 'B정류장',
        nodeNo: '2251',
        cityCode: 31010,
        routeIds: {'GGB200000025', 'GGB200000029'},
      );
      final back = BusStop.fromJson(stop.toJson());
      expect(back.routeIds, {'GGB200000025', 'GGB200000029'});
    });

    test('routeIds 키가 없는 옛 값도 빈 집합으로 읽힌다', () {
      final back = BusStop.fromJson({
        'nodeId': 'GGB201000156',
        'nodeNm': 'B정류장',
        'nodeNo': 2251,
        'cityCode': 31010,
      });
      expect(back.routeIds, isEmpty);
    });
  });

  group('BusStop.regionName — 도시 선택을 없앤 대가로 필요해진 필드', () {
    test('왕복해도 지역명이 남는다', () {
      const stop = BusStop(
        nodeId: 'GGB225000100',
        nodeNm: 'A정류장',
        nodeNo: '26044',
        cityCode: 0,
        regionName: '군포',
      );

      expect(BusStop.fromJson(stop.toJson()).regionName, '군포');
    });

    test('지역명이 없으면 키를 넣지 않는다 — TAGO 경로의 저장 모양을 바꾸지 않는다', () {
      const stop = BusStop(
        nodeId: 'BSB223000123',
        nodeNm: '서면',
        nodeNo: '1234',
        cityCode: 21,
      );

      expect(stop.toJson().containsKey('regionName'), isFalse);
    });

    test('옛 저장 데이터(지역명 없음)도 그대로 읽힌다 — 마이그레이션이 없다', () {
      final stop = BusStop.fromJson(const {
        'nodeId': 'GGB201000156',
        'nodeNm': 'B정류장(길 양쪽)',
        'nodeNo': 2251,
        'cityCode': 31010,
        'routeIds': <String>[],
      });

      expect(stop.regionName, isNull);
      expect(stop.nodeNm, 'B정류장(길 양쪽)');
    });

    test('copyWith가 지역명을 잃지 않는다', () {
      // 확인 시트가 `copyWith(routeIds:)`로 노선만 갈아끼운다. 여기서 지역명이
      // 떨어지면 저장된 정류장의 지역 표시가 등록 직후 사라진다.
      const stop = BusStop(
        nodeId: 'GGB225000100',
        nodeNm: 'A정류장',
        nodeNo: '26044',
        cityCode: 0,
        regionName: '군포',
      );

      expect(stop.copyWith(routeIds: {'GGB1'}).regionName, '군포');
    });
  });

  group('CommuteDirection', () {
    test('flipped는 서로를 가리킨다', () {
      expect(CommuteDirection.toWork.flipped, CommuteDirection.toHome);
      expect(CommuteDirection.toHome.flipped, CommuteDirection.toWork);
    });

    test('otherLabel은 반대 방향을 보라고 말한다', () {
      expect(CommuteDirection.toWork.otherLabel, '퇴근 보기');
      expect(CommuteDirection.toHome.otherLabel, '출근 보기');
    });
  });

  // `BusCardStyle` 그룹은 없다 — `usesSignalColors`를 되읽는 항진 단정이었고
  // (선언부 리터럴을 그대로 비교해 화면을 하나도 지키지 못했다) 필드와 함께 지웠다.
  // 기본 모양이 신호색을 쓰지 않는다는 사실은 `bus_body_test.dart`의 소스 가드가
  // 지킨다.
}
