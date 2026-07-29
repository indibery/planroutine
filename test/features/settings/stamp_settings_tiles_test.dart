import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/settings/presentation/providers/stamp_settings_provider.dart';
import 'package:planroutine/features/settings/presentation/widgets/stamp_settings_tiles.dart';
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

    testWidgets('세 가지 도장 모양이 모두 선택지로 보인다', (tester) async {
      await pumpTiles(tester);

      expect(find.text(TodayStrings.sealComplete), findsOneWidget);
      expect(find.text(TodayStrings.sealApprove), findsOneWidget);
      expect(find.text(TodayStrings.sealPanda), findsOneWidget);
    });

    testWidgets('결재를 고르면 설정에 저장된다', (tester) async {
      final container = await pumpTiles(tester);

      await tester.tap(find.text(TodayStrings.sealApprove));
      await tester.pumpAndSettle();

      expect(current(container).style, SealStyle.approve);
    });

    testWidgets('좋아요를 고르면 설정에 저장된다', (tester) async {
      final container = await pumpTiles(tester);

      await tester.tap(find.text(TodayStrings.sealPanda));
      await tester.pumpAndSettle();

      expect(current(container).style, SealStyle.panda);
    });

    testWidgets('흐리게 스위치를 끄면 설정에 반영된다', (tester) async {
      final container = await pumpTiles(tester);

      await tester.tap(find.byKey(const Key('stamp_dim_switch')));
      await tester.pumpAndSettle();

      expect(current(container).dimPreviousStamps, isFalse);
    });
  });
}
