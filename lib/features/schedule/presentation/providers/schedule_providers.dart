import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../data/schedule_repository.dart';
import '../../domain/entry_kind.dart';
import '../../domain/schedule.dart';

/// 일정 리포지토리 프로바이더
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository();
});

/// 검토 대기 목록.
///
/// **상태·종류·카테고리 필터는 없다**(2026-09-03 단순화). 이 목록은 항상 검토
/// 대기이고, 확정하면 캘린더로 넘어가 여기서 빠진다. 확정된 일정을 이 탭에서
/// 다시 볼 방법은 두지 않았다 — 조작부가 넷이던 시절 "무엇이 지금 목록을
/// 정하는지" 읽을 수 없다는 신고가 있었다.
///
/// ⚠️ 목록에서 빠지는 것과 행이 지워지는 것은 다르다. `schedules` 행은 남는다 —
/// CSV 내보내기·`작년` 배지·중복 체크가 그 행을 본다.
final schedulesProvider =
    AsyncNotifierProvider<SchedulesNotifier, List<Schedule>>(
      SchedulesNotifier.new,
    );

/// 일정 목록 관리 Notifier
class SchedulesNotifier extends AsyncNotifier<List<Schedule>> {
  @override
  Future<List<Schedule>> build() async {
    final repository = ref.watch(scheduleRepositoryProvider);
    return repository.getSchedules(status: ScheduleStatus.pending);
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
  /// [kind]를 주면 그 종류만 — 입력 탭이 종류별로 나눠 확정한다.
  Future<void> confirmAllPending({EntryKind? kind}) async {
    final repository = ref.read(scheduleRepositoryProvider);

    // 확정 전에 대상 pending 일정 ID를 미리 조회
    final pendingSchedules = await repository.getSchedules(
      status: ScheduleStatus.pending,
      kind: kind,
    );

    await repository.confirmAllPending(kind: kind);

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

  /// 검토 대기 일정 일괄 삭제(휴지통) — **대기 전체**.
  /// 필터가 없어졌으므로 범위를 좁힐 인자도 없다. 확정본은 건드리지 않으며
  /// 캘린더 이벤트에도 영향이 없다.
  ///
  /// **실제로 옮긴 건수를 돌려준다.** 버리면 안 된다 — 스낵바가 화면에서 센 수를
  /// 말하고 쿼리가 다른 범위를 잡으면, 그 어긋남이 런타임에도 드러나지 않는다.
  /// `행사 4건 삭제`를 눌러 21건이 사라졌는데 스낵바는 `4건을 옮겼어요`라 말한
  /// 그 버그가 정확히 이 모양이었다.
  Future<int> deleteAllPending() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final moved = await repository.deleteAllPending();
    ref.invalidateSelf();
    return moved;
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
