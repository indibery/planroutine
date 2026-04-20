import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/pending_notification.dart';

/// 플랫폼 알림 시스템 래퍼 — flutter_local_notifications 감싼 얇은 인터페이스.
///
/// 테스트에선 [FakeNotificationService]로 교체. 구현은 iOS 한정으로 필요한 부분만.
abstract class NotificationService {
  Future<void> init();

  /// OS 권한 다이얼로그 띄우고 결과 반환. 이미 승인됐으면 true.
  Future<bool> requestPermission();

  /// 알림 [list]를 현재 상태와 동기화.
  /// 구현 방식: cancelAll → schedule 전체. iOS 상한(64개) 내에서 안전.
  Future<void> replaceAll(List<PendingNotification> list);

  /// 특정 id만 취소
  Future<void> cancel(int id);

  /// 디버그/테스트용 — [seconds]초 후 즉석 알림
  Future<void> scheduleQuickTest({
    required String title,
    required String body,
    int seconds = 5,
  });

  /// 현재 OS에 예약된 알림 목록. 디버그/검증용.
  /// scheduledAt 정보는 OS가 보존하지 않으므로 title/body/id만 반환.
  Future<List<PendingNotificationInfo>> listPending();
}

/// [NotificationService.listPending] 반환 값.
/// OS 계층에선 scheduledAt이 보존되지 않아 id/title/body만 제공.
class PendingNotificationInfo {
  const PendingNotificationInfo({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}

class FlutterLocalNotificationService implements NotificationService {
  FlutterLocalNotificationService._();
  static final instance = FlutterLocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // 디바이스 타임존으로 설정. 한국어 앱이지만 여행 등 고려해 native 경유 없이
    // 기본 Local로 둠 (flutter_local_notifications v18+는 자동 Local 사용).
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        // 권한은 requestPermission에서 명시적으로 받음
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return granted ?? false;
  }

  @override
  Future<void> replaceAll(List<PendingNotification> list) async {
    await _plugin.cancelAll();
    for (final p in list) {
      await _schedule(p);
    }
  }

  Future<void> _schedule(PendingNotification p) async {
    final tzTime = tz.TZDateTime.from(p.scheduledAt, tz.local);
    try {
      await _plugin.zonedSchedule(
        p.id,
        p.title,
        p.body,
        tzTime,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            // 업무 일정 리마인더는 집중 모드/수업 중에도 사용자가 놓치면 안 됨.
            // timeSensitive는 iOS의 집중 필터를 뚫고 올린다.
            // ※ 효과 활성화에는 앱 entitlements + Apple Developer Portal의
            //   "Time Sensitive Notifications" capability가 추가로 필요.
            //   미설정 시 iOS가 silent 무시하고 기본 우선순위로 동작.
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // 디바이스 시계 오차 / 권한 미승인 등으로 실패해도 앱 동작은 계속
      if (kDebugMode) {
        debugPrint('Notification schedule failed (${p.id}): $e');
      }
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<List<PendingNotificationInfo>> listPending() async {
    final list = await _plugin.pendingNotificationRequests();
    return list
        .map((p) => PendingNotificationInfo(
              id: p.id,
              title: p.title ?? '',
              body: p.body ?? '',
            ))
        .toList();
  }

  @override
  Future<void> scheduleQuickTest({
    required String title,
    required String body,
    int seconds = 5,
  }) async {
    final at = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      999999, // 테스트 전용 고정 id (중복되면 덮어씀)
      title,
      body,
      at,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
