import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_authenticator.dart';

/// 지도 기록을 떠난 뒤 이만큼 지나면 다시 잠근다(사용자 결정 2026-10-03 — Bitwarden 모바일 기본값과 같다).
/// 설정으로 내놓지 않는다.
const guidanceRelockAfter = Duration(minutes: 15);

/// 지도 기록 잠금이 풀려 있는지와 **떠난 시각**. 메모리에만 있다 — 앱을 완전히 종료하면 처음 한 번은 다시 묻는다.
///
/// 게이트보다 오래 살아야 한다(탭을 옮기면 중첩 셸과 게이트가 dispose된다). 그래서 autoDispose가 아닌
/// [guidanceUnlockProvider]에 두고, 화면을 다시 그리는 신호 없이 게이트가 필요할 때 읽는다.
///
/// 떠남 = 탭 이동(마지막 게이트가 떨어짐) · 앱이 `hidden`/`paused`. `inactive`(알림 센터·Face ID 창)는 떠남이 아니다.
class GuidanceUnlock extends ChangeNotifier {
  GuidanceUnlock({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  var _unlocked = false;
  DateTime? _leftAt;

  /// 붙어 있는 게이트 수. 테마가 바뀌면 새 게이트가 옛 게이트보다 먼저 붙는다 — 옛 게이트가 떨어질 때
  /// 떠남을 찍으면 탭에 머무는 동안 15분이 흘러 엉뚱하게 잠긴다.
  var _gates = 0;

  bool get isUnlocked => _unlocked;

  /// 인증이 진행 중이면 그 Future. 동시에 부르면 같은 것을 돌려줘 인증 창이 겹치지 않는다.
  Future<AuthOutcome>? _inFlight;

  /// 풀린 상태가 바뀔 때만 알린다.
  void _setUnlocked(bool value) {
    if (_unlocked == value) return;
    _unlocked = value;
    notifyListeners();
  }

  void markUnlocked() {
    _leftAt = null;
    _setUnlocked(true);
  }

  /// 기기 인증으로 푼다. 이미 풀렸으면 인증기를 부르지 않고, 진행 중이면 같은 Future를 돌려준다.
  /// 예상 밖 예외는 실패로 친다. `noCredentials`는 상태를 바꾸지 않고 그대로 돌려준다.
  Future<AuthOutcome> authenticate(DeviceAuthenticator auth, String reason) {
    if (_unlocked) return Future.value(AuthOutcome.success);
    return _inFlight ??= _run(auth, reason);
  }

  Future<AuthOutcome> _run(DeviceAuthenticator auth, String reason) async {
    var outcome = AuthOutcome.failed;
    try {
      outcome = await auth.authenticate(reason);
    } catch (_) {
      // 예상 밖 예외도 실패 — _inFlight가 남아 영구히 못 푸는 일이 없도록 아래에서 비운다.
    } finally {
      _inFlight = null;
    }
    if (outcome == AuthOutcome.success) markUnlocked();
    return outcome;
  }

  /// 풀린 상태에서 처음 떠난 시각만 남긴다(`hidden`과 `paused`가 연달아 와도, 탭을 옮긴 뒤 앱을 떠나도).
  void markLeft() {
    if (_unlocked) _leftAt ??= _clock();
  }

  /// 돌아왔다. 떠난 지 [guidanceRelockAfter]가 지났거나 시계가 뒤로 갔으면 잠그고, 아니면 떠난 시각만 지운다.
  void markBack() {
    final left = _leftAt;
    _leftAt = null;
    if (left == null) return;
    final away = _clock().difference(left);
    // 시계가 뒤로 갔으면(기기 시각을 돌려 재잠금을 피하려는 경우 포함) 만료로 친다.
    if (away.isNegative || away > guidanceRelockAfter) {
      _setUnlocked(false);
    }
  }

  /// 게이트가 붙었다(탭에 들어옴).
  void attach() {
    _gates++;
    markBack();
  }

  /// 게이트가 떨어졌다. 마지막 게이트일 때만 떠남이다.
  void detach() {
    if (_gates > 0) _gates--;
    if (_gates == 0) markLeft();
  }
}

final guidanceUnlockProvider = Provider<GuidanceUnlock>(
  (ref) => GuidanceUnlock(),
);

/// 풀림 여부를 화면이 지켜볼 수 있게 한 값. 상태의 주인은 [guidanceUnlockProvider]다.
final guidanceUnlockedProvider = Provider<bool>((ref) {
  final unlock = ref.watch(guidanceUnlockProvider);
  void onChange() => ref.invalidateSelf();
  unlock.addListener(onChange);
  ref.onDispose(() => unlock.removeListener(onChange));
  return unlock.isUnlocked;
});
