import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/bus/domain/bus_arrival.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_axis.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_body_text.dart';

BusArrival _a(String routeId, String routeNo, int arrMin) =>
    BusArrival(routeId: routeId, routeNo: routeNo, arrMin: arrMin);

BusCardView _view(List<BusArrival> items, {int hidden = 0}) => BusCardView(
      state: BusCardState.ok,
      visible: items,
      hiddenCount: hidden,
      fetchedAt: DateTime(2026, 7, 28, 7, 32),
    );

/// 본문에 주는 폭. 축의 좌표 단정이 이 값에서 나오므로 상수로 둔다.
const _axisWidth = 340.0;

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SizedBox(width: _axisWidth, child: child)),
  ));
}

/// 축의 점 — 원형 `Container`. 레일은 사각(`borderRadius`)이라 걸리지 않는다.
Finder _dot(int index) => find
    .descendant(
      of: find.byType(BusBodyAxis),
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle),
    )
    .at(index);

void main() {
  group('BusBodyText — 색을 쓰지 않고 굵기·크기로만 위계를 만든다', () {
    testWidgets('노선번호와 분이 모두 보인다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])));
      expect(find.text('720번'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('150번'), findsOneWidget);
      expect(find.text('5분'), findsOneWidget);
    });

    testWidgets('0분은 곧 도착으로 쓴다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '15', 0)])));
      expect(find.text('곧 도착'), findsOneWidget);
    });

    testWidgets('임박한 행만 w800 18px ink, 나머지는 w600 14px sub', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '720', 2), _a('B', '150', 5)])));

      final urgent = tester.widget<Text>(find.text('2분'));
      final normal = tester.widget<Text>(find.text('5분'));
      expect(urgent.style?.fontWeight, FontWeight.w800);
      expect(urgent.style?.fontSize, 18);
      expect(urgent.style?.color, AppColors.ink);
      expect(normal.style?.fontWeight, FontWeight.w600);
      expect(normal.style?.fontSize, 14);
      expect(normal.style?.color, AppColors.sub);
    });

    testWidgets('감춘 개수가 있으면 N개 더를 그린다', (tester) async {
      await _pump(tester, BusBodyText(view: _view([_a('A', '1', 2)], hidden: 2)));
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
      expect(BusBodyAxis.dotPosition(15), closeTo(0.97, 0.001));
    });

    test('15분을 넘겨도 97%를 넘지 않는다', () {
      expect(BusBodyAxis.dotPosition(48), closeTo(0.97, 0.001));
    });

    test('중간값은 비례한다', () {
      expect(BusBodyAxis.dotPosition(5), closeTo(1 / 3, 0.01));
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

      final expected = BusBodyAxis.dotPosition(2) * _axisWidth;
      expect(tester.getCenter(_dot(0)).dx, closeTo(expected, 0.5),
          reason: '점 중심이 분에 비례한 x다 — size/2 보정이 그 일을 한다');
      expect(tester.getCenter(find.text('720')).dx, closeTo(expected, 0.5),
          reason: '라벨 중심이 점과 같은 x다 — 폭 28의 -14 보정이 그 일을 한다');
    });

    testWidgets('15분을 넘긴 항목들은 오른쪽 끝 같은 위치로 모인다', (tester) async {
      // clamp가 없으면 31분은 축 폭의 2배 지점으로 나가 화면 밖에서 조용히 잘린다.
      await _pump(
        tester,
        BusBodyAxis(view: _view([_a('A', '720', 18), _a('B', '61', 31)])),
      );

      final far = BusBodyAxis.dotPosition(BusBodyAxis.axisRange) * _axisWidth;
      expect(tester.getCenter(find.text('720')).dx, closeTo(far, 0.5));
      expect(tester.getCenter(find.text('61')).dx, closeTo(far, 0.5),
          reason: '축을 넘긴 값은 97%에 모인다 — 축 밖으로 밀려나지 않는다');
    });

    testWidgets('감춘 개수가 있으면 N개 더를 그린다', (tester) async {
      // 축은 `hiddenCount`를 아예 참조하지 않아 5노선 중 2개를 조용히 버렸다.
      // 화면에는 점 3개뿐이라 사용자는 이 정류장에 버스가 3대만 온다고 읽는다.
      await _pump(tester, BusBodyAxis(view: _view([_a('A', '720', 2)], hidden: 2)));
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
      expect(more.top, greaterThanOrEqualTo(farLabel.bottom),
          reason: '감춘 개수는 라벨 행 아래에 있어야 겹치지 않는다');
    });
  });

  test('가드 — 기본 모양 소스가 busSignal 토큰을 참조하지 않는다', () {
    // 기본 경험의 팔레트 불변을 소스 수준에서 지킨다. 위젯 렌더로는 "색을 쓰지
    // 않았음"을 증명하기 어렵다.
    final source = File(
      'lib/features/bus/presentation/widgets/bus_body_text.dart',
    ).readAsStringSync();
    expect(source.contains('busSignal'), isFalse,
        reason: '간단히 모양은 신호색을 쓰지 않는다 — 팔레트 충돌을 기본값에서 없앤다');
  });
}
