import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../schedule/domain/schedule.dart';
import '../providers/trash_providers.dart';

/// 휴지통 화면 — 설정 탭에서 진입.
///
/// 삭제된 일정/캘린더 이벤트를 함께 보여주고, 복구/영구삭제 가능.
/// 30일이 지난 항목은 앱 시작 시 자동 영구삭제된다 (main.dart 참조).
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trashSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.trashTitle,
          style: AppTextStyles.heading,
        ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.delete_outline, size: 64, color: AppColors.faint),
          SizedBox(height: AppSizes.spacing16),
          Text(
            AppStrings.trashEmpty,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.sub,
            ),
          ),
          SizedBox(height: AppSizes.spacing4),
          Text(
            AppStrings.trashAutoPurgeNotice,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: AppColors.faint,
            ),
          ),
        ],
      ),
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
              const Icon(
                Icons.info_outline,
                size: AppSizes.iconSmall,
                color: AppColors.textHint,
              ),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  '${AppStrings.trashAutoPurgeNotice} · 총 ${snapshot.total}건',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (snapshot.schedules.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: SectionHeader(
              title: AppStrings.trashSectionSchedules,
              trailing: _SectionCountBadge(count: snapshot.schedules.length),
            ),
          ),
          ...snapshot.schedules.map(
            (s) => _TrashScheduleTile(schedule: s),
          ),
        ],
        if (snapshot.events.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: SectionHeader(
              title: AppStrings.trashSectionEvents,
              trailing: _SectionCountBadge(count: snapshot.events.length),
            ),
          ),
          ...snapshot.events.map(
            (e) => _TrashEventTile(event: e),
          ),
        ],
      ],
    );
  }
}

class _SectionCountBadge extends StatelessWidget {
  const _SectionCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
        letterSpacing: 2.5,
      ),
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
    return '$date · $deleted';
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
    return '$date · $deleted';
  }
}

class _TrashActions extends StatelessWidget {
  const _TrashActions({
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppStrings.trashRestore,
          icon: const Icon(Icons.restore, color: AppColors.gold),
          onPressed: onRestore,
        ),
        IconButton(
          tooltip: AppStrings.trashPermanentDelete,
          icon: const Icon(Icons.delete_forever, color: AppColors.inkRed),
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
      title: const Text(AppStrings.trashPermanentDeleteTitle),
      content: const Text(AppStrings.trashPermanentDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            AppStrings.trashPermanentDelete,
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
    if (days == 0) return '${AppStrings.trashDeletedPrefix}오늘';
    return '${AppStrings.trashDeletedPrefix}$days일 전';
  } catch (_) {
    return '';
  }
}
