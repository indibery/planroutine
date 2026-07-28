import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/bus_stop.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/screens/bus_stop_search_screen.dart';

const _stop = BusStop(
  nodeId: 'GGB201000156',
  nodeNm: '수원시청.수원일자리센터',
  nodeNo: 2251,
  cityCode: 31010,
);

final _arrivals = [
  const BusArrival(routeId: 'R1', routeNo: '82-1', arrMin: 8),
  const BusArrival(routeId: 'R2', routeNo: '92', arrMin: 10),
  const BusArrival(routeId: 'R3', routeNo: '92-1', arrMin: 10),
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
  BusCardState state = BusCardState.ok,
  CommuteDirection slot = CommuteDirection.toWork,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => BusStopConfirmSheet.show(
            context,
            stop: _stop,
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
        find.byKey(BusStopSearchScreen.confirmAcceptKey),
      );
      expect(accept.onPressed, isNull,
          reason: '방향을 확인할 재료가 0인데 저장을 허용하면 반대편 정류장이 저장된다');
    });
  });
}

/// 시트를 띄우고 필요한 체크를 해제한 뒤 `맞아요`를 누른다.
Future<BusStop?> _tapAccept(
  WidgetTester tester, {
  List<String> uncheck = const [],
  List<BusArrival>? arrivals,
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

  await tester.tap(find.byKey(BusStopSearchScreen.confirmAcceptKey));
  await tester.pumpAndSettle();
  return result;
}
