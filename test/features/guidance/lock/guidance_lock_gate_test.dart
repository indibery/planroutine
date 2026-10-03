import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_lock_gate.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';
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

class ThrowingOnceAuth implements DeviceAuthenticator {
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    if (calls == 1) throw StateError('예상 밖 예외');
    return AuthOutcome.success;
  }
}

class FakeSecure implements SecureWindow {
  final log = <bool>[];
  @override
  Future<void> setSecure(bool on) async => log.add(on);
}

/// 15분 규칙(사용자 결정 2026-10-03): 한 번 풀면 지도 기록을 떠난 지 [guidanceRelockAfter]까지
/// 다시 묻지 않는다. 떠남 = 탭 이동(게이트 dispose) · `hidden`/`paused`. `inactive`는 떠남이 아니다.
void main() {
  late FakeAuth auth;
  late FakeSecure secure;
  late ProviderContainer container;

  final start = DateTime(2026, 10, 3, 9);
  var now = start;

  const within = Duration(minutes: 10);
  const beyond = Duration(minutes: 16);

  setUp(() {
    SystemSheetGuard.reset();
    now = start;
    auth = FakeAuth();
    secure = FakeSecure();
    // 잠금 상태는 게이트보다 오래 산다 — 테스트도 한 컨테이너를 여러 번의 마운트에 걸쳐 쓴다.
    container = ProviderContainer(
      overrides: [
        deviceAuthenticatorProvider.overrideWithValue(auth),
        secureWindowProvider.overrideWithValue(secure),
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

  /// [show]를 false로 바꾸면 게이트가 사라진다(다른 탭으로 `go`해 중첩 셸이 dispose되는 것).
  Future<void> pump(
    WidgetTester tester, {
    Widget? child,
    bool show = true,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: show
              ? GuidanceLockGate(
                  child:
                      child ??
                      const Scaffold(body: TextField(key: Key('field'))),
                )
              : const SizedBox(),
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
      child: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => tapped = true,
            child: const Text('아래'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('아래'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  // 기대를 바꿨다(15분 규칙, 2026-10-03): 예전에는 앱을 떠나기만 해도 잠갔다.
  // 지금은 떠난 지 15분이 지나야 돌아올 때 잠근다 — 16분을 흘려 같은 의도(풀어도 쓰던 글이 남는다)를 본다.
  testWidgets('앱을 떠난 지 15분이 지나면 잠기고, 다시 풀면 쓰던 글이 그대로다', (tester) async {
    auth.outcomes.addAll([AuthOutcome.success, AuthOutcome.success]);
    await pump(tester);
    await tester.enterText(find.byKey(const Key('field')), '쓰던 글');
    leave(tester);
    now = now.add(beyond);
    comeBack(tester);
    await tester.pumpAndSettle();
    expect(auth.calls, 2, reason: '돌아오면 자동으로 다시 묻는다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    expect(find.text('쓰던 글'), findsOneWidget);
  });

  // 의도는 그대로, 근거가 바뀌었다(15분 규칙): 시스템 창 중의 백그라운드도 이제 "떠남"으로 찍히지만
  // 15분 안에 돌아오므로 다시 묻지 않는다. 게이트는 더 이상 SystemSheetGuard를 보지 않는다.
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
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('인증을 취소한 뒤 돌아와도 다시 묻지 않는다(무한 반복 방지)', (tester) async {
    auth.outcomes.add(AuthOutcome.failed);
    await pump(tester);
    // Face ID 창이 뜨고 닫히며 오는 inactive → resumed — inactive는 떠남이 아니다
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
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

  testWidgets('인증기가 예상 밖 예외를 던져도 덮개는 남고 다시 시도할 수 있다', (tester) async {
    final throwing = ThrowingOnceAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(throwing),
          secureWindowProvider.overrideWithValue(secure),
        ],
        child: const MaterialApp(
          home: GuidanceLockGate(child: Scaffold(body: SizedBox())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(throwing.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
    await tester.tap(find.byKey(GuidanceLockGate.unlockKey));
    await tester.pumpAndSettle();
    expect(throwing.calls, 2, reason: '_authing이 풀려 두 번째 시도가 일어난다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  // 바꿨다(15분 규칙): 예전 'iOS: 고르기 창을 띄운 채 앱을 떠나면 잠근다'. 이제 플랫폼 구분이 없고
  // 떠난 시간이 정한다 — 고르기 창을 띄운 채 홈으로 나가 15분이 지나면 돌아올 때 묻는다.
  testWidgets('고르기 창을 띄운 채 떠나 15분이 지나면 돌아올 때 다시 묻는다', (tester) async {
    // 두 번째 인증은 실패시킨다 — 덮개가 남으면 돌아올 때 잠갔다는 뜻이다.
    auth.outcomes.addAll([AuthOutcome.success, AuthOutcome.failed]);
    await pump(tester);
    final picker = Completer<void>();
    final running = SystemSheetGuard.run(() => picker.future);
    leave(tester);
    now = now.add(beyond);
    comeBack(tester);
    picker.complete();
    await running;
    await tester.pumpAndSettle();
    expect(auth.calls, 2, reason: '돌아오면 다시 묻는다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsOneWidget);
  });

  Future<void> pickerAway(WidgetTester tester, Duration away) async {
    auth.outcomes.addAll([AuthOutcome.success, AuthOutcome.success]);
    await pump(tester);
    final picker = Completer<void>();
    final running = SystemSheetGuard.run(() => picker.future);
    leave(tester); // 고르기 창(Android는 별도 Activity)이 뜨며 paused
    now = now.add(away);
    comeBack(tester);
    picker.complete();
    await running;
    await tester.pumpAndSettle();
  }

  // 바꿨다(15분 규칙): 예전 Android 60초 규칙의 '30초 만에 돌아오면 잠그지 않는다'.
  testWidgets('고르기 창 중 10분 만에 돌아오면 다시 묻지 않는다', (tester) async {
    await pickerAway(tester, within);
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  // 바꿨다(15분 규칙): 예전 Android 60초 규칙의 '90초 떠나 있다 돌아오면 잠근다'.
  testWidgets('고르기 창 중 16분 떠나 있다 돌아오면 다시 묻고, 성공하면 열린다', (tester) async {
    await pickerAway(tester, beyond);
    expect(auth.calls, 2, reason: '돌아온 resumed에서 재인증');
    expect(
      find.byKey(GuidanceLockGate.coverKey),
      findsNothing,
      reason: '재인증이 성공해 다시 열린다',
    );
  });

  // 바꿨다(15분 규칙): 예전 'Android: 오래 떠났다 돌아왔는데 재인증이 실패하면 덮개가 남는다'.
  // 같은 실패 경로는 위 고르기 창 테스트가 보므로, 여기서는 시스템 창 없이 그냥 앱을 떠난 경우를 본다.
  testWidgets('앱을 떠났다 10분 안에 돌아오면 열린 채다(추가 인증 없음)', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    leave(tester);
    now = now.add(within);
    comeBack(tester);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('탭을 옮겼다가 10분 안에 돌아오면 묻지 않고 열린다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    await pump(tester, show: false);
    now = now.add(within);
    await pump(tester);
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('탭을 옮긴 지 15분이 지나 돌아오면 덮개와 자동 인증', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    await pump(tester, show: false);
    now = now.add(beyond);
    await pump(tester);
    expect(auth.calls, 2);
    expect(
      find.byKey(GuidanceLockGate.coverKey),
      findsOneWidget,
      reason: '두 번째 인증은 실패',
    );
  });

  testWidgets('떠난 시각은 탭을 옮긴 때다 — 다른 탭에서 앱을 떠났다 와도 다시 찍지 않는다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    await pump(tester, show: false);
    now = now.add(within);
    leave(tester);
    comeBack(tester);
    now = now.add(within); // 탭을 옮긴 지 20분
    await pump(tester);
    expect(auth.calls, 2);
  });

  testWidgets('알림 센터처럼 inactive만 오가면 오래 있어도 아무 변화 없다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    await pump(tester);
    lifecycle(tester, AppLifecycleState.inactive);
    now = now.add(beyond);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  testWidgets('잠금 없이 열기로 연 것도 같은 15분 규칙을 따른다', (tester) async {
    auth.outcomes.add(AuthOutcome.noCredentials);
    await pump(tester);
    await tester.tap(find.byKey(GuidanceLockGate.openWithoutLockKey));
    await tester.pumpAndSettle();
    await pump(tester, show: false);
    now = now.add(within);
    await pump(tester);
    expect(auth.calls, 1, reason: '10분 안이면 묻지 않는다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
    await pump(tester, show: false);
    now = now.add(beyond);
    auth.outcomes.add(AuthOutcome.noCredentials);
    await pump(tester);
    expect(auth.calls, 2, reason: '15분이 지나면 다시 묻는다');
    expect(find.text(GuidanceStrings.noCredentialsTitle), findsOneWidget);
  });

  // 테마가 바뀌면 app.dart가 하위를 재생성한다 — 새 게이트의 initState가 옛 게이트의 dispose보다 먼저다.
  // 옛 게이트의 dispose가 "떠남"을 찍으면, 탭에 계속 있었는데도 그 시각부터 15분이 흘러 엉뚱하게 잠긴다.
  testWidgets('테마 재생성으로 게이트가 바뀌어도 떠남으로 치지 않는다', (tester) async {
    auth.outcomes.add(AuthOutcome.success);
    Future<void> keyed(int k) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: KeyedSubtree(
              key: ValueKey(k),
              child: const GuidanceLockGate(child: Scaffold(body: SizedBox())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await keyed(1);
    await keyed(2);
    expect(auth.calls, 1, reason: '재생성된 게이트는 다시 묻지 않는다');
    now = now.add(beyond); // 탭에 그대로 머문 채 16분
    leave(tester);
    comeBack(tester);
    await tester.pumpAndSettle();
    expect(auth.calls, 1, reason: '방금 떠났다 돌아온 것뿐이다');
    expect(find.byKey(GuidanceLockGate.coverKey), findsNothing);
  });

  test('덮개 문구가 다시 잠기는 시간(분)을 말한다', () {
    expect(
      GuidanceStrings.lockedBody,
      contains('${guidanceRelockAfter.inMinutes}분'),
    );
  });
}
