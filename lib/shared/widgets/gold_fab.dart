import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_gradients.dart';
import 'button_semantics.dart';

/// 골드 그라디언트 원형 FAB — 캘린더 탭과 오늘 탭이 공유한다.
///
/// 두 탭 모두 "일정 추가" 진입점이라 같은 위젯을 써서 생김새가 어긋나지 않게 한다.
class GoldFab extends StatelessWidget {
  const GoldFab({super.key, required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;

  /// 버튼 이름. 말풍선(`tooltip`)으로 주지 않는다 — `no_tooltip_guard_test.dart` 참고.
  final String semanticLabel;

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
        // `InkWell`은 탭 동작만 주고 버튼 표시를 붙이지 않는다 — 실기 트리에서
        // 이 FAB이 버튼이 아닌 이름 없는 요소로 잡혔다.
        child: ButtonSemantics(
          label: semanticLabel,
          onTap: onTap,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(Icons.add, color: AppColors.onGold, size: 26),
          ),
        ),
      ),
    );
  }
}
