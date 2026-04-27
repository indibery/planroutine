import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../device_calendar/presentation/providers/device_calendar_providers.dart';
import '../../../google/presentation/providers/google_providers.dart';
import '../providers/calendar_target_provider.dart';
import 'settings_section.dart';

/// 외부 캘린더 연동 대상 단일 선택 + 활성 상세(Google 계정 / 기기 권한).
///
/// 기존 GoogleAccountListTile + 신규 라디오 + 권한 상태를 한 섹션에 통합.
class CalendarIntegrationSection extends ConsumerWidget {
  const CalendarIntegrationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(calendarTargetProvider);
    final target = targetAsync.valueOrNull ?? CalendarTarget.none;

    return SettingsSection(
      title: CalendarIntegrationStrings.sectionTitle,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.event_note_outlined,
              color: AppColors.primary,
            ),
            title: const Text(CalendarIntegrationStrings.targetLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_targetLabel(target)),
                const Icon(Icons.expand_more),
              ],
            ),
            onTap: () => _showTargetSheet(context, ref, target),
          ),
          if (target == CalendarTarget.google) const _GoogleAccountRow(),
          if (target == CalendarTarget.device) const _DevicePermissionRow(),
        ],
      ),
    );
  }

  String _targetLabel(CalendarTarget t) {
    switch (t) {
      case CalendarTarget.none:
        return CalendarIntegrationStrings.targetNone;
      case CalendarTarget.google:
        return CalendarIntegrationStrings.targetGoogle;
      case CalendarTarget.device:
        return CalendarIntegrationStrings.targetDevice;
    }
  }

  Future<void> _showTargetSheet(
    BuildContext context,
    WidgetRef ref,
    CalendarTarget current,
  ) async {
    final selected = await showModalBottomSheet<CalendarTarget>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<CalendarTarget>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in CalendarTarget.values)
                RadioListTile<CalendarTarget>(
                  title: Text(_targetLabel(t)),
                  value: t,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != current) {
      await ref.read(calendarTargetProvider.notifier).setTarget(selected);
    }
  }
}

/// Google 선택 시: 로그인 상태에 따라 다른 row.
class _GoogleAccountRow extends ConsumerWidget {
  const _GoogleAccountRow();

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
        title: const Text(GoogleStrings.signIn),
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
          : const Icon(Icons.account_circle, color: AppColors.primary),
      title: Text(account.displayName ?? account.email),
      subtitle: Text(account.email),
      trailing: TextButton(
        onPressed: () => _signOut(context, ref),
        child: const Text(GoogleStrings.signOut),
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
            content: Text('${GoogleStrings.signInFailed}: $e'),
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
        const SnackBar(content: Text(GoogleStrings.signOutDone)),
      );
    }
  }
}

/// 기기 캘린더 선택 시: 권한 상태 표시 + 거부 시 설정 버튼.
class _DevicePermissionRow extends ConsumerWidget {
  const _DevicePermissionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(devicePermissionProvider);
    final granted = permAsync.valueOrNull ?? false;

    if (granted) {
      return const ListTile(
        leading: Icon(Icons.check_circle, color: AppColors.inkGreen),
        title: Text(CalendarIntegrationStrings.permissionGranted),
      );
    }
    return ListTile(
      leading: const Icon(Icons.warning_amber, color: AppColors.gold),
      title: const Text(CalendarIntegrationStrings.permissionDenied),
      trailing: TextButton(
        onPressed: () async {
          await openAppSettings();
          ref.invalidate(devicePermissionProvider);
        },
        child: const Text(CalendarIntegrationStrings.openSettings),
      ),
    );
  }
}
