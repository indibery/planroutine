import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/shared/widgets/button_semantics.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget w) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: w)),
    ),
  );

  testWidgets('이름 있는 버튼 잎 노드이고 안의 글자는 숨긴다', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await pump(
      tester,
      ButtonSemantics(
        label: '정류장 선택',
        onTap: () => tapped++,
        child: GestureDetector(
          onTap: () => tapped++,
          child: const Column(children: [Text('정류장'), Text('선택')]),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('정류장 선택'));
    expect(
      node,
      isSemantics(
        label: '정류장 선택',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(node.childrenCount, 0);
    expect(find.bySemanticsLabel('정류장'), findsNothing);

    tester.semantics.tap(find.semantics.byLabel('정류장 선택'));
    expect(tapped, 1);
    handle.dispose();
  });

  testWidgets('선택·켜짐 상태를 말한다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      Column(
        children: [
          ButtonSemantics(
            label: '행사',
            onTap: () {},
            selected: true,
            child: const Text('행사'),
          ),
          ButtonSemantics(
            label: '완료 취소',
            onTap: () {},
            checked: true,
            child: const Text('○'),
          ),
        ],
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('행사')),
      isSemantics(isSelected: true, hasSelectedState: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('완료 취소')),
      isSemantics(isChecked: true, hasCheckedState: true),
    );
    handle.dispose();
  });

  testWidgets('onTap이 없으면 비활성 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const ButtonSemantics(label: '새로고침', onTap: null, child: Text('↻')),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('새로고침')),
      isSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });
}
