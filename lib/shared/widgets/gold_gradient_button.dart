import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_gradients.dart';
import 'button_semantics.dart';

class GoldGradientButton extends StatelessWidget {
  const GoldGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.height = AppSizes.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 버튼으로 읽히게 한 노드로 묶는다 — `GestureDetector`만 두면 실기 트리에서
    // `저장`이 그냥 글자로 잡혔다(2026-10-04).
    return ButtonSemantics.gesture(
      label: label,
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
          decoration: BoxDecoration(
            gradient: enabled ? AppGradients.gold : null,
            color: enabled ? null : AppColors.goldMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.onGold, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
