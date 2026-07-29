import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/theme/app_text_styles.dart';
import 'package:planroutine/features/bus/data/bus_api_client.dart';
import 'package:planroutine/features/bus/domain/bus_settings.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/providers/bus_providers.dart';
import 'package:planroutine/features/bus/presentation/screens/bus_stop_search_screen.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_stop_confirm_sheet.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';
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
const _savedHwaseong = BusStop(
  nodeId: 'N4401',
  nodeNm: '화성시청',
  nodeNo: 4401,
  cityCode: _hwaseong,
);

/// TAGO는 UTF-8 JSON을 준다. **content-type을 빼면 안 된다** — package:http가
/// 헤더가 없으면 latin1로 떨어져 픽스처의 한글에서 터진다(구현이 아니라 픽스처의
/// 함정이다). `bus_api_client_test.dart`의 `_json`과 같은 이유·같은 모양이다.
http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// GBIS 실측 응답 파일. **손으로 적지 않는다** — 이 작업에서 손으로 쓴 픽스처가
/// 현실과 달라 여러 번 어긋났다(`gbis_response_parser_test.dart`와 같은 이유).
String _gbisFixture(String name) =>
    File('test/fixtures/gbis/$name.json').readAsStringSync();

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

  /// 검색 결과 정류소 ID의 접두. **기본은 비경기(`N…`)다** — 경기(`GGB…`)만 GBIS
  /// 경유노선을 조회하므로, 기본값을 두면 기존 테스트에는 그 호출이 없다.
  String idPrefix = 'N';

  int cityCalls = 0;
  int stopCalls = 0;
  int arrivalCalls = 0;
  int viaRouteCalls = 0;

  Future<http.Response> handle(http.Request req) async {
    final url = req.url;

    if (url.path.endsWith('getBusStationViaRouteListv2')) {
      viaRouteCalls++;
      return _json(_gbisFixture('viaroutes_jangmi_10routes'));
    }

    if (url.path.endsWith('getBusArrivalListv2')) {
      arrivalCalls++;
      return _json(_gbisFixture('arrivals_jangmi_10routes'));
    }

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
                'nodeid': '$idPrefix${e.value}',
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

/// `?slot=`으로 push해서 연다. 저장까지 밟으려면 GoRouter가 있어야 한다 —
/// `_pick` 끝의 `context.pop()`이 go_router 확장이라 라우터 없이는 던진다.
Future<ProviderContainer> _pumpRouted(
  WidgetTester tester,
  _Tago tago, {
  required CommuteDirection slot,
  BusSettings settings = BusSettings.defaults,
}) async {
  final container = _container(tago, settings);
  await container.read(busSettingsProvider.future);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('오늘'))),
      GoRoute(
        path: '/bus/stops',
        builder: (_, state) => BusStopSearchScreen(
          slot: state.uri.queryParameters['slot'] == CommuteDirection.toHome.name
              ? CommuteDirection.toHome
              : CommuteDirection.toWork,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  router.push('/bus/stops?slot=${slot.name}');
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

/// 지금 선택된 도시 칩. 없으면 null.
PillChip? _selectedChip(WidgetTester tester) {
  final chips =
      tester.widgetList<PillChip>(find.byType(PillChip)).where((c) => c.selected);
  return chips.isEmpty ? null : chips.first;
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

  group('도시를 고르기 전 (I6) — 검색은 죽은 컨트롤이 아니다', () {
    testWidgets('먼저 도시를 골라주세요라고 말한다 — 이름을 넣으라고 하지 않는다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      expect(find.text(BusStrings.cityFirst), findsOneWidget);
      expect(find.text(BusStrings.searchPrompt), findsNothing,
          reason: '이름이 아니라 도시가 빠졌는데 이름을 넣으라고 하면 사용자는 이미 넣은 것을 다시 넣는다');
    });

    testWidgets('돋보기가 비활성이고 눌러도 요청이 나가지 않는다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _typeStop(tester, '시청');
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.search),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull, reason: '누를 수 있어 보이는데 아무 일도 없는 것이 최악이다');

      await _tapSearch(tester);
      expect(tago.stopCalls, 0);
      expect(find.text(BusStrings.cityFirst), findsOneWidget,
          reason: '눌렀는데도 화면이 이름을 넣으라고 하면 몇 번을 더 누른다');
      expect(find.text(BusStrings.searchPrompt), findsNothing);
      expect(find.text(BusStrings.searchEmpty), findsNothing);
    });
  });

  group('조회 실패 (M6) — 결과 없음과 다르게 말한다', () {
    testWidgets('도시 목록 실패는 실패라고 말하고 다시 시도를 준다', (tester) async {
      final tago = _Tago()..cityFails = true;
      await _pumpScreen(tester, tago);

      expect(find.text(BusStrings.emptyDown), findsOneWidget);
      expect(find.text(BusStrings.emptyDownAction), findsOneWidget);
      expect(find.text(BusStrings.searchEmpty), findsNothing);
      expect(find.text(BusStrings.cityFirst), findsNothing,
          reason: '고를 도시가 없는 것은 안 고른 것이 아니다');
    });

    testWidgets('다시 시도를 누르면 도시를 다시 불러온다', (tester) async {
      final tago = _Tago()..cityFails = true;
      await _pumpScreen(tester, tago);
      expect(tago.cityCalls, 1);

      tago.cityFails = false;
      await tester.tap(find.text(BusStrings.emptyDownAction));
      await tester.pumpAndSettle();

      expect(tago.cityCalls, 2);
      expect(find.text('수원시'), findsOneWidget);
      expect(find.text(BusStrings.emptyDown), findsNothing);
    });

    testWidgets('정류장 검색 실패를 검색 결과가 없어요로 뭉개지 않는다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      tago.stopFails = true;
      await _typeStop(tester, '시청');
      await _tapSearch(tester);

      expect(find.text(BusStrings.emptyDown), findsOneWidget);
      expect(find.text(BusStrings.emptyDownAction), findsOneWidget);
      expect(find.text(BusStrings.searchEmpty), findsNothing,
          reason: '못 물어본 것을 없다고 말하면 사용자가 이름을 고치며 헛수고한다');
    });

    testWidgets('정말 없으면 검색 결과가 없어요다 — 실패로 말하지 않는다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '없는이름');
      await _tapSearch(tester);

      expect(find.text(BusStrings.searchEmpty), findsOneWidget);
      expect(find.text(BusStrings.emptyDown), findsNothing,
          reason: 'empty를 실패로 말하면 이름을 고치는 대신 무한히 재시도한다');
    });
  });

  group('어느 슬롯에 저장하는지 말한다 (I7)', () {
    testWidgets('출발지 슬롯이면 제목이 출발지다', (tester) async {
      await _pumpScreen(tester, _Tago(), slot: CommuteDirection.toWork);
      expect(find.text('출발지 정류장 찾기'), findsOneWidget);
    });

    testWidgets('도착지 슬롯이면 제목이 도착지다 — 일과시간에 카드에서 들어오는 경로', (tester) async {
      await _pumpScreen(tester, _Tago(), slot: CommuteDirection.toHome);
      expect(find.text('도착지 정류장 찾기'), findsOneWidget);
      expect(find.text('출발지 정류장 찾기'), findsNothing);
    });

    testWidgets('쿼리가 없는 폴백에서도 슬롯을 말한다', (tester) async {
      await _pumpScreen(tester, _Tago());
      expect(find.text('출발지 정류장 찾기'), findsOneWidget,
          reason: '라우트를 손으로 열었을 때의 결과도 화면에 보여야 한다');
    });

    testWidgets('확인 시트도 저장 대상을 말한다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago, slot: CommuteDirection.toHome);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();

      expect(find.text(BusStrings.confirmTitle), findsOneWidget);
      expect(find.text('도착지에 저장합니다'), findsOneWidget,
          reason: '맞아요를 누르는 순간이 되돌리기 가장 어려운 지점이다');
    });

    testWidgets('저장은 화면이 말한 슬롯으로 간다', (tester) async {
      final tago = _Tago();
      final container = await _pumpRouted(
        tester,
        tago,
        slot: CommuteDirection.toHome,
      );

      expect(find.text('도착지 정류장 찾기'), findsOneWidget);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BusStopConfirmSheet.acceptKey));
      await tester.pumpAndSettle();

      final saved = container.read(busSettingsProvider).valueOrNull;
      expect(saved?.arrival?.nodeNm, '수원시청.수원일자리센터');
      expect(saved?.departure, isNull,
          reason: '제목이 도착지라고 말했으면 출발지는 건드리지 않는다');
    });

    testWidgets('경기 정류장은 경유노선을 함께 조회해 시트에 넘긴다', (tester) async {
      // 실기기 버그(2026-07-29)의 화면 경로다. 같은 정류장·같은 시각에 도착정보는
      // 8노선, 경유노선은 10노선이다 — 도착정보로 목록을 만들면 나머지를 고를 수 없다.
      final tago = _Tago()..idPrefix = 'GGB';
      await _pumpRouted(tester, tago, slot: CommuteDirection.toWork);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();

      expect(tago.viaRouteCalls, 1);
      expect(tago.arrivalCalls, 1);

      // **행 개수는 델리게이트에서 읽는다.** `find.byType(CheckboxListTile)`은
      // 뷰포트 밖 자식이 마운트되지 않아 테스트 창(600px) 기준 6개만 센다 — 목록이
      // 몇 건인지와 무관한 수라 단정에 쓰면 화면 크기를 검사하는 테스트가 된다.
      final list = tester.widget<ListView>(find.descendant(
        of: find.byType(BusStopConfirmSheet),
        matching: find.byType(ListView),
      ));
      expect(list.childrenDelegate.estimatedChildCount, 10,
          reason: '도착정보 8건이 아니라 경유노선 10건이 목록이다');

      // `9`는 이 픽스처의 도착정보에서 `정보없음`으로 빠지는 노선이다 — 목록에
      // 있다는 것이 곧 목록의 출처가 경유노선이라는 증거다. 번호순 첫 행이라
      // 뷰포트에 확실히 들어온다.
      expect(find.text('9번'), findsOneWidget);

      // 행선지는 경유노선 응답에만 있다. **그 행의 부제를 직접 읽는다** —
      // 문구로 찾으면 마을 `6`·`9`가 둘 다 금정역행이라(실측) 2건이 잡힌다.
      final tile = tester.widget<CheckboxListTile>(find.ancestor(
        of: find.text('9번'),
        matching: find.byType(CheckboxListTile),
      ));
      expect((tile.subtitle as Text).data, '금정역 방면');
    });

    testWidgets('비경기 정류장은 경유노선을 조회하지 않는다', (tester) async {
      // GBIS는 경기도 전용이다. 헛요청은 일일 트래픽(1,000)만 쓴다.
      final tago = _Tago();
      await _pumpRouted(tester, tago, slot: CommuteDirection.toWork);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();

      expect(tago.viaRouteCalls, 0);
      expect(find.text(BusStrings.confirmTitle), findsOneWidget,
          reason: '경유노선이 없어도 시트는 도착정보로 열린다');
    });
  });

  group('도시를 바꾸면 (M1) 옛 도시의 결과가 남지 않는다', () {
    testWidgets('검색어를 지운 뒤 도시를 바꾸면 옛 목록이 사라진다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      expect(find.text('수원시청.수원일자리센터'), findsOneWidget);

      await _typeStop(tester, '');
      await _tapCity(tester, '성남시');

      expect(find.text('수원시청.수원일자리센터'), findsNothing,
          reason: '성남시가 강조된 칩 아래 수원시 목록이 깔려서는 안 된다');
      expect(find.text(BusStrings.searchPrompt), findsOneWidget);
    });

    testWidgets('검색어가 남아 있으면 새 도시로 다시 찾는다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      expect(tago.stopCalls, 1);

      await _tapCity(tester, '화성시');

      expect(tago.stopCalls, 2);
      expect(find.text('화성시청'), findsOneWidget);
      expect(find.text('수원시청.수원일자리센터'), findsNothing,
          reason: '이름을 넣어둔 채 칩만 바꿨는데 옛 목록이 남으면 그 행을 탭한다');
    });
  });

  group('도시 칩 (I13) — 공용 PillChip을 쓴다', () {
    testWidgets('raw ChoiceChip이 아니라 PillChip이다', (tester) async {
      await _pumpScreen(tester, _Tago());

      expect(find.byType(ChoiceChip), findsNothing,
          reason: 'chipTheme.labelStyle이 선택/비선택 구분 없는 sub라 골드 채움 위에서 사라진다');
      expect(find.byType(PillChip), findsNWidgets(3));
    });

    testWidgets('선택된 도시 이름은 골드로 뒤집혀 읽힌다', (tester) async {
      await _pumpScreen(tester, _Tago());
      await _tapCity(tester, '성남시');

      expect(_selectedChip(tester)?.label, '성남시');
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is PillChip && w.selected),
          matching: find.byType(Text),
        ),
      );
      expect(label.style?.color, AppColors.gold,
          reason: '다크에서 크림 글씨가 골드 채움에 얹히면 대비 1.10:1로 사라진다');
    });
  });

  group('도시 복원 (M13) — 편집 중인 슬롯을 본다', () {
    testWidgets('도착지를 고치면 도착지의 도시가 복원된다', (tester) async {
      await _pumpScreen(
        tester,
        _Tago(),
        slot: CommuteDirection.toHome,
        settings: BusSettings.defaults.copyWith(
          departure: _savedSuwon,
          arrival: _savedHwaseong,
        ),
      );

      expect(_selectedChip(tester)?.label, '화성시',
          reason: '출발지의 도시를 복원하면 잘못된 cityCode가 빈 응답으로 와 헛치게 된다');
    });

    testWidgets('편집 중인 슬롯이 비어 있으면 반대 슬롯의 도시를 쓴다', (tester) async {
      await _pumpScreen(
        tester,
        _Tago(),
        slot: CommuteDirection.toHome,
        settings: BusSettings.defaults.copyWith(departure: _savedSuwon),
      );

      expect(_selectedChip(tester)?.label, '수원시',
          reason: '첫 등록의 두 번째 슬롯에서 도시를 다시 고르게 하지 않는다');
    });
  });

  group('한글 라벨에 영문 장식용 eyebrow를 쓰지 않는다 (M14)', () {
    testWidgets('도시 라벨은 label 스타일이다', (tester) async {
      await _pumpScreen(tester, _Tago());

      final style = tester.widget<Text>(find.text(BusStrings.cityLabel)).style;
      expect(style, AppTextStyles.label);
      expect(style?.letterSpacing, isNull, reason: '자간 2.5는 `도 시`처럼 벌어진다');
    });

    testWidgets('확인 시트의 지시문은 본문 위계로 그린다', (tester) async {
      final tago = _Tago();
      await _pumpScreen(tester, tago);

      await _tapCity(tester, '수원시');
      await _typeStop(tester, '시청');
      await _tapSearch(tester);
      await tester.tap(find.text('수원시청.수원일자리센터'));
      await tester.pumpAndSettle();

      final style =
          tester.widget<Text>(find.text(BusStrings.confirmRoutesTitle)).style;
      expect(style, AppTextStyles.bodyL,
          reason: '시트 안 유일한 지시문이 장식 라벨보다 약하게 읽히면 방향 확인이 무너진다');
    });
  });
}
