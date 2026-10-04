import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../providers/guidance_providers.dart';

/// 탭 안의 휴지통. 공용 휴지통에 두지 않는다 — 거기는 잠금이 없다.
/// 30일 자동 정리 대상도 아니다(근거 자료가 조용히 사라지면 안 된다).
class GuidanceTrashScreen extends ConsumerWidget {
  const GuidanceTrashScreen({super.key});

  static Key restoreKey(int id) => Key('g_trash_restore_$id');
  static Key purgeKey(int id) => Key('g_trash_purge_$id');

  /// 실패해도 화면은 그대로 두고 안내만 띄운다 — 누를 수 없게 되는 버튼이 없다.
  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.actionFailed)));
      }
    }
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, int id) async {
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.purgeTitle,
      message: GuidanceStrings.purgeMessage,
      confirmLabel: GuidanceStrings.purge,
      confirmColor: AppColors.error,
    );
    if (!ok || !context.mounted) return;
    await _guard(context, () => ref.read(guidanceActionsProvider).permanentDelete(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(guidanceDeletedRecordsProvider).valueOrNull ?? const <GuidanceRecord>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(GuidanceStrings.trashTitle, style: AppTextStyles.heading)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.spacing16),
            child: Text(GuidanceStrings.trashIntro, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
          ),
          if (deleted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.spacing32),
              child: Center(child: Text(GuidanceStrings.trashEmpty, style: AppTextStyles.bodyM)),
            ),
          for (final r in deleted)
            ListTile(
              title: Text(r.content.title),
              subtitle: Text(GuidanceStrings.deletedAt(formatStamp(r.deletedAt ?? r.createdAt, now: now))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: restoreKey(r.id),
                    onPressed: () => _guard(context, () => ref.read(guidanceActionsProvider).restore(r.id)),
                    child: Text(
                      GuidanceStrings.restore,
                      // 어느 기록의 버튼인지 이름에 붙인다 — 행 제목이 트리에서 빠져 버튼만 보였다.
                      semanticsLabel: AppStrings.rowAction(r.content.title, GuidanceStrings.restore),
                    ),
                  ),
                  IconButton(
                    key: purgeKey(r.id),
                    icon: Icon(
                      Icons.delete_forever,
                      color: AppColors.error,
                      semanticLabel: AppStrings.rowAction(r.content.title, GuidanceStrings.purge),
                    ),
                    onPressed: () => _purge(context, ref, r.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
