import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../providers/guidance_providers.dart';

/// 판 목록(최신 위). 각 판은 그때의 **전체 내용**을 보여 주고, 앞 판과 견주어 바뀐 칸을 말한다.
class GuidanceHistoryScreen extends ConsumerWidget {
  const GuidanceHistoryScreen({super.key, required this.recordId});

  final int recordId;

  static Key revisionKey(int no) => Key('guidance_revision_$no');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revs = ref.watch(guidanceRevisionsProvider(recordId)).valueOrNull ?? const <GuidanceRevision>[];
    final atts = ref.watch(guidanceAttachmentsProvider(recordId)).valueOrNull ?? const <GuidanceAttachment>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(GuidanceStrings.historyTitle, style: AppTextStyles.heading)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing48),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
            child: Text(GuidanceStrings.historyIntro, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
          ),
          for (final (i, r) in revs.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
              child: _RevisionCard(
                key: revisionKey(r.revisionNo),
                revision: r,
                previous: i + 1 < revs.length ? revs[i + 1] : null,
                isCurrent: i == 0,
                now: now,
              ),
            ),
          if (atts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacing8, bottom: AppSizes.spacing8),
              child: Text(GuidanceStrings.attachmentLog, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
            ),
            for (final a in atts) ...[
              _logLine(GuidanceStrings.attachedLog(_what(a)), formatStamp(a.attachedAt, now: now)),
              if (a.removedAt case final removed?)
                _logLine(GuidanceStrings.removedLog(_what(a)), formatStamp(removed, now: now)),
            ],
          ],
        ],
      ),
    );
  }

  String _what(GuidanceAttachment a) => a.originalName ?? '${a.type.label}(${a.source.label})';

  Widget _logLine(String text, String when) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.bodyS)),
        Text(when, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
      ],
    ),
  );
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    super.key,
    required this.revision,
    required this.previous,
    required this.isCurrent,
    required this.now,
  });

  final GuidanceRevision revision;
  final GuidanceRevision? previous;
  final bool isCurrent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = revision.content;
    final prev = previous;
    final changed = prev == null ? const <ContentField>{} : changedFields(prev.content, c);
    final rows = <(String, String?)>[
      (GuidanceStrings.fieldOccurred, formatOccurred(c, now: now)),
      (GuidanceStrings.fieldKind, c.kind.label),
      (GuidanceStrings.fieldStatus, c.status.label),
      (GuidanceStrings.fieldTitle, c.title),
      (GuidanceStrings.fieldPlace, c.place),
      (GuidanceStrings.fieldParticipants,
          c.participants.isEmpty ? null : c.participants.map((p) => p.displayName).join(' · ')),
      (GuidanceStrings.fieldFacts, c.facts),
      (GuidanceStrings.fieldQuotes, c.quotes),
      (GuidanceStrings.fieldActions, c.actions),
    ];
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: isCurrent ? AppColors.gold : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 좁은 폭에서 제목·`현재` 태그가 저장 시각과 부딪히면 제목 쪽이 줄을 바꾼다
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSizes.spacing8,
                    children: [
                      Text(GuidanceStrings.revisionTitle(revision.revisionNo), style: AppTextStyles.heading),
                      if (isCurrent) _tag(GuidanceStrings.revisionCurrent),
                    ],
                  ),
                ),
                Text(formatStamp(revision.savedAt, now: now), style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
              ],
            ),
            if (changed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spacing4),
                child: Text(
                  GuidanceStrings.changedLabel(
                    [for (final f in ContentField.values) if (changed.contains(f)) f.label].join(', '),
                  ),
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: AppSizes.spacing8),
            for (final (label, value) in rows)
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacing4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 64, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
                      Expanded(child: Text(value, style: AppTextStyles.bodyS)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.lineStrong),
      borderRadius: BorderRadius.circular(AppSizes.radius4),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
  );
}
