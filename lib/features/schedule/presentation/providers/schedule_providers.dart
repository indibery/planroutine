import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../data/schedule_repository.dart';
import '../../domain/entry_kind.dart';
import '../../domain/schedule.dart';

/// 일정 리포지토리 프로바이더
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

/// 일정 상태 필터. 기본 = 검토 대기 — 확정된 일정은 기본 리스트에서 빠지고
/// '확정됨' 칩으로만 본다(검토 탭의 주인공은 아직 결정 안 된 일정).
final scheduleStatusFilterProvider = StateProvider<ScheduleStatus?>((ref) {
  return ScheduleStatus.pending;
});

/// 종류 필터. null = 전체 — 업무와 행사를 한 목록에서 같이 검토하는 게 기본.
final scheduleKindFilterProvider = StateProvider<EntryKind?>((ref) => null);

/// 상태 칩 건수(`pending`/`confirmed`)는 **전역**(카테고리·종류 무관) — 진행도 바와
/// 확정 요약이 쓰고, 다른 상태로 넘어갈지 판단하려면 거기 몇 건이 있는지 보여야 한다.
/// schedulesProvider 변경(확정/삭제/등록)에 반응해 갱신.
///
/// 반면 종류별 대기(`pendingTask`/`pendingEvent`)는 **카테고리 필터를 반영**한다.
/// 이 둘은 종류 칩 라벨로만 쓰이는데, 칩이 약속한 건수와 눌렀을 때 나오는 목록이
/// 다르면(`행사 4`를 눌렀는데 빈 화면) 칩이 거짓말을 한 게 된다.
/// 종류 필터 자체는 반영하지 않는다 — 지금 안 보는 종류가 몇 건인지 알아야 넘어간다.
final scheduleCountsProvider =
    FutureProvider<
      ({int pending, int confirmed, int pendingTask, int pendingEvent})
    >((ref) async {
      await ref.watch(schedulesProvider.future);
      final repository = ref.watch(scheduleRepositoryProvider);
      final category = ref.watch(scheduleCategoryFilterProvider);
      final pending = await repository.getSchedules(
        status: ScheduleStatus.pending,
      );
      final confirmed = await repository.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      // 리포지토리의 `if (category != null)`과 같은 규칙이어야 한다 — 건수와 쿼리가
      // "카테고리 없음"을 다르게 해석하면 칩이 약속한 수와 실제 대상이 갈린다.
      final inCategory = category == null
          ? pending
          : pending.where((s) => s.category == category).toList();
      return (
        pending: pending.length,
        confirmed: confirmed.length,
        pendingTask: inCategory.where((s) => s.kind == EntryKind.task).length,
        pendingEvent: inCategory.where((s) => s.kind == EntryKind.event).length,
      );
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
    final kind = ref.watch(scheduleKindFilterProvider);
    final repository = ref.watch(scheduleRepositoryProvider);
    return repository.getSchedules(
      status: status,
      category: category,
      kind: kind,
    );
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

  /// 삭제한 일정 복구 (스와이프 삭제 Undo용)
  Future<void> restoreSchedule(int id) async {
    final repository = ref.read(scheduleRepositoryProvider);
    await repository.restoreSchedule(id);
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
  /// [kind]를 주면 그 종류만 — 입력 탭의 `일괄 업무 등록`/`일괄 행사 등록`.
  Future<void> confirmAllPending({EntryKind? kind}) async {
    final repository = ref.read(scheduleRepositoryProvider);
    final category = ref.read(scheduleCategoryFilterProvider);

    // 확정 전에 대상 pending 일정 ID를 미리 조회
    final pendingSchedules = await repository.getSchedules(
      status: ScheduleStatus.pending,
      category: category,
      kind: kind,
    );

    await repository.confirmAllPending(category: category, kind: kind);

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

  /// 검토 대기 일정 일괄 삭제(휴지통). 카테고리·종류 필터가 켜져 있으면 거기에 한정.
  /// 확정본은 건드리지 않으며 캘린더 이벤트에도 영향 없음.
  /// 두 필터를 모두 봐야 하는 이유는 `ScheduleRepository.deleteAllPending` 참고.
  Future<void> deleteAllPending() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final category = ref.read(scheduleCategoryFilterProvider);
    final kind = ref.read(scheduleKindFilterProvider);
    await repository.deleteAllPending(category: category, kind: kind);
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
