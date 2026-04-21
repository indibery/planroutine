import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/slide_hint_bar.dart' as shared;

/// 일정 화면 전용 슬라이드 힌트 바 — 공용 `SlideHintBar`를 prefKey와 라벨만 지정해 감쌈.
class SlideHintBar extends StatelessWidget {
  const SlideHintBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const shared.SlideHintBar(
      prefKey: 'schedule_slide_hint_dismissed',
      leftIcon: Icons.check_circle,
      leftText: AppStrings.scheduleSlideHintConfirm,
      leftColor: AppColors.inkGreen,
      rightIcon: Icons.delete_outline,
      rightText: AppStrings.scheduleSlideHintDelete,
      rightColor: AppColors.inkRed,
    );
  }
}
