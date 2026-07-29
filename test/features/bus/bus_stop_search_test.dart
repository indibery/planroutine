import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/bus_route.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_stop_confirm_sheet.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청.수원일자리센터',
  nodeNo: 2251,
  cityCode: 31010,
);

final _arrivals = [
  BusArrival.fromMinutes(routeId: 'R1', routeNo: '82-1', arrMin: 8),
  BusArrival.fromMinutes(routeId: 'R2', routeNo: '92', arrMin: 10),
  BusArrival.fromMinutes(routeId: 'R3', routeNo: '92-1', arrMin: 10),
];

/// 확인 시트를 **띄운 상태로** 둔다 — 시트 안에 무엇이 그려졌는지 검사할 때 쓴다.
///
/// 반환값이 없는 이유: `showModalBottomSheet`의 Future는 시트가 pop될 때까지 완료되지
/// 않으므로, 시트가 열린 채로 값을 돌려주면 그것은 **항상 null**이다. 저장 결과가
/// 필요한 테스트는 `_tapAccept`를 쓴다(null을 돌려주는 헬퍼를 남기면 나중에
/// `expect(await _showSheet(...), isNull)`처럼 아무것도 검증하지 않는 테스트가 생긴다).
Future<void> _showSheet(
  WidgetTester tester, {
  List<BusArrival>? arrivals,
  List<BusRoute> routes = const [],
  BusCardState state = BusCardState.ok,
  CommuteDirection slot = CommuteDirection.toWork,
  BusStop stop = _stop,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => BusStopConfirmSheet.show(
            context,
            stop: stop,
            routes: routes,
            arrivals: arrivals ?? _arrivals,
            state: state,
            slot: slot,
          ),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  group('확인 시트 — 방향을 노선 번호로 판별하게 한다', () {
    testWidgets('정류장 이름·번호와 오는 버스를 보여준다', (tester) async {
      await _showSheet(tester);
      expect(find.text('이 정류장이 맞나요?'), findsOneWidget);
      expect(find.textContaining('수원시청.수원일자리센터'), findsOneWidget);
      expect(find.textContaining('2251'), findsOneWidget);
      expect(find.text('82-1번'), findsOneWidget);
      expect(find.text('92-1번'), findsOneWidget);
    });

    testWidgets('기본은 전부 체크다 — 방향만 확인하려는 사람을 막지 않는다', (tester) async {
      await _showSheet(tester);
      final boxes = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(boxes.length, 3);
      expect(boxes.every((b) => b.value == true), isTrue);
    });

    testWidgets('전부 체크한 채 맞아요를 누르면 routeIds가 빈 집합이다', (tester) async {
      final saved = await _tapAccept(tester);
      expect(saved?.routeIds, isEmpty,
          reason: '전부를 열거해 저장하면 신설 노선이 영구히 안 보인다');
    });

    testWidgets('일부만 체크하면 그것만 저장된다', (tester) async {
      final saved = await _tapAccept(tester, uncheck: ['92번']);
      expect(saved?.routeIds, {'R1', 'R3'});
    });

    testWidgets('전부 해제하면 저장이 막힌다', (tester) async {
      final saved = await _tapAccept(
        tester,
        uncheck: ['82-1번', '92번', '92-1번'],
      );
      expect(saved, isNull);
      expect(find.text('버스를 하나 이상 남겨주세요'), findsOneWidget);
    });

    // 아래 두 개는 원래 한 테스트였다 — `_tapAccept`가 시트를 pop시킨 **뒤에** 시트
    // 안의 문구를 찾아 구조적으로 통과할 수 없었다(트리가 이미 사라졌다). 안내는
    // 띄운 상태에서, 저장 결과는 누른 뒤에 본다.
    testWidgets('오는 버스가 없으면 안내한다', (tester) async {
      await _showSheet(tester, arrivals: const []);
      expect(find.text('지금 이 정류장에 오는 버스가 없어요'), findsOneWidget);
    });

    testWidgets('오는 버스가 없어도 노선 없이 저장된다', (tester) async {
      final saved = await _tapAccept(tester, arrivals: const []);
      expect(saved?.routeIds, isEmpty,
          reason: '막차 후·주말이라 정말 안 오는 것은 등록을 막을 이유가 아니다');
    });

    testWidgets('막차 후(closed)는 안 오는 것이므로 저장을 막지 않는다', (tester) async {
      final saved = await _tapAccept(
        tester,
        arrivals: const [],
        state: BusCardState.closed,
      );
      expect(saved?.routeIds, isEmpty,
          reason: 'closed를 실패로 취급하면 막차 후 등록이 영구 불가가 된다');
    });

    testWidgets('키 문제는 키 문구를 쓴다 — 장애 문구와 섞지 않는다', (tester) async {
      await _showSheet(tester, arrivals: const [], state: BusCardState.keyError);
      expect(find.text('버스 정보를 불러올 수 없어요'), findsOneWidget);
      expect(find.text('지금 정보를 못 받았어요'), findsNothing);
    });

    testWidgets('조회 실패는 안 오는 것과 다르게 말하고 저장을 막는다', (tester) async {
      await _showSheet(tester, arrivals: const [], state: BusCardState.down);

      expect(find.text('지금 정보를 못 받았어요'), findsOneWidget);
      expect(find.text('지금 이 정류장에 오는 버스가 없어요'), findsNothing,
          reason: '못 물어본 것을 안 온다고 말하면 시트가 통과 도장이 된다');

      final accept = tester.widget<ElevatedButton>(
        find.byKey(BusStopConfirmSheet.acceptKey),
      );
      expect(accept.onPressed, isNull,
          reason: '방향을 확인할 재료가 0인데 저장을 허용하면 반대편 정류장이 저장된다');
    });
  });

  group('확인 시트 — 선택 목록은 경유노선에서 나온다', () {
    // 이 그룹이 지키는 것이 실기기 버그다(2026-07-29): 군포 장미아파트는 경유노선이
    // 10개인데 도착정보로 목록을 만들어 사용자 화면에 2개만 떴다. 자기 버스가 목록에
    // 없으면 노선을 좁힐 수 없다.
    testWidgets('도착정보에 없는 노선도 고를 수 있다', (tester) async {
      await _showSheet(tester, routes: _routes, arrivals: _someArrivals);

      // 경유노선 3개 전부가 행으로 있다 — 도착정보는 1개뿐이다.
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.text('9번'), findsOneWidget);
      expect(find.text('3030번'), findsOneWidget);
      expect(find.text('6501번'), findsOneWidget);
    });

    testWidgets('행선지가 보인다 — 길 양쪽 정류장을 가르는 단서', (tester) async {
      await _showSheet(tester, routes: _routes, arrivals: _someArrivals);

      expect(find.text('신사역(중) 방면'), findsOneWidget);
      expect(find.text('금정역 방면'), findsOneWidget);
    });

    testWidgets('도착 시간은 있는 노선에만 붙는다', (tester) async {
      await _showSheet(tester, routes: _routes, arrivals: _someArrivals);

      expect(find.text('4분 후'), findsOneWidget);
      // 도착 정보가 없는 두 노선에 `곧 도착`이 붙으면 안 된다 — 0과 null을 뭉갠 증거다.
      expect(find.text('곧 도착'), findsNothing);
    });

    testWidgets('도착정보 없는 노선만 남겨 저장할 수 있다 — 원래 못 하던 일이다', (tester) async {
      final saved = await _tapAccept(
        tester,
        routes: _routes,
        arrivals: _someArrivals,
        uncheck: ['3030번', '6501번'],
      );

      expect(saved?.routeIds, {'GGB241382001'},
          reason: '그 순간 안 오는 버스가 내가 타는 버스일 수 있다');
    });

    testWidgets('전부 체크한 채 저장하면 빈 집합이다 — 기준이 경유노선 전체다', (tester) async {
      final saved = await _tapAccept(
        tester,
        routes: _routes,
        arrivals: _someArrivals,
      );

      expect(saved?.routeIds, isEmpty);
    });

    testWidgets('경유노선이 있으면 도착 조회가 실패해도 저장할 수 있다', (tester) async {
      // 두 조회는 별개 호출이다. 행선지로 방향을 확인할 수 있는데 막으면, 확인할 수
      // 있는 사람을 막는 것이 된다.
      await _showSheet(
        tester,
        routes: _routes,
        arrivals: const [],
        state: BusCardState.down,
      );

      final accept = tester.widget<ElevatedButton>(
        find.byKey(BusStopConfirmSheet.acceptKey),
      );
      expect(accept.onPressed, isNotNull);
      expect(find.text('신사역(중) 방면'), findsOneWidget);
    });

    testWidgets('그때는 도착 시간을 못 받은 이유를 밝힌다', (tester) async {
      await _showSheet(
        tester,
        routes: _routes,
        arrivals: const [],
        state: BusCardState.down,
      );

      expect(find.text('도착 시간은 지금 못 받았어요'), findsOneWidget);
      // 목록이 있으므로 "오는 버스가 없다"고 말하면 거짓이다.
      expect(find.text('지금 이 정류장에 오는 버스가 없어요'), findsNothing);
    });

    testWidgets('노선이 많아 시트가 커져도 제목이 상태바를 침범하지 않는다', (tester) async {
      // 시뮬레이터 실측으로 잡은 결함이다. 행선지가 붙어 행이 2줄이 되고 건수가
      // 늘면(실측 10) 시트가 처음으로 화면 top까지 자라는데, `showModalBottomSheet`의
      // `useSafeArea` 기본값(false)에서는 top padding이 제거돼 제목
      // `이 정류장이 맞나요?`가 다이나믹 아일랜드에 겹쳐 읽히지 않았다.
      //
      // 시트 높이가 내용에 따라 변하므로 가드가 없으면 **노선이 많은 정류장에서만**
      // 재발한다 — 노선이 적은 정류장으로 테스트하면 통과한다.
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 177); // 59 논리픽셀
      addTearDown(tester.view.reset);

      await _showSheet(tester, routes: _manyRoutes, arrivals: const []);

      expect(
        tester.getTopLeft(find.text('이 정류장이 맞나요?')).dy,
        greaterThanOrEqualTo(59.0),
      );
    });

    testWidgets('서울 정류장은 목록이 전부가 아님을 밝힌다', (tester) async {
      // 실측 응암역.신사오거리: GBIS로는 1개만 나온다(TAGO에는 서울이 없어 대안이
      // 없다). 알리지 않으면 사용자는 목록을 전부라고 믿고 등록하고, 자기 버스가
      // 영구히 안 보이는데 이유를 알 수 없다.
      await _showSheet(tester, stop: _seoulStop, routes: _routes);

      expect(find.text('서울 정류장은 아직 일부 노선만 보여요'), findsOneWidget);
    });

    testWidgets('경기 정류장에는 그 안내를 띄우지 않는다', (tester) async {
      await _showSheet(tester, routes: _routes);

      expect(find.text('서울 정류장은 아직 일부 노선만 보여요'), findsNothing);
    });

    testWidgets('노선은 번호순으로 선다 — 자기 번호를 훑어 찾는다', (tester) async {
      await _showSheet(tester, routes: _routes, arrivals: _someArrivals);

      final titles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((t) => (t.title as Text).data)
          .toList();

      expect(titles, ['9번', '3030번', '6501번']);
    });
  });
}

