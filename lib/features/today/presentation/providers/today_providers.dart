import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../domain/today_view.dart';

/// "오늘"의 기준 시각. 테스트에서 고정 날짜로 override 한다.
final todayReferenceProvider = Provider<DateTime>((ref) => DateTime.now());

/// 오늘 탭 화면 상태.
final todayViewProvider =
    AsyncNotifierProvider<TodayViewNotifier, TodayView>(TodayViewNotifier.new);

class TodayViewNotifier extends AsyncNotifier<TodayView> {
  @override
  Future<TodayView> build() async {
    final today = ref.watch(todayReferenceProvider);
    final repository = ref.watch(calendarRepositoryProvider);
    final events = await repository.getEventsByDateRange(
      today.subtract(const Duration(days: todayOverdueLookbackDays)),
      today,
    );
    return buildTodayView(events: events, today: today);
  }

  /// 완료/완료 취소 토글.
  ///
  /// 목록을 다시 조회하지 않고 해당 항목만 교체한다(`invalidateSelf` 금지) —
  /// 재조회하면 완료 항목이 아래로 재정렬돼 도장 애니메이션이 화면 밖에서 재생된다.
  /// 정렬은 화면에 다시 들어올 때 적용된다.
  Future<void> toggleCompleted(CalendarEvent event) async {
    final id = event.id;
    if (id == null) return;

    final repository = ref.read(calendarRepositoryProvider);
    final completedAt = event.isCompleted ? null : DateTime.now();
    if (completedAt == null) {
      await repository.markIncomplete(id);
    } else {
      await repository.markCompleted(id);
    }

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.withToggled(id, completedAt?.toIso8601String()),
      );
    }

    // 캘린더 탭도 같은 이벤트를 그리므로 캐시를 비운다.
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidate(selectedMonthEventsProvider);
    await _syncNotifications();
  }

  /// 알림 재예약. `computeNotifications`가 완료 이벤트를 대상에서 제외하므로
  /// sync를 빠뜨리면 이미 처리한 일이 다음 알림에 남는다.
  /// 플랫폼 에러(권한 거부 등)는 조용히 무시 — 완료 처리 자체는 이미 끝났다.
  Future<void> _syncNotifications() async {
    try {
      await ref.read(notificationSyncerProvider).sync();
    } catch (_) {
      // 무시
    }
  }
}
