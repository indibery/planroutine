import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_intents_contract.dart';
import 'app_intents_handler.dart';

/// 앱 기동 시 App Intents 채널을 붙인다.
///
/// **`main()`에서 컨테이너를 만든 직후에 부른다.** 늦게 부르면 앱이 백그라운드로
/// 떠서 인텐트를 처리하려는 순간에 핸들러가 아직 없을 수 있다.
abstract final class AppIntentsBridge {
  const AppIntentsBridge._();

  static const _channel = MethodChannel(AppIntentsContract.channelName);

  /// 핸들러를 등록하고 Swift에 준비되었음을 알린다.
  ///
  /// 실패해도 앱 기동을 막지 않는다 — 단축어가 안 되는 것과 앱이 안 뜨는 것은
  /// 심각도가 다르다(`main()`의 다른 초기화와 같은 규칙).
  static Future<void> attach(ProviderContainer container) async {
    final handler = AppIntentsHandler(container);
    _channel.setMethodCallHandler(handler.handle);
    try {
      await _channel.invokeMethod(AppIntentsContract.methodReady);
    } catch (_) {
      // Swift 쪽이 없는 플랫폼(안드로이드·테스트)에서는 그냥 지나간다.
    }
  }

  /// iOS에서만 배선한다. 안드로이드에는 App Intents가 없다 —
  /// 그쪽 대응은 AppFunctions이고 이 계획의 범위 밖이다.
  ///
  /// ⚠️ `defaultTargetPlatform`이 아니라 `dart:io`를 쓴다(리포 규칙).
  /// `flutter test`에서 전자는 항상 android로 강제된다.
  static bool get isSupportedPlatform => Platform.isIOS;
}
