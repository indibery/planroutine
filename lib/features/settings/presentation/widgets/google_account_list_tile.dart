import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../google/presentation/providers/google_providers.dart';

/// 구글 계정 연결 섹션 — 로그인 상태에 따라 다른 UI 노출.
class GoogleAccountListTile extends ConsumerWidget {
  const GoogleAccountListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(googleAccountProvider);
    final account = accountAsync.valueOrNull;

    if (account == null) {
      return ListTile(
        leading: const Icon(
          Icons.account_circle_outlined,
          color: AppColors.primary,
        ),
        title: const Text(AppStrings.settingsGoogleSignIn),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _signIn(context, ref),
      );
    }

    return ListTile(
      leading: account.photoUrl != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(account.photoUrl!),
              backgroundColor: AppColors.surfaceVariant,
            )
          : const Icon(
              Icons.account_circle,
              color: AppColors.primary,
            ),
      title: Text(account.displayName ?? account.email),
      subtitle: Text(account.email),
      trailing: TextButton(
        onPressed: () => _signOut(context, ref),
        child: const Text(AppStrings.settingsGoogleSignOut),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(googleCalendarServiceProvider);
      await service.signIn();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.settingsGoogleSignInFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(googleCalendarServiceProvider).signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.settingsGoogleSignOutDone)),
      );
    }
  }
}
