import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android `FLAG_SECURE` — 최근 앱 화면에 내용이 찍히지 않고 스크린샷도 막힌다.
/// iOS에는 같은 플래그가 없어 아무것도 하지 않는다(잠금 덮개가 그 몫을 한다).
abstract class SecureWindow {
  Future<void> setSecure(bool on);
}

class PlatformSecureWindow implements SecureWindow {
  /// `MainActivity.kt`의 `SECURE_CHANNEL`과 같아야 한다(`lock_native_wiring_test.dart`).
  static const channel = MethodChannel('planroutine/secure_window');

  @override
  Future<void> setSecure(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await channel.invokeMethod<void>('setSecure', on);
    } on PlatformException {
      // 막지 못해도 잠금 덮개는 동작한다 — 기능을 멈추지 않는다.
    } on MissingPluginException {
      // 같은 이유.
    }
  }
}

final secureWindowProvider = Provider<SecureWindow>((ref) => PlatformSecureWindow());
