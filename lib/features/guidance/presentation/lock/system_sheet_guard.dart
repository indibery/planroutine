import 'package:flutter/widgets.dart';

/// 앱이 **직접 연** 시스템 창(사진/파일 고르기·마이크 권한·설정 열기) 동안의 `inactive`를
/// "떠남"으로 치지 않게 하는 표시. 시스템 창을 여는 호출은 [run]으로 감싼다.
///
/// 지금 이 판단을 쓰는 곳은 **녹음 화면** 하나다 — 녹음 중 앱을 떠나면 그때까지 저장하고 닫는데,
/// 시스템 창이 만드는 `inactive`에 녹음이 멈추면 안 된다.
///
/// 잠금 게이트는 이 가드를 보지 않는다(15분 규칙, 2026-10-03). 게이트에게 `inactive`는 원래 떠남이
/// 아니고, 시스템 창 중의 `hidden`·`paused`(Android 고르기 창은 별도 Activity)도 그냥 떠남으로 찍힌 뒤
/// 돌아왔을 때 `guidanceRelockAfter` 규칙이 판단한다.
///
/// 가드 중이라도 `hidden`·`paused`는 흘려보내지 않는다 — 시스템 창을 띄운 채 홈으로 나간 것이다.
abstract final class SystemSheetGuard {
  static int _depth = 0;
  static DateTime? _endedAt;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// 창이 닫힌 뒤 늦게 도착하는 `inactive`·`hidden`(복귀 전이 paused→hidden→inactive→resumed의
  /// 중간 단계)을 흘려보내는 여유. `paused`에는 적용하지 않는다 —
  /// 창이 닫힌 직후 홈으로 나가면 떠난 것이다.
  static const grace = Duration(milliseconds: 800);

  static Future<T> run<T>(Future<T> Function() task) async {
    _depth++;
    try {
      return await task();
    } finally {
      _depth--;
      _endedAt = clock();
    }
  }

  /// 이 생명주기 변화를 떠남에서 뺄지.
  static bool shouldIgnore(AppLifecycleState state) {
    if (_depth > 0) {
      return state != AppLifecycleState.hidden &&
          state != AppLifecycleState.paused;
    }
    final ended = _endedAt;
    return (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden) &&
        ended != null &&
        clock().difference(ended) < grace;
  }

  @visibleForTesting
  static void reset() {
    _depth = 0;
    _endedAt = null;
  }
}
