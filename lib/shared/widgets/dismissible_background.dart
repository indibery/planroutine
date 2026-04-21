import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// `Dismissible` 위젯의 배경 레이어 공용 위젯.
///
/// 좌/우 슬라이드 시 드러나는 액션 라벨(아이콘 + 텍스트)을 정렬 위치에 표시한다.
class DismissibleBackground extends StatelessWidget {
  const DismissibleBackground({
    super.key,
    required this.accent,
    required this.icon,
    required this.label,
    required this.alignment,
    this.bg = AppColors.navySoft,
    this.verticalMargin = AppSizes.spacing8,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final AlignmentGeometry alignment;
  final Color bg;
  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: verticalMargin,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
