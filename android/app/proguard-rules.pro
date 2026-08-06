# flutter_local_notifications가 SharedPreferences에 저장한 목록을
# TypeToken<ArrayList<NotificationDetails>>로 되읽어 부팅 후 재예약한다.
# R8 fullMode(AGP 8.x 기본)에서 시그니처가 지워지면 그 경로가 release에서만 깨진다.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# device_calendar는 Kotlin 모델을 Gson **리플렉션**으로 직렬화해 Dart로 넘기고
# (`CalendarDelegate.kt:193` `_gson.toJson(calendars)`), Dart는 `json['isReadOnly']`처럼
# **필드 이름 그대로** 읽는다(`lib/src/models/calendar.dart:36`).
#
# R8이 이름을 줄이면 JSON 키가 `a`/`b`가 되어 Dart 쪽 값이 전부 null이 된다.
# 그러면 `c.isReadOnly == false`가 거짓이라 **쓰기 가능한 캘린더가 0개**로 보이고,
# `DeviceCalendarService._resolveDefaultCalendarId`가 null을 돌려주며
# `writable 캘린더가 없습니다`로 끝난다 — 기기 캘린더 저장이 **release에서만**
# `저장 실패`가 된다(Galaxy A34 실측 2026-08-06. 디버그 빌드는 정상 동작했다).
#
# 위 `@SerializedName` 규칙으로는 안 걸린다 — 이 모델들에는 애노테이션이 없다.
# 플러그인이 consumer-rules를 제공하지 않으므로 **앱이 지켜야 한다.**
-keep class com.builttoroam.devicecalendar.models.** { *; }
-keep class com.builttoroam.devicecalendar.common.RecurrenceFrequency { *; }
