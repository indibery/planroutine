import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/imported_schedule.dart';

/// 가져온 일정 하나를 표시하는 리스트 타일
class ImportedScheduleTile extends StatelessWidget {
  const ImportedScheduleTile({
    super.key,
    required this.schedule,
  });

  final ImportedSchedule schedule;

  /// 카테고리에 따른 배지 색상
  Color _categoryColor() {
    final category = schedule.category ?? '';
    if (category.contains(AppStrings.categoryDailyOps)) {
      return AppColors.categoryDailyOps;
    }
    if (category.contains('교육과정')) {
      return AppColors.categoryCurriculum;
    }
    if (category.contains('조직') || category.contains('통계')) {
      return AppColors.categoryOrganization;
    }
    if (category.contains('학생') || category.contains('학적')) {
      return AppColors.categoryStudentRecord;
    }
    return AppColors.categoryDefault;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 날짜 + 결재유형
            Row(
              children: [
                Text(
                  schedule.registrationDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const Spacer(),
                if (schedule.approvalType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacing8,
                      vertical: AppSizes.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.radius4),
                    ),
                    child: Text(
                      schedule.approvalType ?? '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing8),
            // 제목
            Text(
              schedule.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.spacing8),
            // 하단: 카테고리 배지
            if (schedule.category != null && schedule.category?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing8,
                  vertical: AppSizes.spacing4,
                ),
                decoration: BoxDecoration(
                  color: _categoryColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
                child: Text(
                  schedule.category ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _categoryColor(),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
