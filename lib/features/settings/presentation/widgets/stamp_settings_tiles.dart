import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../today/domain/stamp_settings.dart';
import '../providers/stamp_settings_provider.dart';
import 'stamp_style_sheet.dart';

/// 완료 도장 설정 — 도장 모양 한 줄 + "이미 찍은 도장 흐리게" 스위치.
///
/// **모양 선택지는 이 화면에 두지 않는다.** 칩 `Wrap`으로 두던 시절 도장이 4종이
/// 되자 라벨 옆에 못 들어가 줄이 둘로 갈라졌다 — 같은 화면의 `화면 테마`는 라벨과
/// 세그먼트가 한 줄이라, 한 화면에 행 문법이 두 종류가 됐다.
///
/// 규칙: **개수가 고정된 설정은 세그먼트**(화면 테마 3종),
/// **늘어나는 설정은 시트**([StampStyleSheet]). 도장은 늘어나는 축이라 5번째가
/// 들어와도 이 화면은 변하지 않는다 — 시트가 자기 높이만 한 줄 늘린다.
///
/// (이전 규칙은 "늘어나는 설정은 칩"이었다. 칩은 개수 제한이 없어 세그먼트보다
/// 나았지만, 라벨과 같은 줄에 못 서는 것은 마찬가지였다.)
class StampSettingsTiles extends ConsumerWidget {
  const StampSettingsTiles({super.key});

  static const styleTileKey = Key('stamp_style_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(stampSettingsProvider).valueOrNull ?? StampSettings.defaults;
    final notifier = ref.read(stampSettingsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: styleTileKey,
          leading: Icon(Icons.approval_outlined, color: AppColors.primary),
          title: Text(
            SettingsStrings.stampStyleLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.style.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSizes.spacing4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => StampStyleSheet.show(context),
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
