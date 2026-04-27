import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule.dart';

/// 일정 리포지토리 프로바이더
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

/// 일정 상태 필터
final scheduleStatusFilterProvider = StateProvider<ScheduleStatus?>((ref) {
  return null; // null = 전체
});

/// 일정 카테고리 필터
final scheduleCategoryFilterProvider = StateProvider<String?>((ref) {
  return null; // null = 전체
});

/// 필터 적용된 일정 목록
final schedulesProvider =
    AsyncNotifierProvider<SchedulesNotifier, List<Schedule>>(
  SchedulesNotifier.new,
);

/// 현재 활성 일정에서 사용 중인 카테고리 목록 (빈도순).
/// schedulesProvider 변경에 반응해 갱신된다.
final availableCategoriesProvider = FutureProvider<List<String>>((ref) async {
  // schedulesProvider invalidate 시 같이 갱신되도록 의존
  await ref.watch(schedulesProvider.future);
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.getDistinctCategories();
});

/// 일정 목록 관리 Notifier
class SchedulesNotifier extends AsyncNotifier<List<Schedule>> {
  @override
  Future<List<Schedule>> build() async {
    final status = ref.watch(scheduleStatusFilterProvider);
    final category = ref.watch(scheduleCategoryFilterProvider);
    final repository = ref.watch(scheduleRepositoryProvider);
    return repository.getSchedules(status: status, category: category);
  }

  /// 일정 상태 변경 (확정 시 캘린더 이벤트 자동 생성)
  Future<void> updateStatus(int id, ScheduleStatus status) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.updateStatus(id, status);

    // 확정 시 캘린더 이벤트 자동 생성
    if (status == ScheduleStatus.confirmed) {
      final calendarRepo = ref.read(calendarRepositoryProvider);
      await calendarRepo.createFromSchedule(id);
      ref.invalidate(monthEventsByYearMonthProvider);
      ref.invalidate(selectedMonthEventsProvider);
    }

    ref.invalidateSelf();
  }

  /// 일정 삭제
  Future<void> deleteSchedule(int id) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.deleteSchedule(id);
    ref.invalidateSelf();
  }

  /// 일정 수정
  Future<void> updateSchedule(
    int id, {
    String? title,
    DateTime? date,
    String? description,
  }) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.updateSchedule(
      id,
      title: title,
      date: date,
      description: description,
    );
    ref.invalidateSelf();
  }

  /// 검토 대기 일정 일괄 확정 (캘린더 이벤트 일괄 생성).
  /// 카테고리 필터가 켜져 있으면 그 카테고리만 대상.
  Future<void> confirmAllPending() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final category = ref.read(scheduleCategoryFilterProvider);

    // 확정 전에 대상 pending 일정 ID를 미리 조회
    final pendingSchedules = await repository.getSchedules(
      status: ScheduleStatus.pending,
      category: category,
    );

    await repository.confirmAllPending(category: category);

    // 각 확정된 일정에 대해 캘린더 이벤트 생성
    final calendarRepo = ref.read(calendarRepositoryProvider);
    for (final schedule in pendingSchedules) {
      if (schedule.id != null) {
        await calendarRepo.createFromSchedule(schedule.id!);
      }
    }
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidate(selectedMonthEventsProvider);

    ref.invalidateSelf();
  }

  /// 전체 일정 삭제 (테스트용)
  Future<void> deleteAll() async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.deleteAll();
    ref.invalidate(monthEventsByYearMonthProvider);
    ref.invalidate(selectedMonthEventsProvider);
    ref.invalidateSelf();
  }

  /// 가져온 일정에서 생성
  Future<void> createFromImported(
    int importedScheduleId,
    DateTime scheduledDate,
  ) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.createFromImported(importedScheduleId, scheduledDate);
    ref.invalidateSelf();
  }
}
