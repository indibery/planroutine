import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../providers/stamp_settings_provider.dart';
import '../../../../shared/widgets/pill_chip.dart';

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
        _StyleRow(selected: settings.style, onChanged: notifier.setStyle),
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

/// 도장 모양 선택 — 라벨 한 줄 + 아래에 칩.
///
/// **`SegmentedSettingRow`를 쓰지 않는다.** 그 위젯은 한 줄에 라벨과 세그먼트를 나란히
/// 놓는데, 도장이 4종이 되자 320pt에서 **33px 넘쳤다**(폭 훑기가 잡았다).
///
/// 2줄 세그먼트로 고칠 수도 있었지만 **도장 모양은 늘어나는 축**이다(판다를 넣었고
/// 강아지도 후보다). 4개는 되고 5개는 또 넘친다. 칩 `Wrap`은 개수 제한이 없다.
///
/// 그래서 이 화면에는 두 모양이 함께 있다 — 규칙은 이것이다:
/// **개수가 고정된 설정은 세그먼트**(화면 테마 3종), **늘어나는 설정은 칩**(도장 모양).
/// 리포의 선택 가능한 칩은 전부 `PillChip`이므로 입력 탭 히어로와도 같은 모양이다.
class _StyleRow extends StatelessWidget {
  const _StyleRow({required this.selected, required this.onChanged});

  final SealStyle selected;
  final ValueChanged<SealStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `SegmentedSettingRow`와 같은 여백 — 위아래 행과 왼쪽 선이 맞아야 한 섹션으로 읽힌다.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            ],
          ),
          const SizedBox(height: AppSizes.spacing8),
          Wrap(
            spacing: AppSizes.spacing8,
            runSpacing: AppSizes.spacing4,
            children: [
              for (final style in SealStyle.values)
                PillChip(
                  label: style.label,
                  selected: style == selected,
                  onTap: () => onChanged(style),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
