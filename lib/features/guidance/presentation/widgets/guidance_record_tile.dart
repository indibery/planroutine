import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import 'guidance_badges.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 목록 한 줄. 배경·테두리는 `Material`이 진다 — 잉크가 보이게(ListTile 규칙과 같은 이유).
/// 기록 한 줄의 이름 — 화면 순서대로 사건 시각 · 구분 · (진행 상태) · 제목 · (관련인).
String guidanceRecordSemanticsLabel(GuidanceRecord record, {required DateTime now}) {
  final c = record.content;
  final names = _participantNames(c);
  return [
    formatOccurred(c, now: now),
    c.kind.label,
    if (c.status != GuidanceStatus.open) c.status.label,
    c.title,
    if (names.isNotEmpty) names,
  ].join(', ');
}

/// 관련인 이름 한 줄 — 화면과 이름이 같은 규칙(` · `)을 쓴다.
String _participantNames(GuidanceContent c) =>
    c.participants.map((p) => p.displayName).join(' · ');

class GuidanceRecordTile extends StatelessWidget {
  const GuidanceRecordTile({super.key, required this.record, required this.now, this.onTap});

  final GuidanceRecord record;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = record.content;
    final names = _participantNames(c);
    final meta = TextStyle(fontSize: 14, color: AppColors.sub);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius14),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ButtonSemantics(label: guidanceRecordSemanticsLabel(record, now: now), onTap: onTap, child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(formatOccurred(c, now: now), style: meta)),
                  if (record.attachmentCount > 0) ...[
                    Icon(Icons.attach_file, size: AppSizes.iconSmall, color: AppColors.sub),
                    Text('${record.attachmentCount}', style: meta),
                    const SizedBox(width: AppSizes.spacing8),
                  ],
                  if (record.revisionCount > 1)
                    Text(GuidanceStrings.revisedTimes(record.revisionCount - 1), style: meta),
                ],
              ),
              const SizedBox(height: AppSizes.spacing4),
              Row(
                children: [
                  GuidanceKindBadge(c.kind),
                  if (c.status != GuidanceStatus.open) ...[
                    const SizedBox(width: AppSizes.spacing4),
                    GuidanceStatusBadge(c.status),
                  ],
                  const SizedBox(width: AppSizes.spacing8),
                  Expanded(
                    child: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              if (names.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacing4),
                Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
              ],
            ],
          ),
        ),
      )),
    );
  }
}
