import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';

/// 일정 상태/카테고리 필터 바
class ScheduleFilterBar extends ConsumerWidget {
  const ScheduleFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = ref.watch(scheduleStatusFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          _StatusChip(
            label: AppStrings.scheduleAll,
            color: AppColors.primary,
            isSelected: currentStatus == null,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state = null;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          _StatusChip(
            label: AppStrings.schedulePending,
            color: AppColors.statusPending,
            isSelected: currentStatus == ScheduleStatus.pending,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.pending;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          _StatusChip(
            label: AppStrings.scheduleConfirmed,
            color: AppColors.statusConfirmed,
            isSelected: currentStatus == ScheduleStatus.confirmed,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.confirmed;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          _StatusChip(
            label: AppStrings.scheduleCompleted,
            color: AppColors.statusCompleted,
            isSelected: currentStatus == ScheduleStatus.completed,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.completed;
            },
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
    );
  }
}
