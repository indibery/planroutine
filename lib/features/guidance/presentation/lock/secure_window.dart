import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "지도 기록이 보이는 중"을 네이티브에 알린다.
/// - Android: `FLAG_SECURE` — 최근 앱 화면에 내용이 찍히지 않고 스크린샷도 막힌다.
/// - iOS: 같은 플래그가 없다. 대신 `SceneDelegate`가 비활성이 되는 순간 창 위에 불투명 가림막을
///   올린다 — Flutter 잠금 덮개는 `inactive` 콜백 **한 프레임 뒤**에 그려져(런타임 확인 2026-10-03)
///   앱 전환기 스냅샷이 그보다 먼저 찍히면 내용이 보일 수 있다.
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
    bool? isIOS,
    Future<void> Function(bool on)? invoke,
  }) : _supported = (isAndroid ?? Platform.isAndroid) || (isIOS ?? Platform.isIOS),
       _invoke = invoke ?? _invokeChannel;

  /// `MainActivity.kt`의 `SECURE_CHANNEL`, iOS `AppDelegate`의 채널과 같아야 한다
  /// (`lock_native_wiring_test.dart`).
  static const channel = MethodChannel('planroutine/secure_window');
  static const method = 'setSecure';

  final bool _supported;
  final Future<void> Function(bool on) _invoke;
  var _count = 0;

  static Future<void> _invokeChannel(bool on) =>
      channel.invokeMethod<void>(method, on);

  @override
  Future<void> setSecure(bool on) async {
    if (!_supported) return;
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
