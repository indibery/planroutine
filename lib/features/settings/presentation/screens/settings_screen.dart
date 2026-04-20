import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../google/presentation/providers/google_providers.dart';
import '../../../import/presentation/widgets/import_section.dart';
import '../../../trash/presentation/providers/trash_providers.dart';
import '../providers/app_info_provider.dart';
import '../providers/settings_providers.dart';

/// 설정 화면 (하단 탭)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ResetState>(appResetProvider, (prev, next) {
      switch (next) {
        case ResetSuccess():
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(content: Text(AppStrings.settingsResetAllDone)),
            );
        case ResetFailure(message: final msg):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('${AppStrings.settingsResetAllFailed}: $msg'),
                backgroundColor: AppColors.error,
              ),
            );
        case ResetIdle() || ResetInProgress():
          break;
      }
    });

    final resetState = ref.watch(appResetProvider);
    final isResetting = resetState is ResetInProgress;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(title: AppStrings.settingsImportSection),
          const ImportSection(),
          const SizedBox(height: AppSizes.spacing8),
          const Divider(height: 1),
          _SectionHeader(title: AppStrings.settingsExportSection),
          _ExportListTile(),
          const Divider(height: 1),
          _SectionHeader(title: AppStrings.settingsGoogleSection),
          _GoogleAccountListTile(),
          const Divider(height: 1),
          _SectionHeader(title: AppStrings.settingsTrashSection),
          _TrashListTile(),
          const Divider(height: 1),
          _SectionHeader(title: AppStrings.settingsDataSection),
          ListTile(
            leading: const Icon(
              Icons.delete_forever,
              color: AppColors.error,
            ),
            title: const Text(
              AppStrings.settingsResetAll,
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(AppStrings.settingsResetAllDescription),
            trailing: isResetting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: isResetting ? null : () => _showConfirmDialog(context, ref),
          ),
          const Divider(height: 1),
          _SectionHeader(title: AppStrings.settingsAboutSection),
          _AppInfoListTile(),
          const SizedBox(height: AppSizes.spacing24),
        ],
      ),
    );
  }

  Future<void> _showConfirmDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.settingsResetAllConfirmTitle),
        content: const Text(AppStrings.settingsResetAllConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.settingsResetAllConfirm,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(appResetProvider.notifier).resetAll();
    }
  }
}

/// 현재 일정 CSV로 내보내기 (공유시트)
class _ExportListTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ExportListTile> createState() => _ExportListTileState();
}

class _ExportListTileState extends ConsumerState<_ExportListTile> {
  bool _exporting = false;

  /// iOS 공유시트가 popup을 띄울 때 쓰는 앵커 Rect.
  /// ListTile의 화면상 위치를 반환. RenderBox 못 구하면 안전한 fallback 제공.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    // fallback: 화면 중앙 근처 (iOS가 요구하는 "non-zero, within screen" 만족)
    final size = MediaQuery.of(context).size;
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  Future<void> _onExport() async {
    // iOS/iPad에서 Share popup 앵커로 쓸 ListTile의 화면상 위치를 미리 구함
    // (sharePositionOrigin 미지정 시 iOS에서 PlatformException 발생)
    final origin = _shareOrigin();

    setState(() => _exporting = true);
    try {
      final exporter = ref.read(scheduleCsvExporterProvider);
      final result = await exporter.exportActiveSchedules();
      if (result.count == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.settingsExportEmpty)),
          );
        }
        return;
      }
      await Share.shareXFiles(
        [XFile(result.filePath)],
        subject: AppStrings.settingsExportShareSubject,
        text: '${result.count}${AppStrings.settingsExportShareCountSuffix}',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.settingsExportFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.ios_share, color: AppColors.primary),
      title: const Text(AppStrings.settingsExportTitle),
      subtitle: const Text(AppStrings.settingsExportDescription),
      trailing: _exporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _exporting ? null : _onExport,
    );
  }
}

/// 구글 계정 연결 섹션 — 로그인 상태에 따라 다른 UI 노출.
class _GoogleAccountListTile extends ConsumerWidget {
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
        subtitle: const Text(AppStrings.settingsGoogleSignInDescription),
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

/// 휴지통 ListTile — 건수 배지 포함
class _TrashListTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(trashSnapshotProvider);
    final count = snapshotAsync.valueOrNull?.total ?? 0;
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.primary),
      title: const Text(AppStrings.trashTitle),
      subtitle: const Text(AppStrings.settingsTrashDescription),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacing8,
                vertical: AppSizes.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(width: AppSizes.spacing4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(AppRoutes.trash),
    );
  }
}

/// 앱 정보 — 앱 이름 + 버전/빌드 번호 표시 (정보성, 탭 비활성)
class _AppInfoListTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(appInfoProvider);
    return ListTile(
      leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
      title: Text(infoAsync.valueOrNull?.appName ?? AppStrings.appName),
      subtitle: Text(
        infoAsync.when(
          data: (info) => info.displayVersion,
          loading: () => AppStrings.loading,
          error: (_, _) => AppStrings.error,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing16,
        AppSizes.spacing8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
