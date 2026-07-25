import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/gold_fab.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../calendar/presentation/widgets/event_edit_dialog.dart';
import '../providers/today_providers.dart';
import '../widgets/today_body.dart';

/// 오늘 탭 — provider 배선만 담당하는 얇은 조합. 화면 구성은 [TodayBody].
///
/// AppBar(eyebrow + 제목) + 골드 FAB 구조는 캘린더·검토 탭과 동일하게 맞춘 것이다.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayViewProvider);
    final today = ref.watch(todayReferenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TODAY',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(TodayStrings.title, style: AppTextStyles.heading),
          ],
        ),
      ),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            AppStrings.error,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              color: AppColors.sub,
            ),
          ),
        ),
        data: (data) => TodayBody(
          view: data,
          today: today,
          onToggle: (event) =>
              ref.read(todayViewProvider.notifier).toggleCompleted(event),
          onEventTap: (event) => _onEditEvent(context, ref, event),
        ),
      ),
      floatingActionButton: GoldFab(
        onTap: () => _onAddEvent(context, ref, today),
        tooltip: TodayStrings.addEvent,
      ),
    );
  }

  /// FAB — 오늘 날짜로 새 일정 등록.
  Future<void> _onAddEvent(
    BuildContext context,
    WidgetRef ref,
    DateTime today,
  ) async {
    final result = await EventEditDialog.show(context, initialDate: today);
    if (result == null) return;
    // 캘린더 탭과 같은 경로로 저장한다 — 여기서 리비전이 올라 오늘 목록도 갱신된다.
    await ref.read(selectedMonthEventsProvider.notifier).addEvent(result);
  }

  /// 본문 탭 → 캘린더 탭과 같은 편집 시트.
  /// 저장·삭제 모두 캘린더 notifier를 거치므로 리비전이 올라 목록이 자동 갱신된다.
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
    if (result == null) return;
    await ref.read(selectedMonthEventsProvider.notifier).updateEvent(result);
  }
}
