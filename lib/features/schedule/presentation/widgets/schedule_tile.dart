import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/dismissible_background.dart';
import '../../domain/schedule.dart';
import 'category_label.dart';

/// 일정 항목 카드
class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.schedule,
    required this.onConfirm,
    required this.onDelete,
    required this.onTap,
  });

  final Schedule schedule;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('schedule_${schedule.id}'),
      // 기본 0.4 → 0.2/0.25로 낮춰 더 짧은 스와이프로 반응
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.2,
        DismissDirection.endToStart: 0.25,
      },
      movementDuration: const Duration(milliseconds: 150),
      background: const DismissibleBackground(
        accent: AppColors.inkGreen,
        icon: Icons.check_circle_outline,
        label: ScheduleStrings.confirm,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const DismissibleBackground(
        accent: AppColors.inkRed,
        icon: Icons.delete_outline,
        label: ScheduleStrings.delete,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 이미 확정된 항목은 재슬라이드 시 무시 (C6)
          if (schedule.status == ScheduleStatus.confirmed) return false;
          onConfirm();
          return false;
        }
        // 삭제 방향은 애니메이션을 허용하고 실제 삭제는 onDismissed에서 처리
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing4,
        ),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(AppSizes.radius14),
          border: Border.all(color: AppColors.line, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius14),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            child: Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (schedule.status == ScheduleStatus.confirmed) ...[
                            _buildConfirmedBadge(),
                            const SizedBox(width: AppSizes.spacing8),
                          ],
                          Expanded(
                            child: Text(
                              schedule.title,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.sub,
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                          Text(
                            _formatDate(schedule.scheduledDate),
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (schedule.category != null) ...[
                  const SizedBox(width: AppSizes.spacing8),
                  _buildCategoryBadge(schedule.category ?? ''),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final color = _statusColor(schedule.status);
    return Container(
      width: 3,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
    );
  }

  /// 확정된 일정에만 붙는 "확정" 뱃지 (inkGreen 배경 + navy 글씨 + 체크 아이콘)
  Widget _buildConfirmedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.inkGreen,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check, size: 12, color: AppColors.navy),
          SizedBox(width: 3),
          Text(
            ScheduleStrings.confirm,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 10,
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    final color = categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Text(
        shortenCategory(category),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _statusColor(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.pending:
        return AppColors.gold;
      case ScheduleStatus.confirmed:
        return AppColors.inkGreen;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
