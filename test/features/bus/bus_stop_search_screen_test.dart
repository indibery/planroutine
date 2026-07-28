import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/screens/bus_stop_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면(`_loadCities`·`_search`·`_pick`·`_chipCities`·`?slot=`)을 밟는 테스트다.
/// 확인 시트만 다루는 것은 `bus_stop_search_test.dart`에 있다.

const _suwon = 31010;
const _seongnam = 31020;
const _hwaseong = 41590;

/// 저장된 정류장. 도시 복원 경로가 **어느 슬롯의** 도시를 쓰는지 보려면 두 슬롯의
/// 도시코드가 달라야 한다.
const _savedSuwon = BusStop(
  nodeId: 'N2251',
  nodeNm: '수원시청.수원일자리센터',
  nodeNo: 2251,
  cityCode: _suwon,
);

/// TAGO는 UTF-8 JSON을 준다. **content-type을 빼면 안 된다** — package:http가
/// 헤더가 없으면 latin1로 떨어져 픽스처의 한글에서 터진다(구현이 아니라 픽스처의
/// 함정이다). `bus_api_client_test.dart`의 `_json`과 같은 이유·같은 모양이다.
http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 실측 껍데기. 데이터가 없을 때 `items`는 **빈 문자열**로 온다.
String _body(Object? inner) => jsonEncode({
      'response': {
        'header': {'resultCode': '00', 'resultMsg': 'NORMAL SERVICE.'},
        'body': {
          'items': inner == '' ? '' : {'item': inner},
          'numOfRows': 50,
          'pageNo': 1,
        },
      },
    });

/// TAGO 세 엔드포인트를 URL로 갈라 응답한다 — 화면이 도시 목록·정류장 검색·도착
/// 조회를 **각각** 언제 부르는지 세려면 한 핸들러가 셋을 구별해야 한다.
class _Tago {
  /// 도시코드 → 이름.
  Map<int, String> cities = const {
    _suwon: '수원시',
    _seongnam: '성남시',
    _hwaseong: '화성시',
  };

  /// 도시코드 → (정류장 이름 → 정류소번호). 등록되지 않은 도시는 빈 응답이다.
  Map<int, Map<String, int>> stops = const {
    _suwon: {'수원시청.수원일자리센터': 2251},
    _seongnam: {'성남시청': 3301},
    _hwaseong: {'화성시청': 4401},
  };

  /// 켜면 그 엔드포인트가 500을 준다 — 클라이언트는 `malformed`로 읽는다.
  bool cityFails = false;
  bool stopFails = false;

  int cityCalls = 0;
  int stopCalls = 0;
  int arrivalCalls = 0;

  Future<http.Response> handle(http.Request req) async {
    final url = req.url;

    if (url.path.endsWith('getCtyCodeList')) {
      cityCalls++;
      if (cityFails) return _json('boom', 500);
      return _json(_body(cities.entries
          .map((e) => {'citycode': e.key, 'cityname': e.value})
          .toList()));
    }

    if (url.path.endsWith('getSttnNoList')) {
      stopCalls++;
      if (stopFails) return _json('boom', 500);
      final code = int.tryParse(url.queryParameters['cityCode'] ?? '') ?? 0;
      final name = url.queryParameters['nodeNm'] ?? '';
      final rows = (stops[code] ?? const {})
          .entries
          .where((e) => e.key.contains(name))
          .map((e) => {
                'nodeid': 'N${e.value}',
                'nodenm': e.key,
                'nodeno': e.value,
              })
          .toList();
      return _json(_body(rows.isEmpty ? '' : rows));
    }

    arrivalCalls++;
    return _json(_body([
      {
        'arrprevstationcnt': 3,
        'arrtime': 480,
        'nodeid': 'N',
        'nodenm': '정류장',
        'routeid': 'R1',
        'routeno': 720,
        'vehicletp': '일반버스',
      }
    ]));
  }
}

ProviderContainer _container(_Tago tago, BusSettings settings) {
  SharedPreferences.setMockInitialValues({
    'bus_settings_v1': jsonEncode(settings.toJson()),
  });
  final container = ProviderContainer(overrides: [
    busApiClientProvider.overrideWithValue(BusApiClient(
      client: MockClient(tago.handle),
      serviceKey: 'TESTKEY',
    )),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// 화면만 띄운다. **설정을 먼저 해석해 둔다** — 해석 전이면 `valueOrNull`이 null이라
/// 도시 복원 경로가 통째로 무검증이 된다(실사용에서는 오늘 탭·설정 탭이 이미
/// 이 provider를 읽고 있다).
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  _Tago tago, {
  CommuteDirection? slot,
  BusSettings settings = BusSettings.defaults,
}) async {
  final container = _container(tago, settings);
  await container.read(busSettingsProvider.future);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: BusStopSearchScreen(slot: slot)),
  ));
  await tester.pumpAndSettle();
  return container;
}


Future<void> _typeStop(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(BusStopSearchScreen.stopFieldKey), name);
  await tester.pumpAndSettle();
}

Future<void> _tapSearch(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
}

Future<void> _tapCity(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}


void main() {
  group('화면 기본 배선', () {
    testWidgets('도시 칩을 그린다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      expect(tago.cityCalls, 1);
      expect(find.text('수원시'), findsOneWidget);
      expect(find.text('성남시'), findsOneWidget);
      expect(find.byKey(BusStopSearchScreen.stopFieldKey), findsOneWidget);
    });

    testWidgets('도시를 고르고 이름을 검색하면 결과 행이 뜬다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);

      expect(tago.stopCalls, 1);
      expect(find.widgetWithText(ListTile, '수원시청.수원일자리센터'), findsOneWidget);
    });

    testWidgets('결과 행을 탭하면 도착을 조회해 확인 시트를 띄운다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();

      expect(tago.arrivalCalls, 1, reason: '저장 전에 오는 버스를 물어본다');
      expect(find.text(BusStrings.confirmTitle), findsOneWidget);
      expect(find.text('720번'), findsOneWidget);
    });

    testWidgets('저장된 도시를 복원한다 — 칩을 다시 고르지 않아도 검색된다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(
        tester,
        tago,
        settings: BusSettings.defaults.copyWith(departure: _savedSuwon),
      );

      await _typeStop(tester, '시청');
      await _tapSearch(tester);

      expect(tago.stopCalls, 1);
      expect(find.widgetWithText(ListTile, '수원시청.수원일자리센터'), findsOneWidget);
    });

    testWidgets('칩은 20개까지만 그리고 선택된 도시는 상한 밖이어도 맨 앞에 남는다', (tester) async {
      // 목록이 citycode 오름차순 원본이라 상한만 두면 경기 후반·강원 이남은
      // 구조적으로 밖으로 밀린다 — 복원해 놓고도 칩이 화면에 없으면 사용자는
      // "안 골라졌다"고 읽고 엉뚱한 칩으로 갈아치운다.
      final tago = _Tago()
        ..cities = {
          for (var i = 1; i <= 25; i++) 31000 + i: '가$i시',
        };
      await _pumpScreen(
        tester,
        tago,
        settings: BusSettings.defaults.copyWith(
          departure: const BusStop(
            nodeId: 'N1',
            nodeNm: '끝도시 정류장',
            nodeNo: 1,
            cityCode: 31025,
          ),
        ),
      );

      expect(find.text('가25시'), findsOneWidget, reason: '선택된 도시는 맨 앞');
      expect(find.text('가19시'), findsOneWidget);
      expect(find.text('가20시'), findsNothing, reason: '상한 20 = 선택 1 + 나머지 19');
    });
  });

}
