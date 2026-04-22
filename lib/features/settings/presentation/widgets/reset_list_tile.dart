import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
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
      leading: const Icon(Icons.delete_forever, color: AppColors.error),
      title: const Text(
        AppStrings.settingsResetAll,
        style: TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
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
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.settingsResetAllConfirmTitle,
      message: AppStrings.settingsResetAllConfirmMessage,
      confirmLabel: AppStrings.settingsResetAllConfirm,
      confirmColor: AppColors.error,
    );
    if (!confirmed) return;
    await ref.read(appResetProvider.notifier).resetAll();
  }
}
