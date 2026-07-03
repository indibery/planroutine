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

    test('light(쿨 미스트) 적용 시 배경 화이트블루, 본문 네이비, 딥골드 액센트', () {
      AppColors.applyBrightness(Brightness.light);
      expect(AppColors.background, const Color(0xFFF6F8FB));
      expect(AppColors.textPrimary, const Color(0xFF17253D));
      // 배경 위 딥골드 액센트(텍스트/아이콘/토요일)
      expect(AppColors.gold, const Color(0xFF9A7415));
      // 채움은 밝은 골드 + 그 위 네이비
      expect(AppColors.goldFill, const Color(0xFFE6B95C));
      expect(AppColors.onGold, const Color(0xFF17253D));
    });

    test('dark 적용 시 배경이 네이비, 본문이 크림빛', () {
      AppColors.applyBrightness(Brightness.dark);
      expect(AppColors.background, const Color(0xFF0A1628));
      expect(AppColors.textPrimary, const Color(0xFFF0EAD9));
      expect(AppColors.gold, const Color(0xFFE0B96A));
      // 다크는 채움=액센트 골드, 위에 네이비
      expect(AppColors.goldFill, const Color(0xFFE0B96A));
      expect(AppColors.onGold, const Color(0xFF0A1628));
    });
  });
}
