import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../providers/guidance_providers.dart';
import '../widgets/person_edit_sheet.dart';

class GuidancePeopleScreen extends ConsumerWidget {
  const GuidancePeopleScreen({super.key});

  static const addKey = Key('people_add');
  static const pasteKey = Key('people_paste');
  static const archivedKey = Key('people_archived');
  static Key personKey(int id) => Key('people_person_$id');

  Future<void> _unarchive(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(guidanceActionsProvider).unarchivePerson(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.actionFailed)));
    }
  }

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final names = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PasteSheet(),
    );
    if (names == null || names.isEmpty || !context.mounted) return;
    try {
      final n = await ref.read(guidanceActionsProvider).addNames(names);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(GuidanceStrings.pasteDone(n))));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.actionFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(guidancePeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final archived = ref.watch(guidanceArchivedPeopleProvider).valueOrNull ?? const <GuidancePerson>[];
    final counts = countRecordsByPerson(ref.watch(guidanceRecordsProvider).valueOrNull ?? const []);
    final students = [
      for (final p in active)
        if (p.role == PersonRole.student) p,
    ];
    final others = [
      for (final p in active)
        if (p.role != PersonRole.student) p,
    ];

    Widget tile(GuidancePerson p) {
      final n = counts[p.id] ?? 0;
      return ListTile(
        key: personKey(p.id ?? -1),
        title: Text(p.name),
        subtitle: Text(p.memo == null ? p.role.label : '${p.role.label} · ${p.memo}'),
        trailing: n == 0 ? null : Text(GuidanceStrings.recordCount(n)),
        onTap: () => showPersonEditSheet(context, person: p),
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing4,
      ),
      child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(GuidanceStrings.peopleTitle, style: AppTextStyles.heading),
        actions: [
          TextButton(
            key: pasteKey,
            onPressed: () => _paste(context, ref),
            child: const Text(GuidanceStrings.pasteTitle),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: addKey,
        tooltip: GuidanceStrings.personAddTitle,
        backgroundColor: AppColors.goldFill,
        foregroundColor: AppColors.onGold,
        onPressed: () => showPersonEditSheet(context),
        child: const Icon(Icons.person_add_alt),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.spacing48 * 2),
        children: [
          header(GuidanceStrings.studentsHeader(students.length)),
          for (final p in students) tile(p),
          if (others.isNotEmpty) ...[header(GuidanceStrings.othersHeader), for (final p in others) tile(p)],
          if (archived.isNotEmpty)
            ExpansionTile(
              key: archivedKey,
              title: Text(GuidanceStrings.archivedHeader(archived.length)),
              children: [
                for (final p in archived)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.role.label),
                    trailing: TextButton(
                      onPressed: () => _unarchive(context, ref, p.id ?? -1),
                      child: const Text(GuidanceStrings.unarchive),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PasteSheet extends StatefulWidget {
  const _PasteSheet();

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = parseRosterPaste(_text.text);
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
              Text(GuidanceStrings.pasteTitle, style: AppTextStyles.heading),
              const SizedBox(height: AppSizes.spacing4),
              Text(GuidanceStrings.pasteHint, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
              const SizedBox(height: AppSizes.spacing12),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(GuidanceStrings.pastePreview(names.length), style: AppTextStyles.bodyS),
              const SizedBox(height: AppSizes.spacing12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                ),
                onPressed: names.isEmpty ? null : () => Navigator.pop(context, names),
                child: const Text(GuidanceStrings.pasteConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
