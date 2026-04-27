import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/dismissible_background.dart';
import '../../domain/calendar_event.dart';

/// 선택된 날짜의 이벤트 목록 섹션.
///
/// 각 이벤트는 스와이프 지원:
///   - 오른쪽 스와이프: Google 캘린더 저장 (옵션) — [onEventSaveToGoogle]가 null이면 비활성
///   - 왼쪽 스와이프: 완료/완료 취소 토글
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

  /// Google 저장 콜백. null이면 오른쪽 스와이프가 비활성화돼 왼쪽 스와이프(완료 토글)만 동작.
  final ValueChanged<CalendarEvent>? onEventSaveToGoogle;
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
    final googleSave = onEventSaveToGoogle;

    // 완료 토글 배경 — 왼쪽 스와이프 시 노출.
    final completeBackground = DismissibleBackground(
      accent: isDone ? AppColors.faint : AppColors.gold,
      icon: isDone ? Icons.radio_button_unchecked : Icons.check_circle,
      label: isDone
          ? CalendarStrings.undoComplete
          : CalendarStrings.markComplete,
      alignment: Alignment.centerRight,
      verticalMargin: AppSizes.spacing4,
    );

    return Dismissible(
      key: Key('event_${event.id}'),
      direction: googleSave != null
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      movementDuration: const Duration(milliseconds: 150),
      // Dismissible assertion(secondaryBackground 있으면 background 필수) 회피:
      // Google 저장이 활성일 땐 오른쪽 스와이프에 Google 배경, 왼쪽엔 완료 배경.
      // Google이 꺼지면 endToStart 전용이므로 background 슬롯에 완료 배경을 넣고
      // secondaryBackground는 null.
      background: googleSave != null
          ? const DismissibleBackground(
              accent: AppColors.inkGreen,
              icon: Icons.cloud_upload,
              label: CalendarStrings.swipeGoogleSave,
              alignment: Alignment.centerLeft,
              verticalMargin: AppSizes.spacing4,
            )
          : completeBackground,
      secondaryBackground: googleSave != null ? completeBackground : null,
      // 실제 dismiss는 막고(false), 액션만 실행
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && googleSave != null) {
          googleSave(event);
        } else {
          // horizontal의 endToStart, 또는 endToStart 전용 모두 완료 토글
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
                        fontSize: 15,
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
                            fontSize: 14,
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
