import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../notifications/domain/notification_settings.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// 알림 설정 타일 — 마스터 스위치 하나만 기본 노출. 이번 주/당일 아침/알림
/// 시각/테스트/예약된 알림 목록은 '고급' ExpansionTile 안에 숨긴다. 마스터 옆
/// 서브라인에 현재 상태 요약을 보여줘, 고급을 열지 않아도 알림 구성이 보인다.
class NotificationSettingsTiles extends ConsumerWidget {
  const NotificationSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? NotificationSettings.defaults;
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final subEnabled = settings.masterEnabled;
    final summary = _buildSummary(settings);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.notifications_outlined,
            color: AppColors.primary,
          ),
          title: const Text(NotificationStrings.master),
          subtitle: summary == null
              ? null
              : Text(
                  summary,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.sub,
                  ),
                ),
          value: settings.masterEnabled,
          onChanged: (v) => notifier.setMaster(v),
        ),
        Theme(
          // ExpansionTile 기본 divider 제거 — SettingsSection의 Divider와 중복
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const SizedBox(width: 40),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            title: Text(
              NotificationStrings.advanced,
              style: TextStyle(fontSize: 14, color: AppColors.sub),
            ),
            iconColor: AppColors.sub,
            collapsedIconColor: AppColors.sub,
            children: [
              _SubSwitch(
                label: NotificationStrings.weekly,
                value: settings.weeklyEnabled,
                enabled: subEnabled,
                onChanged: notifier.setWeekly,
              ),
              _SubSwitch(
                label: NotificationStrings.dayOf,
                value: settings.dayOfEnabled,
                enabled: subEnabled,
                onChanged: notifier.setDayOf,
              ),
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text(
                  NotificationStrings.time,
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  _formatTime(settings.hour, settings.minute),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: subEnabled
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ),
                enabled: subEnabled,
                onTap: subEnabled
                    ? () => _pickTime(context, ref, settings)
                    : null,
              ),
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text(
                  NotificationStrings.debug,
                  style: TextStyle(fontSize: 14),
                ),
                trailing:
                    Icon(Icons.list_alt, color: AppColors.primary),
                onTap: () => _showPendingDialog(context, ref),
              ),
              ListTile(
                leading: const SizedBox(width: 40),
                title: const Text(
                  NotificationStrings.test,
                  style: TextStyle(fontSize: 14),
                ),
                trailing:
                    Icon(Icons.alarm_on, color: AppColors.primary),
                onTap: () => _sendTestNotification(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 마스터 스위치 아래 요약. master off 면 null 반환하여 subtitle 숨김.
  String? _buildSummary(NotificationSettings s) {
    if (!s.masterEnabled) return null;
    final kinds = <String>[
      if (s.weeklyEnabled) '이번 주',
      if (s.dayOfEnabled) '당일',
    ];
    if (kinds.isEmpty) return '세부 알림이 모두 꺼져있어요';
    return '${_formatTime(s.hour, s.minute)} · ${kinds.join('·')}';
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
      // iOS 느낌 유지 위해 다이얼 고정 (입력 모드는 터치 실수 유발)
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked == null) return;
    if (picked.hour == settings.hour && picked.minute == settings.minute) {
      return;
    }
    await ref.read(notificationSettingsProvider.notifier).setTime(
          hour: picked.hour,
          minute: picked.minute,
        );
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final service = ref.read(notificationServiceProvider);
    // 권한 없으면 먼저 요청
    await service.requestPermission();
    await service.scheduleQuickTest(
      title: '테스트 알림',
      body: '5초 후 발송된 테스트 알림입니다',
      seconds: 5,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(NotificationStrings.testScheduled),
        ),
      );
    }
  }

  Future<void> _showPendingDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final service = ref.read(notificationServiceProvider);
    final list = await service.listPending();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${NotificationStrings.debugTitle} '
          '${list.length}${NotificationStrings.debugCountSuffix}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text(NotificationStrings.debugEmpty)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        p.title,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        p.body,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '#${p.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }
}

class _SubSwitch extends StatelessWidget {
  const _SubSwitch({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const SizedBox(width: 40),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: enabled ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
      dense: true,
    );
  }
}
