import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/period_row.dart';

/// 교시 한 줄(시안 A) — 이름 · 시각 · 그 칸의 사람들 · 남은 자리 · 줄 끝 버튼 하나.
/// 버튼 자리는 하나다: 내 예약이 있으면 [취소], 없고 자리가 남았으면 [예약](사용자 결정).
/// 내 예약은 골드 테두리로 강조하고, 다른 반 예약은 누를 수 없다.
class PeriodRowTile extends StatelessWidget {
  const PeriodRowTile({
    super.key,
    required this.view,
    required this.pending,
    required this.onBook,
    required this.onCancel,
  });

  final PeriodRowView view;

  /// 이 줄의 바로 예약 요청이 도는 중 — 버튼 대신 `예약 중…`(취소는 시트가 잠근다).
  final bool pending;
  final VoidCallback onBook;
  final VoidCallback onCancel;

  static Key rowKey(String periodName) => Key('schoolbook_period_$periodName');
  static Key bookKey(String periodName) => Key('schoolbook_book_$periodName');
  static Key cancelKey(String periodName) => Key('schoolbook_cancel_$periodName');

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
          AppSizes.spacing12, AppSizes.spacing8, AppSizes.spacing8, AppSizes.spacing8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(
              // 학교가 정한 교시 이름(`4교시(저학년)`, 최대 20자)이 잘리지 않게 두 줄까지
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.name,
                    maxLines: 2,
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
            const SizedBox(width: AppSizes.spacing8),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    final name = view.slot.name;
    if (pending) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8),
        child: Text(
          SchoolbookStrings.booking,
          style: TextStyle(fontSize: 13, color: AppColors.sub),
        ),
      );
    }
    return switch (view.action) {
      RowAction.book => FilledButton(
          key: bookKey(name),
          onPressed: onBook,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.goldFill,
            foregroundColor: AppColors.onGold,
            minimumSize: const Size(64, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
          ),
          child: Text(
            SchoolbookStrings.bookAction,
            semanticsLabel: SchoolbookStrings.bookPeriod(name),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      RowAction.cancel => OutlinedButton(
          key: cancelKey(name),
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.inkRed,
            side: BorderSide(color: AppColors.inkRed),
            minimumSize: const Size(64, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
          ),
          child: Text(
            SchoolbookStrings.cancelAction,
            semanticsLabel: SchoolbookStrings.cancelPeriod(name),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      RowAction.none => const SizedBox(width: 64),
    };
  }

  Widget _label(String text, Color color, {bool bold = false}) => Text(
        text,
        style: TextStyle(fontSize: 14, color: color, fontWeight: bold ? FontWeight.w700 : null),
      );

  Widget _person(PersonChip p) {
    if (p.fixed) return _label(SchoolbookStrings.fixedPerson(p.label), AppColors.info);
    if (!p.mine) return _label(p.label, AppColors.inkRed, bold: true);
    // 내 예약 — 골드 테두리로 다른 반 예약과 가른다
    return Semantics(
      label: SchoolbookStrings.mine(p.label),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.goldFill.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(color: AppColors.gold),
        ),
        child: Text(
          p.label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold),
        ),
      ),
    );
  }
}
