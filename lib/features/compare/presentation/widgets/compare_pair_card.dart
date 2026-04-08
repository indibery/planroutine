import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/compare_item.dart';

/// 작년/올해 일정 비교 카드
class ComparePairCard extends StatelessWidget {
  const ComparePairCard({
    super.key,
    required this.item,
    this.onRegisterThisYear,
  });

  final CompareItem item;
  final VoidCallback? onRegisterThisYear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchBadge(),
            const SizedBox(height: AppSizes.spacing8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLastYearSide()),
                _buildCenterDivider(),
                Expanded(child: _buildThisYearSide()),
              ],
            ),
            if (item.matchType == MatchType.onlyLastYear &&
                onRegisterThisYear != null) ...[
              const SizedBox(height: AppSizes.spacing8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRegisterThisYear,
                  icon: const Icon(Icons.add, size: AppSizes.iconSmall),
                  label: const Text(AppStrings.compareRegisterThisYear),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize:
                        const Size.fromHeight(AppSizes.buttonHeightSmall),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchBadge() {
    final (label, color) = _matchInfo(item.matchType);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing8,
        vertical: AppSizes.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLastYearSide() {
    final lastItem = item.lastYearItem;
    if (lastItem == null) {
      return _buildEmptySide(AppStrings.compareLastYear);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.compareLastYear,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.spacing4),
        Text(
          lastItem.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSizes.spacing4),
        Text(
          _formatDate(lastItem.registrationDate),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        if (lastItem.category != null) ...[
          const SizedBox(height: AppSizes.spacing4),
          Text(
            lastItem.category ?? '',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThisYearSide() {
    final thisItem = item.thisYearItem;
    if (thisItem == null) {
      return _buildEmptySide(AppStrings.compareThisYear);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.compareThisYear,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.spacing4),
        Text(
          thisItem.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _isChanged() ? AppColors.info : AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSizes.spacing4),
        Text(
          _formatDate(thisItem.scheduledDate),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCenterDivider() {
    return Container(
      width: 1,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8),
      color: AppColors.divider,
    );
  }

  Widget _buildEmptySide(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        const Text(
          '-',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  bool _isChanged() {
    if (item.lastYearItem == null || item.thisYearItem == null) return false;
    return item.matchType == MatchType.similar;
  }

  (String, Color) _matchInfo(MatchType type) {
    switch (type) {
      case MatchType.exact:
        return (AppStrings.compareExactMatch, AppColors.success);
      case MatchType.similar:
        return (AppStrings.compareSimilarMatch, AppColors.warning);
      case MatchType.onlyLastYear:
        return (AppStrings.compareOnlyLastYear, AppColors.error);
      case MatchType.onlyThisYear:
        return (AppStrings.compareOnlyThisYear, AppColors.info);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MM.dd', 'ko_KR').format(date);
    } catch (_) {
      // yyyy.MM.dd 형식 처리
      if (dateStr.contains('.')) {
        final parts = dateStr.split('.');
        if (parts.length >= 3) {
          return '${parts[1]}.${parts[2]}';
        }
      }
      return dateStr;
    }
  }
}
