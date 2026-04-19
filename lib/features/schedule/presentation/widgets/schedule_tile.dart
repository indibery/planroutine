import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/schedule.dart';

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
      background: _buildSwipeBackground(
        color: AppColors.statusConfirmed,
        icon: Icons.check_circle_outline,
        label: AppStrings.scheduleConfirm,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        color: AppColors.error,
        icon: Icons.delete_outline,
        label: AppStrings.scheduleDelete,
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
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            child: Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: AppSizes.iconSmall,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                          Text(
                            _formatDate(schedule.scheduledDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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
      width: 4,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: _categoryColor(category).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
      ),
      child: Text(
        _shortenCategory(category),
        style: TextStyle(
          fontSize: 11,
          color: _categoryColor(category),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.pending:
        return AppColors.statusPending;
      case ScheduleStatus.confirmed:
        return AppColors.statusConfirmed;
    }
  }

  Color _categoryColor(String category) {
    if (category.contains('일과운영')) return AppColors.categoryDailyOps;
    if (category.contains('교육과정')) return AppColors.categoryCurriculum;
    if (category.contains('조직') || category.contains('통계')) {
      return AppColors.categoryOrganization;
    }
    if (category.contains('학적')) return AppColors.categoryStudentRecord;
    return AppColors.categoryDefault;
  }

  String _shortenCategory(String category) {
    if (category.contains('일과운영')) return '일과운영';
    if (category.contains('교육과정')) return '교육과정';
    if (category.contains('조직') || category.contains('통계')) return '조직통계';
    if (category.contains('학적')) return '학생학적';
    return category.length > 4 ? '${category.substring(0, 4)}...' : category;
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
