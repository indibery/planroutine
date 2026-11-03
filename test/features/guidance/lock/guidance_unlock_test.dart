import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/device_authenticator.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';

class _Auth implements DeviceAuthenticator {
  _Auth(this.run);
  final Future<AuthOutcome> Function(int call) run;
  var calls = 0;
  @override
  Future<AuthOutcome> authenticate(String reason) {
    calls++;
    return run(calls);
  }
}

void main() {
  late DateTime now;
  late GuidanceUnlock unlock;
  late int notified;

  setUp(() {
    now = DateTime(2026, 11, 3, 9);
    unlock = GuidanceUnlock(clock: () => now);
    notified = 0;
    unlock.addListener(() => notified++);
  });

  test('풀릴 때만 알린다 — 이미 풀린 상태에서 다시 풀어도 알리지 않는다', () {
    unlock.markUnlocked();
    expect(notified, 1);
    unlock.markUnlocked();
    expect(notified, 1);
  });

  test('떠난 지 15분이 지나 만료되면 알린다', () {
    unlock.markUnlocked();
    notified = 0;
    unlock.markLeft();
    now = now.add(guidanceRelockAfter + const Duration(minutes: 1));
    unlock.markBack();
    expect(unlock.isUnlocked, isFalse);
    expect(notified, 1);
  });

  test('authenticate: 동시에 두 번 불러도 인증기는 한 번, 같은 결과', () async {
    final gate = Completer<AuthOutcome>();
    final auth = _Auth((_) => gate.future);
    final a = unlock.authenticate(auth, '이유');
    final b = unlock.authenticate(auth, '이유');
    gate.complete(AuthOutcome.success);
    expect(await a, AuthOutcome.success);
    expect(await b, AuthOutcome.success);
    expect(auth.calls, 1);
    expect(unlock.isUnlocked, isTrue);
  });

  test('authenticate: 인증기가 예외를 던지면 failed, 다음엔 다시 인증기를 부른다', () async {
    final auth = _Auth((n) async {
      if (n == 1) throw StateError('예상 밖');
      return AuthOutcome.success;
    });
    expect(await unlock.authenticate(auth, '이유'), AuthOutcome.failed);
    expect(unlock.isUnlocked, isFalse);
    expect(await unlock.authenticate(auth, '이유'), AuthOutcome.success);
    expect(auth.calls, 2);
  });

  test('authenticate: 이미 풀려 있으면 인증기를 부르지 않고 success', () async {
    unlock.markUnlocked();
    final auth = _Auth((_) async => AuthOutcome.failed);
    expect(await unlock.authenticate(auth, '이유'), AuthOutcome.success);
    expect(auth.calls, 0);
  });

  test('authenticate: noCredentials는 상태를 바꾸지 않고 그대로 돌려준다', () async {
    final auth = _Auth((_) async => AuthOutcome.noCredentials);
    expect(await unlock.authenticate(auth, '이유'), AuthOutcome.noCredentials);
    expect(unlock.isUnlocked, isFalse);
    expect(notified, 0);
  });

  test('guidanceUnlockedProvider가 풀림을 따라 true로 바뀐다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final values = <bool>[];
    container.listen(guidanceUnlockedProvider, (_, v) => values.add(v));
    expect(container.read(guidanceUnlockedProvider), isFalse);
    container.read(guidanceUnlockProvider).markUnlocked();
    expect(container.read(guidanceUnlockedProvider), isTrue);
    expect(values, [true]);
  });
}
