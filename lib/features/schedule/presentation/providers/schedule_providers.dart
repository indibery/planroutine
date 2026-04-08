import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// 일정 목록 관리 Notifier
class SchedulesNotifier extends AsyncNotifier<List<Schedule>> {
  @override
  Future<List<Schedule>> build() async {
    final status = ref.watch(scheduleStatusFilterProvider);
    final category = ref.watch(scheduleCategoryFilterProvider);
    final repository = ref.watch(scheduleRepositoryProvider);
    return repository.getSchedules(status: status, category: category);
  }

  /// 일정 상태 변경
  Future<void> updateStatus(int id, ScheduleStatus status) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.updateStatus(id, status);
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

  /// 검토 대기 일정 일괄 확정
  Future<void> confirmAllPending() async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.confirmAllPending();
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
