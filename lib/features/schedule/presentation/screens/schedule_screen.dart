import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import '../widgets/schedule_filter_bar.dart';
import '../widgets/schedule_tile.dart';

/// 일정 검토/확정 화면
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.scheduleTitle),
      ),
      body: Column(
        children: [
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
          return FloatingActionButton.extended(
            onPressed: () => _showBulkConfirmDialog(context, ref),
            icon: const Icon(Icons.done_all),
            label: const Text(AppStrings.scheduleConfirmAll),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          );
        },
      ),
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
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            hasFilter
                ? AppStrings.scheduleEmptyFiltered
                : AppStrings.scheduleEmpty,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
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
      padding: const EdgeInsets.only(bottom: 80),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...schedules.map(
          (schedule) => ScheduleTile(
            schedule: schedule,
            onConfirm: () {
              if (schedule.id != null) {
                ref.read(schedulesProvider.notifier).updateStatus(
                      schedule.id ?? 0,
                      ScheduleStatus.confirmed,
                    );
              }
            },
            onDelete: () {
              if (schedule.id != null) {
                ref
                    .read(schedulesProvider.notifier)
                    .deleteSchedule(schedule.id ?? 0);
              }
            },
            onTap: () => _showEditBottomSheet(context, ref, schedule),
          ),
        ),
      ],
    );
  }

  void _showEditBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Schedule schedule,
  ) {
    final titleController = TextEditingController(text: schedule.title);
    final descController =
        TextEditingController(text: schedule.description ?? '');
    DateTime selectedDate =
        DateTime.tryParse(schedule.scheduledDate) ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius16),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.spacing24,
            AppSizes.spacing24,
            AppSizes.spacing24,
            MediaQuery.of(context).viewInsets.bottom + AppSizes.spacing24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.scheduleEditTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacing16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: AppStrings.scheduleTitleLabel,
                ),
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: AppStrings.scheduleDescriptionHint,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSizes.spacing12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    locale: const Locale('ko', 'KR'),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: AppStrings.scheduleDateLabel,
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacing24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (schedule.id != null) {
                          ref.read(schedulesProvider.notifier).updateSchedule(
                                schedule.id ?? 0,
                                title: titleController.text,
                                date: selectedDate,
                                description: descController.text.isEmpty
                                    ? null
                                    : descController.text,
                              );
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text(AppStrings.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
