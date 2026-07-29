import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_colors.dart';
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
  String stopName = '수원시청',
  // false면 `onToggleExpanded`로 null을 넘긴다 = 접을 수 없는 카드(정류장 미등록).
  bool collapsible = true,
}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BusArrivalCard(
        view: view,
        style: style,
        direction: CommuteDirection.toWork,
        stopName: stopName,
        expanded: expanded,
        onToggleExpanded: collapsible ? (onToggle ?? () {}) : null,
        onFlipDirection: onFlip ?? () {},
      ),
    ),
  ));
}

void main() {
  // 320pt = 화면 확대를 켠 아이폰(390pt 기기가 이 폭으로 렌더)이고, 배포 타깃 iOS 13이
  // 포함하는 SE 1세대의 폭이기도 하다. `stale`의 기준시각이 `07:32 기준 · 갱신 실패`로
  // 길어지면 제목줄의 고정 요소 셋이 본문 폭을 넘어, `Expanded`인 정류장 이름을 0으로
  // 줄여도 21px이 넘쳤다(`ok`는 넘치지 않았다 — 그래서 이 가드는 stale로 잡아야 한다).
  group('좁은 폭 — 제목줄이 넘치지 않는다', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        view: _view(
          state: BusCardState.stale,
          fetchedAt: DateTime(2026, 7, 29, 7, 32),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('320pt에서 stale 제목줄이 넘치지 않고 이모지를 뗀다', (tester) async {
      await pumpAt(tester, 320);
      expect(tester.takeException(), isNull, reason: '오버플로가 없어야 한다');
      expect(find.text('출근'), findsOneWidget);
      expect(find.text('🏠→🏫 출근'), findsNothing,
          reason: '이모지가 장식이고 말뜻은 문자가 진다 — 줄일 것은 이모지다');
      expect(find.text('07:32 기준 · 갱신 실패'), findsOneWidget,
          reason: '신선도 고백은 좁은 폭에서도 잘리지 않는다');
    });

    testWidgets('375pt에서는 1픽셀도 바뀌지 않는다', (tester) async {
      await pumpAt(tester, 375);
      expect(tester.takeException(), isNull);
      expect(find.text('🏠→🏫 출근'), findsOneWidget,
          reason: '문턱 위에서는 원래 라벨을 그대로 쓴다');
    });
  });

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

  group('정류장 미등록 카드 — 기능을 켠 사용자가 가장 먼저 보는 화면', () {
    testWidgets('이름이 비면 매달린 구분점이 없다', (tester) async {
      await _pump(
        tester,
        view: _view(state: BusCardState.noStop, items: const []),
        stopName: '',
        collapsible: false,
      );
      expect(find.text('· '), findsNothing,
          reason: '제목줄이 `출근   · `로 끝나면 잘린 것처럼 보인다');
      expect(find.textContaining('·'), findsNothing);
      expect(find.text('🏠→🏫 출근'), findsOneWidget);
    });

    testWidgets('접을 수 없으면 chevron도 탭 대상도 없다', (tester) async {
      await _pump(
        tester,
        view: _view(state: BusCardState.noStop, items: const []),
        stopName: '',
        collapsible: false,
      );
      expect(find.byIcon(Icons.expand_less), findsNothing,
          reason: '눌러도 아무 일이 없는데 스크린리더가 `접기`라고 읽는다');
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byKey(BusArrivalCard.headerKey), findsNothing);
      // 등록 유도와 방향 토글은 그대로 남는다 — 카드가 죽는 것이 아니다.
      expect(find.text('정류장을 등록하면 도착시간이 보여요'), findsOneWidget);
      expect(find.textContaining('퇴근 보기'), findsOneWidget);
    });

    testWidgets('이름이 있으면 구분점과 chevron이 그대로다', (tester) async {
      await _pump(tester, view: _view());
      expect(find.text('· 수원시청'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });
  });

  group('모양을 바꿔도 같은 정보가 보인다 — 두 본문의 공유 계약', () {
    // 5노선 정류장 + 필터 없음(= 확인 시트의 기본 저장값)에서 상한이 3개를 남긴 모습.
    const visible = [
      BusArrival(routeId: 'A', routeNo: '720', arrMin: 2),
      BusArrival(routeId: 'B', routeNo: '150', arrMin: 5),
      BusArrival(routeId: 'C', routeNo: '92', arrMin: 9),
    ];

    // **모양별로 따로 쓰지 않고 순회한다.** `hiddenCount`가 `간단히`에만 있었던 것이
    // I5의 원인이므로, 새 모양을 더할 때 자동으로 같은 계약이 걸리게 둔다.
    for (final style in BusCardStyle.values) {
      testWidgets('${style.label} — 감춘 개수를 말한다', (tester) async {
        await _pump(tester, style: style, view: _view(items: visible, hidden: 2));
        expect(find.text('2개 더'), findsOneWidget,
            reason: '한 모양에만 없으면 그 모양을 고른 사용자는 이 정류장에 '
                '버스가 3대만 온다고 읽는다 — 자기 노선이 4·5번째면 포기한다');
      });

      testWidgets('${style.label} — 보이는 노선번호가 모두 있다', (tester) async {
        await _pump(tester, style: style, view: _view(items: visible, hidden: 2));
        for (final a in visible) {
          expect(find.textContaining(a.routeNo), findsWidgets,
              reason: '${a.routeNo}번이 ${style.label}에서 사라졌다');
        }
      });

      testWidgets('${style.label} — 감춘 개수가 0이면 그 줄이 없다', (tester) async {
        await _pump(tester, style: style, view: _view(items: visible));
        expect(find.textContaining('개 더'), findsNothing);
      });
    }

    testWidgets('N개 더는 골드가 아니다 — 카드 안 골드는 전부 탭 대상이다', (tester) async {
      // `다시 시도`·`정류장 등록`·`퇴근 보기`가 모두 골드 + 탭이라 카드 안에서
      // 골드 = 행동으로 굳었다. 탭할 수 없는 라벨에 같은 색을 쓰면 눌러도 아무 일이
      // 없는 링크가 된다(리뷰 M2).
      await _pump(tester, view: _view(items: visible, hidden: 2));
      final more = tester.widget<Text>(find.text('2개 더'));
      expect(more.style?.color, isNot(AppColors.gold));
      expect(more.style?.color, AppColors.sub);
    });
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
