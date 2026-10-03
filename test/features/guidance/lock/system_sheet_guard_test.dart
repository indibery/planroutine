import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';
import 'package:planroutine/features/guidance/presentation/lock/system_sheet_guard.dart';

void main() {
  var now = DateTime(2026, 10, 3, 9);
  setUp(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = () => now;
  });
  tearDown(() {
    SystemSheetGuard.reset();
    SystemSheetGuard.clock = DateTime.now;
  });

  // 기대값을 바꿨다(15분 규칙, 2026-10-03): 예전에는 Android에서 가드 중 백그라운드(paused)까지
  // 흘려보내고 60초 규칙으로 잠갔다. 게이트가 가드를 보지 않게 되면서 그 분기의 유일한 이유가
  // 사라졌다 — 이제 남은 사용처(녹음 화면)에게 가드는 플랫폼 구분 없이 비활성만 흘려보낸다.
  test('시스템 창이 떠 있는 동안 비활성은 무시한다(플랫폼 구분 없음)', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    done.complete();
    await running;
  });

  // 기대값을 바꿨다(15분 규칙): 예전에는 iOS만 이랬다. 이제 모든 플랫폼이 같다.
  test('시스템 창이 떠 있어도 백그라운드는 떠난 것이다(비활성만 무시)', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.hidden), isFalse);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
    done.complete();
    await running;
  });

  // 아래 셋은 예전 Android 60초 규칙(`takeLongAbsence`) 테스트였다. 그 규칙은 걷어냈고, 같은 상황
  // (고르기 창을 띄운 채 백그라운드로 갔다 돌아옴)을 이제 15분 규칙이 판단한다 — 같은 장면을 새 규칙으로 본다.
  test('고르기 창 중 백그라운드로 가 15분을 넘겨 돌아오면 다시 잠긴다', () async {
    final unlock = GuidanceUnlock(clock: () => now)..markUnlocked();
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
    unlock.markLeft();
    now = now.add(const Duration(minutes: 16));
    done.complete();
    await running;
    unlock.markBack();
    expect(unlock.isUnlocked, isFalse);
  });

  test('고르기 창 중 15분 안에 돌아오면 풀린 채다', () async {
    final unlock = GuidanceUnlock(clock: () => now)..markUnlocked();
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    unlock.markLeft();
    now = now.add(const Duration(minutes: 14));
    done.complete();
    await running;
    unlock.markBack();
    expect(unlock.isUnlocked, isTrue);
    // 돌아오면 떠난 시각이 지워진다 — 다음 떠남은 그때부터 다시 잰다.
    now = now.add(const Duration(minutes: 14));
    unlock.markLeft();
    now = now.add(const Duration(minutes: 14));
    unlock.markBack();
    expect(unlock.isUnlocked, isTrue);
  });

  test('처음 떠난 시각부터 잰다(hidden·paused가 여러 번 와도)', () async {
    final unlock = GuidanceUnlock(clock: () => now)..markUnlocked();
    unlock.markLeft();
    now = now.add(const Duration(minutes: 10));
    unlock.markLeft();
    now = now.add(const Duration(minutes: 6));
    unlock.markBack();
    expect(unlock.isUnlocked, isFalse);
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
