import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'device_authenticator.dart';
import 'secure_window.dart';
import 'system_sheet_guard.dart';

/// 지도 기록 탭 전체를 감싸는 잠금. 중첩 셸의 builder가 쓴다 — 다른 탭으로 `go`하면
/// 셸과 함께 dispose되어 다음에 들어올 때 다시 잠겨 있다.
///
/// **덮개는 화면을 덮기만 한다.** 아래 화면을 dispose하지 않으므로 잠금을 풀면 쓰던 글이
/// 그대로다. 잠긴 동안에는 아래 화면이 눌리지 않고(`IgnorePointer`) 스크린리더도
/// 읽지 않는다(`ExcludeSemantics`).
class GuidanceLockGate extends ConsumerStatefulWidget {
  const GuidanceLockGate({super.key, required this.child});

  final Widget child;

  static const coverKey = Key('guidance_lock_cover');
  static const unlockKey = Key('guidance_unlock');
  static const openWithoutLockKey = Key('guidance_open_without_lock');

  @override
  ConsumerState<GuidanceLockGate> createState() => _GuidanceLockGateState();
}

class _GuidanceLockGateState extends ConsumerState<GuidanceLockGate> with WidgetsBindingObserver {
  var _unlocked = false;
  var _noCredentials = false;
  var _authing = false;

  /// 생명주기 때문에 잠겼다 — 돌아오면(resumed) 자동으로 다시 묻는다.
  /// 인증 창을 취소한 뒤의 resumed에서는 묻지 않는다(그 비활성은 가드가 흘려보냈으므로 이 값이 안 켜진다).
  var _askOnResume = false;

  late final SecureWindow _secure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secure = ref.read(secureWindowProvider);
    _secure.setSecure(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secure.setSecure(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_askOnResume) {
        _askOnResume = false;
        _authenticate();
      }
      return;
    }
    if (state == AppLifecycleState.detached) return;
    if (SystemSheetGuard.shouldIgnore(state)) return;
    _askOnResume = true;
    if (_unlocked) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _unlocked = false);
    }
  }

  Future<void> _authenticate() async {
    if (_authing || _unlocked || !mounted) return;
    _authing = true;
    final outcome = await SystemSheetGuard.run(
      () => ref.read(deviceAuthenticatorProvider).authenticate(GuidanceStrings.unlockReason),
    );
    _authing = false;
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case AuthOutcome.success:
          _unlocked = true;
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
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: IgnorePointer(ignoring: locked, child: widget.child),
        ),
        if (locked)
          _LockCover(
            key: GuidanceLockGate.coverKey,
            noCredentials: _noCredentials,
            onUnlock: _authenticate,
            onOpenAnyway: () => setState(() => _unlocked = true),
          ),
      ],
    );
  }
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
                noCredentials ? GuidanceStrings.noCredentialsTitle : GuidanceStrings.lockedTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSizes.spacing8),
              Text(
                noCredentials ? GuidanceStrings.noCredentialsBody : GuidanceStrings.lockedBody,
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
