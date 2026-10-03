import 'dart:io';

import 'package:flutter/widgets.dart';

/// 앱이 **직접 연** 시스템 창(Face ID·사진/파일 고르기·마이크 권한) 동안 잠그지 않게 하는 표시.
///
/// ⚠️ 그 창들은 앱을 `inactive`(Android 고르기 창은 별도 Activity라 `paused`)로 만든다. 이 가드가
/// 없으면 Face ID 창이 뜨는 순간 다시 잠겨 **무한 반복**되고, 사진을 고르러 갔다 오면 잠긴다.
/// 시스템 창을 여는 호출은 반드시 [run]으로 감싼다.
///
/// 가드 중이라도 **앱을 떠난 것**은 잠가야 한다(고르기 창을 띄운 채 홈으로 나가는 경우). 플랫폼마다 다르다:
/// - **iOS**: 시스템 창은 앱을 `inactive`로만 만든다. 그래서 가드 중에도 `hidden`·`paused`는 떠난 것이다 → 잠근다.
/// - **Android**: 고르기 창이 떠 있는 동안 `paused`가 정상으로 온다 — 그것만으로는 떠났는지 알 수 없다.
///   가드 중 처음 `paused`를 받은 시각을 기억해 두고, 돌아왔을 때(`resumed`) [androidAwayLimit]을 넘었으면
///   [takeLongAbsence]가 잠그라고 알린다.
abstract final class SystemSheetGuard {
  static int _depth = 0;
  static DateTime? _endedAt;

  /// Android: 가드 중 처음 백그라운드가 된 시각.
  static DateTime? _awayFrom;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static bool platformIsIOS() => Platform.isIOS;

  /// iOS가 아니면 Android 규칙을 쓴다(테스트 호스트 macOS 포함 — 테스트는 이 값을 직접 정한다).
  @visibleForTesting
  static bool Function() isIOS = platformIsIOS;

  /// 창이 닫힌 뒤 늦게 도착하는 `inactive`·`hidden`(복귀 전이 paused→hidden→inactive→resumed의
  /// 중간 단계)을 흘려보내는 여유. `paused`에는 적용하지 않는다 —
  /// 고르기 직후 홈으로 나가면 잠겨야 한다.
  static const grace = Duration(milliseconds: 800);

  /// Android: 시스템 창 중 이보다 오래 백그라운드에 있었으면 돌아올 때 잠근다.
  /// 사진을 고르는 데 쓰는 시간까지 포함된다 — 그보다 길면 다시 인증을 묻는 것이 대가다.
  static const androidAwayLimit = Duration(seconds: 60);

  static Future<T> run<T>(Future<T> Function() task) async {
    _depth++;
    try {
      return await task();
    } finally {
      _depth--;
      _endedAt = clock();
    }
  }

  /// 이 생명주기 변화를 잠금 사유에서 뺄지. Android에서 가드 중 `paused`가 오면 그 시각을 기억한다
  /// (여러 번 불려도 처음 시각만 남는다 — 게이트와 녹음 화면이 같은 상태를 각각 묻는다).
  static bool shouldIgnore(AppLifecycleState state) {
    if (_depth > 0) {
      final leaving =
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused;
      if (isIOS()) return !leaving;
      if (state == AppLifecycleState.paused) _awayFrom ??= clock();
      return true;
    }
    final ended = _endedAt;
    return (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden) &&
        ended != null &&
        clock().difference(ended) < grace;
  }

  /// Android: 시스템 창 중 [androidAwayLimit]보다 오래 떠나 있다 돌아왔는지. 한 번 묻으면 지워진다.
  /// 게이트가 `resumed`에서 부른다.
  static bool takeLongAbsence() {
    final from = _awayFrom;
    _awayFrom = null;
    return from != null && clock().difference(from) > androidAwayLimit;
  }

  @visibleForTesting
  static void reset() {
    _depth = 0;
    _endedAt = null;
    _awayFrom = null;
  }
}
