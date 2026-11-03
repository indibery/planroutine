import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../lock/device_authenticator.dart';
import '../lock/guidance_unlock.dart';
import '../providers/guidance_providers.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../widgets/guidance_record_tile.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../../../shared/widgets/gold_fab.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../../../shared/widgets/tab_header_title.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 지도 기록 탭 첫 화면. 잠금은 이 화면이 아니라 셸(`GuidanceLockGate`)이 진다.
class GuidanceListScreen extends ConsumerStatefulWidget {
  const GuidanceListScreen({super.key});

  static const addKey = Key('guidance_add');
  static const trashKey = Key('guidance_trash');
  static const recordFabKey = Key('guidance_record_fab');
  static const personFilterKey = Key('guidance_person_filter');
  static Key kindFilterKey(GuidanceKind? kind) => Key('guidance_kind_${kind?.dbValue ?? 'all'}');
  static Key rowKey(int id) => Key('guidance_row_$id');

  @override
  ConsumerState<GuidanceListScreen> createState() => _GuidanceListScreenState();
}

class _GuidanceListScreenState extends ConsumerState<GuidanceListScreen> {
  /// 열기 요청이 진행 중이면 다른 누름을 무시한다 — 빠른 두 번 탭이 화면을 두 번 열지 않게.
  var _opening = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(guidanceRecordsProvider).valueOrNull;
    final visible = ref.watch(visibleGuidanceRecordsProvider).valueOrNull ?? const <GuidanceRecord>[];
    final kind = ref.watch(guidanceKindFilterProvider);
    final person = ref.watch(guidancePersonFilterProvider);
    final now = DateTime.now();
    final locked = !ref.watch(guidanceUnlockedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TabHeaderTitle(
          eyebrow: GuidanceStrings.eyebrow,
          title: GuidanceStrings.title,
        ),
        actions: [
          _TrashShortcut(
            key: GuidanceListScreen.trashKey,
            onTap: () => _open(AppRoutes.guidanceTrash),
          ),
        ],
      ),
      // 오늘·캘린더와 같은 원형 골드 추가 버튼(2026-10-04 디자인 점검). `GoldFab`은 스스로
      // 이름 있는 잎 노드다 — `FloatingActionButton`은 mobile MCP가 이름을 놓쳤다.
      // 녹음 버튼을 + 위에 둔다 — 상담을 하며 녹음부터 하는 경우가 많다(사용자 제안 2026-10-04).
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordFab(
            key: GuidanceListScreen.recordFabKey,
            onTap: () => context.push(AppRoutes.guidanceNewRecording),
          ),
          const SizedBox(height: AppSizes.spacing12),
          GoldFab(
            key: GuidanceListScreen.addKey,
            semanticLabel: GuidanceStrings.newRecord,
            onTap: () => context.push(AppRoutes.guidanceNew),
          ),
        ],
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
                // 입력 히어로와 같은 테두리형 칩(2026-10-04 디자인 점검). 사람을 골라 두면
                // 그 칩도 선택 모양이 된다 — 걸러 보고 있다는 사실이 보여야 한다.
                // 잠긴 동안은 사람 칩을 그리지 않는다 — 이름 목록이 시트에 열린다.
                if (!locked)
                  PillChip(
                    key: GuidanceListScreen.personFilterKey,
                    label: person == null ? GuidanceStrings.personAll : GuidanceStrings.personLabel(person.name),
                    selected: person != null,
                    onTap: () => _pickPerson(context, ref, all ?? const []),
                  ),
                for (final k in <GuidanceKind?>[null, ...GuidanceKind.values])
                  PillChip(
                    key: GuidanceListScreen.kindFilterKey(k),
                    label: k?.label ?? GuidanceStrings.kindAll,
                    selected: kind == k,
                    onTap: () => ref.read(guidanceKindFilterProvider.notifier).state = k,
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
                                key: GuidanceListScreen.rowKey(r.id),
                                record: r,
                                now: now,
                                locked: locked,
                                onTap: () => _open(AppRoutes.guidanceRecord(r.id)),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  /// 풀렸으면 바로, 잠겼으면 그 자리에서 기기 인증 뒤에 연다. 기기 암호가 없으면 안내 후 잠금 없이 연다.
  Future<void> _open(String location) async {
    if (_opening) return;
    _opening = true;
    try {
      final unlock = ref.read(guidanceUnlockProvider);
      if (!unlock.isUnlocked) {
        final outcome = await unlock.authenticate(
          ref.read(deviceAuthenticatorProvider),
          GuidanceStrings.unlockReason,
        );
        if (!mounted) return;
        switch (outcome) {
          case AuthOutcome.success:
            break;
          case AuthOutcome.failed:
            return;
          case AuthOutcome.noCredentials:
            final ok = await ConfirmDialog.show(
              context: context,
              useRootNavigator: false,
              title: GuidanceStrings.noCredentialsTitle,
              message: GuidanceStrings.noCredentialsBody,
              confirmLabel: GuidanceStrings.openWithoutLock,
            );
            if (!ok || !mounted) return;
            unlock.markUnlocked();
        }
      }
      if (mounted) context.push(location);
    } finally {
      _opening = false;
    }
  }

  Widget _empty() => const EmptyState(
    icon: Icons.lock_outline,
    title: GuidanceStrings.empty,
    hint: GuidanceStrings.emptyHint,
  );

  /// 기록에 등장한 사람 중 하나를 고른다. `(null,)`은 "전체", 시트를 그냥 닫으면 null.
  Future<void> _pickPerson(BuildContext context, WidgetRef ref, List<GuidanceRecord> records) async {
    final candidates = collectParticipants(records);
    final picked = await showModalBottomSheet<(Participant?,)>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, child) {
          // 시트가 열린 채 다시 잠기면(앱을 떠났다 15분 뒤 복귀) 저장된 이름이 남지 않게 닫는다.
          sheetRef.listen<bool>(guidanceUnlockedProvider, (_, unlocked) {
            if (!unlocked && ctx.mounted) Navigator.of(ctx).maybePop();
          });
          return child!;
        },
        child: SafeArea(
          child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSizes.spacing16),
              child: SheetTitle(GuidanceStrings.personPickerTitle),
            ),
            ListTile(
              title: const Text(GuidanceStrings.kindAll),
              onTap: () => Navigator.pop(ctx, (null,)),
            ),
            if (candidates.isEmpty)
              const ListTile(title: Text(GuidanceStrings.personPickerEmpty)),
            for (final p in candidates)
              ListTile(
                title: Text(p.displayName),
                onTap: () => Navigator.pop(ctx, (p,)),
              ),
          ],
        ),
        ),
      ),
    );
    if (picked == null) return;
    ref.read(guidancePersonFilterProvider.notifier).state = picked.$1;
  }
}

/// 삭제한 기록으로 가는 버튼 — 되살리는 곳이라는 것을 아이콘(휴지통 + 위 화살표)과 작은 글자로 말한다.
class _TrashShortcut extends StatelessWidget {
  const _TrashShortcut({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonSemantics(
      label: GuidanceStrings.trashTitle,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacing12,
            vertical: AppSizes.spacing4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restore_from_trash_outlined, color: AppColors.ink),
              Text(GuidanceStrings.trashShortcut, style: AppTextStyles.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// + 위의 녹음 버튼 — 누르면 새 기록을 열고 곧바로 녹음을 시작한다. +보다 한 단계 작고 조용하다.
class _RecordFab extends StatelessWidget {
  const _RecordFab({super.key, required this.onTap});

  static const _size = 48.0;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.gold, width: 1.5)),
      elevation: 2,
      child: ButtonSemantics(
        label: GuidanceStrings.newRecordByRecording,
        onTap: onTap,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(Icons.mic_none_rounded, color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

