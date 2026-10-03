import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_gate.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

class FakeAuth implements DeviceAuthenticator {
  final outcomes = <AuthOutcome>[];
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    return outcomes.isEmpty ? AuthOutcome.failed : outcomes.removeAt(0);
  }
}

class FakeSecure implements SecureWindow {
  final log = <bool>[];
  @override
  Future<void> setSecure(bool on) async => log.add(on);
}

void main() {
  late FakeAuth auth;
  late FakeSecure secure;

  setUp(() {
    SystemSheetGuard.reset();
    auth = FakeAuth();
    secure = FakeSecure();
  });

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(auth),
          secureWindowProvider.overrideWithValue(secure),
        ],
        child: MaterialApp(
          home: GuidanceLockGate(
            child: child ??
                const Scaffold(body: TextField(key: Key('field'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void lifecycle(WidgetTester tester, AppLifecycleState s) =>
      tester.binding.handleAppLifecycleStateChanged(s);

  // Flutter는 상태 전이 순서를 assert로 검사한다 — 실제 기기와 같은 순서로 보낸다.
  // 떠날 때: resumed → inactive → hidden → paused
  void leave(WidgetTester tester) {
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.paused);
  }

  // 돌아올 때: paused → hidden → inactive → resumed
  void comeBack(WidgetTester tester) {
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
  }

  testWidgets('들어오면 자동으로 인증하고, 성공하면 덮개가 걷힌다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('실패하면 덮개가 남고 잠금 해제 버튼으로 다시 시도한다', (tester) async {
    auth.outcomes.addAll([AuthOutcome.failed, AuthOutcome.success]);
    await pump(tester);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
    expect(find.text(GuidanceStrings.lockedTitle), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.unlockKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('잠긴 동안 아래 화면은 눌리지 않는다', (tester) async {
    var tapped = false;
    await pump(
      tester,
      child: Scaffold(body: Center(child: TextButton(onPressed: () => tapped = true, child: const Text('아래')))),
    );
    await tester.tap(find.text('아래'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('앱을 떠나면 잠기고, 다시 풀면 쓰던 글이 그대로다', (tester) async {
    auth.outcomes.addAll([AuthOutcome.success, AuthOutcome.success]);
    await pump(tester);
    await tester.enterText(find.byKey(const Key('field')), '쓰던 글');
    // 방금 끝난 인증의 여유 시간(grace)과 무관하게 떠남이 잠그는지 본다.
    SystemSheetGuard.reset();
    leave(tester);
    await tester.pump();
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
    comeBack(tester);
    await tester.pumpAndSettle();
    expect(auth.calls, 2, reason: '돌아오면 자동으로 다시 묻는다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    expect(find.text('쓰던 글'), findsOneWidget);
  });

  testWidgets('시스템 창(사진 고르기 등) 동안의 비활성·백그라운드는 잠그지 않는다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    final picker = Completer<void>();
    final running = SystemSheetGuard.run(() => picker.future);
    leave(tester);
    comeBack(tester);
    await tester.pump();
    picker.complete();
    await running;
    await tester.pump();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('인증을 취소한 뒤 돌아와도 다시 묻지 않는다(무한 반복 방지)', (tester) async {
    auth.outcomes.add(AuthOutcome.failed);
    await pump(tester);
    // Face ID 창이 뜨고 닫히며 오는 inactive → resumed — 가드가 흘려보내므로 다시 잠금 사유가 아니다
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
  });

  testWidgets('기기 암호가 없으면 안내하고 잠금 없이 열 수 있다', (tester) async {
    auth.outcomes.add(AuthOutcome.noCredentials);
    await pump(tester);
    expect(find.text(GuidanceStrings.noCredentialsTitle), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.openWithoutLockKey));
    await tester.pumpAndSettle();
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('보이는 동안 FLAG_SECURE를 켜고 떠나면 끈다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    expect(secure.log, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(secure.log, [true, false]);
  });
}
