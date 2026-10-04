// test/shared/pill_chip_semantics_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';

/// `PillChip`은 사용처 전부가 고르는 칩이다(입력 탭 종류·버스 도시·지역).
/// 선택 여부가 색과 체크 아이콘으로만 보이면 VoiceOver와 시뮬레이터 자동화가
/// 지금 무엇이 골라져 있는지 읽지 못한다.
void main() {
  Future<void> pumpChips(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            PillChip(label: '행사', selected: true, onTap: () {}),
            PillChip(label: '업무', onTap: () {}),
          ],
        ),
      ),
    ),
  );

  testWidgets('이름 있는 버튼이고 선택 상태를 말한다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpChips(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('행사')),
      isSemantics(
        label: '행사',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('업무')),
      isSemantics(
        label: '업무',
        isButton: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('시맨틱스 탭이 onTap을 부른다', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PillChip(label: '업무', onTap: () => tapped++),
        ),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('업무'));
    expect(tapped, 1);
    handle.dispose();
  });
}
