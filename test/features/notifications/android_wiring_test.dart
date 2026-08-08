// Android 알림 배선 — **없어서 기능 전체가 조용히 죽어 있던 것들.**
//
// 실기기 신고(Galaxy A34, 2026-08-08): 알림 스위치를 켜도 즉시 OFF로 되돌아가고
// 기능이 동작하지 않는다. iOS는 권한 다이얼로그가 뜨고 허용하면 정상.
//
// 사망 지점이 둘이었다.
//
//   ① `InitializationSettings`에 `android:`가 없어 `init()`이 첫 줄에서
//      `ArgumentError`를 던졌다. `main.dart`의 `catch (_)`가 먹어 **크래시 없이**
//      `_initialized`가 안 켜지고 이어지는 `sync()`도 같은 catch에 먹혔다 —
//      화면상 증상 0.
//   ② `requestPermission()`이 iOS 플러그인만 resolve해 Android에선 늘 `false`.
//      `setMaster(true)`가 그 false를 받고 마스터를 도로 껐다 — **스위치를 켤 수조차
//      없었다.**
//
// 서비스는 플러그인 인스턴스를 들고 있어 단위 테스트로 못 밟는다. 그래서 값과
// 소스를 검사한다 — 실제 동작 확인은 에뮬레이터·실기기의 몫이다.

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/notifications/data/notification_details.dart';

String _serviceSource() =>
    File('lib/features/notifications/data/notification_service.dart')
        .readAsStringSync();

String _manifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

