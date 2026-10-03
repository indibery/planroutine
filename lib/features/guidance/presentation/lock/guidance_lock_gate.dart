import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'device_authenticator.dart';
import 'guidance_unlock.dart';
import 'secure_window.dart';

/// 지도 기록 탭 전체를 감싸는 잠금. 중첩 셸의 builder가 쓴다.
///
/// **한 번 풀면 지도 기록을 떠난 지 [guidanceRelockAfter](15분)까지 다시 묻지 않는다**(사용자 결정 2026-10-03).
/// 풀린 상태는 게이트가 아니라 [guidanceUnlockProvider]가 든다 — 탭을 옮기면 게이트는 dispose되지만 상태는 남는다.
/// 떠남은 탭 이동(dispose)과 `hidden`/`paused`뿐이고, `inactive`(알림 센터·Face ID 창)는 아무것도 하지 않는다.
///
/// **덮개는 화면을 덮기만 한다.** 아래 화면을 dispose하지 않으므로 잠금을 풀면 쓰던 글이
/// 그대로다. 잠긴 동안에는 아래 화면이 눌리지 않고(`IgnorePointer`) 스크린리더도
/// 읽지 않는다(`ExcludeSemantics`).
class GuidanceLockGate extends ConsumerStatefulWidget {
  const GuidanceLockGate({super.key, required this.child});

  final Widget child;

  static const coverKey = Key('guidance_lock_cover');
  static const veilKey = Key('guidance_lock_veil');
  static const unlockKey = Key('guidance_unlock');
  static const openWithoutLockKey = Key('guidance_open_without_lock');

  @override
  ConsumerState<GuidanceLockGate> createState() => _GuidanceLockGateState();
}

class _GuidanceLockGateState extends ConsumerState<GuidanceLockGate>
    with WidgetsBindingObserver {
  var _noCredentials = false;
  var _authing = false;

  /// 화면을 가리기만 하는 면(잠금 상태와 무관). 풀린 상태에서 `inactive`가 오면 켠다 —
  /// 15분이 지나 돌아오면 `resumed`에서야 만료를 아는데, 그때 덮개를 올리면 그려지기 전 몇 프레임
  /// 동안 기록이 보인다. `hidden`/`paused`에서는 프레임이 그려지지 않으므로 `inactive`에서 미리 가린다.
  var _veiled = false;

  // dispose에서 ref를 쓰지 않는다 — 둘 다 initState에서 읽어 둔다.
  late final SecureWindow _secure;
  late final GuidanceUnlock _unlock;

  bool get _unlocked => _unlock.isUnlocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secure = ref.read(secureWindowProvider);
    _secure.setSecure(true);
    _unlock = ref.read(guidanceUnlockProvider);
    _unlock.attach();
    // 15분 안에 돌아왔으면 덮개 없이 연다. 처음 들어왔거나 만료됐으면 덮개 + 자동 인증.
    if (!_unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlock.detach();
    _secure.setSecure(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _unlock.markLeft();
      case AppLifecycleState.resumed:
        // 풀려 있다가 만료된 경우에만 묻는다. 이미 잠긴 채(인증 취소·실패)였으면 묻지 않는다 —
        // 그러지 않으면 Face ID 창을 닫을 때마다 다시 떠 무한 반복된다.
        final was = _unlocked;
        _unlock.markBack();
        if (!was || _unlocked) {
          // 15분 안에 돌아왔다(또는 이미 잠긴 채였다) — 가림 면만 걷는다.
          if (_veiled) setState(() => _veiled = false);
          return;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _veiled = false);
        _authenticate();
      case AppLifecycleState.inactive:
        // 잠금 상태도 떠난 시각도 건드리지 않는다(inactive는 떠남이 아니다) — 보이는 것만 가린다.
        if (_unlocked && !_veiled) setState(() => _veiled = true);
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _authenticate() async {
    if (_authing || _unlocked || !mounted) return;
    _authing = true;
    var outcome = AuthOutcome.failed;
    try {
      outcome = await ref
          .read(deviceAuthenticatorProvider)
          .authenticate(GuidanceStrings.unlockReason);
    } catch (_) {
      // 예상 밖 예외도 실패로 취급한다 — `_authing`이 true로 남으면 잠금 해제 버튼과
      // 복귀 재인증이 모두 조용히 무시되어 영구히 못 푼다.
    } finally {
      _authing = false;
    }
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case AuthOutcome.success:
          _unlock.markUnlocked();
          _noCredentials = false;
        case AuthOutcome.noCredentials:
          _noCredentials = true;
        case AuthOutcome.failed:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = !_unlocked;
    final hidden = locked || _veiled;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: hidden,
          child: IgnorePointer(ignoring: hidden, child: widget.child),
        ),
        if (!locked && _veiled) const _Veil(key: GuidanceLockGate.veilKey),
        if (locked)
          _LockCover(
            key: GuidanceLockGate.coverKey,
            noCredentials: _noCredentials,
            onUnlock: _authenticate,
            onOpenAnyway: () => setState(_unlock.markUnlocked),
          ),
      ],
    );
  }
}

/// 문구 없는 불투명 면 — iOS `SceneDelegate`의 앱 전환기 가림막과 같은 모양(배경색 + 가운데 자물쇠).
/// 잠긴 덮개(문구·버튼)와 구별한다: 이것은 잠금이 아니라 잠깐 가리는 것이다.
class _Veil extends StatelessWidget {
  const _Veil({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Center(child: Icon(Icons.lock, size: 40, color: AppColors.sub)),
  );
}

class _LockCover extends StatelessWidget {
  const _LockCover({
    super.key,
    required this.noCredentials,
    required this.onUnlock,
    required this.onOpenAnyway,
  });

  final bool noCredentials;
  final VoidCallback onUnlock;
  final VoidCallback onOpenAnyway;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppColors.gold),
              const SizedBox(height: AppSizes.spacing16),
              Text(
                noCredentials
                    ? GuidanceStrings.noCredentialsTitle
                    : GuidanceStrings.lockedTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                noCredentials
                    ? GuidanceStrings.noCredentialsBody
                    : GuidanceStrings.lockedBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(color: AppColors.sub),
              ),
              const SizedBox(height: AppSizes.spacing24),
              FilledButton.icon(
                key: GuidanceLockGate.unlockKey,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                ),
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text(GuidanceStrings.unlock),
              ),
              if (noCredentials) ...[
                const SizedBox(height: AppSizes.spacing8),
                TextButton(
                  key: GuidanceLockGate.openWithoutLockKey,
                  onPressed: onOpenAnyway,
                  child: const Text(GuidanceStrings.openWithoutLock),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
