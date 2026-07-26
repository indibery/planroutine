import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/dismissible_background.dart';
import '../../../settings/presentation/providers/calendar_target_provider.dart';
import '../../../schedule/presentation/widgets/kind_badge.dart';
import '../../domain/calendar_event.dart';

/// 선택된 날짜의 이벤트 목록 섹션.
///
/// 각 이벤트는 스와이프 지원:
///   - 오른쪽 스와이프: 외부 캘린더 저장 (옵션) — [onEventSaveToGoogle]가 null이면 비활성
///   - 왼쪽 스와이프: 완료/완료 취소 토글
/// 삭제는 탭 → 편집 시트의 우측 휴지통 아이콘으로 이동했음.
class EventListSection extends ConsumerWidget {
  const EventListSection({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onEventTap,
    required this.onEventSaveToGoogle,
    required this.onEventToggleCompleted,
    this.highlight = false,
  });

  /// 날짜 점프 도착 지점 강조 플래시. 켜졌다 꺼지며 골드 배경이 서서히 사라진다.
  final bool highlight;

  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  /// 외부 캘린더 저장 콜백. null이면 오른쪽 스와이프가 비활성화돼 왼쪽 스와이프(완료 토글)만 동작.
  final ValueChanged<CalendarEvent>? onEventSaveToGoogle;
  final ValueChanged<CalendarEvent> onEventToggleCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(
      calendarTargetProvider
          .select((a) => a.valueOrNull ?? CalendarTarget.none),
    );
    final saveLabel = target == CalendarTarget.device
        ? CalendarIntegrationStrings.swipeSaveDevice
        : CalendarStrings.swipeGoogleSave;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radius14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(context),
          const SizedBox(height: AppSizes.spacing8),
          if (events.isEmpty)
            _buildEmptyState()
          else
            ...events.map((e) => _buildDismissibleEventTile(e, saveLabel)),
        ],
      ),
    );
  }

  Widget _buildDismissibleEventTile(CalendarEvent event, String saveLabel) {
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
          ? DismissibleBackground(
              accent: AppColors.inkGreen,
              icon: Icons.cloud_upload,
              label: saveLabel,
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
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
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
    final showImportant = event.showsImportant;
    final titleColor = isDone ? AppColors.sub : AppColors.ink;
    // 색상 피커 제거 후 이벤트 색은 통일 — 저장된 color 무시, 공통 액센트 사용.
    // 중요는 색이 아닌 형태(★)로 구분하되 레일만 골드로 살짝 강조.
    final accentColor = isDone
        ? AppColors.faint
        : (showImportant ? AppColors.goldFill : AppColors.eventAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      child: GestureDetector(
        onTap: () => onEventTap(event),
        child: Container(
          key: Key('event_card_${event.id}'),
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            color: showImportant
                ? AppColors.goldFill.withValues(alpha: 0.14)
                : AppColors.glass,
            borderRadius: BorderRadius.circular(AppSizes.radius14),
            border: Border.all(
              color: showImportant
                  ? AppColors.goldFill.withValues(alpha: 0.5)
                  : AppColors.line,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                key: Key('event_accent_bar_${event.id}'),
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
                    Row(
                      children: [
                        KindBadge(kind: event.kind),
                        const SizedBox(width: AppSizes.spacing8),
                        if (showImportant) ...[
                          Semantics(
                            label: CalendarStrings.importantBadge,
                            child: Icon(
                              Icons.star_rounded,
                              key: Key('event_important_badge_${event.id}'),
                              size: 16,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: AppSizes.spacing4),
                        ],
                        Expanded(
                          child: Text(
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
                        ),
                      ],
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
              _buildImportBadge(event),
              if (isDone)
                Padding(
                  padding: const EdgeInsets.only(left: AppSizes.spacing4),
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

  /// 가져온 자료 중 **아직 검토하지 않은** 항목에 붙는 배지.
  ///
  /// 연도를 보지 않는다 — 제목에 연도가 없어도 붙는다. 편집 시트에서 저장하면
  /// (`reviewed_at` 기록) 사라지므로, 남아 있는 배지가 곧 "아직 정리 안 한 목록"이 된다.
  /// 누르는 것이 아니므로 조용해야 하고, 종류 배지(채움)와 한 행에서 구분되도록
  /// **테두리형**으로 그린다. 골드는 오늘·중요 전용이라 쓰지 않는다.
  Widget _buildImportBadge(CalendarEvent event) {
    if (!event.showsImportBadge) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.spacing8),
      child: Container(
        key: Key('event_import_badge_${event.id}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.sub.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          CalendarStrings.fromImportBadge,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.sub,
          ),
        ),
      ),
    );
  }
}
