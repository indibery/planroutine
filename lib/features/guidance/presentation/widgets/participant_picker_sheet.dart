import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';

/// 관련인 한 명을 고른다. 명단에서 고르거나, 명단 밖 이름을 구분·소속과 함께 넣는다.
/// 시트는 지도 기록의 중첩 내비게이터에 뜬다(`showModalBottomSheet` 기본값) — 잠금 덮개 아래.
Future<Participant?> showParticipantPicker(
  BuildContext context, {
  required List<Participant> exclude,
}) => showModalBottomSheet<Participant>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ParticipantPickerSheet(exclude: exclude),
);

class ParticipantPickerSheet extends ConsumerStatefulWidget {
  const ParticipantPickerSheet({super.key, required this.exclude});

  final List<Participant> exclude;

  static const queryKey = Key('picker_query');
  static const outsideKey = Key('picker_outside');
  static const memoKey = Key('picker_memo');
  static const addToRosterKey = Key('picker_add_to_roster');
  static const confirmKey = Key('picker_confirm');
  static Key roleKey(PersonRole r) => Key('picker_role_${r.dbValue}');

  @override
  ConsumerState<ParticipantPickerSheet> createState() => _ParticipantPickerSheetState();
}

class _ParticipantPickerSheetState extends ConsumerState<ParticipantPickerSheet> {
  final _query = TextEditingController();
  final _memo = TextEditingController();
  var _composing = false;
  var _role = PersonRole.student;
  var _addToRoster = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _confirmOutside() async {
    if (_busy) return;
    final name = _query.text.trim();
    if (name.isEmpty) return;
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    var result = Participant(name: name, role: _role, memo: memo);
    if (_addToRoster) {
      setState(() => _busy = true);
      final saved = await ref
          .read(guidanceActionsProvider)
          .addPerson(GuidancePerson(name: name, role: _role, memo: memo));
      result = saved.toParticipant();
    }
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom < 0 ? 0 : bottom),
      child: _composing ? _outsideForm() : _list(),
    );
  }

  Widget _list() {
    final q = _query.text.trim();
    final roster = ref.watch(guidancePeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final candidates = [
      for (final p in roster)
        if (!widget.exclude.any((e) => sameParticipant(e, p.toParticipant())) &&
            (q.isEmpty || p.name.contains(q)))
          p,
    ];
    final exact = roster.any((p) => p.name == q);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          ListTile(title: Text(GuidanceStrings.pickerTitle, style: AppTextStyles.heading)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: TextField(
              key: ParticipantPickerSheet.queryKey,
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(hintText: GuidanceStrings.pickerQueryHint),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isNotEmpty && !exact)
                  ListTile(
                    key: ParticipantPickerSheet.outsideKey,
                    leading: const Icon(Icons.person_add_alt_outlined),
                    title: Text(GuidanceStrings.outsideRoster(q)),
                    onTap: () => setState(() => _composing = true),
                  ),
                for (final p in candidates)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.memo == null ? p.role.label : '${p.role.label} · ${p.memo}'),
                    onTap: () => Navigator.pop(context, p.toParticipant()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outsideForm() => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_query.text.trim(), style: AppTextStyles.heading),
          const SizedBox(height: AppSizes.spacing12),
          Wrap(
            spacing: AppSizes.spacing8,
            children: [
              for (final r in PersonRole.values)
                ChoiceChip(
                  key: ParticipantPickerSheet.roleKey(r),
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: (_) => setState(() => _role = r),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spacing12),
          TextField(
            key: ParticipantPickerSheet.memoKey,
            controller: _memo,
            decoration: const InputDecoration(hintText: GuidanceStrings.outsideMemoHint),
          ),
          CheckboxListTile(
            key: ParticipantPickerSheet.addToRosterKey,
            contentPadding: EdgeInsets.zero,
            value: _addToRoster,
            onChanged: (v) => setState(() => _addToRoster = v ?? false),
            title: const Text(GuidanceStrings.addToRoster),
          ),
          const SizedBox(height: AppSizes.spacing8),
          FilledButton(
            key: ParticipantPickerSheet.confirmKey,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.goldFill,
              foregroundColor: AppColors.onGold,
            ),
            onPressed: _busy ? null : _confirmOutside,
            child: const Text(GuidanceStrings.pickerConfirm),
          ),
        ],
      ),
    ),
  );
}
