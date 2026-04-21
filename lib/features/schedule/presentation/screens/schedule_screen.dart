import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import '../widgets/schedule_edit_sheet.dart';
import '../widgets/schedule_filter_bar.dart';
import '../widgets/schedule_tile.dart';
import '../widgets/slide_hint_bar.dart';

/// 일정 검토/확정 화면
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'REVIEW',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: AppColors.gold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              AppStrings.scheduleTitle,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProgress(schedulesAsync),
          const SlideHintBar(),
          const ScheduleFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) => schedules.isEmpty
                  ? _buildEmptyState(ref)
                  : _buildScheduleList(context, ref, schedules),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.error,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    TextButton(
                      onPressed: () => ref.invalidate(schedulesProvider),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: schedulesAsync.whenOrNull(
        data: (schedules) {
          final hasPending =
              schedules.any((s) => s.status == ScheduleStatus.pending);
          if (!hasPending) return null;
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppSizes.tabBarHeight + AppSizes.spacing16,
            ),
            child: SizedBox(
              width: 180,
              child: GoldGradientButton(
                label: AppStrings.scheduleConfirmAll,
                icon: Icons.done_all,
                onPressed: () => _showBulkConfirmDialog(context, ref),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 확정/전체 일정 진행도 바 — 얇은 2px gold gradient.
  Widget _buildProgress(AsyncValue<List<Schedule>> schedulesAsync) {
    return schedulesAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final total = list.length;
        final confirmed =
            list.where((s) => s.status == ScheduleStatus.confirmed).length;
        final ratio = total == 0 ? 0.0 : confirmed / total;
        final percent = (ratio * 100).round();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.spacing12,
            AppSizes.pagePadding,
            AppSizes.spacing4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$confirmed / $total · $percent% 완료',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: AppSizes.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                child: Stack(
                  children: [
                    Container(
                      height: 2,
                      color: AppColors.navySoft,
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.progress,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    final hasFilter = ref.watch(scheduleStatusFilterProvider) != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: AppColors.faint,
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            hasFilter
                ? AppStrings.scheduleEmptyFiltered
                : AppStrings.scheduleEmpty,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(
    BuildContext context,
    WidgetRef ref,
    List<Schedule> schedules,
  ) {
    // 월별 그룹핑
    final grouped = <String, List<Schedule>>{};
    for (final schedule in schedules) {
      final monthKey = _extractMonthKey(schedule.scheduledDate);
      grouped.putIfAbsent(monthKey, () => []).add(schedule);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: AppSizes.tabBarHeight + AppSizes.spacing48 + AppSizes.spacing16,
      ),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final monthKey = sortedKeys[index];
        final items = grouped[monthKey] ?? [];
        return _buildMonthGroup(context, ref, monthKey, items);
      },
    );
  }

  Widget _buildMonthGroup(
    BuildContext context,
    WidgetRef ref,
    String monthKey,
    List<Schedule> schedules,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing8,
          ),
          child: Text(
            _formatMonthKey(monthKey),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
        ...schedules.map(
          (schedule) => ScheduleTile(
            schedule: schedule,
            onConfirm: () {
              if (schedule.id case final id?) {
                ref.read(schedulesProvider.notifier).updateStatus(
                      id,
                      ScheduleStatus.confirmed,
                    );
              }
            },
            onDelete: () {
              if (schedule.id case final id?) {
                ref.read(schedulesProvider.notifier).deleteSchedule(id);
              }
            },
            onTap: () => ScheduleEditSheet.show(context, schedule),
          ),
        ),
      ],
    );
  }

  void _showBulkConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.scheduleBulkConfirmTitle),
        content: const Text(AppStrings.scheduleBulkConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(schedulesProvider.notifier).confirmAllPending();
              Navigator.of(context).pop();
            },
            child: const Text(AppStrings.scheduleConfirm),
          ),
        ],
      ),
    );
  }

  String _extractMonthKey(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length >= 7 ? dateStr.substring(0, 7) : dateStr;
    }
  }

  String _formatMonthKey(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length >= 2) {
        return '${parts[0]}${AppStrings.compareYearFormat} ${int.parse(parts[1])}월';
      }
    } catch (_) {}
    return monthKey;
  }
}
