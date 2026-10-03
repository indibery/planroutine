import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android `FLAG_SECURE` — 최근 앱 화면에 내용이 찍히지 않고 스크린샷도 막힌다.
/// iOS에는 같은 플래그가 없어 아무것도 하지 않는다(잠금 덮개가 그 몫을 한다).
abstract class SecureWindow {
  Future<void> setSecure(bool on);
}

/// 켜짐을 **참조 횟수**로 센다. 테마가 바뀌면 `app.dart`가 라우트 하위를 재생성하는데,
/// 새 게이트의 `setSecure(true)`가 옛 게이트의 `setSecure(false)`(프레임 끝 dispose)보다
/// 먼저 불린다 — 단순 on/off면 게이트가 화면에 있는데 플래그가 꺼진다.
/// 0→1일 때만 켜고 1→0일 때만 끈다.
class PlatformSecureWindow implements SecureWindow {
  PlatformSecureWindow({
    bool? isAndroid,
    Future<void> Function(bool on)? invoke,
  }) : _isAndroid = isAndroid ?? Platform.isAndroid,
       _invoke = invoke ?? _invokeChannel;

  /// `MainActivity.kt`의 `SECURE_CHANNEL`과 같아야 한다(`lock_native_wiring_test.dart`).
  static const channel = MethodChannel('planroutine/secure_window');

  final bool _isAndroid;
  final Future<void> Function(bool on) _invoke;
  var _count = 0;

  static Future<void> _invokeChannel(bool on) =>
      channel.invokeMethod<void>('setSecure', on);

  @override
  Future<void> setSecure(bool on) async {
    if (!_isAndroid) return;
    if (on) {
      _count++;
      if (_count != 1) return;
    } else {
      if (_count == 0) return;
      _count--;
      if (_count != 0) return;
    }
    try {
      await _invoke(on);
    } on PlatformException {
      // 막지 못해도 잠금 덮개는 동작한다 — 기능을 멈추지 않는다.
    } on MissingPluginException {
      // 같은 이유.
    }
  }
}

final secureWindowProvider = Provider<SecureWindow>((ref) => PlatformSecureWindow());
