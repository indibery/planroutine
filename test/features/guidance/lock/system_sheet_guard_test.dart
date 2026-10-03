import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('시스템 창이 떠 있는 동안에는 비활성·백그라운드를 모두 무시한다', () async {
    final done = Completer<void>();
    final running = SystemSheetGuard.run(() => done.future);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.inactive), isTrue);
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isTrue);
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
    await expectLater(SystemSheetGuard.run(() async => throw StateError('x')), throwsStateError);
    now = now.add(const Duration(seconds: 5));
    expect(SystemSheetGuard.shouldIgnore(AppLifecycleState.paused), isFalse);
  });
}
