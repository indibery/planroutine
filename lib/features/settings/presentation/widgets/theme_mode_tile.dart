import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../providers/theme_mode_provider.dart';
import 'segmented_setting_row.dart';

/// 화면 테마 선택 타일 — 시스템/밝게/어둡게 세그먼트.
class ThemeModeTile extends ConsumerWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return SegmentedSettingRow<ThemeMode>(
      icon: Icons.brightness_6_outlined,
      label: SettingsStrings.themeLabel,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(SettingsStrings.themeSystem),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text(SettingsStrings.themeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(SettingsStrings.themeDark),
        ),
      ],
      selected: mode,
      onChanged: (next) => ref.read(themeModeProvider.notifier).set(next),
    );
  }
}
