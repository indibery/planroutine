import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/button_semantics.dart';
import '../../domain/period_row.dart';

/// 교시 한 줄 — 이름 · 시각 · 그 칸의 사람들 · 남은 자리 · 체크칸.
/// 사람 칩은 취소할 수 있을 때만 누를 수 있다(취소 시트).
class PeriodRowTile extends StatelessWidget {
  const PeriodRowTile({
    super.key,
    required this.view,
    required this.checked,
    required this.onChecked,
    required this.onPersonTap,
  });

  final PeriodRowView view;
  final bool checked;
  final ValueChanged<bool> onChecked;
  final ValueChanged<PersonChip> onPersonTap;

  static Key rowKey(String periodName) => Key('schoolbook_period_$periodName');

  @override
  Widget build(BuildContext context) {
    final slot = view.slot;
    final start = slot.startTime;
    final remaining = view.remainingToShow;
    return Opacity(
      opacity: slot.archived ? 0.5 : 1,
      child: Container(
        key: rowKey(slot.name),
        margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spacing12, AppSizes.spacing8, AppSizes.spacing4, AppSizes.spacing8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          border: Border.all(color: checked ? AppColors.gold : Colors.transparent, width: 1.5),
        ),
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  if (start != null)
                    Text(start, style: TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Expanded(
              child: Wrap(
                spacing: AppSizes.spacing8,
                runSpacing: AppSizes.spacing4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (view.people.isEmpty)
                    _label(SchoolbookStrings.free, AppColors.inkGreen, bold: true),
                  for (final p in view.people) _person(p),
                  if (remaining != null && view.people.isNotEmpty)
                    _label(SchoolbookStrings.remaining(remaining), AppColors.inkGreen),
                ],
              ),
            ),
            if (view.selectable)
              Checkbox(
                value: checked,
                onChanged: (v) => onChecked(v ?? false),
                semanticLabel: SchoolbookStrings.selectPeriod(slot.name),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color color, {bool bold = false}) => Text(
        text,
        style: TextStyle(fontSize: 14, color: color, fontWeight: bold ? FontWeight.w700 : null),
      );

  Widget _person(PersonChip p) {
    if (p.fixed) return _label(SchoolbookStrings.fixedPerson(p.label), AppColors.info);
    final text = _label(p.label, AppColors.inkRed, bold: true);
    if (!p.cancellable) return text;
    return ButtonSemantics.gesture(
      label: SchoolbookStrings.cancelSheetTitle(p.label, view.slot.name),
      onTap: () => onPersonTap(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing4),
        child: text,
      ),
    );
  }
}
