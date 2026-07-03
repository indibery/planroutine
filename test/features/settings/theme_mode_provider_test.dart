import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/settings/presentation/providers/theme_mode_provider.dart';

void main() {
  group('themeModeProvider — 저장/로드', () {
    test('기본값은 시스템', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(themeModeProvider.future);
      expect(mode, ThemeMode.system);
    });

    test('저장된 light 값을 로드', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(themeModeProvider.future);
      expect(mode, ThemeMode.light);
    });

    test('set(dark) 후 SharedPreferences에 저장되고 상태 갱신', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.future);
      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);

      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });

  group('AppColors.applyBrightness — 팔레트 전환', () {
    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    test('light 적용 시 배경이 크림, 본문이 네이비', () {
      AppColors.applyBrightness(Brightness.light);
      expect(AppColors.background, const Color(0xFFF4EFE3));
      expect(AppColors.textPrimary, const Color(0xFF182A44));
      // 딥골드 액센트
      expect(AppColors.gold, const Color(0xFF8A6210));
    });

    test('dark 적용 시 배경이 네이비, 본문이 크림빛', () {
      AppColors.applyBrightness(Brightness.dark);
      expect(AppColors.background, const Color(0xFF0A1628));
      expect(AppColors.textPrimary, const Color(0xFFF0EAD9));
      expect(AppColors.gold, const Color(0xFFE0B96A));
    });
  });
}
