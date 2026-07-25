import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../calendar/presentation/widgets/event_edit_dialog.dart';
import '../providers/today_providers.dart';
import '../widgets/today_body.dart';

/// 오늘 탭 — provider 배선만 담당하는 얇은 조합. 화면 구성은 [TodayBody].
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(todayViewProvider);
    final today = ref.watch(todayReferenceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: view.when(
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
            onEventTap: (event) => _onEventTap(context, ref, event),
          ),
        ),
      ),
    );
  }

  /// 본문 탭 → 캘린더 탭과 같은 편집 시트를 띄운다.
  /// 삭제는 시트가 직접 처리하고 null로 닫히므로, 결과와 무관하게 목록을 새로 읽는다.
  Future<void> _onEventTap(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final result = await EventEditDialog.show(
      context,
      initialDate: event.eventDateTime,
      event: event,
    );
    if (!context.mounted) return;
    if (result != null) {
      await ref.read(selectedMonthEventsProvider.notifier).updateEvent(result);
    }
    ref.invalidate(todayViewProvider);
  }
}
