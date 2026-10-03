import 'package:flutter/widgets.dart';

/// 앱이 **직접 연** 시스템 창(Face ID·사진/파일 고르기·마이크 권한) 동안 잠그지 않게 하는 표시.
///
/// ⚠️ 그 창들은 앱을 `inactive`(Android는 `paused`)로 만든다. 이 가드가 없으면
/// Face ID 창이 뜨는 순간 다시 잠겨 **무한 반복**되고, 사진을 고르러 갔다 오면 잠긴다.
/// 시스템 창을 여는 호출은 반드시 [run]으로 감싼다.
abstract final class SystemSheetGuard {
  static int _depth = 0;
  static DateTime? _endedAt;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// 창이 닫힌 뒤 늦게 도착하는 `inactive`·`hidden`(복귀 전이 paused→hidden→inactive→resumed의
  /// 중간 단계)을 흘려보내는 여유. `paused`에는 적용하지 않는다 —
  /// 고르기 직후 홈으로 나가면 잠겨야 한다.
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

  static bool shouldIgnore(AppLifecycleState state) {
    if (_depth > 0) return true;
    final ended = _endedAt;
    return (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) &&
        ended != null &&
        clock().difference(ended) < grace;
  }

  @visibleForTesting
  static void reset() {
    _depth = 0;
    _endedAt = null;
  }
}
