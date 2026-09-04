import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/bulk_bar_snack.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../import/presentation/widgets/photo_input_hero.dart';
import '../../domain/entry_kind.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import '../widgets/schedule_edit_sheet.dart';
import '../widgets/schedule_tile.dart';
import '../widgets/slide_hint_bar.dart';

/// 입력 탭 — 넣기가 주인공, **검토 대기**는 그 아래.
///
/// 사용자가 자주 하는 동작은 검토가 아니라 **넣기**(월간 일정표 사진 → AI 변환)라서
/// 히어로를 맨 위에 두고, 검토 영역은 대기가 있을 때만 아래에서 커진다.
///
/// **조작부는 둘뿐이다**(2026-09-03 단순화): 대기 일괄 삭제 pill 하나와 하단
/// 종류별 일괄 확정 pill. 그 전에는 상태 칩·종류 칩·카테고리 칩·접히는 `필터`
/// 토글에 진행도 바와 `확정됨 N건 보기` 링크까지 겹쳐, 무엇이 지금 목록을 정하는지
/// 읽을 수 없다는 신고를 받았다.
///
/// 확정하면 캘린더로 넘어가고 이 목록에서 빠진다 — **행을 지우는 것이 아니다**
/// (CSV 내보내기·`작년` 배지·중복 체크가 그 행을 본다).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  /// 종류별 일괄 확정 pill — 테스트가 문구가 아니라 **정체**로 찾게 한다.
  /// "해당 종류 0건이면 숨는다"를 문자열로 검사하면, 다음 문구 개편에서 그 문자열이
  /// 아무 데서도 렌더되지 않는 순간 `findsNothing`이 0건 pill을 보고도 통과한다.
  static const bulkRegisterTaskKey = Key('bulk_register_task');
  static const bulkRegisterEventKey = Key('bulk_register_event');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);
    // 한 번만 푼다 — 아래 두 헬퍼가 각자 `valueOrNull`을 다시 열면
    // 로딩·오류 상태를 다루는 것처럼 보이는데, 실제로는 못 본다.
    final pending = schedulesAsync.valueOrNull ?? const <Schedule>[];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('INPUT', style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            Text(ScheduleStrings.title, style: AppTextStyles.heading),
          ],
        ),
      ),
      body: Column(
        children: [
          // 주 경로 = 사진 AI. 작년 업무 CSV는 히어로 안의 보조 한 줄.
          PhotoInputHero(onOpenCsvImport: () => context.push(AppRoutes.import)),
          const Divider(height: 1),
          // 검토할 것이 있을 때만 안내와 일괄 삭제가 나온다.
          // 목록이 곧 대기 목록이라 "비었다 = 검토할 것이 없다"가 된다.
          if (pending.isNotEmpty) ...[
            const SlideHintBar(),
            _buildDeletePendingRow(context, ref, pending),
            const Divider(height: 1),
          ],
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) => schedules.isEmpty
                  ? _buildEmptyState()
                  : _buildScheduleList(context, ref, schedules),
              loading: () => const Center(child: CircularProgressIndicator()),
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
          _buildBulkRegisterBar(context, ref, pending),
        ],
      ),
    );
  }

  /// 종류별 일괄 확정 바 — `일괄 업무 확정 N건` / `일괄 행사 확정 N건`.
  ///
  /// 건수는 **목록의 종류별 대기 수**이고, 해당 종류가 0이면 그 pill은 숨는다.
  /// 성격이 다른 것이 한 번에 섞여 확정되지 않게 나눴다.
  ///
  /// `status`로 다시 거르지 않는다 — 아래 삭제 pill과 같은 규칙이다. 목록이 항상
  /// 대기이므로 재필터는 아무것도 걸러내지 못하면서 "확정도 이 목록에 들어올 수
  /// 있다"는 잘못된 신호만 준다.
  Widget _buildBulkRegisterBar(
    BuildContext context,
    WidgetRef ref,
    List<Schedule> pending,
  ) {
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
      // spacing은 **렌더된** 자식 사이에만 들어간다 — 한쪽 pill이 숨어도
      // 빈 간격이 남지 않으므로 "둘 다 있을 때만 간격" 조건이 필요 없다.
      child: Row(
        spacing: AppSizes.spacing8,
        children: [
          if (taskCount > 0)
            Expanded(
              child: _BulkConfirmPill(
                key: bulkRegisterTaskKey,
                label: ScheduleStrings.bulkConfirm(
                  EntryKind.task.label,
                  taskCount,
                ),
                onPressed: () => _showBulkConfirmDialog(
                  context,
                  ref,
                  kind: EntryKind.task,
                  pendingCount: taskCount,
                ),
              ),
            ),
          if (eventCount > 0)
            Expanded(
              child: _BulkConfirmPill(
                key: bulkRegisterEventKey,
                label: ScheduleStrings.bulkConfirm(
                  EntryKind.event.label,
                  eventCount,
                ),
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

  /// 대기 일괄 삭제 pill 한 줄.
  ///
  /// 필터 바가 사라지면서 이 pill이 얹혀 있던 `trailing` 자리가 없어져 자기 줄을
  /// 갖는다. 목록 위 오른쪽에 조용히 둔다 — 주역은 아래 목록과 하단 확정 pill이다.
  ///
  /// 건수는 목록 길이 그대로다. 목록이 항상 대기라 `status`로 다시 거를 이유가 없고,
  /// 거르면 "화면에 보이는 수"와 "지워지는 수"가 갈릴 여지만 생긴다.
  ///
  /// 호출부가 이미 비어 있지 않음을 확인하고 부르므로 0건 분기를 두지 않는다.
  Widget _buildDeletePendingRow(
    BuildContext context,
    WidgetRef ref,
    List<Schedule> pending,
  ) {
    final pendingCount = pending.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing8,
        AppSizes.spacing16,
        AppSizes.spacing8,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: _DeleteAllPill(
          label: ScheduleStrings.deletePending(pendingCount),
          onPressed: () =>
              _showBulkDeleteDialog(context, ref, pendingCount: pendingCount),
        ),
      ),
    );
  }

  /// 검토할 대기가 없을 때. **문구 하나뿐이다.**
  ///
  /// 예전에는 여기서 `확정 N건` 요약과 `확정됨 N건 보기` 링크를 띄웠다. 그 링크가
  /// 확정 뷰로 가는 유일한 문이었는데, 그 뷰를 없앴으므로 문도 없앴다.
  /// 다음 행동(넣기)은 위 히어로가 이미 맡고 있어 여기서 CTA를 다시 세우지 않는다.
  /// 대기가 0이면 하단 확정 pill도 스와이프 안내 바도 안 뜬다 — **이 블록이 화면의
  /// 전부**라 상태와 다음 행동을 함께 말한다(오늘 탭·버스 카드와 같은 두 줄 문법).
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 64, color: AppColors.faint),
            const SizedBox(height: AppSizes.spacing16),
            Text(
              ScheduleStrings.empty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.sub,
              ),
            ),
            const SizedBox(height: AppSizes.spacing4),
            Text(
              ScheduleStrings.emptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: AppColors.faint,
              ),
            ),
          ],
        ),
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

    // 목록 아래에 붙이던 초록 `확정 N건은 캘린더에 반영됨` 줄은 없앴다 —
    // 그것도 확정 뷰로 가는 문이었고, 확정 건수를 아는 마지막 자리였다.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final monthKey = sortedKeys[index];
        final items = grouped[monthKey] ?? [];
        return _buildMonthGroup(context, ref, monthKey, items);
      },
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
                ref
                    .read(schedulesProvider.notifier)
                    .updateStatus(id, ScheduleStatus.confirmed);
              }
            },
            onDelete: () {
              if (schedule.id case final id?) {
                ref.read(schedulesProvider.notifier).deleteSchedule(id);
                // **실행취소를 달지 않는다.** 앱의 다른 삭제 경로에 없어서 여기만
                // 예외였고, 그 비일관이 불편으로 신고됐다(2026-09-04). 되돌리는
                // 길은 휴지통 하나로 모은다 — soft-delete라 값은 남아 있다.
                //
                // 알림은 pill 위로 띄운다(`showBulkBarSnack`). 액션이 없어도
                // 가리면 4초 동안 확정을 누를 수 없다.
                showBulkBarSnack(context, ScheduleStrings.deletedSnack);
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
    // 확정 범위의 종류는 눌린 pill에서 온다(표시 이름의 단일 출처는
    // `EntryKind.label`). 삭제 쪽은 범위가 대기 전체라 스코프 문구가 아예 없다.
    final scope = kind.label;
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
  ///
  /// 범위를 좁히는 인자가 없다 — 필터가 없어졌으므로 대상은 언제나 대기 전체이고,
  /// 그 수가 곧 pill에 적힌 수다. 문구와 쿼리가 갈릴 자리가 사라졌다.
  Future<void> _showBulkDeleteDialog(
    BuildContext context,
    WidgetRef ref, {
    required int pendingCount,
  }) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: ScheduleStrings.bulkDeleteTitle,
      message: ScheduleStrings.bulkDeleteMessage(pendingCount),
      confirmLabel: ScheduleStrings.delete,
      confirmColor: AppColors.error,
    );
    if (!ok) return;
    // 스낵바는 **DB가 실제로 옮긴 수**를 말한다. 화면에서 센 `pendingCount`를
    // 그대로 쓰면, pill의 범위와 쿼리의 범위가 갈려도 사용자에게 드러나지 않는다.
    final moved = await ref.read(schedulesProvider.notifier).deleteAllPending();
    if (!context.mounted) return;
    showBulkBarSnack(context, ScheduleStrings.bulkDeletedSnack(moved));
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

/// 하단 종류별 일괄 확정 pill — 골드 채움 + onGold 글씨.
class _BulkConfirmPill extends StatelessWidget {
  const _BulkConfirmPill({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 붙여넣기 스낵바가 이 바를 비켜 뜨려면 높이를 한 곳에서 읽어야 한다
        // (`AppSizes.bulkRegisterBarHeight`가 이 값에서 파생된다).
        height: AppSizes.bulkRegisterPillHeight,
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

/// 목록 위 오른쪽의 소형 빨강 outline pill — '검토 대기 일괄 삭제'(확정 pill 대칭).
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
