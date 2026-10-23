import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../schedule/domain/entry_kind.dart';
import '../../domain/memo.dart';
import '../../domain/memo_color.dart';
import '../providers/memo_providers.dart';
import 'memo_card.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 쪽지 시트 — 큰 색 쪽지에 바로 쓰고, 쪽지 아래쪽에 날짜·색, 맨 아래 한 줄에 삭제·일정으로 등록·저장
/// (E안, 사용자 결정 2026-10-23). 보드의 +(새 쪽지, `memo.id == null`)와 쪽지 누르기·캘린더가 같은 시트를 연다.
/// 새 쪽지에는 삭제·일정으로 등록이 없다 — 아직 붙지 않은 쪽지다.
class MemoSheet extends ConsumerStatefulWidget {
  const MemoSheet({super.key, required this.memo});

  final Memo memo;

  static const textKey = Key('memo_sheet_text');
  static Key colorKey(MemoColor c) => Key('memo_sheet_color_${c.dbValue}');
  static const dateRowKey = Key('memo_sheet_date');
  static const dateRemoveKey = Key('memo_sheet_date_remove');
  static const saveKey = Key('memo_sheet_save');
  static Key kindKey(EntryKind k) => Key('memo_sheet_kind_${k.dbValue}');
  static const toEventKey = Key('memo_sheet_to_event');
  static const removeKey = Key('memo_sheet_remove');

  static Future<void> show(BuildContext context, Memo memo) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: AppColors.navyMid,
        barrierColor: AppColors.navy.withValues(alpha: 0.7),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radius28),
          ),
        ),
        builder: (_) => MemoSheet(memo: memo),
      );

  @override
  ConsumerState<MemoSheet> createState() => _MemoSheetState();
}

/// 시트 위로 남겨 두는 빈 높이(상태 표시줄 아래) — 뒤 화면이 조금 보여 시트임을 알린다.
const _sheetTopGap = 64.0;

class _MemoSheetState extends ConsumerState<MemoSheet> {
  late final _text = TextEditingController(text: widget.memo.text);
  late MemoColor _color = widget.memo.color;
  late DateTime? _date = widget.memo.memoDate;

  /// DB 왕복 중 두 번째 탭을 막는다 — 일정이 둘 생기는 것을 방지.
  bool _busy = false;

