import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/import/presentation/widgets/photo_input_hero.dart';

/// 입력 탭 히어로의 누를 수 있는 것들은 **버튼**으로 읽혀야 한다.
///
/// `GestureDetector`·`InkWell`만 두면 실기 접근성 트리에서 `① 프롬프트`·
/// `② 붙여넣기`·CSV 카드가 그냥 `Text`로 잡혀, 누를 수 있다는 것도 종류 칩
/// 중 어느 쪽이 골라져 있는지도 알 수 없었다(2026-10-04 실측).
void main() {
  Future<void> pumpHero(WidgetTester tester, {VoidCallback? onCsv}) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PhotoInputHero(onOpenCsvImport: onCsv ?? () {}),
              ),
            ),
          ),
        ),
      );

  testWidgets('① 프롬프트·② 붙여넣기·CSV 카드가 이름 있는 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHero(tester);

    for (final label in [
      ImportStrings.heroStepCopy,
      ImportStrings.heroStepPaste,
      ImportStrings.heroCsvLink,
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('종류 칩은 기본으로 행사가 선택돼 있다고 말한다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHero(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel(ImportStrings.aiSourceEvent)),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(ImportStrings.aiSourceTask)),
      isSemantics(isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('CSV 카드의 시맨틱스 탭이 가져오기를 연다', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await pumpHero(tester, onCsv: () => opened++);

    tester.semantics.tap(find.semantics.byLabel(ImportStrings.heroCsvLink));
    expect(opened, 1);
    handle.dispose();
  });
}
