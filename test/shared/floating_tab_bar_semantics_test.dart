// test/shared/floating_tab_bar_semantics_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/shared/widgets/floating_tab_bar.dart';

/// 탭바 항목은 **이름 있는 버튼 + 선택 상태**로 읽혀야 한다.
///
/// `GestureDetector`만 두면 접근성 트리에 아이콘 글리프와 라벨이 따로 `Text`로
/// 잡혀, VoiceOver와 시뮬레이터 자동화(`snapshot_ui`) 모두 누를 대상을 0개로
/// 보고 지금 어느 탭인지도 알 수 없었다(2026-10-04 실측).
void main() {
  const labels = [
    AppStrings.tabToday,
    AppStrings.tabCalendar,
    AppStrings.tabSchedule,
    SettingsStrings.title,
  ];

  Future<List<int>> pumpBar(WidgetTester tester, {int current = 1}) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingTabBar(
            currentIndex: current,
            onTap: taps.add,
            tabs: [
              for (final l in labels)
                FloatingTabItem(
                  icon: Icons.circle_outlined,
                  activeIcon: Icons.circle,
                  label: l,
                ),
            ],
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('각 탭이 이름 있는 버튼이고 현재 탭만 선택 상태다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, current: 1);

    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(labels[i])),
        isSemantics(
          label: labels[i],
          isButton: true,
          isSelected: i == 1,
          hasTapAction: true,
        ),
        reason: '${labels[i]} 탭',
      );
    }
    handle.dispose();
  });

  testWidgets('시맨틱스 탭 동작이 그 탭으로 이동시킨다', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = await pumpBar(tester);

    tester.semantics.tap(find.semantics.byLabel(labels[2]));
    expect(taps, [2]);
    handle.dispose();
  });

  testWidgets('아이콘 글리프가 이름 없는 노드로 따로 잡히지 않는다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);

    // 탭 하나가 잎 노드 하나여야 한다. 실기 트리에서는 아이콘 글리프와 글자가
    // 각각 `Text` 요소로 잡혔다(2026-10-04). 위젯 테스트 트리에서는 수정 전에도
    // 이미 잎 노드라 이 검사가 그 분리를 재현하지 못한다 — 수정 뒤 구조를 고정하는
    // 가드로만 둔다.
    for (final l in labels) {
      final node = tester.getSemantics(find.bySemanticsLabel(l));
      expect(node.childrenCount, 0, reason: l);
      expect(node.label, l, reason: l);
    }
    handle.dispose();
  });
}