  bool get _isNew => widget.memo.id == null;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Memo get _edited => widget.memo.copyWith(
    text: _text.text.trim(),
    color: _color,
    memoDate: _date,
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030), // 일정 편집 시트와 같은 상한 — 바꾼 일정을 다시 열 수 있게
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_busy || _text.text.trim().isEmpty) return;
    _busy = true;
    final notifier = ref.read(memosProvider.notifier);
    if (_isNew) {
      await notifier.add(_text.text, color: _color, memoDate: _date);
    } else {
      await notifier.save(_edited);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final id = widget.memo.id;
    if (_busy || id == null) return;
    _busy = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(memosProvider.notifier).remove(id);
    if (mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(content: Text(MemoStrings.removedSnack)),
    );
  }

  /// 날짜가 없으면 오늘. 고친 글이 있으면 고친 글로 등록한다.
  Future<void> _toEvent(EntryKind kind) async {
    if (_busy || _text.text.trim().isEmpty) return;
    _busy = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref
        .read(memosProvider.notifier)
        .convertToEvent(_edited, kind: kind, date: _date ?? DateTime.now());
    if (mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(content: Text(MemoStrings.convertedSnack)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 두 편집 시트와 같은 규칙 — 음수 인셋을 걸러내고 홈 인디케이터를 비켜 간다.
    final bottom = math.max(
      0.0,
      math.max(
        MediaQuery.viewInsetsOf(context).bottom,
        MediaQuery.viewPaddingOf(context).bottom,
      ),
    );
    // 시트는 상태 표시줄 아래로 64pt를 비워 두고, 그 안에서 쪽지가 남은 높이를 다 쓴다(최대 460).
    // 키보드가 올라오면 쪽지가 줄어들고 맨 아래 줄은 키보드 바로 위에 붙는다.
    final maxSheet = MediaQuery.sizeOf(context).height -
        MediaQuery.viewPaddingOf(context).top -
        _sheetTopGap;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(0.0, maxSheet)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.spacing16,
          AppSizes.spacing12,
          AppSizes.spacing16,
          AppSizes.spacing16 + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: _note(),
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            _actions(),
          ],
        ),
      ),
    );
  }

  /// 쪽지 한 장 — 글, 그 아래 날짜 칩과 색 점. 오른쪽 아래 모서리만 크게 둥글려 메모지처럼.
  Widget _note() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing12,
        AppSizes.spacing12,
      ),
      decoration: BoxDecoration(
        color: memoFill(_color),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              key: MemoSheet.textKey,
              controller: _text,
              autofocus: _isNew,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: 20, height: 1.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: MemoStrings.quickHint,
                hintStyle: TextStyle(
                  fontSize: 20,
                  height: 1.5,
                  color: AppColors.faint,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacing8),
          // 좁은 화면(320pt)에서는 색 점이 다음 줄로 내려간다 — 날짜 글자를 줄이지 않는다.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppSizes.spacing4,
            children: [
              _dateChip(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final c in MemoColor.values) _colorButton(c)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChip() {
    final date = _date;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ButtonSemantics(
              label: date == null
                  ? MemoStrings.dateLabel
                  : '${MemoStrings.dateLabel} ${memoLongDate.format(date)}',
              onTap: _pickDate,
              child: InkWell(
                key: MemoSheet.dateRowKey,
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing12,
                    vertical: AppSizes.spacing8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          date == null
                              ? MemoStrings.dateLabel
                              : memoLongDate.format(date),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (date != null)
            IconButton(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              key: MemoSheet.dateRemoveKey,
              onPressed: () => setState(() => _date = null),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close,
                size: 16,
                color: AppColors.sub,
                semanticLabel: MemoStrings.dateRemove,
              ),
            ),
        ],
      ),
    );
  }

  /// 맨 아래 한 줄 — 삭제(작지만 늘 보이게) · 일정으로 등록 ▾ · 저장. 새 쪽지는 저장만.
  Widget _actions() {
    return Row(
      children: [
        if (!_isNew) ...[
          TextButton.icon(
            key: MemoSheet.removeKey,
            onPressed: _remove,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkRed,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text(MemoStrings.remove),
          ),
          const SizedBox(width: AppSizes.spacing4),
          Flexible(
            child: MenuAnchor(
              menuChildren: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spacing16,
                    AppSizes.spacing8,
                    AppSizes.spacing16,
                    AppSizes.spacing4,
                  ),
                  child: Text(
                    MemoStrings.toEventMenuTitle,
                    style: TextStyle(fontSize: 12, color: AppColors.sub),
                  ),
                ),
                for (final k in EntryKind.values)
                  MenuItemButton(
                    key: MemoSheet.kindKey(k),
                    onPressed: () => _toEvent(k),
                    child: Text(MemoStrings.toEventAs(k.label)),
                  ),
              ],
              builder: (context, controller, _) => OutlinedButton(
                key: MemoSheet.toEventKey,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(color: AppColors.gold),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacing12,
                  ),
                ),
                child: const Text(
                  '${MemoStrings.toEvent} ▾',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        // 채움은 goldFill + onGold — Material 기본(primary)은 라이트에서 3.57:1이다.
        FilledButton(
          key: MemoSheet.saveKey,
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.goldFill,
            foregroundColor: AppColors.onGold,
            minimumSize: const Size(88, 44),
          ),
          child: const Text(MemoStrings.save),
        ),
      ],
    );
  }

  /// 선택 표시는 **체크 아이콘 + 테두리**. 색만으로 두지 않는다(도장 시트와 같은 규칙).
  /// 점은 작아도 누르는 칸은 36×40pt다.
  Widget _colorButton(MemoColor c) {
    final selected = c == _color;
    final label = switch (c) {
      MemoColor.yellow => MemoStrings.colorYellow,
      MemoColor.green => MemoStrings.colorGreen,
      MemoColor.blue => MemoStrings.colorBlue,
      MemoColor.pink => MemoStrings.colorPink,
    };
    return ButtonSemantics(
      label: label,
      selected: selected,
      onTap: () => setState(() => _color = c),
      child: InkWell(
        key: MemoSheet.colorKey(c),
        onTap: () => setState(() => _color = c),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 40,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: memoFill(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.ink
                      : AppColors.ink.withValues(alpha: 0.25),
                  width: selected ? 2.5 : 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: AppColors.ink)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
