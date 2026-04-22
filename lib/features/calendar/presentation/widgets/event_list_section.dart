import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/dismissible_background.dart';
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
      // 오른쪽 스와이프 배경: Google 저장 (navySoft + inkGreen 아이콘)
      background: const DismissibleBackground(
        accent: AppColors.inkGreen,
        icon: Icons.cloud_upload,
        label: CalendarStrings.swipeGoogleSave,
        alignment: Alignment.centerLeft,
        verticalMargin: AppSizes.spacing4,
      ),
      // 왼쪽 스와이프 배경: 완료 토글 (navySoft + gold 아이콘)
      secondaryBackground: DismissibleBackground(
        accent: isDone ? AppColors.faint : AppColors.gold,
        icon: isDone ? Icons.radio_button_unchecked : Icons.check_circle,
        label: isDone
            ? CalendarStrings.undoComplete
            : CalendarStrings.markComplete,
        alignment: Alignment.centerRight,
        verticalMargin: AppSizes.spacing4,
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

  Widget _buildDateHeader(BuildContext context) {
    final formatter = DateFormat('M월 d일 (E)', 'ko_KR');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
      child: Text(
        formatter.format(selectedDate),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
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
          CalendarStrings.noEvents,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            color: AppColors.faint,
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(CalendarEvent event) {
    final isDone = event.isCompleted;
    final titleColor = isDone ? AppColors.sub : AppColors.ink;
    final accentColor = isDone
        ? AppColors.faint
        : event.eventColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      child: GestureDetector(
        onTap: () => onEventTap(event),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(AppSizes.radius14),
            border: Border.all(color: AppColors.line, width: 0.5),
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
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.faint,
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
                          event.description ?? '',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: AppColors.sub,
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
                    color: AppColors.inkGreen,
                  ),
                )
              else if (event.isAllDay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing8,
                    vertical: AppSizes.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navySoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    border: Border.all(color: AppColors.line, width: 0.5),
                  ),
                  child: const Text(
                    CalendarStrings.eventAllDay,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sub,
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
