import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_settings_tiles.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_style_sheet.dart';
import 'package:planroutine/features/today/domain/stamp_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpTiles(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: StampSettingsTiles())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  StampSettings current(ProviderContainer container) =>
      container.read(stampSettingsProvider).requireValue;

  group('완료 도장 설정', () {
    testWidgets('기본값은 완료 도장 + 흐리게 켜짐', (tester) async {
      final container = await pumpTiles(tester);

      expect(current(container).style, SealStyle.complete);
      expect(current(container).dimPreviousStamps, isTrue);
    });

    // 모양 선택지 자체(전 모양 렌더 · 고르면 저장)의 검증은 시트로 옮겨 갔다 —
    // `stamp_style_sheet_test.dart` 참고. 여기 남는 것은 "행이 한 줄이고 현재값을
    // 보여주며 시트로 보낸다"까지다.
    testWidgets('현재 도장 이름이 한 줄에 보인다', (tester) async {
      await pumpTiles(tester);

      expect(find.byKey(StampSettingsTiles.styleTileKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(StampSettingsTiles.styleTileKey),
          matching: find.text(TodayStrings.sealComplete),
        ),
        findsOneWidget,
      );
    });

    testWidgets('누르면 도장 모양 시트가 열린다', (tester) async {
      await pumpTiles(tester);

      await tester.tap(find.byKey(StampSettingsTiles.styleTileKey));
      await tester.pumpAndSettle();

      expect(find.byType(StampStyleSheet), findsOneWidget);
    });

    testWidgets('시트에서 고른 모양이 행에 반영된다', (tester) async {
      // 두 위젯이 같은 provider를 보는지 — 행만 고쳐도, 시트만 고쳐도 깨진다.
      final container = await pumpTiles(tester);

      await tester.tap(find.byKey(StampSettingsTiles.styleTileKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(StampStyleSheet.optionKey(SealStyle.approve)),
      );
      await tester.pumpAndSettle();

      expect(current(container).style, SealStyle.approve);
      expect(
        find.descendant(
          of: find.byKey(StampSettingsTiles.styleTileKey),
          matching: find.text(TodayStrings.sealApprove),
        ),
        findsOneWidget,
      );
    });

    testWidgets('흐리게 스위치를 끄면 설정에 반영된다', (tester) async {
      final container = await pumpTiles(tester);

      await tester.tap(find.byKey(const Key('stamp_dim_switch')));
      await tester.pumpAndSettle();

      expect(current(container).dimPreviousStamps, isFalse);
    });
  });
}
