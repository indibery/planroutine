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

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SizedBox(width: 340, child: child)),
  ));
}

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
