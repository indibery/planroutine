import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/attachment_tile.dart';
import '../widgets/guidance_badges.dart';

class GuidanceDetailScreen extends ConsumerWidget {
  const GuidanceDetailScreen({super.key, required this.recordId});

  final int recordId;

  static const editKey = Key('guidance_detail_edit');
  static const deleteKey = Key('guidance_detail_delete');
  static const historyKey = Key('guidance_detail_history');

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.deleteTitle,
      message: GuidanceStrings.deleteMessage,
      confirmLabel: GuidanceStrings.delete,
      confirmColor: AppColors.error,
    );
    if (!ok) return;
    await ref.read(guidanceActionsProvider).delete(recordId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(guidanceRecordProvider(recordId)).valueOrNull;
    final attachments = [
      for (final a in ref.watch(guidanceAttachmentsProvider(recordId)).valueOrNull ?? const <GuidanceAttachment>[])
        if (!a.isRemoved) a,
    ];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        actions: [
          // 글자만 있으면 버튼으로 읽히지 않는다(실기기 피드백) — 골드 채움 버튼으로 둔다.
          FilledButton(
            key: editKey,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.goldFill,
              foregroundColor: AppColors.onGold,
              minimumSize: const Size(0, AppSizes.buttonHeightSmall),
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            ),
            onPressed: () => context.push(AppRoutes.guidanceEdit(recordId)),
            child: const Text(GuidanceStrings.edit),
          ),
          // 메뉴에 `삭제` 하나뿐이라 `⋯`로 감출 이유가 없다(실기기 피드백) — 바로 누르는 아이콘으로 둔다.
          IconButton(
            key: deleteKey,
            tooltip: GuidanceStrings.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: record == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding, 0, AppSizes.pagePadding, AppSizes.spacing48,
              ),
              children: [
                Row(
                  children: [
                    GuidanceKindBadge(record.content.kind),
                    if (record.content.status != GuidanceStatus.open) ...[
                      const SizedBox(width: AppSizes.spacing4),
                      GuidanceStatusBadge(record.content.status),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.spacing8),
                Text(record.content.title, style: AppTextStyles.titleM),
                const SizedBox(height: AppSizes.spacing8),
                _meta(GuidanceStrings.labelOccurredShort, _occurredLine(record, now)),
                _meta(GuidanceStrings.labelCreatedShort, formatStamp(record.createdAt, now: now)),
                if (record.revisionCount > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: historyKey,
                      onPressed: () => context.push(AppRoutes.guidanceHistory(recordId)),
                      icon: const Icon(Icons.history, size: AppSizes.iconSmall),
                      label: Text(
                        GuidanceStrings.revisionLink(
                          record.revisionCount - 1,
                          formatStamp(record.latest.savedAt, now: now),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.spacing12),
                if (record.content.participants.isNotEmpty)
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [for (final p in record.content.participants) _personChip(p)],
                  ),
                _section(GuidanceStrings.labelFacts, record.content.facts),
                _section(GuidanceStrings.labelQuotes, record.content.quotes, boxed: true),
                _section(GuidanceStrings.labelActions, record.content.actions),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spacing20),
                  _heading(GuidanceStrings.labelAttachments),
                  for (final a in attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
                      child: AttachmentTile(key: ValueKey(a.id), attachment: a, now: now),
                    ),
                ],
              ],
            ),
    );
  }

  String _occurredLine(GuidanceRecord r, DateTime now) {
    final place = r.content.place;
    final when = formatOccurred(r.content, now: now);
    return place == null ? when : '$when · $place';
  }

  Widget _meta(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
        Expanded(child: Text(value, style: AppTextStyles.bodyS)),
      ],
    ),
  );

  /// 명단 관리 화면이 없어져 `명단 밖` 구분도 뺐다 — 관련인은 모두 같은 칩이다.
  Widget _personChip(Participant p) =>
      Chip(label: Text(p.displayName), backgroundColor: AppColors.surfaceVariant, side: BorderSide.none);

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
  );

  Widget _section(String label, String? body, {bool boxed = false}) {
    if (body == null) return const SizedBox.shrink();
    final text = Text(body, style: AppTextStyles.bodyL);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(label),
          if (boxed)
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSizes.radius12),
              ),
              child: Padding(padding: const EdgeInsets.all(AppSizes.spacing12), child: text),
            )
          else
            text,
        ],
      ),
    );
  }
}
