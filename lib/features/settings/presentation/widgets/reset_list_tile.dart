import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../guidance/presentation/providers/guidance_providers.dart';
import '../providers/settings_providers.dart';

/// '전체 데이터 초기화' 타일 — 탭 시 확인 다이얼로그 후 resetAll 실행.
/// 진행 중에는 trailing 로딩 인디케이터 + 탭 비활성.
class ResetListTile extends ConsumerWidget {
  const ResetListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resetState = ref.watch(appResetProvider);
    final isResetting = resetState is ResetInProgress;

    return ListTile(
      leading: Icon(Icons.delete_forever, color: AppColors.error),
      title: Text(
        SettingsStrings.resetAll,
        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
      ),
      trailing: isResetting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isResetting ? null : () => _onTap(context, ref),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // 지도 기록은 되돌릴 수 없는 근거 자료다 — 지워진다는 사실을 건수로 따로 말한다.
    final counts = await ref.read(guidanceRepositoryProvider).counts();
    if (!context.mounted) return;
    // 기록이 0건이어도 명단은 지워진다 — 명단 줄은 따로 말한다.
    final warnings = [
      if (counts.records > 0)
        GuidanceStrings.resetWarning(counts.records, counts.attachments),
      if (counts.people > 0) GuidanceStrings.resetPeopleWarning(counts.people),
    ];
    final message = warnings.isEmpty
        ? SettingsStrings.resetAllConfirmMessage
        : '${SettingsStrings.resetAllConfirmMessage}\n\n${warnings.join('\n')}';
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: SettingsStrings.resetAllConfirmTitle,
      message: message,
      confirmLabel: SettingsStrings.resetAllConfirm,
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;
    await ref.read(appResetProvider.notifier).resetAll();
  }
}
