import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../providers/stamp_settings_provider.dart';
import 'segmented_setting_row.dart';

/// 완료 도장 설정 — 도장 모양 선택 + "이미 찍은 도장 흐리게" 스위치.
class StampSettingsTiles extends ConsumerWidget {
  const StampSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(stampSettingsProvider).valueOrNull ?? StampSettings.defaults;
    final notifier = ref.read(stampSettingsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedSettingRow<SealStyle>(
          icon: Icons.approval_outlined,
          label: SettingsStrings.stampStyleLabel,
          segments: [
            for (final style in SealStyle.values)
              ButtonSegment(value: style, label: Text(style.label)),
          ],
          selected: settings.style,
          onChanged: notifier.setStyle,
        ),
        SwitchListTile(
          key: const Key('stamp_dim_switch'),
          value: settings.dimPreviousStamps,
          onChanged: notifier.setDimPreviousStamps,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
          ),
          title: Text(
            SettingsStrings.stampDimLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            SettingsStrings.stampDimDescription,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
