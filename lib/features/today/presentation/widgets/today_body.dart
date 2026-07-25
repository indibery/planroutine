import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../domain/stamp_settings.dart';
import '../../domain/today_view.dart';
import 'today_event_row.dart';
import 'today_progress_ring.dart';

/// 오늘 탭 본문 — provider 없이 [TodayView]만 받아 그린다(위젯 테스트 대상).
///
/// 구성: 결산 링(또는 빈 상태) → 기한이 지난(기본 접힘) → 오늘 목록.
/// 화면 제목은 AppBar가 담당한다 — 캘린더·검토 탭과 같은 구조.
class TodayBody extends StatefulWidget {
  const TodayBody({
    super.key,
    required this.view,
    required this.today,
    required this.onToggle,
    required this.onEventTap,
    this.stampSettings = StampSettings.defaults,
  });

  final TodayView view;
  final DateTime today;

  /// 도장 모양 + "이미 찍은 도장 흐리게" 설정.
  final StampSettings stampSettings;
  final ValueChanged<CalendarEvent> onToggle;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  State<TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends State<TodayBody> {
  /// build마다 새로 만들지 않는다 — calendar_screen.dart의 _monthFormatter와 같은 이유.
  static final _heroFormatter = DateFormat('M월 d일 EEEE', 'ko_KR');

  /// 지난 항목은 기본 접힘 — 임포트 직후엔 수십 건이 쌓여 있어 오늘이 밀려난다.
  bool _overdueExpanded = false;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing48),
      children: [
        // 제목은 AppBar가 담당한다(다른 탭과 동일 구조).
        if (view.hasToday) _progressHero(view) else _emptyToday(),
        if (view.overdue.isNotEmpty) ...[
          _overdueHeader(view.overdue.length),
          if (_overdueExpanded)
            ...view.overdue.map((e) => _row(e, overdue: true)),
          if (view.hasToday) _sectionRule(),
        ],
        ...view.today.map((e) => _row(e, overdue: false)),
      ],
    );
  }

  /// 결산 히어로 — 링 + 오늘 날짜 + 남은 건수(또는 완주 문안).
  Widget _progressHero(TodayView view) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing12,
        AppSizes.pagePadding,
        AppSizes.spacing8,
      ),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        border: Border.all(color: AppColors.line, width: 0.5),
      ),
      child: Row(
        children: [
          TodayProgressRing(
            key: const Key('today_progress_ring'),
            done: view.doneCount,
            total: view.totalCount,
          ),
          const SizedBox(width: AppSizes.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _heroFormatter.format(widget.today),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  view.isAllDone
                      ? TodayStrings.allDone
                      : TodayStrings.remaining(view.remainingCount),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: view.isAllDone ? AppColors.gold : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyToday() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing32,
      ),
      child: Column(
        children: [
          Text(
            TodayStrings.emptyToday,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
          Text(
            TodayStrings.emptyTodayHint,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overdueHeader(int count) {
    return GestureDetector(
      key: const Key('today_overdue_header'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _overdueExpanded = !_overdueExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.spacing16,
          AppSizes.pagePadding,
          AppSizes.spacing8,
        ),
        child: Row(
          children: [
            Text(
              TodayStrings.overdueSection,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.inkRed,
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.inkRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Text(
                TodayStrings.overdueCount(count),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkRed,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              _overdueExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.faint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionRule() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing12,
      ),
      child: Container(height: 0.5, color: AppColors.line),
    );
  }

  Widget _row(CalendarEvent event, {required bool overdue}) {
    return TodayEventRow(
      key: Key('today_row_${event.id}'),
      event: event,
      stampSettings: widget.stampSettings,
      showOverdueDate: overdue,
      onToggle: () => widget.onToggle(event),
      onTap: () => widget.onEventTap(event),
    );
  }
}
