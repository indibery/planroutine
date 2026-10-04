import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../memo/domain/memo.dart';
import '../../../schedule/domain/schedule.dart';
import '../../domain/trash_entries.dart';
import '../providers/trash_providers.dart';
import '../../../../shared/widgets/empty_state.dart';

/// 휴지통 화면 — 설정 탭에서 진입.
///
/// 삭제된 일정·캘린더 이벤트·쪽지를 **한 목록**에 최근에 지운 것부터 보여주고(줄마다
/// 종류를 적는다), 복구/영구삭제 가능.
/// 30일이 지난 항목은 앱 시작 시 자동 영구삭제된다 (main.dart 참조).
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trashSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(TrashStrings.title, style: AppTextStyles.heading),
      ),
      body: snapshotAsync.when(
        data: (snapshot) => snapshot.isEmpty
            ? _buildEmpty()
            : _buildList(context, ref, snapshot),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.error)),
      ),
    );
  }

  Widget _buildEmpty() {
    return const EmptyState(
      icon: Icons.delete_outline,
      title: TrashStrings.empty,
      hint: TrashStrings.autoPurgeNotice,
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    TrashSnapshot snapshot,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.spacing24),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.spacing16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppSizes.iconSmall,
                color: AppColors.textHint,
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  '${TrashStrings.autoPurgeNotice} · 총 ${snapshot.total}건',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
            ],
          ),
        ),
        // 종류별 묶음 없이 한 목록 — 최근에 지운 것이 위(`mergeTrashEntries`).
        for (final entry in snapshot.entries)
          switch (entry) {
            TrashScheduleEntry(:final schedule) => _TrashScheduleTile(
              schedule: schedule,
            ),
            TrashEventEntry(:final event) => _TrashEventTile(event: event),
            TrashMemoEntry(:final memo) => _TrashMemoTile(memo: memo),
          },
      ],
    );
  }
}

class _TrashScheduleTile extends ConsumerWidget {
  const _TrashScheduleTile({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(schedule.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(schedule)),
      trailing: _TrashActions(
        itemTitle: schedule.title,
        onRestore: () => ref
            .read(trashSnapshotProvider.notifier)
            .restoreSchedule(schedule.id!),
        onPermanentDelete: () => _confirmPermanentDelete(
          context,
          () => ref
              .read(trashSnapshotProvider.notifier)
              .permanentDeleteSchedule(schedule.id!),
        ),
      ),
    );
  }

  String _subtitle(Schedule s) {
    final date = _safeFormat(s.scheduledDate, 'yyyy.MM.dd');
    final deleted = _daysAgo(s.deletedAt);
    return '${TrashStrings.sectionSchedules} · $date · $deleted';
  }
}

class _TrashEventTile extends ConsumerWidget {
  const _TrashEventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(event)),
      trailing: _TrashActions(
        itemTitle: event.title,
        onRestore: () =>
            ref.read(trashSnapshotProvider.notifier).restoreEvent(event.id!),
        onPermanentDelete: () => _confirmPermanentDelete(
          context,
          () => ref
              .read(trashSnapshotProvider.notifier)
              .permanentDeleteEvent(event.id!),
        ),
      ),
    );
  }

  String _subtitle(CalendarEvent e) {
    final date = _safeFormat(e.eventDate, 'yyyy.MM.dd');
    final deleted = _daysAgo(e.deletedAt);
    return '${TrashStrings.sectionEvents} · $date · $deleted';
  }
}

class _TrashMemoTile extends ConsumerWidget {
  const _TrashMemoTile({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = memo.id ?? -1;
    return ListTile(
      title: Text(memo.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${TrashStrings.sectionMemos} · ${_daysAgo(memo.deletedAt)}',
      ),
      trailing: _TrashActions(
        itemTitle: memo.text,
        onRestore: () =>
            ref.read(trashSnapshotProvider.notifier).restoreMemo(id),
        onPermanentDelete: () => _confirmPermanentDelete(
          context,
          () =>
              ref.read(trashSnapshotProvider.notifier).permanentDeleteMemo(id),
        ),
      ),
    );
  }
}

class _TrashActions extends StatelessWidget {
  const _TrashActions({
    required this.itemTitle,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  /// 버튼 이름에 붙일 항목 제목 — 행마다 같은 버튼이 반복된다(자동화가 위치로 고르지 않게).
  final String itemTitle;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.restore,
            color: AppColors.gold,
            semanticLabel: AppStrings.rowAction(
              itemTitle,
              TrashStrings.restore,
            ),
          ),
          onPressed: onRestore,
        ),
        IconButton(
          icon: Icon(
            Icons.delete_forever,
            color: AppColors.inkRed,
            semanticLabel: AppStrings.rowAction(
              itemTitle,
              TrashStrings.permanentDelete,
            ),
          ),
          onPressed: onPermanentDelete,
        ),
      ],
    );
  }
}

Future<void> _confirmPermanentDelete(
  BuildContext context,
  VoidCallback onConfirmed,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(TrashStrings.permanentDeleteTitle),
      content: const Text(TrashStrings.permanentDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            TrashStrings.permanentDelete,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  if (ok == true) onConfirmed();
}

String _safeFormat(String iso, String pattern) {
  try {
    return DateFormat(pattern, 'ko_KR').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _daysAgo(String? iso) {
  if (iso == null) return '';
  try {
    final deleted = DateTime.parse(iso);
    final days = DateTime.now().difference(deleted).inDays;
    if (days == 0) return '${TrashStrings.deletedPrefix}오늘';
    return '${TrashStrings.deletedPrefix}$days일 전';
  } catch (_) {
    return '';
  }
}
