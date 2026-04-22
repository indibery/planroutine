import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/slide_hint_bar.dart' as shared;

/// 캘린더 화면 전용 슬라이드 힌트 바 — 공용 `SlideHintBar`를 prefKey와 라벨만 지정해 감쌈.
class CalendarSlideHintBar extends StatelessWidget {
  const CalendarSlideHintBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const shared.SlideHintBar(
      prefKey: 'calendar_slide_hint_dismissed',
      leftIcon: Icons.cloud_upload,
      leftText: CalendarStrings.swipeHintGoogle,
      leftColor: AppColors.inkGreen,
      rightIcon: Icons.check_circle,
      rightText: CalendarStrings.swipeHintComplete,
      rightColor: AppColors.gold,
    );
  }
}
