import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../import/presentation/widgets/photo_input_hero.dart';
import '../../domain/entry_kind.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import '../widgets/category_label.dart';
import '../widgets/schedule_edit_sheet.dart';
import '../widgets/schedule_filter_bar.dart';
import '../widgets/schedule_tile.dart';
import '../widgets/slide_hint_bar.dart';

/// 입력 탭 — 넣기가 주인공, 검토는 그 아래.
///
/// 사용자가 자주 하는 동작은 검토가 아니라 **넣기**(월간 일정표 사진 → AI 변환)라서
/// 히어로를 맨 위에 두고, 검토 영역은 대기가 있을 때만 아래에서 커진다.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('INPUT', style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            Text(
              ScheduleStrings.title,
              style: AppTextStyles.heading,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 주 경로 = 사진 AI. 작년 업무 CSV는 히어로 안의 보조 한 줄.
          PhotoInputHero(
            onOpenCsvImport: () => context.push(AppRoutes.import),
          ),
          const Divider(height: 1),
          // 스와이프 안내는 스와이프할 목록이 있을 때만
          if (schedulesAsync.valueOrNull?.isNotEmpty ?? false)
            const SlideHintBar(),
          // 검토가 모두 끝난 완료 상태에선 필터할 게 없으므로 필터 줄을 숨긴다.
          if (!_reviewComplete(ref)) ...[
            // 진행도 바는 필터 요약 줄에 붙여야 '확정 N건'의 시각화로 읽힌다.
            _buildProgressBar(ref),
            ScheduleFilterBar(
              trailing: _buildDeletePendingPill(context, ref, schedulesAsync),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) => schedules.isEmpty
                  ? _buildEmptyState(ref)
                  : _buildScheduleList(context, ref, schedules),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.error,
                      style: TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: AppSizes.spacing8),
                    TextButton(
                      onPressed: () => ref.invalidate(schedulesProvider),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBulkRegisterBar(context, ref, schedulesAsync),
        ],
      ),
    );
  }

  /// 종류별 일괄 등록 바 — `일괄 업무 등록 N건` / `일괄 행사 등록 N건`.
  ///
  /// 현재 뷰(카테고리·종류 필터 반영)의 대기 건수 기준이고, 해당 종류의 대기가
  /// 0이면 그 pill은 숨는다. 성격이 다른 것이 한 번에 섞여 확정되지 않게 나눴다.
  Widget _buildBulkRegisterBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Schedule>> schedulesAsync,
  ) {
    final list = schedulesAsync.valueOrNull ?? const <Schedule>[];
    final pending =
        list.where((s) => s.status == ScheduleStatus.pending).toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    final taskCount = pending.where((s) => s.kind == EntryKind.task).length;
    final eventCount = pending.where((s) => s.kind == EntryKind.event).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.spacing8,
        AppSizes.pagePadding,
        AppSizes.spacing12,
      ),
      child: Row(
        children: [
          if (taskCount > 0)
            Expanded(
              child: _BulkRegisterPill(
                label: ScheduleStrings.bulkRegisterTask(taskCount),
                onPressed: () => _showBulkConfirmDialog(
                  context,
                  ref,
                  kind: EntryKind.task,
                  pendingCount: taskCount,
                ),
              ),
            ),
          if (taskCount > 0 && eventCount > 0)
            const SizedBox(width: AppSizes.spacing8),
          if (eventCount > 0)
            Expanded(
              child: _BulkRegisterPill(
                label: ScheduleStrings.bulkRegisterEvent(eventCount),
                onPressed: () => _showBulkConfirmDialog(
                  context,
                  ref,
                  kind: EntryKind.event,
                  pendingCount: eventCount,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 확정 진행도 — 2px 바만 남긴다.
  ///
  /// `149 / 149 · 100% 완료` 텍스트는 필터 요약 줄의 `확정됨 149`와 같은 말이었다.
  /// 같은 숫자를 두 번 말하느라 43px을 썼으므로 텍스트를 버리고 바만 남겼다.
  Widget _buildProgressBar(WidgetRef ref) {
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;
    if (counts == null) return const SizedBox.shrink();
    final total = counts.pending + counts.confirmed;
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      // 좌우는 필터 줄과 같은 16 — 눈금이 어긋나면 장식처럼 보인다.
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing8,
        AppSizes.spacing16,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Stack(
          children: [
            Container(height: 2, color: AppColors.navySoft),
            FractionallySizedBox(
              widthFactor: (counts.confirmed / total).clamp(0.0, 1.0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(gradient: AppGradients.progress),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 검토 대기 일괄 삭제 pill — 필터 요약 줄 우측에 얹는다.
  /// 건수는 현재 뷰(카테고리·종류 필터 반영) 기준. 대기가 없으면 아예 없다.
  Widget? _buildDeletePendingPill(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Schedule>> schedulesAsync,
  ) {
    final list = schedulesAsync.valueOrNull ?? const <Schedule>[];
    final pendingCount =
        list.where((s) => s.status == ScheduleStatus.pending).length;
    if (pendingCount == 0) return null;
    final category = ref.watch(scheduleCategoryFilterProvider);

    return _DeleteAllPill(
      label: ScheduleStrings.deletePending(pendingCount),
      onPressed: () => _showBulkDeleteDialog(
        context,
        ref,
        category: category,
        pendingCount: pendingCount,
      ),
    );
  }

  /// 검토 완료 상태 판정 — 대기 0 + 확정 있음 + 카테고리 필터 없음 + 대기 뷰.
  /// body의 필터 줄 숨김과 _buildEmptyState의 완료 화면 분기가 같은 기준을 쓴다.
  bool _reviewComplete(WidgetRef ref) {
    final status = ref.watch(scheduleStatusFilterProvider);
    final hasCategoryFilter =
        ref.watch(scheduleCategoryFilterProvider) != null;
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;
    if (counts == null) return false;
    return status == ScheduleStatus.pending &&
        !hasCategoryFilter &&
        counts.confirmed > 0 &&
        counts.pending == 0;
  }

  Widget _buildEmptyState(WidgetRef ref) {
    final status = ref.watch(scheduleStatusFilterProvider);
    final hasCategoryFilter =
        ref.watch(scheduleCategoryFilterProvider) != null;
    final confirmedCount =
        ref.watch(scheduleCountsProvider).valueOrNull?.confirmed ?? 0;

    if (_reviewComplete(ref)) {
      return _buildReviewDoneState(ref, confirmedCount);
    }

    final hasFilter =
        status == ScheduleStatus.confirmed || hasCategoryFilter;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: AppColors.faint,
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            hasFilter
                ? ScheduleStrings.emptyFiltered
                : ScheduleStrings.empty,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }

  /// 대기가 없을 때의 최소 요약 — `검토 대기 없음 · 확정 N건` + 보기 링크 한 줄.
  ///
  /// 검토는 검토할 때만 크게 나온다. 다음 행동(넣기)은 위 히어로가 이미 맡고 있어
  /// 여기서 다시 CTA를 세우지 않는다.
  Widget _buildReviewDoneState(WidgetRef ref, int confirmedCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.spacing12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: AppColors.inkGreen),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  ScheduleStrings.reviewIdle,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: AppColors.sub,
                  ),
                ),
              ),
              Text(
                ScheduleStrings.confirmedTotal(confirmedCount),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () =>
                ref.read(scheduleStatusFilterProvider.notifier).state =
                    ScheduleStatus.confirmed,
            style: TextButton.styleFrom(foregroundColor: AppColors.sub),
            child: Text(ScheduleStrings.viewConfirmed(confirmedCount)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(
    BuildContext context,
    WidgetRef ref,
    List<Schedule> schedules,
  ) {
    final grouped = <String, List<Schedule>>{};
    for (final schedule in schedules) {
      final monthKey = _extractMonthKey(schedule.scheduledDate);
      grouped.putIfAbsent(monthKey, () => []).add(schedule);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    // 대기 뷰 하단에 "확정 N건은 캘린더에 반영됨" 요약 — 확정분이 사라진 게
    // 아니라 반영됐음을 상기. 탭하면 확정됨 뷰로 전환.
    final confirmedCount =
        ref.watch(scheduleCountsProvider).valueOrNull?.confirmed ?? 0;
    final showDoneSummary =
        ref.watch(scheduleStatusFilterProvider) == ScheduleStatus.pending &&
            confirmedCount > 0;

    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: AppSizes.spacing16,
      ),
      itemCount: sortedKeys.length + (showDoneSummary ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == sortedKeys.length) {
          return _buildDoneSummary(ref, confirmedCount);
        }
        final monthKey = sortedKeys[index];
        final items = grouped[monthKey] ?? [];
        return _buildMonthGroup(context, ref, monthKey, items);
      },
    );
  }

  /// 대기 목록 아래 초록 요약 한 줄 — 탭하면 확정됨 뷰로.
  Widget _buildDoneSummary(WidgetRef ref, int confirmedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing8,
        AppSizes.spacing16,
        AppSizes.spacing4,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius12),
        onTap: () => ref.read(scheduleStatusFilterProvider.notifier).state =
            ScheduleStatus.confirmed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing12,
            vertical: AppSizes.spacing12,
          ),
          decoration: BoxDecoration(
            color: AppColors.inkGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSizes.radius12),
            border: Border.all(
              color: AppColors.inkGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle,
                  size: 16, color: AppColors.inkGreen),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  ScheduleStrings.doneSummary(confirmedCount),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.sub,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 16, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGroup(
    BuildContext context,
    WidgetRef ref,
    String monthKey,
    List<Schedule> schedules,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing16,
            AppSizes.spacing8,
          ),
          child: Text(
            _formatMonthKey(monthKey),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
        ...schedules.map(
          (schedule) => ScheduleTile(
            schedule: schedule,
            onConfirm: () {
              if (schedule.id case final id?) {
                ref.read(schedulesProvider.notifier).updateStatus(
                      id,
                      ScheduleStatus.confirmed,
                    );
              }
            },
            onDelete: () {
              if (schedule.id case final id?) {
                final notifier = ref.read(schedulesProvider.notifier);
                notifier.deleteSchedule(id);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                    content: const Text(ScheduleStrings.deletedSnack),
                    action: SnackBarAction(
                      label: ScheduleStrings.undoAction,
                      onPressed: () => notifier.restoreSchedule(id),
                    ),
                  ));
              }
            },
            onTap: () => ScheduleEditSheet.show(context, schedule),
          ),
        ),
      ],
    );
  }

  Future<void> _showBulkConfirmDialog(
    BuildContext context,
    WidgetRef ref, {
    required EntryKind kind,
    required int pendingCount,
  }) async {
    final scope = kind == EntryKind.task
        ? ScheduleStrings.kindTask
        : ScheduleStrings.kindEvent;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: ScheduleStrings.bulkConfirmTitle,
      message: ScheduleStrings.bulkConfirmMessageFor(scope, pendingCount),
      confirmLabel: ScheduleStrings.confirm,
    );
    if (!confirmed) return;
    ref.read(schedulesProvider.notifier).confirmAllPending(kind: kind);
  }

  /// 남은 검토 대기를 한 번에 휴지통으로 (일괄 확정 대칭). soft-delete라 복구 가능.
  Future<void> _showBulkDeleteDialog(
    BuildContext context,
    WidgetRef ref, {
    required String? category,
    required int pendingCount,
  }) async {
    final scope = (category == null || category.isEmpty)
        ? ScheduleStrings.all
        : shortenCategory(category);
    final ok = await ConfirmDialog.show(
      context: context,
      title: ScheduleStrings.bulkDeleteTitle,
      message: ScheduleStrings.bulkDeleteMessageFor(scope, pendingCount),
      confirmLabel: ScheduleStrings.delete,
      confirmColor: AppColors.error,
    );
    if (!ok) return;
    await ref.read(schedulesProvider.notifier).deleteAllPending();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(ScheduleStrings.bulkDeletedSnack(pendingCount)),
      ));
  }

  String _extractMonthKey(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length >= 7 ? dateStr.substring(0, 7) : dateStr;
    }
  }

  String _formatMonthKey(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length >= 2) {
        return '${parts[0]}${AppStrings.compareYearFormat} ${int.parse(parts[1])}월';
      }
    } catch (_) {}
    return monthKey;
  }
}

/// 하단 종류별 일괄 등록 pill — 골드 채움 + onGold 글씨.
class _BulkRegisterPill extends StatelessWidget {
  const _BulkRegisterPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.gold,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, color: AppColors.onGold, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 진행도 행의 소형 빨강 outline pill — '검토 대기 일괄 삭제' 액션(확정 pill 대칭).
class _DeleteAllPill extends StatelessWidget {
  const _DeleteAllPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
