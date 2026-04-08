import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/event_edit_dialog.dart';
import '../widgets/event_list_section.dart';

/// 캘린더 화면
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final monthEventsMap = ref.watch(monthEventsMapProvider);
    final dateEvents = ref.watch(selectedDateEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calendarTitle)),
      body: Column(
        children: [
          _buildMonthHeader(context, ref, selectedDate),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: monthEventsMap.when(
              data: (eventsMap) => CalendarGrid(
                year: selectedDate.year,
                month: selectedDate.month,
                selectedDate: selectedDate,
                eventsMap: eventsMap,
                onDateSelected: (date) {
                  ref.read(selectedDateProvider.notifier).state = date;
                },
              ),
              loading: () => const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox(
                height: 280,
                child: Center(child: Text(AppStrings.error)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: AppSizes.spacing16,
                bottom: AppSizes.spacing48,
              ),
              child: dateEvents.when(
                data: (events) => EventListSection(
                  selectedDate: selectedDate,
                  events: events,
                  onEventTap: (event) => _onEditEvent(context, ref, event),
                  onEventLongPress: (event) =>
                      _onDeleteEvent(context, ref, event),
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.spacing32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.spacing32),
                    child: Text(AppStrings.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddEvent(context, ref, selectedDate),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final formatter = DateFormat('yyyy년 M월', 'ko_KR');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(selectedDate.year, selectedDate.month - 1, 1);
              ref.read(selectedDateProvider.notifier).state = prev;
            },
          ),
          GestureDetector(
            onTap: () {
              final today = DateTime.now();
              ref.read(selectedDateProvider.notifier).state = today;
            },
            child: Column(
              children: [
                Text(
                  formatter.format(selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  AppStrings.calendarToday,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(selectedDate.year, selectedDate.month + 1, 1);
              ref.read(selectedDateProvider.notifier).state = next;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onAddEvent(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final result = await EventEditDialog.show(
      context,
      initialDate: date,
    );
    if (result != null) {
      await ref.read(selectedMonthEventsProvider.notifier).addEvent(result);
    }
  }

  Future<void> _onEditEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final result = await EventEditDialog.show(
      context,
      initialDate: event.eventDateTime,
      event: event,
    );
    if (result != null) {
      await ref.read(selectedMonthEventsProvider.notifier).updateEvent(result);
    }
  }

  Future<void> _onDeleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.delete),
        content: const Text(AppStrings.calendarDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.delete,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (event.id case final id?) {
        await ref.read(selectedMonthEventsProvider.notifier).deleteEvent(id);
      }
    }
  }
}