/// 서울 정류장. 목록이 부분집합이라는 것을 시트가 알려야 한다.
const _seoulStop = BusStop(
  nodeId: 'GGB111000090',
  nodeNm: '응암역.신사오거리',
  nodeNo: 13108,
  cityCode: 0,
  regionName: '서울',
);

/// 군포 장미아파트 실측 경유노선에서 셋을 골랐다 — 마을 `9`, 직행좌석 `3030`·`6501`.
/// routeId는 실측 GBIS 값에 `GGB` 접두를 붙인 형태다(파서가 그렇게 준다).
const _routes = [
  BusRoute(routeId: 'GGB208000027', routeNo: '3030', destName: '신사역(중)'),
  BusRoute(
    routeId: 'GGB234001163',
    routeNo: '6501',
    destName: '부곡공영차고지(미정차)',
  ),
  BusRoute(routeId: 'GGB241382001', routeNo: '9', destName: '금정역'),
];

/// 위 셋 중 **하나만** 지금 오는 상태. 실기기에서 목록이 줄어든 그 상황이다.
final _someArrivals = [
  BusArrival.fromMinutes(routeId: 'GGB208000027', routeNo: '3030', arrMin: 4),
];

/// 군포 장미아파트 실측 경유노선 **10개 전부**. 시트가 화면 top까지 자라는 조건이라
/// 상단 침범 가드가 이 픽스처를 쓴다.
const _manyRoutes = [
  BusRoute(routeId: 'GGB241382003', routeNo: '6', destName: '금정역'),
  BusRoute(routeId: 'GGB241382001', routeNo: '9', destName: '금정역'),
  BusRoute(
    routeId: 'GGB208000005',
    routeNo: '11-5',
    destName: '정금마을.방배경찰서(중)',
  ),
  BusRoute(routeId: 'GGB208000001', routeNo: '15', destName: '창박골'),
  BusRoute(routeId: 'GGB208000032', routeNo: '87', destName: '산본1동'),
  BusRoute(
    routeId: 'GGB100100574',
    routeNo: '541',
    destName: '신분당선강남역(중)',
  ),
  BusRoute(
    routeId: 'GGB208000026',
    routeNo: '917',
    destName: '신사역8번출구.가로수길',
  ),
  BusRoute(routeId: 'GGB208000027', routeNo: '3030', destName: '신사역(중)'),
  BusRoute(
    routeId: 'GGB100100279',
    routeNo: '5623',
    destName: '여의도환승센터(1번승강장)',
  ),
  BusRoute(
    routeId: 'GGB234001163',
    routeNo: '6501',
    destName: '부곡공영차고지(미정차)',
  ),
];

/// 시트를 띄우고 필요한 체크를 해제한 뒤 `맞아요`를 누른다.
Future<BusStop?> _tapAccept(
  WidgetTester tester, {
  List<String> uncheck = const [],
  List<BusArrival>? arrivals,
  List<BusRoute> routes = const [],
  BusCardState state = BusCardState.ok,
  CommuteDirection slot = CommuteDirection.toWork,
}) async {
  BusStop? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await BusStopConfirmSheet.show(
              context,
              stop: _stop,
              routes: routes,
              arrivals: arrivals ?? _arrivals,
              state: state,
              slot: slot,
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();

  for (final label in uncheck) {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(BusStopConfirmSheet.acceptKey));
  await tester.pumpAndSettle();
  return result;
}