void main() {
  group('스케줄 모드 — 두 경로가 같은 상수를 쓴다', () {
    test('inexact다 — exact로 되돌리면 Play 고위험 권한 선언 대상이 된다', () {
      expect(kAndroidScheduleMode, AndroidScheduleMode.inexactAllowWhileIdle,
          reason: 'exact*는 SCHEDULE_EXACT_ALARM 선언 양식을 요구한다. '
              '이 앱은 하루 1건으로 병합돼 Doze 9분 규칙이 무해하다');
    });

    test('두 예약 경로가 리터럴 대신 상수를 쓴다', () {
      // 한 곳만 고치면 나머지 경로가 조용히 정확 알람을 요구하고, 그 요구는
      // **런타임 예외로만** 드러난다(`ExactAlarmPermissionException`).
      final src = _serviceSource();

      expect(src, isNot(contains('AndroidScheduleMode.exact')),
          reason: '정확 알람 리터럴이 남아 있다');
      expect(
        RegExp('androidScheduleMode: kAndroidScheduleMode').allMatches(src).length,
        2,
        reason: '_schedule과 scheduleQuickTest 양쪽이 상수를 써야 한다',
      );
    });
  });

  group('details 조립', () {
    test('Android 채널과 BigText 스타일을 담는다', () {
      const body = '오늘 — 학부모 상담\n이번 주 — 운동회';
      final details = buildNotificationDetails(body);

      final android = details.android;
      expect(android, isNotNull, reason: 'Android details가 없으면 채널이 안 붙는다');
      expect(android!.channelId, kAndroidChannelId);
      expect(android.importance, Importance.high);

      // **본문이 두 줄이다.** 이것이 없으면 접힌 알림에서 `이번 주` 섹션이 통째로
      // 안 보인다. iOS는 여러 줄을 그대로 보여줘 차이가 안 드러났다.
      final style = android.styleInformation;
      expect(style, isA<BigTextStyleInformation>());
      expect((style! as BigTextStyleInformation).bigText, body,
          reason: '본문을 넘기지 않으면 펼쳐도 빈다');
    });

    test('iOS 경로는 그대로다 — timeSensitive 유지', () {
      final details = buildNotificationDetails('x');
      expect(details.iOS?.interruptionLevel, InterruptionLevel.timeSensitive);
    });

    test('채널 이름·설명은 Strings에서 온다 — 사용자에게 보이는 문자열이다', () {
      final android = buildNotificationDetails('x').android!;
      expect(android.channelName, NotificationStrings.channelName);
      expect(android.channelDescription, NotificationStrings.channelDescription);
    });

    test('채널 id는 Strings에 두지 않는다 — 바뀌면 사용자 설정이 초기화된다', () {
      // id는 UI 문자열이 아니라 DB 키에 가깝다. `*Strings`에 두면 문구를 정리하다
      // 바뀌고, 그러면 채널이 갈라져 사용자가 해둔 알림 설정이 날아간다.
      final strings =
          File('lib/core/constants/strings/notification_strings.dart')
              .readAsStringSync();
      expect(strings, isNot(contains(kAndroidChannelId)));
    });
  });

  group('서비스 배선', () {
    test('init이 Android 설정을 준다 — 없으면 첫 줄에서 예외였다', () {
      final src = _serviceSource();
      expect(src, contains('android: AndroidInitializationSettings'));
    });

    test('채널을 예약 때가 아니라 init에서 미리 만든다', () {
      // 자동 생성은 **발화할 때** 일어난다. 그때까지 `설정 › 앱 › 알림`에 채널이
      // 없어 "알림이 오지 않나요?" 안내가 빈 화면으로 간다.
      expect(_serviceSource(), contains('createNotificationChannel'));
    });

    test('requestPermission에 Android 분기가 있다 — 이것이 신고된 증상의 원인이었다', () {
      final src = _serviceSource();
      // 플러그인 API는 **복수형** `requestNotificationsPermission()`이다.
      expect(src, contains('requestNotificationsPermission()'));
      // Android 분기가 iOS보다 **먼저** 와야 한다 — iOS resolve가 Android에서
      // null을 주는 것에 기대는 구조라, 순서가 뒤집혀도 동작은 같지만 의도가 흐려진다.
      expect(
        src.indexOf('AndroidFlutterLocalNotificationsPlugin>();\n    if (android'),
        greaterThan(0),
        reason: 'Android를 먼저 resolve하고 분기해야 한다',
      );
    });
  });

  group('매니페스트', () {
    test('예약 알림을 실제로 띄우는 리시버가 있다', () {
      // ⚠️ 이름만 보면 부팅용으로 읽혀 빠뜨리기 쉽다. 없으면 **재부팅과 무관하게**
      // 예약 알림이 한 건도 발화하지 않는다.
      expect(_manifest(), contains('ScheduledNotificationReceiver'));
    });

    test('부팅 후 재예약 리시버와 권한이 있다', () {
      final m = _manifest();
      expect(m, contains('ScheduledNotificationBootReceiver'));
      expect(m, contains('android.permission.RECEIVE_BOOT_COMPLETED'),
          reason: '플러그인이 이 권한을 자체 선언하지 않는다');
      expect(m, contains('android.intent.action.BOOT_COMPLETED'));
      expect(m, contains('android.intent.action.MY_PACKAGE_REPLACED'),
          reason: '앱 교체 후에도 재예약해야 한다');
    });

    test('정확 알람 권한을 선언하지 않는다 — inexact를 쓰기 때문이다', () {
      final m = _manifest();
      expect(m, isNot(contains('SCHEDULE_EXACT_ALARM')));
      expect(m, isNot(contains('USE_EXACT_ALARM')));
    });
  });

  group('아이콘', () {
    test('drawable에 있다 — mipmap이면 플러그인이 못 찾는다', () {
      // 네이티브가 `getIdentifier(name, "drawable", pkg)`로 찾고 defType이 고정이다.
      expect(File('android/app/src/main/res/drawable/ic_notification.xml').existsSync(),
          isTrue);
    });

    test('리소스 축소로부터 보호된다 — Dart 문자열만 참조한다', () {
      // release는 리소스 축소가 기본 ON이라, 지워지면 initialize가 아이콘 검증에
      // 실패해 **알림이 한 건도 뜨지 않는다.** release에서만 깨져 알기 어렵다.
      final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
      expect(keep, contains('@drawable/ic_notification'));
    });

    test('테두리를 한 path로 그리지 않는다 — 상태바에 흰 사각형이 뜬다', () {
      // 기본 fillType이 nonZero라 "바깥 사각형 + 안쪽 사각형"을 한 path에 넣으면
      // 구멍이 안 뚫리고 통째로 칠해진다.
      final svg =
          File('android/app/src/main/res/drawable/ic_notification.xml')
              .readAsStringSync();
      final paths = RegExp(r'android:pathData="([^"]+)"').allMatches(svg);

      expect(paths.length, greaterThanOrEqualTo(8),
          reason: '막대·격자를 나눠 그려야 한다');
      for (final m in paths) {
        expect(m.group(1)!.toLowerCase().split('m').length - 1, 1,
            reason: '한 pathData에 서브패스가 둘이면 nonZero로 메워진다: ${m.group(1)}');
      }
    });
  });
}
