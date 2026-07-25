import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../domain/today_view.dart';

/// "오늘"의 기준 시각. 테스트에서 고정 날짜로 override 한다.
final todayReferenceProvider = Provider<DateTime>((ref) => DateTime.now());

/// 오늘 탭 화면 상태.
///
/// autoDispose인 이유: 이 앱은 `StatefulShellRoute`가 아닌 평범한 `ShellRoute`라
/// 탭을 옮기면 화면 위젯이 dispose된다. provider만 살아남으면 화면과 상태의 수명이
/// 어긋나 다시 들어와도 예전 목록이 보인다. 수명을 화면에 묶어 재진입 = 재조회로 만든다.
final todayViewProvider =
    AsyncNotifierProvider.autoDispose<TodayViewNotifier, TodayView>(
  TodayViewNotifier.new,
);

class TodayViewNotifier extends AutoDisposeAsyncNotifier<TodayView> {
  @override
  Future<TodayView> build() async {
    // 화면에 머문 채 다른 경로로 이벤트가 바뀌면(캘린더 탭 CRUD, 오늘 탭 FAB 등록,
    // 편집 시트 저장·삭제) 리비전이 올라 여기가 다시 돈다.
    ref.watch(eventsRevisionProvider);
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
    // 단 eventsRevisionProvider는 올리지 않는다 — 올리면 이 provider의 build가 다시
    // 돌아 목록이 재정렬되고, 위에서 지킨 자리 고정이 그 자리에서 깨진다.
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidate(selectedMonthEventsProvider);
    await _syncNotifications();
  }

  bool _syncing = false;
  bool _syncPending = false;

  /// 알림 재예약. `computeNotifications`가 완료 이벤트를 대상에서 제외하므로
  /// sync를 빠뜨리면 이미 처리한 일이 다음 알림에 남는다.
  ///
  /// **연속 체크를 합친다.** sync 1회가 1년치 DB 조회 + 최대 60건 순차 재예약이라,
  /// 오늘 탭의 주 사용 패턴(연달아 5~10개 체크)에서 그 비용이 그대로 곱해진다.
  /// 진행 중이면 "한 번 더 필요하다"만 표시하고, 끝난 뒤 마지막 상태로 한 번만 다시 돈다.
  ///
  /// 플랫폼 에러(권한 거부 등)는 조용히 무시 — 완료 처리 자체는 이미 끝났다.
  Future<void> _syncNotifications() async {
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncPending = false;
        await ref.read(notificationSyncerProvider).sync();
      } while (_syncPending);
    } catch (_) {
      // 무시
    } finally {
      _syncing = false;
    }
  }
}
