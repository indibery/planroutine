import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../data/notification_rules.dart';
import '../../data/notification_service.dart';
import '../../domain/notification_settings.dart';

// v1 → v2: 기본 알림 시각 09:00 → 08:00. 키 bump으로 기존 저장값 자연 리셋.
const _prefsKey = 'notification_settings_v2';

/// 플랫폼 NotificationService 프로바이더 (앱 시작 시 init 필수).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return FlutterLocalNotificationService.instance;
});

/// 알림 설정 AsyncNotifier — SharedPreferences에 JSON 직렬화 저장
final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return NotificationSettings.defaults;
    try {
      return NotificationSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return NotificationSettings.defaults;
    }
  }

  Future<void> save(NotificationSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
    await ref.read(notificationSyncerProvider).sync();
  }

  Future<void> setMaster(bool value) async {
    final current = state.valueOrNull ?? NotificationSettings.defaults;
    // 마스터 ON 전환 시 권한 요청 시도
    if (value && !current.masterEnabled) {
      final ok =
          await ref.read(notificationServiceProvider).requestPermission();
      if (!ok) {
        // 권한 거부되면 마스터도 OFF 유지
        await save(current.copyWith(masterEnabled: false));
        return;
      }
    }
    await save(current.copyWith(masterEnabled: value));
  }

  Future<void> setMonthStart(bool value) async =>
      save((state.valueOrNull ?? NotificationSettings.defaults)
          .copyWith(monthStartEnabled: value));

  Future<void> setWeekBefore(bool value) async =>
      save((state.valueOrNull ?? NotificationSettings.defaults)
          .copyWith(weekBeforeEnabled: value));

  Future<void> setDayBefore(bool value) async =>
      save((state.valueOrNull ?? NotificationSettings.defaults)
          .copyWith(dayBeforeEnabled: value));

  /// 알림 발송 시각 변경. 저장 후 자동 재동기화.
  Future<void> setTime({required int hour, required int minute}) async =>
      save((state.valueOrNull ?? NotificationSettings.defaults)
          .copyWith(hour: hour, minute: minute));
}

/// 이벤트 CRUD / 설정 변경 시 알림을 재동기화하는 서비스
final notificationSyncerProvider = Provider<NotificationSyncer>((ref) {
  return NotificationSyncer(ref);
});

class NotificationSyncer {
  NotificationSyncer(this._ref);

  final Ref _ref;

  /// 현재 DB의 활성 이벤트 + 저장된 설정을 읽어 전체 재예약
  Future<void> sync() async {
    final calendarRepo = _ref.read(calendarRepositoryProvider);
    final service = _ref.read(notificationServiceProvider);
    final settings = await _ref.read(notificationSettingsProvider.future);

    // 충분히 넓은 범위 — 오늘 기준 1년치 이벤트 로드
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year + 1, now.month, 1);
    final events = await calendarRepo.getEventsByDateRange(start, end);

    final pending = computeNotifications(
      events: events,
      settings: settings,
      now: now,
    );
    await service.replaceAll(pending);
  }
}
