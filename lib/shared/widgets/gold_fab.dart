import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_gradients.dart';

/// 골드 그라디언트 원형 FAB — 캘린더 탭과 오늘 탭이 공유한다.
///
/// 두 탭 모두 "일정 추가" 진입점이라 같은 위젯을 써서 생김새가 어긋나지 않게 한다.
class GoldFab extends StatelessWidget {
  const GoldFab({super.key, required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.fabSize,
      height: AppSizes.fabSize,
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: switch (tooltip) {
            final String message => Tooltip(message: message, child: _icon()),
            null => _icon(),
          },
        ),
      ),
    );
  }

  Widget _icon() => Icon(Icons.add, color: AppColors.onGold, size: 26);
}
