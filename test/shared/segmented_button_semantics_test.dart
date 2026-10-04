import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/shared/widgets/segmented_button_semantics.dart';

import '../helpers/source_scan.dart';

/// Flutter `SegmentedButton`의 세그먼트는 시뮬레이터 자동화 한쪽에서 이름이 빠진다.
///
/// Flutter 트리에는 이름이 있다(`MergeSemantics`로 합친 노드에 `label`·버튼·선택이 다 있다).
/// 그런데 mobile MCP(XCUITest)는 그 노드를 이름 없는 `Button selected`로 읽었다 — 이름을
/// `Semantics`·`Text(semanticsLabel:)`로 바꿔 줘도 같았고, 같은 플래그를 단 **직접 만든
/// 잎 노드**만 이름이 보였다(2026-10-04 실측). 그래서 겉모양은 `SegmentedButton`에 두고
/// 시맨틱스만 세그먼트마다 잎 노드로 겹쳐 그린다.
void main() {
  Future<List<Set<String>>> pump(
    WidgetTester tester, {
    Set<String> selected = const {'업무'},
  }) async {
    final changes = <Set<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SegmentedButtonSemantics<String>(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: '업무', label: Text('업무')),
                  ButtonSegment(value: '행사', label: Text('행사')),
                ],
                selected: selected,
                onSelectionChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('세그먼트마다 이름·버튼·선택을 가진 잎 노드다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    final work = tester.getSemantics(find.bySemanticsLabel('업무'));
    expect(
      work,
      isSemantics(
        label: '업무',
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(work.childrenCount, 0);
    expect(
      tester.getSemantics(find.bySemanticsLabel('행사')),
      isSemantics(label: '행사', isButton: true, isSelected: false),
    );
    // SegmentedButton 자체의 노드는 숨긴다 — 남기면 이름 없는 버튼이 함께 잡힌다.
    expect(find.bySemanticsLabel('업무'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('잎 노드가 보이는 세그먼트 자리에 겹친다', (tester) async {
    await pump(tester);

    for (final label in ['업무', '행사']) {
      final nodeRect = tester.getRect(find.bySemanticsLabel(label));
      final textCenter = tester.getCenter(find.text(label));
      expect(
        nodeRect.contains(textCenter),
        isTrue,
        reason: '$label 노드 $nodeRect가 글자 중심 $textCenter를 덮어야 한다',
      );
    }
  });

  testWidgets('시맨틱스 탭이 그 세그먼트를 고른다', (tester) async {
    final handle = tester.ensureSemantics();
    final changes = await pump(tester);

    tester.semantics.tap(find.semantics.byLabel('행사'));
    expect(changes, [
      {'행사'},
    ]);
    handle.dispose();
  });

  testWidgets('꽉 찬 폭에서도 겉모양이 그대로이고 노드가 자기 세그먼트를 덮는다', (tester) async {
    // `Stack`의 기본 fit(loose)이 부모의 꽉 찬 폭을 풀면 SegmentedButton이 글자 크기만큼
    // 쪼그라들고, 노드는 폭 전체로 나뉘어 실제 세그먼트와 어긋났다 — 지도 기록 구분·상태
    // (`ListView`)와 쪽지 종류(`Column(stretch)`)가 그랬다(verifier가 잡았다, 2026-10-04).
    // 위 테스트들은 `Center` 안이라 폭이 늘 느슨해서 이 경우를 못 봤다.
    SegmentedButton<String> segmented() => SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: '생활지도', label: Text('생활지도')),
        ButtonSegment(value: '교육활동 침해', label: Text('교육활동 침해')),
      ],
      selected: const {'생활지도'},
      onSelectionChanged: (_) {},
    );
    Future<double> buttonWidth(Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ListView(children: [child])),
        ),
      );
      return tester.getSize(find.byType(SegmentedButton<String>)).width;
    }

    final bare = await buttonWidth(segmented());
    final wrapped = await buttonWidth(
      SegmentedButtonSemantics<String>(
        child: segmented(),
      ),
    );
    expect(wrapped, bare, reason: '감싸도 버튼 폭이 같아야 한다');

    for (final label in ['생활지도', '교육활동 침해']) {
      expect(
        tester
            .getRect(find.bySemanticsLabel(label))
            .contains(tester.getCenter(find.text(label))),
        isTrue,
        reason: '$label 노드가 자기 글자 중심을 덮어야 한다',
      );
    }
  });

  testWidgets('겹친 노드가 손가락 탭을 가로채지 않는다', (tester) async {
    final changes = await pump(tester);

    await tester.tap(find.text('행사'));
    expect(changes, [
      {'행사'},
    ]);
  });

  test('lib의 SegmentedButton은 전부 SegmentedButtonSemantics로 감싼다', () {
    final missing = <String>[];
    for (final file in libDartFiles()) {
      final code = file.readAsLinesSync().map(stripLineComment).join('\n');
      final buttons = RegExp(r'\bSegmentedButton<').allMatches(code).length;
      final wrapped = RegExp(
        r'SegmentedButtonSemantics<\w+>\(\s*child:\s*SegmentedButton<',
      ).allMatches(code).length;
      // 래퍼 정의 파일은 `SegmentedButton<T>`를 타입으로만 쓴다.
      if (file.path.endsWith('segmented_button_semantics.dart')) continue;
      if (buttons != wrapped) {
        missing.add('${file.path}: SegmentedButton $buttons개 중 $wrapped개만 감쌈');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
