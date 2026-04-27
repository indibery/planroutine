import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import 'category_label.dart';

/// 일정 검토 화면 필터 바.
///
/// 1줄: 상태 필터 (전체/검토 대기/확정됨)
/// 2줄: 카테고리 필터 (전체 + DB에서 동적 추출, 빈도순). 카테고리가 0개면 줄 자체 숨김.
class ScheduleFilterBar extends ConsumerWidget {
  const ScheduleFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(),
        _CategoryRow(),
      ],
    );
  }
}

/// 상태 필터 1줄 (기존 동작 그대로)
class _StatusRow extends ConsumerWidget {
  const _StatusRow();

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
          PillChip(
            label: ScheduleStrings.all,
            selected: currentStatus == null,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state = null;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: ScheduleStrings.pending,
            selected: currentStatus == ScheduleStatus.pending,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.pending;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: ScheduleStrings.confirmed,
            selected: currentStatus == ScheduleStatus.confirmed,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.confirmed;
            },
          ),
        ],
      ),
    );
  }
}

/// 카테고리 필터 1줄 (신규).
/// 항목이 0개면 SizedBox.shrink로 줄 자체를 숨김.
class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(availableCategoriesProvider);
    final currentCategory = ref.watch(scheduleCategoryFilterProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing4,
          ),
          child: Row(
            children: [
              PillChip(
                label: ScheduleStrings.all,
                selected: currentCategory == null,
                onTap: () {
                  ref.read(scheduleCategoryFilterProvider.notifier).state =
                      null;
                },
              ),
              for (final raw in categories) ...[
                const SizedBox(width: AppSizes.spacing8),
                PillChip(
                  label: shortenCategory(raw),
                  selected: currentCategory == raw,
                  onTap: () {
                    ref.read(scheduleCategoryFilterProvider.notifier).state =
                        raw;
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
