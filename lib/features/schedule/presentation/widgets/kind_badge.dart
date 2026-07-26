import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entry_kind.dart';

/// 업무 / 행사 배지 — 입력 탭 검토 목록과 캘린더 목록이 공유한다.
///
/// 옅은배경(15%) + 진한글씨 형이라 다크/라이트 양쪽에서 대비가 안정적이다.
/// 골드는 오늘·중요 전용이라 쓰지 않는다.
///
/// `shared/widgets/`가 아니라 schedule feature에 두는 이유: 이 배지는 [EntryKind]에
/// 종속인데 `shared/widgets/` 아래 어떤 위젯도 `features/`를 import 하지 않는다.
/// 캘린더는 이미 schedule 도메인에 의존하므로(calendar_event.dart) 여기서 가져다 쓴다.
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});

  final EntryKind kind;

  @override
  Widget build(BuildContext context) {
    final color = kind == EntryKind.event ? AppColors.info : AppColors.sub;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
