import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../schedule/domain/schedule.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';

/// 휴지통 항목 묶음 (일정 + 캘린더 이벤트).
class TrashSnapshot {
  const TrashSnapshot({
    required this.schedules,
    required this.events,
  });

  final List<Schedule> schedules;
  final List<CalendarEvent> events;

  int get total => schedules.length + events.length;
  bool get isEmpty => total == 0;
}

/// 휴지통 목록 (최근 삭제 순, 일정/캘린더 동시 조회)
final trashSnapshotProvider =
    AsyncNotifierProvider<TrashNotifier, TrashSnapshot>(TrashNotifier.new);

class TrashNotifier extends AsyncNotifier<TrashSnapshot> {
  @override
  Future<TrashSnapshot> build() async {
    final scheduleRepo = ref.watch(scheduleRepositoryProvider);
    final calendarRepo = ref.watch(calendarRepositoryProvider);
    final (schedules, events) = await (
      scheduleRepo.getDeletedSchedules(),
      calendarRepo.getDeletedEvents(),
    ).wait;
    return TrashSnapshot(schedules: schedules, events: events);
  }

  Future<void> restoreSchedule(int id) async {
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.restoreSchedule(id);
    ref.invalidate(schedulesProvider);
    ref.invalidateSelf();
  }

  Future<void> restoreEvent(int id) async {
    final repo = ref.read(calendarRepositoryProvider);
    await repo.restoreEvent(id);
    ref.invalidate(selectedMonthEventsProvider);
    ref.invalidateSelf();
  }

  Future<void> permanentDeleteSchedule(int id) async {
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.permanentDeleteSchedule(id);
    ref.invalidateSelf();
  }

  Future<void> permanentDeleteEvent(int id) async {
    final repo = ref.read(calendarRepositoryProvider);
    await repo.permanentDeleteEvent(id);
    ref.invalidateSelf();
  }
}

/// 앱 시작 시 30일 이상 경과한 soft-delete 항목을 영구 삭제한다.
/// 반환: (삭제된 일정 건수, 삭제된 이벤트 건수)
Future<({int schedules, int events})> purgeExpiredTrash(
  ProviderContainer container,
) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final scheduleRepo = container.read(scheduleRepositoryProvider);
  final calendarRepo = container.read(calendarRepositoryProvider);
  final results = await (
    scheduleRepo.purgeOlderThan(cutoff),
    calendarRepo.purgeOlderThan(cutoff),
  ).wait;
  return (schedules: results.$1, events: results.$2);
}
