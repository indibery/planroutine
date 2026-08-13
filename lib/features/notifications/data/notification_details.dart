import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/constants/app_strings.dart';

/// 플랫폼 알림 details 조립. **순수 함수다** — 플러그인 인스턴스도 채널도 만들지
/// 않고 값만 만든다. 자리를 `data/`에 두는 이유: `NotificationDetails`가 플러그인
/// 타입이라, `domain/`이 플러그인을 모르는 상태를 깨지 않는다.
///
/// `NotificationService`를 부르는 테스트가 리포에 0건이라, 서비스 파일 안에 사설
/// 함수로 두면 회귀 신호를 만들 방법이 없다 — `computeNotifications`·
/// `busPollIntervalFor`를 떼어 둔 것과 같은 패턴이고 같은 이유다.

/// Android 알림 채널 id.
///
/// **한 번 만들면 importance·소리를 코드로 못 바꾼다**(Android 규칙). 바꿔야 하면
/// id를 bump 해야 하고, 그러면 채널이 갈라져 **사용자가 해둔 알림 설정이 초기화된다.**
///
/// 그래서 이 값은 `*Strings`에 두지 않는다 — UI 문자열이 아니라 DB 키·리소스 이름에
/// 가깝고, `*Strings`에 두면 문구를 정리하다 바뀔 위험이 생긴다.
///
/// ⚠️ **`_` 접두를 붙이지 않는다.** 소비처가 두 파일이다 — 이 파일의
/// [buildNotificationDetails]와 `notification_service.dart`의 채널 생성.
/// Dart의 `_` 최상위 선언은 라이브러리 private이라 다른 파일에서 안 보이고,
/// 한쪽에 리터럴을 다시 적으면 같은 id가 두 곳에서 따로 바뀐다.
const kAndroidChannelId = 'schedule_reminder';

/// 예약 알람의 스케줄 모드.
///
/// **값 하나에 Play 심사가 달려 있다** — `exact*`로 되돌리면
/// `SCHEDULE_EXACT_ALARM` 고위험 권한 선언 양식 대상이 된다.
///
/// 권한이 필요 없는 근거: `inexactAllowWhileIdle`은 플러그인 네이티브에서
/// `AlarmManagerCompat.setAndAllowWhileIdle` 분기로 가 `checkCanScheduleExactAlarms`를
/// **호출하지 않는다**(그 함수가 `ExactAlarmPermissionException`을 던지는 곳이다).
///
/// **대가는 Doze의 9분 규칙이고 이 앱에는 무해하다** — `computeNotifications`가
/// 발송 시각을 키로 병합해 **하루 1건**만 만들므로 발화 간격이 최소 24시간이다.
/// 개별 이벤트마다 알림을 만드는 앱이었다면 이 결정은 성립하지 않는다.
///
/// ⚠️ 9분 규칙에 안 걸리는 것이 **정시 발화를 뜻하지는 않는다.** `setAndAllowWhileIdle`은
/// inexact alarm이라 시스템이 알람을 묶어 발화하고 공식 문서에 지연 상한이 없다.
/// 약속할 수 있는 것은 "정시가 아니다"까지다.
///
/// **iOS는 이 값을 읽지 않는다** — iOS `zonedSchedule`은
/// `UNCalendarNotificationTrigger`로 등록되어 시스템이 정시 발화를 보장한다.
const kAndroidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

/// [body]를 담은 플랫폼별 details.
///
/// `const`를 포기하고 본문마다 만든다 — `BigTextStyleInformation('')`을 const로 두면
/// 펼쳤을 때 본문이 빈다.
NotificationDetails buildNotificationDetails(String body) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        kAndroidChannelId,
        NotificationStrings.channelName,
        channelDescription: NotificationStrings.channelDescription,
        importance: Importance.high, // 채널 importance (Android 8.0+)
        priority: Priority.high, // Android 7.1 이하 폴백
        category: AndroidNotificationCategory.reminder,
        // **본문이 두 줄이다.** `computeNotifications`가 만드는 body는
        // `오늘 — …\n이번 주 — …`인데, Android는 접힌 알림에서 한 줄만 보여준다.
        // 이것이 없으면 `이번 주` 섹션이 통째로 안 보인다. iOS는 여러 줄을 그대로
        // 보여줘 이 차이가 지금까지 드러나지 않았다.
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        // 업무 리마인더는 집중 모드/수업 중에도 놓치면 안 된다.
        // ※ 효과 활성화에는 entitlements + Apple Developer Portal의
        //   "Time Sensitive Notifications" capability가 추가로 필요하다.
        //
        // Android에 정확히 대응하는 개념은 없다. 가장 가까운 자리가 채널
        // `Importance.high` + `category: reminder`이고 **등가는 아니다.**
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
