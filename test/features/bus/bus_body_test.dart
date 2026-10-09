import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

BusArrival _a(String routeId, String routeNo, int arrMin) =>
    BusArrival.fromMinutes(routeId: routeId, routeNo: routeNo, arrMin: arrMin);

BusCardView _view(List<BusArrival> items, {int hidden = 0}) => BusCardView(
  state: BusCardState.ok,
  visible: items,
  hiddenCount: hidden,
  fetchedAt: DateTime(2026, 7, 28, 7, 32),
);

/// 본문에 주는 폭. 축의 좌표 단정이 이 값에서 나오므로 상수로 둔다.
const _axisWidth = 340.0;

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: _axisWidth, child: child),
      ),
    ),
  );
}


final _circle = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle,
);

void main() {
  group('BusBodyText — 첫 차를 크게, 분·초까지, 임박도 색으로', () {
    testWidgets('첫 차는 강조 줄에, 나머지는 칩에 노선번호와 분·초가 보인다', (tester) async {
      await _pump(
        tester,
        BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])),
      );
      final first = find.byKey(BusBodyText.firstKey);
      expect(
        find.descendant(of: first, matching: find.text('720번')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.text('2분 00초')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.text('가장 먼저')),
        findsOneWidget,
      );
      expect(find.text('150번'), findsOneWidget);
      expect(find.text('5분 00초'), findsOneWidget);
      expect(
        find.descendant(of: first, matching: find.text('150번')),
        findsNothing,
        reason: '둘째 차부터는 강조 줄 밖의 칩이다',
      );
    });

    testWidgets('0초는 곧 도착, 1분 미만은 초만 쓴다', (tester) async {
      await _pump(
        tester,
        BusBodyText(
          view: _view([
            _a('A', '15', 0),
            BusArrival(routeId: 'B', routeNo: '16', arrSec: 48),
          ]),
        ),
      );
      expect(find.text('곧 도착'), findsOneWidget);
      expect(find.text('48초'), findsOneWidget);
    });

    testWidgets('첫 차의 시간은 칩보다 크고 굵다', (tester) async {
      await _pump(
        tester,
        BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])),
      );
      final big = tester.widget<Text>(find.text('2분 00초'));
      final chip = tester.widget<Text>(find.text('5분 00초'));
      expect(big.style?.fontWeight, FontWeight.w800);
      expect(big.style?.fontSize, greaterThanOrEqualTo(24));
      expect(chip.style?.fontSize, 14);
    });

    testWidgets('첫 차가 3분 안이면 큰 숫자가 빨강, 줄 배경도 빨강 틴트다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 2)])));
      final big = tester.widget<Text>(find.text('2분 00초'));
      expect(big.style?.color, AppColors.busSignalNear);
      final box = tester.widget<Container>(find.byKey(BusBodyText.firstKey));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color?.withValues(alpha: 1), AppColors.busSignalNear);
      expect(deco.color!.a, lessThan(0.3), reason: '배경은 옅은 틴트다');
    });

    testWidgets('3분 밖이면 큰 숫자는 본문색 — 노랑·초록 글자는 라이트에서 대비가 모자라다', (tester) async {
      // 라이트 실측: 노랑 #C98A0E는 틴트 위 2.63:1, 초록 #1E9E63은 2.99:1로 큰 글자
      // 기준(3:1)도 못 넘는다. 색은 틴트와 점이 말하고 글자는 본문색으로 둔다.
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 5)])));
      final big = tester.widget<Text>(find.text('5분 00초'));
      expect(big.style?.color, AppColors.ink);
      final box = tester.widget<Container>(find.byKey(BusBodyText.firstKey));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color?.withValues(alpha: 1), AppColors.busSignalSoon);
    });

    testWidgets('색은 보이는 분(내림)으로 고른다 — 2분 59초는 빨강이다', (tester) async {
      await _pump(
        tester,
        BusBodyText(
          view: _view([BusArrival(routeId: 'A', routeNo: '7', arrSec: 179)]),
        ),
      );
      final big = tester.widget<Text>(find.text('2분 59초'));
      expect(big.style?.color, AppColors.busSignalNear);
    });

    testWidgets('감춘 개수가 있으면 N개 더를 그린다', (tester) async {
      await _pump(
        tester,
        BusBodyText(view: _view([_a('A', '1', 2)], hidden: 2)),
      );
      expect(find.text('2개 더'), findsOneWidget);
    });

    testWidgets('감춘 개수가 0이면 더 보기가 없다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '1', 2)])));
      expect(find.textContaining('개 더'), findsNothing);
    });
  });

  group('BusBodyAxis.dotPosition — 0~15분을 3~97%로 clamp한다', () {
    test('0분은 왼쪽 끝(3%)이다', () {
      expect(BusBodyAxis.dotPosition(0), closeTo(0.03, 0.001));
    });

    test('15분은 오른쪽 끝(97%)이다', () {
      expect(BusBodyAxis.dotPosition(15 * 60), closeTo(0.97, 0.001));
    });

    test('15분을 넘겨도 97%를 넘지 않는다', () {
      expect(BusBodyAxis.dotPosition(48 * 60), closeTo(0.97, 0.001));
    });

    test('중간값은 비례한다', () {
      expect(BusBodyAxis.dotPosition(5 * 60), closeTo(1 / 3, 0.01));
    });
  });

  group('BusBodyAxis 렌더', () {
    testWidgets('눈금과 노선번호를 그린다 — 노선번호에 번은 붙이지 않는다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));
      expect(find.text('지금'), findsOneWidget);
      expect(find.text('15분'), findsOneWidget);
      expect(find.text('720'), findsOneWidget);
    });

    testWidgets('라벨이 스크린리더에 도착 시각을 준다 — 눈금은 읽지 않는다', (tester) async {
      // 이 모양은 분을 **화면 위치로만** 인코딩한다(점은 색뿐, 라벨은 노선번호뿐).
      // 감싸지 않으면 `720`·`61`이 맥락 없이 읽혀 화면을 못 보는 사용자에게
      // 정보가 0이 된다 — `간단히`는 같은 데이터를 `720번` + `2분`으로 읽어 준다.
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '720', 2), _a('B', '61', 0)])),
      );

      expect(find.bySemanticsLabel('720번 2분'), findsOneWidget);
      expect(find.bySemanticsLabel('61번 곧 도착'), findsOneWidget);
      // 눈금은 좌표계일 뿐이라 라벨의 분과 섞이면 숫자가 두 배로 들린다.
      expect(find.bySemanticsLabel('15분'), findsNothing);

      handle.dispose();
    });

    testWidgets('점과 라벨이 분에 비례한 x좌표에 놓인다', (tester) async {
      // 위 테스트처럼 **존재만** 보면 무검증이다 — `_dot`의 `left` 식을 아무렇게나
      // 바꾸거나 `_labels`의 `- 14` 중심 보정을 지워도 `find.text`는 통과한다
      // (Stack은 Flex와 달리 오버플로를 FlutterError로 알리지 않고 클립만 하므로,
      // 340폭 안에서 left 680으로 놓아도 예외가 없다). `시간 축`의 존재 이유가
      // "간격이 공간으로 보인다"이므로 그 공간 매핑을 위젯 레벨에서 고정한다.
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));

      final expected = BusBodyAxis.dotPosition(2 * 60) * _axisWidth;
      expect(
        tester.getCenter(find.byKey(BusBodyAxis.dotKeyFor('A'))).dx,
        closeTo(expected, 0.5),
        reason: '점 중심이 분에 비례한 x다 — size/2 보정이 그 일을 한다',
      );
      expect(
        tester.getCenter(find.byKey(BusBodyAxis.labelKeyFor('A'))).dx,
        closeTo(expected, 0.5),
        reason: '라벨 중심이 점과 같은 x다 — 폭 28의 -14 보정이 그 일을 한다',
      );
    });

    testWidgets('15분을 넘긴 항목들은 점이 오른쪽 끝에 모인다', (tester) async {
      // clamp가 없으면 31분은 축 폭의 2배 지점으로 나가 화면 밖에서 조용히 잘린다.
      //
      // **점으로 잰다.** 라벨은 겹침을 피해 밀려나므로(`layoutAxisLabels`) 더 이상
      // 같은 자리에 서지 않는다 — 그게 이 화면의 개선이다. clamp가 지키는 것은
      // "축 밖으로 나가지 않는다"이고 그 책임은 점에 있다.
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '720', 18), _a('B', '61', 31)])),
      );

      final far =
          BusBodyAxis.dotPosition(BusBodyAxis.axisRange * 60) * _axisWidth;
      expect(
        tester.getCenter(find.byKey(BusBodyAxis.dotKeyFor('A'))).dx,
        closeTo(far, 0.5),
      );
      expect(
        tester.getCenter(find.byKey(BusBodyAxis.dotKeyFor('B'))).dx,
        closeTo(far, 0.5),
        reason: '축을 넘긴 값은 97%에 모인다 — 축 밖으로 밀려나지 않는다',
      );
    });

    testWidgets('붙어 있는 두 라벨은 겹치지 않는다', (tester) async {
      // 실기기 신고 2026-07-30: 1분·1.5분 두 대의 라벨이 `55536023`으로 뭉쳤다.
      // 점은 구별되는데 라벨 폭(34pt = 축의 1.7분치)이 서로를 먹었다.
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '553', 1), _a('B', '5623', 2)])),
      );

      // 두 줄로 엇갈리므로 가로만 보지 않고 **사각형 전체**가 겹치지 않는지 본다.
      final a = tester.getRect(find.byKey(BusBodyAxis.labelKeyFor('A')));
      final b = tester.getRect(find.byKey(BusBodyAxis.labelKeyFor('B')));
      expect(
        a.deflate(0.5).overlaps(b.deflate(0.5)),
        isFalse,
        reason: '두 라벨의 사각형이 겹치면 글자가 뭉쳐 읽힌다',
      );
    });

    testWidgets('점이 버스 모양이다 — 둥근 네모 안에 버스 아이콘', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));
      final marker = find.byKey(BusBodyAxis.dotKeyFor('A'));
      expect(
        find.descendant(of: marker, matching: find.byIcon(Icons.directions_bus)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marker, matching: _circle),
        findsNothing,
        reason: '동그란 점이 아니라 버스 모양 표시다',
      );
    });

    testWidgets('라벨에 분이 붙는다 — 시간 축은 초를 쓰지 않는다', (tester) async {
      await _pump(
        tester,
        BusBodyAxis(
          view: _view([
            BusArrival(routeId: 'A', routeNo: '720', arrSec: 134),
            _a('B', '61', 0),
          ]),
        ),
      );
      final a = find.byKey(BusBodyAxis.labelKeyFor('A'));
      expect(find.descendant(of: a, matching: find.text('2분')), findsOneWidget);
      final b = find.byKey(BusBodyAxis.labelKeyFor('B'));
      expect(find.descendant(of: b, matching: find.text('곧')), findsOneWidget);
      expect(find.textContaining('초'), findsNothing);
    });

    testWidgets('가까운 두 라벨은 두 줄로 엇갈린다', (tester) async {
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '553', 1), _a('B', '5623', 2)])),
      );
      final a = tester.getRect(find.byKey(BusBodyAxis.labelKeyFor('A')));
      final b = tester.getRect(find.byKey(BusBodyAxis.labelKeyFor('B')));
      expect(b.top, greaterThan(a.top), reason: '둘째 라벨은 아랫줄이다');
    });

    testWidgets('범례가 임박도 세 칸을 말한다 — 스크린리더는 읽지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));
      // `3분 안`이라고 쓰면 노랑으로 칠한 `3분` 버스와 모순돼 보였다(에뮬레이터 실측
      // 2026-10-09) — 칸 경계를 그대로 적는다.
      expect(find.text('3분 미만'), findsOneWidget);
      expect(find.text('3~7분'), findsOneWidget);
      expect(find.text('여유'), findsOneWidget);
      expect(find.bySemanticsLabel('여유'), findsNothing);
      handle.dispose();
    });

    testWidgets('감춘 개수가 있으면 N개 더를 그린다', (tester) async {
      // 축은 `hiddenCount`를 아예 참조하지 않아 5노선 중 2개를 조용히 버렸다.
      // 화면에는 점 3개뿐이라 사용자는 이 정류장에 버스가 3대만 온다고 읽는다.
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '720', 2)], hidden: 2)),
      );
      expect(find.text('2개 더'), findsOneWidget);
    });

    testWidgets('감춘 개수가 0이면 더 보기가 없다', (tester) async {
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)])));
      expect(find.textContaining('개 더'), findsNothing);
    });

    testWidgets('15분을 넘긴 라벨과 겹치지 않는다 — 우측 정렬이 아니라 별 줄이다', (tester) async {
      // 상한이 걸릴 만큼 노선이 많으면 보이는 3개 중 하나가 15분 이상인 일이 흔하다.
      // 그 라벨은 0.97로 clamp돼 오른쪽 끝에 고정되므로, `N개 더`를 라벨 행 우측에
      // 넣으면 겹쳐서 감추려던 정보가 또 안 읽힌다.
      await _pump(
        tester,
        BusBodyAxis(
          view: _view([_a('A', '720', 2), _a('B', '61', 31)], hidden: 2),
        ),
      );
      final more = tester.getRect(find.text('2개 더'));
      final farLabel = tester.getRect(find.text('61'));
      expect(
        more.top,
        greaterThanOrEqualTo(farLabel.bottom),
        reason: '감춘 개수는 라벨 행 아래에 있어야 겹치지 않는다',
      );
    });
  });

  test('가드 — 두 모양이 같은 함수로 임박도를 고른다', () {
    // 2026-10-09 사용자 결정으로 `간단히`도 신호색을 쓴다(예전 가드는 그 반대였다).
    // 색 칸을 모양마다 따로 계산하면 같은 버스가 두 모양에서 다른 색이 된다.
    for (final path in [
      'lib/features/bus/presentation/widgets/bus_body_text.dart',
      'lib/features/bus/presentation/widgets/bus_body_axis.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains('busSignalOf('), isTrue, reason: path);
      expect(source.contains('isUrgent('), isFalse,
          reason: '$path — 임박 판정을 직접 하지 말고 busSignalOf를 거친다');
    }
  });
}
