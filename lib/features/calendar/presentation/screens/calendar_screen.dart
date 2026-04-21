import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../google/data/google_calendar_service.dart';
import '../../../google/presentation/providers/google_providers.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/calendar_slide_hint_bar.dart';
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
          const CalendarSlideHintBar(),
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
                          onEventSaveToGoogle: (event) =>
                              _onSaveToGoogle(context, ref, event),
                          onEventToggleCompleted: (event) =>
                              _onToggleCompleted(context, ref, event),
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

  /// 오른쪽 스와이프 — 구글 캘린더에 이벤트 저장.
  /// 로그인 안 돼있으면 먼저 로그인 유도, 실패는 스낵바로 안내.
  ///
  /// 중복 방지: `event.googleEventId`가 이미 있으면 update API 호출.
  /// 구글쪽에서 지워져 404면 insert로 재시도(사용자가 의도적으로 재생성).
  Future<void> _onSaveToGoogle(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final service = ref.read(googleCalendarServiceProvider);
    final repository = ref.read(calendarRepositoryProvider);
    try {
      if (service.currentUser == null) {
        final account = await service.signIn();
        if (account == null) return; // 사용자 취소
      }

      final start = event.eventDateTime;
      final end = event.endDate != null ? event.endDateTime : start;

      String? resultId;
      var wasNewSave = true; // insert 경로일 때만 true, update 성공 시 false
      final existingId = event.googleEventId;
      if (existingId != null && existingId.isNotEmpty) {
        try {
          final updated = await service.updateEvent(
            eventId: existingId,
            title: event.title,
            description: event.description,
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
          );
          resultId = updated.id;
          wasNewSave = false;
        } on GoogleEventNotFoundException {
          // 구글쪽에서 삭제됨 → 새로 생성 (local id는 새 id로 덮어씀)
          final created = await service.createEvent(
            title: event.title,
            description: event.description,
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
          );
          resultId = created.id;
        }
      } else {
        final created = await service.createEvent(
          title: event.title,
          description: event.description,
          startDate: start,
          endDate: end,
          isAllDay: event.isAllDay,
        );
        resultId = created.id;
      }

      // 받은 id를 로컬에 기록 (다음 저장을 update로 처리하기 위해)
      final eventId = event.id;
      if (eventId != null && resultId != null && resultId.isNotEmpty) {
        await repository.updateGoogleEventId(eventId, resultId);
        ref.invalidate(selectedMonthEventsProvider);
      }

      if (context.mounted) {
        final msg = wasNewSave
            ? AppStrings.calendarSaveToGoogleDone
            : AppStrings.calendarSaveToGoogleAlready;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${AppStrings.calendarSaveToGoogleFailed}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  /// 왼쪽 스와이프 — 이벤트 완료/완료 취소 토글.
  Future<void> _onToggleCompleted(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    await ref
        .read(selectedMonthEventsProvider.notifier)
        .toggleCompleted(event);
  }
}
