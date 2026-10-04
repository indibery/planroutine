import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../../../shared/widgets/sheet_title.dart';

Future<void> showAttachmentInfo(
  BuildContext context,
  GuidanceAttachment a, {
  required DateTime now,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spacing20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle(GuidanceStrings.attachmentInfo),
          const SizedBox(height: AppSizes.spacing12),
          _row(GuidanceStrings.infoSource, '${a.type.label} · ${a.source.label}'),
          if (a.originalName case final name?) _row(GuidanceStrings.infoOriginalName, name),
          _row(GuidanceStrings.infoSize, GuidanceStrings.sizeLabel(a.byteSize)),
          if (a.capturedAt case final at?) _row(GuidanceStrings.infoCaptured, formatStamp(at, now: now)),
          _row(GuidanceStrings.infoAttached, formatStamp(a.attachedAt, now: now)),
          const SizedBox(height: AppSizes.spacing8),
          Text(GuidanceStrings.infoHash, style: AppTextStyles.fieldLabel),
          SelectableText(a.sha256, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: AppSizes.spacing4),
          Text(GuidanceStrings.infoHashNote, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
        ],
      ),
    ),
  ),
);

Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 80, child: Text(label, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub))),
      Expanded(child: Text(value, style: AppTextStyles.bodyM)),
    ],
  ),
);
