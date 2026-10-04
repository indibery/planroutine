import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'button_semantics.dart';

/// 날짜·시각처럼 눌러서 고르는 값 칸 — `라벨 … 값 [아이콘]` 한 줄 테두리 타일.
///
/// 일정 편집 시트에만 있던 모양이다. 지도 기록은 같은 일을 골드 테두리 알약 버튼으로
/// 하고 있어 한 앱에 날짜 입력이 두 모양이었다(2026-10-04 디자인 점검).
class PickerFieldTile extends StatelessWidget {
  const PickerFieldTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonSemantics.gesture(
      label: '$label, $value',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSizes.spacing12),
            // 좁은 폭(320pt)에서는 값이 남은 자리에 맞춰 줄어든다 — 라벨과 아이콘은 그대로.
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Icon(icon, size: AppSizes.iconSmall, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
