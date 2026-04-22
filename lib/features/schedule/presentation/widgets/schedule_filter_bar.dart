import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';

/// 일정 상태 필터 바 (전체/검토 대기/확정됨)
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
