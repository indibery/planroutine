import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/theme_mode_provider.dart';

/// 화면 테마 선택 타일 — 시스템/밝게/어둡게 세그먼트.
class ThemeModeTile extends ConsumerWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          Icon(Icons.brightness_6_outlined, color: AppColors.primary),
          const SizedBox(width: AppSizes.spacing16),
          Text(
            SettingsStrings.themeLabel,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          SegmentedButton<ThemeMode>(
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
              // 채움(선택) 세그먼트는 goldFill + onGold — 라이트에서 gold(딥골드)를
              // 채움에 쓰면 navy 텍스트와 대비가 낮다(3.57:1). goldFill로 8.37:1.
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
            selected: {mode},
            onSelectionChanged: (sel) {
              ref.read(themeModeProvider.notifier).set(sel.first);
            },
          ),
        ],
      ),
    );
  }
}
