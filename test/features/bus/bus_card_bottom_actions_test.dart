// 정류장 미등록 카드의 두 표적은 **가로로 갈라지고, 손가락만 하다.**
//
// 실기기 신고(2026-08-07): `정류장 등록`과 `출근 보기`가 세로로 붙어 있어
// 누르기 어려웠다. 원인이 둘이었다.
//
//   거리 — 두 링크가 세로 23dp 간격. 손가락 접촉면(8~10mm)보다 좁아 하나를
//          누르려다 다른 것을 스친다.
//   크기 — 둘 다 패딩 없는 맨 텍스트라 히트 영역이 글자 높이(약 18dp)뿐.
//          Material 권장 최소는 48dp다.
//
// 그래서 한 행에 양쪽 끝으로 벌리고 둘 다 알약으로 만들었다. 무게는 다르다 —
// 등록은 골드 채움(이 카드가 존재하는 이유), 방향 전환은 테두리만(보조 이동).
// 둘 다 같은 알약이면 보조가 주만큼 중요해 보인다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/bus/domain/bus_card_style.dart';
import 'package:planroutine/features/bus/domain/bus_card_view.dart';
import 'package:planroutine/features/bus/domain/commute_direction.dart';
import 'package:planroutine/features/bus/presentation/widgets/bus_arrival_card.dart';

Future<void> _pumpNoStop(
  WidgetTester tester, {
  double widthDp = 390,
  VoidCallback? onRegister,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(widthDp * 3, 844 * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BusArrivalCard(
          view: const BusCardView(
            state: BusCardState.noStop,
            visible: [],
            hiddenCount: 0,
            fetchedAt: null,
          ),
          style: BusCardStyle.text,
          direction: CommuteDirection.toHome,
          stopName: '',
          expanded: true,
          onToggleExpanded: null,
          onFlipDirection: () {},
          onRegister: onRegister ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('정류장 미등록 카드의 하단 두 표적', () {
    testWidgets('한 행에서 좌: 방향 전환 · 우: 선택으로 갈라진다', (tester) async {
      await _pumpNoStop(tester);

      final flip = tester.getRect(find.byKey(BusArrivalCard.flipKey));
      final register = tester.getRect(find.byKey(BusArrivalCard.registerKey));

      expect(
        register.left,
        greaterThan(flip.right),
        reason: '겹치면 둘 다 오탭한다 — 새로고침과 방향 전환에 이미 적용한 규칙이다',
      );
      expect(
        (flip.center.dy - register.center.dy).abs(),
        lessThan(8),
        reason: '같은 행이어야 세로로 붙어 있던 원래 문제가 사라진다',
      );
    });

    testWidgets('손가락만 한 히트 영역 — 세로 44dp 이상', (tester) async {
      await _pumpNoStop(tester);

      for (final entry in {
        '방향 전환': BusArrivalCard.flipKey,
        '정류장 선택': BusArrivalCard.registerKey,
      }.entries) {
        final rect = tester.getRect(find.byKey(entry.value));
        expect(
          rect.height,
          greaterThanOrEqualTo(44),
          reason:
              '${entry.key}의 히트 높이가 ${rect.height} — 맨 텍스트(약 18dp)로 '
              '되돌아갔다',
        );
      }
    });

    // **보이는 것은 글씨, 누르는 것은 44dp.** 한때 알약(테두리·채움)으로 만들었다가
    // 작은 카드에 버튼 둘이 앉아 너무 두껍게 읽혀 되돌렸다(사용자 확인 2026-08-07).
    // 되돌릴 때 히트 영역까지 함께 잃기 쉬워서 — 그것이 원래 신고의 절반이었다 —
    // 장식이 없다는 것을 못박아 둔다. 크기는 위 테스트가 따로 지킨다.
    testWidgets('장식을 두르지 않는다 — 글씨 그대로여야 한다', (tester) async {
      await _pumpNoStop(tester);

      for (final entry in {
        '방향 전환': BusArrivalCard.flipKey,
        '정류장 선택': BusArrivalCard.registerKey,
      }.entries) {
        final box = tester.widget<Container>(
          find.descendant(
            of: find.byKey(entry.value),
            matching: find.byType(Container),
          ),
        );
        final deco = box.decoration as BoxDecoration?;
        expect(deco?.color, isNull, reason: '${entry.key}에 채움이 생겼다');
        expect(deco?.border, isNull, reason: '${entry.key}에 테두리가 생겼다');
      }
    });

    testWidgets('본문에는 같은 링크가 남아 있지 않다 — 표적이 둘이면 도로 헷갈린다', (tester) async {
      await _pumpNoStop(tester);

      expect(
        find.text(BusStrings.emptyNoStopAction),
        findsOneWidget,
        reason: '하단 알약 하나뿐이어야 한다(본문에도 그리면 둘이 된다)',
      );
      expect(
        find.text(BusStrings.emptyNoStop),
        findsOneWidget,
        reason: '안내 문구는 본문에 남는다',
      );
    });

    testWidgets('좁은 폭에서도 한 행에 들어간다', (tester) async {
      await _pumpNoStop(tester, widthDp: 320);

      expect(tester.takeException(), isNull, reason: '320dp에서 하단 행이 넘쳤다');
      final flip = tester.getRect(find.byKey(BusArrivalCard.flipKey));
      final register = tester.getRect(find.byKey(BusArrivalCard.registerKey));
      expect(register.left, greaterThan(flip.right));
    });

    testWidgets('선택을 누르면 콜백이 온다', (tester) async {
      var tapped = 0;
      await _pumpNoStop(tester, onRegister: () => tapped++);

      await tester.tap(find.byKey(BusArrivalCard.registerKey));
      await tester.pump();

      expect(tapped, 1);
    });
  });
}
