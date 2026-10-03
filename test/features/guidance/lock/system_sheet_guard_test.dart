import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

void main() {
  var now = DateTime(2026, 10, 3, 9);
  setUp(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = () => now;
    // 플랫폼은 각 테스트가 정한다 — 테스트 호스트(macOS)의 실제 값에 기대지 않는다.
    SystemSheetGuard.isIOS = () => false;
  });
  tearDown(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = DateTime.now;
    SystemSheetGuard.isIOS = SystemSheetGuard.platformIsIOS;
  });

  // 기대값을 바꿨다(2026-10-03 최종 리뷰): 예전에는 "시스템 창 중이면 백그라운드도 무시"를
  // 플랫폼 구분 없이 고정했는데, 그러면 고르기 창을 띄운 채 홈으로 나가도 잠기지 않았다.
  // 지금 이 동작은 **Android 한정**이다(고르기 창이 별도 Activity라 paused가 정상으로 온다) —
  // 대신 오래 떠나 있었으면 돌아올 때 잠근다(아래 테스트들).
  test('Android: 시스템 창이 떠 있는 동안에는 비활성·백그라운드를 모두 무시한다', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isTrue);
    done.complete();
    await running;
  });

  test('iOS: 시스템 창이 떠 있어도 백그라운드는 잠근다(비활성만 무시)', () async {
    SystemSheetGuard.isIOS = () => true;
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.hidden), isFalse);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
    done.complete();
    await running;
  });

  test('Android: 시스템 창 중 백그라운드에서 60초 넘게 있다 돌아오면 잠그라는 신호가 한 번 난다', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    SystemSheetGuard.shouldIgnore(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 90));
    done.complete();
    await running;
    expect(SystemSheetGuard.takeLongAbsence(), isTrue);
    expect(
      SystemSheetGuard.takeLongAbsence(),
      isFalse,
      reason: '한 번 가져가면 사라진다',
    );
  });

  test('Android: 60초 안에 돌아오면 잠그라는 신호가 없다', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    SystemSheetGuard.shouldIgnore(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    expect(SystemSheetGuard.takeLongAbsence(), isFalse);
    done.complete();
    await running;
  });

  test('Android: 처음 백그라운드가 된 시각부터 잰다(paused가 여러 번 와도)', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    SystemSheetGuard.shouldIgnore(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 50));
    SystemSheetGuard.shouldIgnore(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 20));
    expect(SystemSheetGuard.takeLongAbsence(), isTrue);
    done.complete();
    await running;
  });

  test('끝난 직후 잠깐은 비활성만 무시하고 백그라운드는 잠근다', () async {
    await SystemSheetGuard.run(() async {});
    now = now.add(const Duration(milliseconds: 300));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    // 복귀 전이(paused→hidden→inactive→resumed)의 중간 단계도 같이 흘려보낸다.
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.hidden), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isFalse);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.hidden), isFalse);
  });

  test('작업이 실패해도 가드는 풀린다', () async {
    await expectLater(
      SystemSheetGuard.run(() async => throw StateError('x')),
      throwsStateError,
    );
    now = now.add(const Duration(seconds: 5));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
  });
}
