import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';

/// 시트는 지도 기록의 중첩 내비게이터에 뜬다(`showModalBottomSheet` 기본값) — 잠금 덮개 아래.
Future<void> showPersonEditSheet(BuildContext context, {GuidancePerson? person}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PersonEditSheet(person: person),
    );

class PersonEditSheet extends ConsumerStatefulWidget {
  const PersonEditSheet({super.key, this.person});

  final GuidancePerson? person;

  static const nameKey = Key('person_name');
  static const memoKey = Key('person_memo');
  static const saveKey = Key('person_save');
  static const archiveKey = Key('person_archive');
  static Key roleKey(PersonRole r) => Key('person_role_${r.dbValue}');

  @override
  ConsumerState<PersonEditSheet> createState() => _PersonEditSheetState();
}

class _PersonEditSheetState extends ConsumerState<PersonEditSheet> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _memo = TextEditingController(text: widget.person?.memo ?? '');
  late var _role = widget.person?.role ?? PersonRole.student;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  /// 동작이 실패하면 버튼을 풀고 오류를 시트 안에 보인다 — 스낵바는 시트 뒤에 가려질 수 있다.
  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure;
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    final actions = ref.read(guidanceActionsProvider);
    final existing = widget.person;
    await _run(() async {
      if (existing == null) {
        await actions.addPerson(GuidancePerson(name: name, role: _role, memo: memo));
      } else {
        await actions.updatePerson(existing.copyWith(name: name, role: _role, memo: memo));
      }
    }, GuidanceStrings.saveFailed);
  }

  Future<void> _archive() async {
    final id = widget.person?.id;
    if (id == null) return;
    final actions = ref.read(guidanceActionsProvider);
    await _run(() => actions.archivePerson(id), GuidanceStrings.actionFailed);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom < 0 ? 0 : bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.spacing20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.person == null ? GuidanceStrings.personAddTitle : GuidanceStrings.personEditTitle,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                key: PersonEditSheet.nameKey,
                controller: _name,
                autofocus: widget.person == null,
                decoration: const InputDecoration(hintText: GuidanceStrings.personName),
              ),
              const SizedBox(height: AppSizes.spacing12),
              Wrap(
                spacing: AppSizes.spacing8,
                children: [
                  for (final r in PersonRole.values)
                    ChoiceChip(
                      key: PersonEditSheet.roleKey(r),
                      label: Text(r.label),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                key: PersonEditSheet.memoKey,
                controller: _memo,
                decoration: const InputDecoration(hintText: GuidanceStrings.personMemo),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.spacing8),
                Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.spacing16),
              FilledButton(
                key: PersonEditSheet.saveKey,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                ),
                onPressed: _busy ? null : _save,
                child: const Text(GuidanceStrings.save),
              ),
              if (widget.person != null) ...[
                const SizedBox(height: AppSizes.spacing8),
                TextButton(
                  key: PersonEditSheet.archiveKey,
                  onPressed: _busy ? null : _archive,
                  child: const Text(GuidanceStrings.archive),
                ),
                Text(
                  GuidanceStrings.archiveNote,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
