import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/app_strings.dart';
import '../domain/pending_notification.dart';
import 'notification_details.dart';

/// 플랫폼 알림 시스템 래퍼 — flutter_local_notifications 감싼 얇은 인터페이스.
///
/// 테스트에선 [FakeNotificationService]로 교체.
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

/// 상태바 아이콘. `res/drawable/ic_notification.xml` — **확장자 없이** 이름만 준다.
///
/// 플러그인 네이티브가 `getIdentifier(name, "drawable", packageName)`으로 찾는다 —
/// defType이 `"drawable"`로 고정이라 `res/mipmap/`에 두면 못 찾고, 아이콘 검증에
/// 실패하면 `initialize`가 성공 응답 없이 return해 Dart에 `PlatformException`이 온다.
///
/// 소비처가 이 파일의 `init()` 하나라 파일 로컬로 둔다.
const _androidIcon = 'ic_notification';

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
      // **Android 설정이 없으면 여기서 예외가 난다.** 플러그인이
      // `initializationSettings.android == null`이면 `ArgumentError`를 던지는데,
      // `main.dart`의 `try { … } catch (_) {}`가 먹어 크래시 없이 `_initialized`가
      // 안 켜지고 이어지는 `sync()`도 같은 catch에 먹혔다 — 화면상 증상 0으로
      // **알림 기능 전체가 조용히 죽어 있었다**(Android, ~v147).
      android: AndroidInitializationSettings(_androidIcon),
      iOS: DarwinInitializationSettings(
        // 권한은 requestPermission에서 명시적으로 받음
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);

    // **채널을 여기서 먼저 만든다.** 안 만들어도 첫 발화 때 자동 생성되지만, 그
    // 시점은 "예약할 때"가 아니라 "발화할 때"다 — 그때까지 `설정 › 앱 › 알림`에
    // 채널이 없어 "알림이 오지 않나요?" 안내가 빈 화면으로 간다.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            kAndroidChannelId,
            NotificationStrings.channelName,
            description: NotificationStrings.channelDescription,
            importance: Importance.high,
          ),
        );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    // **Android 분기가 없어 여기가 늘 false를 돌려줬다.** `setMaster(true)`가 그
    // false를 받고 마스터를 도로 꺼서 **알림 스위치를 켤 수조차 없었다**
    // (실기기 신고 2026-08-08, Galaxy A34).
    //
    // 플러그인 API 이름은 `requestNotificationsPermission()` — **복수형**이다.
    // 우리 추상 메서드 이름(`requestPermission`)과 달라 헷갈리기 쉽다.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // API 33+는 POST_NOTIFICATIONS 다이얼로그, 그 아래는 현재 상태를 답한다
      // (no-op이 아니다).
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
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
        buildNotificationDetails(p.body),
        androidScheduleMode: kAndroidScheduleMode,
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
        .map(
          (p) => PendingNotificationInfo(
            id: p.id,
            title: p.title ?? '',
            body: p.body ?? '',
          ),
        )
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
      buildNotificationDetails(body),
      androidScheduleMode: kAndroidScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
