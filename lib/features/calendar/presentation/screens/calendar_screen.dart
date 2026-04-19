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
    final monthEventsGrouped = ref.watch(monthEventsGroupedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calendarTitle)),
      body: Column(
        children: [
          _buildMonthHeader(context, ref, selectedDate),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < 0) {
                // 왼쪽 스와이프 → 다음 달
                final next = DateTime(selectedDate.year, selectedDate.month + 1, 1);
                ref.read(selectedDateProvider.notifier).state = next;
              } else if (details.primaryVelocity! > 0) {
                // 오른쪽 스와이프 → 이전 달
                final prev = DateTime(selectedDate.year, selectedDate.month - 1, 1);
                ref.read(selectedDateProvider.notifier).state = prev;
              }
            },
            child: Padding(
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
          ),
          const Divider(height: 1),
          Expanded(
            child: monthEventsGrouped.when(
              data: (groupedEntries) => groupedEntries.isEmpty
                  ? const Center(
                      child: Text(
                        AppStrings.calendarNoEvents,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        top: AppSizes.spacing16,
                        bottom: AppSizes.spacing48,
                      ),
                      itemCount: groupedEntries.length,
                      itemBuilder: (context, index) {
                        final entry = groupedEntries[index];
                        final date = DateTime.parse(entry.key);
                        return EventListSection(
                          selectedDate: date,
                          events: entry.value,
                          onEventTap: (event) =>
                              _onEditEvent(context, ref, event),
                          onEventLongPress: (event) =>
                              _onDeleteEvent(context, ref, event),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text(AppStrings.error)),
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

  /// 캘린더 이벤트 삭제 (확인 다이얼로그 없이 즉시 삭제 + 실행취소 스낵바)
  Future<void> _onDeleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    if (event.id case final id?) {
      await ref.read(selectedMonthEventsProvider.notifier).deleteEvent(id);
      if (context.mounted) {
        // clearSnackBars()는 현재 + queue까지 모두 제거하여 연속 삭제 시 누적 방지
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('"${event.title}" ${AppStrings.delete}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: AppStrings.undo,
                onPressed: () {
                  // id를 비운 새 이벤트로 재삽입 (새 id 부여)
                  ref
                      .read(selectedMonthEventsProvider.notifier)
                      .addEvent(event.copyWith(id: null));
                },
              ),
            ),
          );
      }
    }
  }
}
