import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';

/// 가져오기 결과 요약 카드
class ImportSummaryCard extends StatelessWidget {
  const ImportSummaryCard({
    super.key,
    required this.totalCount,
    required this.categorySummary,
    required this.sourceYear,
  });

  final int totalCount;
  final Map<String, int> categorySummary;
  final int sourceYear;

  /// 카테고리명에 따른 색상 반환
  Color _categoryColor(String category) {
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
        padding: const EdgeInsets.all(AppSizes.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: AppSizes.iconLarge,
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.importSuccess,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSizes.spacing4),
                      Text(
                        '$sourceYear년 일정 $totalCount건',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacing16),
            const Divider(),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              '카테고리별 분류',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSizes.spacing8),
            ...categorySummary.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.spacing12,
                      height: AppSizes.spacing12,
                      decoration: BoxDecoration(
                        color: _categoryColor(entry.key),
                        borderRadius: BorderRadius.circular(AppSizes.radius4),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    Text(
                      '${entry.value}건',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
