import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_style_sheet.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';
import 'package:planroutine/features/today/presentation/widgets/completion_seal.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// 시트를 연 상태로 만든다. 여는 버튼을 하나 두고 눌러 **실제 경로를 탄다** —
  /// 시트 본문만 pump하면 `show()`의 `useSafeArea` 같은 설정이 검증에서 빠진다.
  Future<ProviderContainer> openSheet(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StampStyleSheet.show(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return container;
  }

  StampSettings current(ProviderContainer container) =>
      container.read(stampSettingsProvider).requireValue;

  group('도장 모양 시트', () {
    testWidgets('모든 도장 모양이 선택지로 있다', (tester) async {
      // 가드 — 새 모양을 SealStyle에 추가하고 시트에 빠뜨리는 것을 막는다.
      // 개수를 숫자로 박지 않는다(박으면 추가할 때마다 테스트만 고치고 넘어간다).
      await openSheet(tester);

      for (final style in SealStyle.values) {
        expect(
          find.byKey(StampStyleSheet.optionKey(style)),
          findsOneWidget,
          reason: '${style.name} 선택지가 시트에 없다',
        );
      }
    });

    testWidgets('선택지마다 실제 도장이 미리보기로 그려진다', (tester) async {
      // 라벨만으로는 모양을 알 수 없다 — 시트의 존재 이유가 이 미리보기다.
      await openSheet(tester);

      expect(
        find.byType(CompletionSeal),
        findsNWidgets(SealStyle.values.length),
      );
    });

    testWidgets('제목이 보인다', (tester) async {
      await openSheet(tester);

      expect(find.text(SettingsStrings.stampStyleSheetTitle), findsOneWidget);
    });

    testWidgets('고르면 저장되고 시트가 닫힌다', (tester) async {
      final container = await openSheet(tester);

      await tester.tap(find.byKey(StampStyleSheet.optionKey(SealStyle.gecko)));
      await tester.pumpAndSettle();

      expect(current(container).style, SealStyle.gecko);
      expect(find.byType(StampStyleSheet), findsNothing);
    });

    testWidgets('선택된 칸에만 체크가 있다', (tester) async {
      // 색만으로 표시하지 않는다 — 비색상 단서가 하나 있어야 한다.
      await openSheet(tester);

      expect(
        find.descendant(
          of: find.byKey(StampStyleSheet.optionKey(SealStyle.complete)),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(StampStyleSheet.optionKey(SealStyle.gecko)),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });
  });
}
