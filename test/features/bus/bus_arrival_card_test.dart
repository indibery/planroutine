import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

/// `fetchedAt`은 **기본이 null**이다 — 앱은 `down`·`keyError`·`noStop`을 항상
/// `fetchedAt: null`로 만든다(조회가 실패했거나 아예 안 했다). 기본값을 시각으로 두면
/// 제목줄에 `07:32 기준`을 달고 본문에 `지금 정보를 못 받았어요`를 쓰는, 앱에 존재하지
/// 않는 자기모순 카드를 테스트가 축복한다. 시각이 필요한 테스트만 명시로 넘긴다.
BusCardView _view({
  BusCardState state = BusCardState.ok,
  List<BusArrival>? items,
  int hidden = 0,
  DateTime? fetchedAt,
}) {
  return BusCardView(
    state: state,
    visible: items ?? [const BusArrival(routeId: 'A', routeNo: '720', arrMin: 2)],
    hiddenCount: hidden,
    fetchedAt: fetchedAt,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required BusCardView view,
  BusCardStyle style = BusCardStyle.text,
  bool expanded = true,
  VoidCallback? onToggle,
  VoidCallback? onFlip,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BusArrivalCard(
        view: view,
        style: style,
        direction: CommuteDirection.toWork,
        stopName: '수원시청',
        expanded: expanded,
        onToggleExpanded: onToggle ?? () {},
        onFlipDirection: onFlip ?? () {},
      ),
    ),
  ));
}

void main() {
  group('펼침', () {
    testWidgets('방향·정류장·기준시각·본문·방향토글이 모두 보인다', (tester) async {
      await _pump(tester, view: _view(fetchedAt: DateTime(2026, 7, 28, 7, 32)));
      expect(find.text('🏠→🏫 출근'), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
      expect(find.text('07:32 기준'), findsOneWidget);
      expect(find.byType(BusBodyText), findsOneWidget);
      expect(find.textContaining('퇴근 보기'), findsOneWidget);
    });

    testWidgets('모양이 axis면 축 본문을 그린다', (tester) async {
      await _pump(tester, view: _view(), style: BusCardStyle.axis);
      expect(find.byType(BusBodyAxis), findsOneWidget);
      expect(find.byType(BusBodyText), findsNothing);
    });
  });

  group('접힘 — 사라지는 것과 남는 것', () {
    testWidgets('본문·기준시각·방향토글이 사라지고 방향·정류장은 남는다', (tester) async {
      await _pump(tester, view: _view(), expanded: false);

      expect(find.byType(BusBodyText), findsNothing);
      expect(find.text('07:32 기준'), findsNothing);
      expect(find.textContaining('퇴근 보기'), findsNothing);

      expect(find.text('🏠→🏫 출근'), findsOneWidget);
      expect(find.textContaining('수원시청'), findsOneWidget);
    });

    testWidgets('도착 분이 남지 않는다 — 안 보이게 하는 것이 목적이다', (tester) async {
      await _pump(tester, view: _view(), expanded: false);
      expect(find.text('2분'), findsNothing);
      expect(find.text('720번'), findsNothing);
    });
  });

  group('제목줄이 같은 칸에서 토글된다', () {
    testWidgets('펼침에서 제목줄을 누르면 콜백이 온다', (tester) async {
      var tapped = 0;
      await _pump(tester, view: _view(), onToggle: () => tapped++);
      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      expect(tapped, 1);
    });

    testWidgets('접힘에서도 같은 키를 누른다 — 표적이 움직이지 않는다', (tester) async {
      var tapped = 0;
      await _pump(tester, view: _view(), expanded: false, onToggle: () => tapped++);
      await tester.tap(find.byKey(BusArrivalCard.headerKey));
      expect(tapped, 1);
    });

    testWidgets('접힘과 펼침에서 제목줄의 y좌표가 같다', (tester) async {
      await _pump(tester, view: _view());
      final expandedY = tester.getTopLeft(find.byKey(BusArrivalCard.headerKey)).dy;

      await _pump(tester, view: _view(), expanded: false);
      final collapsedY = tester.getTopLeft(find.byKey(BusArrivalCard.headerKey)).dy;

      expect(collapsedY, expandedY);
    });
  });

  testWidgets('방향 토글은 별 콜백이다', (tester) async {
    var flipped = 0;
    await _pump(tester, view: _view(), onFlip: () => flipped++);
    await tester.tap(find.byKey(BusArrivalCard.flipKey));
    expect(flipped, 1);
  });

  group('실패 계약 — 다섯 상태가 서로 다르게 읽힌다', () {
    testWidgets('closed / down / keyError / noStop 문구가 각각 다르다', (tester) async {
      await _pump(tester, view: _view(state: BusCardState.closed, items: const []));
      expect(find.text('오늘 운행이 끝났어요'), findsOneWidget);

      // down·keyError·noStop 세 상태는 앱이 항상 fetchedAt: null로 만든다 — 제목줄에
      // 기준시각이 붙으면 "정보를 못 받았는데 07:32 기준"이라는 자기모순이 된다.
      // 각 상태의 트리가 살아 있는 동안(다음 _pump로 교체되기 전에) 바로 확인한다 —
      // 마지막에 한 번만 확인하면 그 시점에 남아 있는 트리(noStop)만 검증된다.
      // closed는 막차 후 조회 성공이라 기준시각이 붙는 것이 정상이라 제외한다.
      await _pump(tester, view: _view(state: BusCardState.down, items: const []));
      expect(find.text('지금 정보를 못 받았어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.textContaining('기준'), findsNothing);

      await _pump(tester, view: _view(state: BusCardState.keyError, items: const []));
      expect(find.text('버스 정보를 불러올 수 없어요'), findsOneWidget);
      expect(find.textContaining('기준'), findsNothing);

      await _pump(tester, view: _view(state: BusCardState.noStop, items: const []));
      expect(find.text('정류장을 등록하면 도착시간이 보여요'), findsOneWidget);
      expect(find.textContaining('기준'), findsNothing);
    });

    testWidgets('고른 노선만 안 오면 막차 문구가 아니라 별 문구다', (tester) async {
      await _pump(tester, view: _view(
        state: BusCardState.filteredOut,
        items: const [],
        fetchedAt: DateTime(2026, 7, 28, 7, 30),
      ));
      expect(find.text('고른 노선은 지금 오지 않아요'), findsOneWidget);
      expect(find.text('오늘 운행이 끝났어요'), findsNothing,
          reason: '정류장에는 다른 버스가 오고 있다 — 정반대의 행동을 부르는 정보다');
      expect(find.textContaining('설정에서 고를 수 있어요'), findsOneWidget);
    });

    testWidgets('stale + 필터로 목록이 비면 막차 문구가 아니라 못 받았어요다', (tester) async {
      // 와일드카드 분기가 있으면 여기서 '오늘 운행이 끝났어요'가 나온다.
      await _pump(tester, view: _view(
        state: BusCardState.stale,
        items: const [],
        fetchedAt: DateTime(2026, 7, 28, 7, 30),
      ));
      expect(find.text('지금 정보를 못 받았어요'), findsOneWidget);
      expect(find.text('오늘 운행이 끝났어요'), findsNothing);
    });

    testWidgets('stale은 목록을 유지하고 갱신 실패를 고백한다', (tester) async {
      await _pump(tester, view: _view(
        state: BusCardState.stale,
        fetchedAt: DateTime(2026, 7, 28, 7, 32),
      ));
      expect(find.byType(BusBodyText), findsOneWidget);
      expect(find.text('07:32 기준 · 갱신 실패'), findsOneWidget);
    });
  });
}
