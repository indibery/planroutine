import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/calendar_event.dart';

/// 선택된 날짜의 이벤트 목록 섹션.
///
/// 각 이벤트는 양방향 스와이프 지원:
///   - 오른쪽 스와이프: Google 캘린더 저장 (파랑)
///   - 왼쪽 스와이프: 완료/완료 취소 토글 (녹색·회색)
/// 삭제는 탭 → 편집 시트의 우측 휴지통 아이콘으로 이동했음.
class EventListSection extends StatelessWidget {
  const EventListSection({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onEventTap,
    required this.onEventSaveToGoogle,
    required this.onEventToggleCompleted,
  });

  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<CalendarEvent> onEventSaveToGoogle;
  final ValueChanged<CalendarEvent> onEventToggleCompleted;

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
    final isDone = event.isCompleted;
    return Dismissible(
      key: Key('event_${event.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      movementDuration: const Duration(milliseconds: 150),
      // 오른쪽 스와이프 배경: Google 저장 (파랑)
      background: _buildSwipeBackground(
        color: AppColors.primary,
        icon: Icons.cloud_upload,
        label: AppStrings.calendarSwipeGoogleSave,
        alignment: Alignment.centerLeft,
      ),
      // 왼쪽 스와이프 배경: 완료 토글 (녹색 또는 회색)
      secondaryBackground: _buildSwipeBackground(
        color: isDone ? AppColors.textHint : AppColors.statusConfirmed,
        icon: isDone ? Icons.radio_button_unchecked : Icons.check_circle,
        label: isDone
            ? AppStrings.calendarUndoComplete
            : AppStrings.calendarMarkComplete,
        alignment: Alignment.centerRight,
      ),
      // 양방향 모두 실제 dismiss는 막고(false), 액션만 실행
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEventSaveToGoogle(event);
        } else {
          onEventToggleCompleted(event);
        }
        return false;
      },
      child: _buildEventTile(event),
    );
  }

  Widget _buildSwipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppSizes.spacing8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final isDone = event.isCompleted;
    final titleColor = isDone ? AppColors.textHint : AppColors.textPrimary;
    final accentColor = isDone
        ? AppColors.textHint
        : event.eventColor;

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
            color: isDone ? AppColors.surfaceVariant : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.textHint,
                        decorationThickness: 2,
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
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (isDone)
                const Padding(
                  padding: EdgeInsets.only(left: AppSizes.spacing4),
                  child: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.statusConfirmed,
                  ),
                )
              else if (event.isAllDay)
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
