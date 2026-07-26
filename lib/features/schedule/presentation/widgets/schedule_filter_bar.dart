import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/entry_kind.dart';
import '../../domain/filter_summary.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import 'category_label.dart';

/// 입력 탭 검토 영역 필터 바 — **접히는** 한 줄 + 펼친 칩 3줄.
///
/// 접힌 줄: `[검토 대기 21 · 업무] [21건 삭제] [▾]`
/// 펼친 칩: 상태(대기/확정됨) · 종류(업무/학교일정 토글) · 카테고리(동적, 없으면 숨김)
///
/// 히어로가 위쪽을 210px 쓰기 때문에 칩 3줄(약 166px)을 항상 펼쳐두면 iPhone에서
/// 검토 목록에 두어 칸밖에 남지 않는다. 그렇다고 필터를 화면 밖(바텀시트)으로
/// 보내면 지금 무엇으로 걸러졌는지 알 수 없다 — 그래서 **요약은 남기고 칩만 접는다**.
///
/// 초기 상태는 대기 건수로 정한다: 검토할 것이 있으면 펼침, 없으면 접힘.
/// 이 앱은 학기 초에 검토를 몰아서 하고 그 뒤엔 조용하다.
class ScheduleFilterBar extends ConsumerStatefulWidget {
  const ScheduleFilterBar({super.key, this.trailing});

  /// 접힌 줄 우측에 함께 놓을 위젯(일괄 삭제 pill). 진행도 행을 없앴으므로
  /// 대기 관련 액션은 이 줄이 맡는다.
  final Widget? trailing;

  static const summaryKey = Key('filter_summary');
  static const chipRowsKey = Key('filter_chip_rows');
  static const toggleKey = Key('filter_toggle');

  @override
  ConsumerState<ScheduleFilterBar> createState() => _ScheduleFilterBarState();
}

class _ScheduleFilterBarState extends ConsumerState<ScheduleFilterBar> {
  /// null = 아직 사용자가 손대지 않음 → 대기 건수로 자동 결정.
  bool? _expandedOverride;

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;
    final status = ref.watch(scheduleStatusFilterProvider);
    final kind = ref.watch(scheduleKindFilterProvider);
    final category = ref.watch(scheduleCategoryFilterProvider);
    final categoryLabel =
        (category == null || category.isEmpty) ? null : shortenCategory(category);

    // 건수를 모르는 동안 요약을 그리면 '검토 대기 0'이 잠깐 스쳐 오해를 준다.
    if (counts == null) return const SizedBox.shrink();

    // 기본은 접힘. 넣기(히어로)와 검토 목록에 높이를 내주는 것이 이 탭의 목적이고,
    // 필터를 쓰는 순간은 그보다 드물다. 접힌 줄이 현재 필터를 말해주므로 정보 손실도 없다.
    final expanded = _expandedOverride ?? false;
    final narrowed =
        hasNarrowingFilter(kind: kind, categoryLabel: categoryLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16,
            AppSizes.spacing8,
            AppSizes.spacing16,
            AppSizes.spacing4,
          ),
          child: Row(
            children: [
              Flexible(
                child: GestureDetector(
                  key: ScheduleFilterBar.toggleKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expandedOverride = !expanded),
                  child: Container(
                    // 접혀 있을 때는 이 줄이 유일한 필터 조작부라 눌러 보여야 한다.
                    // 펼치면 아래 칩이 주역이므로 테두리를 벗고 조용해진다.
                    padding: expanded
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: expanded
                        ? null
                        : BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusPill),
                            border: Border.all(
                              color: narrowed ? AppColors.gold : AppColors.line,
                              width: narrowed ? 1.0 : 0.5,
                            ),
                            color: narrowed
                                ? AppColors.goldFill.withValues(alpha: 0.15)
                                : null,
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            key: ScheduleFilterBar.summaryKey,
                            // 펼쳐져 있으면 칩이 다 보이므로 요약은 군더더기다.
                            expanded
                                ? ScheduleStrings.filter
                                : buildFilterSummary(
                                    status: status,
                                    kind: kind,
                                    categoryLabel: categoryLabel,
                                    pendingCount: counts.pending,
                                    confirmedCount: counts.confirmed,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: (!expanded && narrowed)
                                  ? AppColors.gold
                                  : AppColors.sub,
                            ),
                          ),
                        ),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: narrowed && !expanded
                              ? AppColors.gold
                              : AppColors.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.trailing case final trailing?) ...[
                const SizedBox(width: AppSizes.spacing8),
                trailing,
              ],
            ],
          ),
        ),
        if (expanded)
          const Column(
            key: ScheduleFilterBar.chipRowsKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(),
              _KindRow(),
              _CategoryRow(),
            ],
          ),
      ],
    );
  }
}

