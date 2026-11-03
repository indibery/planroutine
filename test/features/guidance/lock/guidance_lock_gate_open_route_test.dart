import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_gate.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

class _FakeAuth implements DeviceAuthenticator {
  final outcomes = <AuthOutcome>[];
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    return outcomes.isEmpty ? AuthOutcome.failed : outcomes.removeAt(0);
  }
}

class _FakeSecure implements SecureWindow {
  @override
  Future<void> setSecure(bool on) async {}
}

/// 열린 화면(목록·새 기록)에서는 게이트가 묻지 않는다 — `requiresUnlock: false`.
void main() {
  late _FakeAuth auth;
  late ProviderContainer container;
  var now = DateTime(2026, 11, 3, 9);

  setUp(() {
    SystemSheetGuard.reset();
    now = DateTime(2026, 11, 3, 9);
    auth = _FakeAuth();
    container = ProviderContainer(
      overrides: [
        deviceAuthenticatorProvider.overrideWithValue(auth),
        secureWindowProvider.overrideWithValue(_FakeSecure()),
        guidanceUnlockProvider.overrideWith(
          (ref) => GuidanceUnlock(clock: () => now),
        ),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    SystemSheetGuard.reset();
  });

  var tapped = 0;
  Future<void> pump(
    WidgetTester tester, {
    required bool requiresUnlock,
    VoidCallback? onBack,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GuidanceLockGate(
            requiresUnlock: requiresUnlock,
            onBack: onBack,
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => tapped++,
                  child: const Text('아래'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void lifecycle(WidgetTester tester, AppLifecycleState s) =>
      tester.binding.handleAppLifecycleStateChanged(s);

  setUp(() => tapped = 0);

  testWidgets('열린 화면은 인증하지 않고 덮개도 없고 아래 버튼이 눌린다', (tester) async {
    await pump(tester, requiresUnlock: false);
    expect(auth.calls, 0);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    await tester.tap(find.text('아래'));
    expect(tapped, 1);
  });

  testWidgets('열린 채 떠났다 16분 뒤 돌아오면 조용히 잠기고 묻지 않는다', (tester) async {
    container.read(guidanceUnlockProvider).markUnlocked();
    await pump(tester, requiresUnlock: false);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 16));
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    expect(container.read(guidanceUnlockProvider).isUnlocked, isFalse);
  });

  testWidgets('false에서 true로 바뀌면 잠겨 있을 때 자동 인증하고 실패하면 덮개', (tester) async {
    await pump(tester, requiresUnlock: false);
    expect(auth.calls, 0);
    await pump(tester, requiresUnlock: true);
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
  });

  testWidgets('onBack이 있으면 덮개에 목록으로 버튼이 뜨고 누르면 불린다', (tester) async {
    var back = 0;
    await pump(tester, requiresUnlock: true, onBack: () => back++);
    expect(find.text(GuidanceStrings.backToList), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.backKey));
    expect(back, 1);
  });

  testWidgets('onBack이 없으면 목록으로 버튼이 없다', (tester) async {
    await pump(tester, requiresUnlock: true);
    expect(find.byKey(GuidanceLockGate.backKey), findsNothing);
  });
}
