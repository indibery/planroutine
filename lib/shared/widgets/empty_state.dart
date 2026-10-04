import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// 목록이 비었을 때 — 아이콘 + 상태 한 줄 + 다음 행동 한 줄.
///
/// 입력 탭·휴지통·포스트잇·지도 기록이 아이콘 크기(64·48·없음)와 글자 크기(15·14·12)를
/// 저마다 다르게 그리고 있었다. 입력 탭 모양으로 맞춘다(2026-10-04 디자인 점검, 사용자 결정 A).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  /// 아이콘 크기는 하나다 — 화면마다 달랐던 것을 여기서 묶는다.
  static const double iconSize = 64;

  final IconData icon;
  final String title;

  /// 다음 행동. 할 일이 없는 빈 상태(삭제한 기록 등)는 생략한다.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: AppColors.faint),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.sub,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSizes.spacing4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: AppColors.faint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
