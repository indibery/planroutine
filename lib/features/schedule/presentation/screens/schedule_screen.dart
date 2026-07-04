import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import '../widgets/category_label.dart';
import '../widgets/schedule_edit_sheet.dart';
import '../widgets/schedule_filter_bar.dart';
import '../widgets/schedule_tile.dart';
import '../widgets/slide_hint_bar.dart';

/// 일정 검토/확정 화면
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
            Text(
              'REVIEW',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ScheduleStrings.title,
              style: AppTextStyles.heading,
            ),
          ],
        ),
        actions: [
          // 가져오기 상시 진입점 — 검토할 일정의 공급 문은 검토 탭에 둔다.
          IconButton(
            icon: Icon(Icons.file_download_outlined,
                color: AppColors.gold),
            tooltip: ScheduleStrings.goImport,
            onPressed: () => context.push(AppRoutes.import),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgress(context, ref, schedulesAsync),
          // 스와이프 안내는 스와이프할 목록이 있을 때만
          if (schedulesAsync.valueOrNull?.isNotEmpty ?? false)
            const SlideHintBar(),
          // 검토가 모두 끝난 완료 상태에선 필터할 게 없으므로 필터 줄을 숨긴다.
          if (!_reviewComplete(ref)) ...[
            const ScheduleFilterBar(),
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
        ],
      ),
    );
  }

  /// 확정/전체 일정 진행도 바. 오른쪽에 '전체 확정' pill 버튼을 인라인 배치한다.
  Widget _buildProgress(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Schedule>> schedulesAsync,
  ) {
    // 진행도는 전역 건수(카테고리·상태 필터 무관) — 기본 뷰가 대기만 보여줘도
    // "전체 중 몇 건 확정"이 유지되도록.
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;
    return schedulesAsync.when(
      data: (list) {
        final total = (counts?.pending ?? 0) + (counts?.confirmed ?? 0);
        if (counts == null || total == 0) return const SizedBox.shrink();
        final confirmed = counts.confirmed;
        // 일괄 확정 pill은 현재 뷰(카테고리 필터 반영)의 대기 건수 기준
        final pendingCount =
            list.where((s) => s.status == ScheduleStatus.pending).length;
        final hasPending = pendingCount > 0;
        final category = ref.watch(scheduleCategoryFilterProvider);
        final ratio = confirmed / total;
        final percent = (ratio * 100).round();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.spacing12,
            AppSizes.pagePadding,
            AppSizes.spacing4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      // 대기가 있으면 우측 두 pill(삭제·확정)에 공간을 내주려 축약.
                      hasPending
                          ? '$confirmed / $total'
                          : '$confirmed / $total · $percent% 완료',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sub,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasPending) ...[
                    _DeleteAllPill(
                      label: ScheduleStrings.deletePending(pendingCount),
                      onPressed: () => _showBulkDeleteDialog(
                        context,
                        ref,
                        category: category,
                        pendingCount: pendingCount,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacing8),
                    _ConfirmAllPill(
                      label: ScheduleStrings.confirmPending(pendingCount),
                      onPressed: () => _showBulkConfirmDialog(
                        context,
                        ref,
                        category: category,
                        pendingCount: pendingCount,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                child: Stack(
                  children: [
                    Container(
                      height: 2,
                      color: AppColors.navySoft,
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: AppGradients.progress,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
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
          if (!hasFilter) ...[
            const SizedBox(height: AppSizes.spacing16),
            Builder(
              builder: (context) => GoldGradientButton(
                label: ScheduleStrings.goImport,
                icon: Icons.file_download_outlined,
                onPressed: () => context.push(AppRoutes.import),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 모두 확정된 뒤의 조용한 완료 화면 — 리스트 대신 절제된 마무리.
  Widget _buildReviewDoneState(WidgetRef ref, int confirmedCount) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.inkGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check,
                size: 34, color: AppColors.inkGreen),
          ),
          const SizedBox(height: AppSizes.spacing16),
          Text(
            ScheduleStrings.reviewDoneTitle,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            ScheduleStrings.reviewDoneBody(confirmedCount),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              height: 1.65,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: AppSizes.spacing20),
          // 주 행동 = 다음 공급(가져오기) 골드 pill. 확정 기록 보기는 약한 텍스트 링크로.
          Builder(
            builder: (context) => GoldGradientButton(
              label: ScheduleStrings.goImport,
              icon: Icons.file_download_outlined,
              onPressed: () => context.push(AppRoutes.import),
            ),
          ),
          const SizedBox(height: AppSizes.spacing4),
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
    required String? category,
    required int pendingCount,
  }) async {
    final scope =
        (category == null || category.isEmpty) ? ScheduleStrings.all : shortenCategory(category);
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: ScheduleStrings.bulkConfirmTitle,
      message: ScheduleStrings.bulkConfirmMessageFor(scope, pendingCount),
      confirmLabel: ScheduleStrings.confirm,
    );
    if (!confirmed) return;
    ref.read(schedulesProvider.notifier).confirmAllPending();
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

/// 진행도 행 우측의 소형 골드 pill — '전체 확정' 액션.
class _ConfirmAllPill extends StatelessWidget {
  const _ConfirmAllPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
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
            Icon(Icons.done_all, color: AppColors.onGold, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onGold,
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
