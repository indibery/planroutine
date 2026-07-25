import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../providers/stamp_settings_provider.dart';

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
        _styleRow(settings, notifier),
        SwitchListTile(
          key: const Key('stamp_dim_switch'),
          value: settings.dimPreviousStamps,
          onChanged: notifier.setDimPreviousStamps,
          activeThumbColor: AppColors.onGold,
          activeTrackColor: AppColors.goldFill,
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

  Widget _styleRow(StampSettings settings, StampSettingsNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          Icon(Icons.approval_outlined, color: AppColors.primary),
          const SizedBox(width: AppSizes.spacing16),
          Text(
            SettingsStrings.stampStyleLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          SegmentedButton<SealStyle>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // 채움(선택)은 goldFill + onGold — 테마 전환 시 대비를 함께 맞춘다.
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.onGold
                      : AppColors.sub),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.goldFill
                      : Colors.transparent),
              side: WidgetStatePropertyAll(
                BorderSide(color: AppColors.lineStrong, width: 0.5),
              ),
            ),
            segments: [
              for (final style in SealStyle.values)
                ButtonSegment(value: style, label: Text(style.label)),
            ],
            selected: {settings.style},
            onSelectionChanged: (selection) =>
                notifier.setStyle(selection.first),
          ),
        ],
      ),
    );
  }
}
