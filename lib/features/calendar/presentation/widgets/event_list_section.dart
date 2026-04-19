import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/calendar_event.dart';

/// 선택된 날짜의 이벤트 목록 섹션.
///
/// 각 이벤트는 좌→우 슬라이드로 삭제(soft-delete). 일정 탭과 동일한
/// thresholds/duration을 사용해 UX를 통일.
class EventListSection extends StatelessWidget {
  const EventListSection({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onEventTap,
    required this.onEventDelete,
  });

  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<CalendarEvent> onEventDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateHeader(context),
        const SizedBox(height: AppSizes.spacing8),
        if (events.isEmpty)
          _buildEmptyState()
        else
          ...events.map(_buildDismissibleEventTile),
      ],
    );
  }

  Widget _buildDismissibleEventTile(CalendarEvent event) {
    return Dismissible(
      key: Key('event_${event.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.25},
      movementDuration: const Duration(milliseconds: 150),
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: AppSizes.spacing8),
            Text(
              AppStrings.delete,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onEventDelete(event),
      child: _buildEventTile(event),
    );
  }

  Widget _buildDateHeader(BuildContext context) {
    final formatter = DateFormat('M월 d일 (E)', 'ko_KR');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
      child: Text(
        formatter.format(selectedDate),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing32,
      ),
      child: Center(
        child: Text(
          AppStrings.calendarNoEvents,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(CalendarEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      child: GestureDetector(
        onTap: () => onEventTap(event),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacing12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: event.eventColor,
                  borderRadius: BorderRadius.circular(AppSizes.radius4),
                ),
              ),
              const SizedBox(width: AppSizes.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.description != null &&
                        event.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSizes.spacing4),
                        child: Text(
                          event.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (event.isAllDay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing8,
                    vertical: AppSizes.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: const Text(
                    AppStrings.calendarEventAllDay,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
