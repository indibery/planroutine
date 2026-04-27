import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/slide_hint_bar.dart' as shared;
import '../../../settings/presentation/providers/calendar_target_provider.dart';

/// 캘린더 화면 슬라이드 힌트 — target에 따라 라벨 변경/숨김.
///
/// - target == none: 힌트 바 자체 숨김 (외부 저장 슬라이드 비활성)
/// - target == google: "오른쪽으로 밀기 — Google 저장"
/// - target == device: "오른쪽으로 밀기 — 기기 저장"
class CalendarSlideHintBar extends ConsumerWidget {
  const CalendarSlideHintBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFeatures.googleCalendarEnabled) {
      return const SizedBox.shrink();
    }

    final target = ref.watch(
      calendarTargetProvider
          .select((a) => a.valueOrNull ?? CalendarTarget.none),
    );
    if (target == CalendarTarget.none) {
      return const SizedBox.shrink();
    }

    final leftText = target == CalendarTarget.device
        ? CalendarIntegrationStrings.swipeHintDevice
        : CalendarStrings.swipeHintGoogle;

    return shared.SlideHintBar(
      prefKey: 'calendar_slide_hint_dismissed',
      leftIcon: Icons.cloud_upload,
      leftText: leftText,
      leftColor: AppColors.inkGreen,
      rightIcon: Icons.check_circle,
      rightText: CalendarStrings.swipeHintComplete,
      rightColor: AppColors.gold,
    );
  }
}