/// 상태 필터 1줄 — 검토 대기/확정됨 2칩(건수 표기). '전체'는 없다:
/// 할 일(대기)과 기록(확정)은 목적이 달라 한 화면에 섞지 않는다.
class _StatusRow extends ConsumerWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStatus = ref.watch(scheduleStatusFilterProvider);
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          PillChip(
            label: counts == null
                ? ScheduleStrings.pending
                : ScheduleStrings.chipPending(counts.pending),
            selected: currentStatus == ScheduleStatus.pending,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.pending;
            },
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: counts == null
                ? ScheduleStrings.confirmed
                : ScheduleStrings.chipConfirmed(counts.confirmed),
            selected: currentStatus == ScheduleStatus.confirmed,
            onTap: () {
              ref.read(scheduleStatusFilterProvider.notifier).state =
                  ScheduleStatus.confirmed;
            },
          ),
        ],
      ),
    );
  }
}

/// 종류 필터 1줄 — 업무 / 학교일정 토글.
///
/// '전체' 칩을 두지 않는다 — 아래 카테고리 줄에도 '전체'가 있어 무엇의 전체인지
/// 헷갈린다. 선택된 칩을 다시 누르면 해제(=전체)다.
/// 대기 뷰에서만 건수를 붙인다(확정됨 뷰에서 대기 건수를 보여주면 오독을 부른다).
class _KindRow extends ConsumerWidget {
  const _KindRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(scheduleKindFilterProvider);
    final isPendingView =
        ref.watch(scheduleStatusFilterProvider) == ScheduleStatus.pending;
    final counts = ref.watch(scheduleCountsProvider).valueOrNull;

    String label(String base, int? count) =>
        (isPendingView && count != null) ? '$base $count' : base;

    // 같은 칩 재탭 = 해제. 별도 '전체' 칩 없이 전체로 돌아가는 길을 준다.
    void toggle(EntryKind kind) =>
        ref.read(scheduleKindFilterProvider.notifier).state =
            current == kind ? null : kind;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing4,
      ),
      child: Row(
        children: [
          PillChip(
            label: label(EntryKind.task.label, counts?.pendingTask),
            selected: current == EntryKind.task,
            onTap: () => toggle(EntryKind.task),
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: label(EntryKind.event.label, counts?.pendingEvent),
            selected: current == EntryKind.event,
            onTap: () => toggle(EntryKind.event),
          ),
        ],
      ),
    );
  }
}

/// 카테고리 필터 1줄 (신규).
/// 항목이 0개면 SizedBox.shrink로 줄 자체를 숨김.
class _CategoryRow extends ConsumerWidget {
  const _CategoryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(availableCategoriesProvider);
    final currentCategory = ref.watch(scheduleCategoryFilterProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing16,
            vertical: AppSizes.spacing4,
          ),
          child: Row(
            children: [
              PillChip(
                label: ScheduleStrings.all,
                selected: currentCategory == null,
                onTap: () {
                  ref.read(scheduleCategoryFilterProvider.notifier).state =
                      null;
                },
              ),
              for (final raw in categories) ...[
                const SizedBox(width: AppSizes.spacing8),
                PillChip(
                  label: shortenCategory(raw),
                  selected: currentCategory == raw,
                  onTap: () {
                    ref.read(scheduleCategoryFilterProvider.notifier).state =
                        raw;
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
