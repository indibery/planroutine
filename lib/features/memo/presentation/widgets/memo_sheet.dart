import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../schedule/domain/entry_kind.dart';
import '../../domain/memo.dart';
import '../../domain/memo_color.dart';
import '../providers/memo_providers.dart';
import 'memo_card.dart';

/// 쪽지 시트 — 글·색·날짜 고치기, 일정으로 등록, 떼기. 보드와 캘린더가 같은 시트를 연다.
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radius28)),
        ),
        builder: (_) => MemoSheet(memo: memo),
      );

  @override
  ConsumerState<MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends ConsumerState<MemoSheet> {
  late final _text = TextEditingController(text: widget.memo.text);
  late MemoColor _color = widget.memo.color;
  late DateTime? _date = widget.memo.memoDate;
  EntryKind _kind = EntryKind.task;

  /// DB 왕복 중 두 번째 탭을 막는다 — 일정이 둘 생기는 것을 방지.
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Memo get _edited => widget.memo.copyWith(text: _text.text.trim(), color: _color, memoDate: _date);

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
    await ref.read(memosProvider.notifier).save(_edited);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final id = widget.memo.id;
    if (_busy || id == null) return;
    _busy = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(memosProvider.notifier).remove(id);
    if (mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text(MemoStrings.removedSnack)));
  }

  /// 날짜가 없으면 오늘. 고친 글이 있으면 고친 글로 등록한다.
  Future<void> _toEvent() async {
    if (_busy || _text.text.trim().isEmpty) return;
    _busy = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref
        .read(memosProvider.notifier)
        .convertToEvent(_edited, kind: _kind, date: _date ?? DateTime.now());
    if (mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text(MemoStrings.convertedSnack)));
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return Padding(
      // 두 편집 시트와 같은 규칙 — 음수 인셋을 걸러내고 홈 인디케이터를 비켜 간다.
      padding: EdgeInsets.only(
        bottom: math.max(
          0,
          math.max(
            MediaQuery.viewInsetsOf(context).bottom,
            MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: MemoSheet.textKey,
                controller: _text,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: MemoStrings.sheetTextLabel,
                  filled: true,
                  fillColor: memoFill(_color),
                ),
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              const SizedBox(height: AppSizes.spacing16),
              Text(MemoStrings.colorLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.sub)),
              const SizedBox(height: AppSizes.spacing8),
              Row(
                children: [
                  for (final c in MemoColor.values) ...[
                    _colorButton(c),
                    const SizedBox(width: AppSizes.spacing12),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.spacing8),
              ListTile(
                key: MemoSheet.dateRowKey,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today_outlined, color: AppColors.gold),
                title: const Text(MemoStrings.dateLabel),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(date == null ? MemoStrings.dateNone : DateFormat('M월 d일 (E)', 'ko').format(date)),
                    if (date != null)
                      IconButton(
                        key: MemoSheet.dateRemoveKey,
                        tooltip: MemoStrings.dateRemove,
                        onPressed: () => setState(() => _date = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSizes.spacing8),
              // 채움은 goldFill + onGold — Material 기본(primary)은 라이트에서 3.57:1이다.
              FilledButton(
                key: MemoSheet.saveKey,
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                ),
                child: const Text(MemoStrings.save),
              ),
              const Divider(height: AppSizes.spacing32),
              Text(MemoStrings.toEventTitle, style: TextStyle(fontSize: 14, color: AppColors.sub)),
              const SizedBox(height: AppSizes.spacing8),
              SegmentedButton<EntryKind>(
                segments: [
                  for (final k in EntryKind.values)
                    ButtonSegment(value: k, label: Text(k.label, key: MemoSheet.kindKey(k))),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: AppSizes.spacing8),
              OutlinedButton(key: MemoSheet.toEventKey, onPressed: _toEvent, child: const Text(MemoStrings.toEvent)),
              const SizedBox(height: AppSizes.spacing8),
              TextButton(
                key: MemoSheet.removeKey,
                onPressed: _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.inkRed),
                child: const Text(MemoStrings.remove),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택 표시는 **체크 아이콘 + 테두리**. 색만으로 두지 않는다(도장 시트와 같은 규칙).
  Widget _colorButton(MemoColor c) {
    final selected = c == _color;
    final label = switch (c) {
      MemoColor.yellow => MemoStrings.colorYellow,
      MemoColor.green => MemoStrings.colorGreen,
      MemoColor.blue => MemoStrings.colorBlue,
      MemoColor.pink => MemoStrings.colorPink,
    };
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        key: MemoSheet.colorKey(c),
        onTap: () => setState(() => _color = c),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: memoFill(c),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.gold : AppColors.line, width: selected ? 2 : 1),
          ),
          child: selected ? Icon(Icons.check, size: 18, color: AppColors.ink) : null,
        ),
      ),
    );
  }
}
