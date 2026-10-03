import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/guidance_record_tile.dart';

/// 지도 기록 탭 첫 화면. 잠금은 이 화면이 아니라 셸(`GuidanceLockGate`)이 진다.
class GuidanceListScreen extends ConsumerWidget {
  const GuidanceListScreen({super.key});

  static const addKey = Key('guidance_add');
  static const peopleKey = Key('guidance_people');
  static const trashKey = Key('guidance_trash');
  static const personFilterKey = Key('guidance_person_filter');
  static Key kindFilterKey(GuidanceKind? kind) => Key('guidance_kind_${kind?.dbValue ?? 'all'}');
  static Key rowKey(int id) => Key('guidance_row_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(guidanceRecordsProvider).valueOrNull;
    final visible = ref.watch(visibleGuidanceRecordsProvider).valueOrNull ?? const <GuidanceRecord>[];
    final kind = ref.watch(guidanceKindFilterProvider);
    final person = ref.watch(guidancePersonFilterProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(GuidanceStrings.eyebrow, style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            Text(GuidanceStrings.title, style: AppTextStyles.heading),
          ],
        ),
        actions: [
          IconButton(
            key: peopleKey,
            tooltip: GuidanceStrings.peopleTitle,
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push(AppRoutes.guidancePeople),
          ),
          IconButton(
            key: trashKey,
            tooltip: GuidanceStrings.trashTitle,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push(AppRoutes.guidanceTrash),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: addKey,
        tooltip: GuidanceStrings.newRecord,
        backgroundColor: AppColors.goldFill,
        foregroundColor: AppColors.onGold,
        onPressed: () => context.push(AppRoutes.guidanceNew),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing16, AppSizes.spacing4, AppSizes.spacing16, AppSizes.spacing12,
            ),
            child: Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: [
                ActionChip(
                  key: personFilterKey,
                  avatar: const Icon(Icons.person_outline, size: AppSizes.iconSmall),
                  label: Text(
                    person == null ? GuidanceStrings.personAll : GuidanceStrings.personLabel(person.name),
                  ),
                  onPressed: () => _pickPerson(context, ref, all ?? const []),
                ),
                for (final k in <GuidanceKind?>[null, ...GuidanceKind.values])
                  ChoiceChip(
                    key: kindFilterKey(k),
                    label: Text(k?.label ?? GuidanceStrings.kindAll),
                    selected: kind == k,
                    onSelected: (_) => ref.read(guidanceKindFilterProvider.notifier).state = k,
                  ),
              ],
            ),
          ),
          Expanded(
            child: all == null
                ? const SizedBox.shrink()
                : all.isEmpty
                    ? _empty()
                    : visible.isEmpty
                        ? Center(child: Text(GuidanceStrings.noMatch, style: AppTextStyles.bodyM))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing48 * 2,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.cardGap),
                            itemBuilder: (context, i) {
                              final r = visible[i];
                              return GuidanceRecordTile(
                                key: rowKey(r.id),
                                record: r,
                                now: now,
                                onTap: () => context.push(AppRoutes.guidanceRecord(r.id)),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: AppColors.faint),
          const SizedBox(height: AppSizes.spacing12),
          Text(GuidanceStrings.empty, style: AppTextStyles.bodyL),
          const SizedBox(height: AppSizes.spacing8),
          Text(
            GuidanceStrings.emptyScope,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
          ),
        ],
      ),
    ),
  );

  /// 기록에 등장한 사람(명단 밖 포함) 중 하나를 고른다. `(null,)`은 "전체", 시트를 그냥 닫으면 null.
  Future<void> _pickPerson(BuildContext context, WidgetRef ref, List<GuidanceRecord> records) async {
    final candidates = collectParticipants(records);
    final picked = await showModalBottomSheet<(Participant?,)>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(GuidanceStrings.personPickerTitle, style: AppTextStyles.heading)),
            ListTile(
              title: const Text(GuidanceStrings.kindAll),
              onTap: () => Navigator.pop(ctx, (null,)),
            ),
            if (candidates.isEmpty)
              const ListTile(title: Text(GuidanceStrings.personPickerEmpty)),
            for (final p in candidates)
              ListTile(
                title: Text(p.displayName),
                subtitle: Text(p.role.label),
                onTap: () => Navigator.pop(ctx, (p,)),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    ref.read(guidancePersonFilterProvider.notifier).state = picked.$1;
  }
}
