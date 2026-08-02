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
