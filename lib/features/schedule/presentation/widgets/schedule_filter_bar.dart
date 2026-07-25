import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/entry_kind.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import 'category_label.dart';

/// 입력 탭 검토 영역 필터 바.
///
/// 1줄: 상태 필터 (검토 대기/확정됨)
/// 2줄: 종류 필터 (전체/업무/학교일정) — 성격이 다른 둘을 갈라 볼 수 있게
/// 3줄: 카테고리 필터 (전체 + DB에서 동적 추출, 빈도순). 카테고리가 0개면 줄 자체 숨김.
class ScheduleFilterBar extends ConsumerWidget {
  const ScheduleFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(),
        _KindRow(),
        _CategoryRow(),
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

/// 종류 필터 1줄 — 전체/업무/학교일정.
///
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

    void select(EntryKind? kind) =>
        ref.read(scheduleKindFilterProvider.notifier).state = kind;

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
            selected: current == null,
            onTap: () => select(null),
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: label(ScheduleStrings.kindTask, counts?.pendingTask),
            selected: current == EntryKind.task,
            onTap: () => select(EntryKind.task),
          ),
          const SizedBox(width: AppSizes.spacing8),
          PillChip(
            label: label(ScheduleStrings.kindEvent, counts?.pendingEvent),
            selected: current == EntryKind.event,
            onTap: () => select(EntryKind.event),
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
