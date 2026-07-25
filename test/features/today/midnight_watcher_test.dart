import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/presentation/providers/today_providers.dart';
import 'package:planroutine/features/today/presentation/widgets/midnight_watcher.dart';

void main() {
  /// 백그라운드 → 복귀 전체 사이클. 라이프사이클 상태 전이는 순서를 지켜야 한다.
  void resumeApp(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// 기준일이 갱신됐는지 값으로 확인한다.
  ///
  /// 무효화되면 provider가 다시 계산돼 새 `DateTime.now()`가 나오고, 무효화되지
  /// 않으면 캐시된 같은 값이 그대로 나온다. 리스너 알림 타이밍에 의존하지 않는다.
  ({ProviderContainer container, DateTime Function() read}) watchReference() {
    final container = ProviderContainer();
    return (
      container: container,
      read: () => container.read(todayReferenceProvider),
    );
  }

  Future<void> pumpWatcher(
    WidgetTester tester,
    ProviderContainer container,
    DateTime Function() clock,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MidnightWatcher(clock: clock, child: const SizedBox()),
      ),
    );
    await tester.pump();
  }

  group('자정 넘김 대응', () {
    testWidgets('앱 복귀 시 날짜가 바뀌었으면 오늘 기준일을 갱신한다', (tester) async {
      var now = DateTime(2026, 7, 25, 23, 58);
      final w = watchReference();
      addTearDown(w.container.dispose);
      await pumpWatcher(tester, w.container, () => now);
      final before = w.read();

      now = DateTime(2026, 7, 26, 0, 3); // 자정 넘김
      resumeApp(tester);
      await tester.pump();

      expect(w.read(), isNot(before));
    });

    testWidgets('같은 날 복귀면 갱신하지 않는다 (불필요한 재조회 방지)', (tester) async {
      var now = DateTime(2026, 7, 25, 9, 0);
      final w = watchReference();
      addTearDown(w.container.dispose);
      await pumpWatcher(tester, w.container, () => now);
      final before = w.read();

      now = DateTime(2026, 7, 25, 14, 30); // 같은 날 오후
      resumeApp(tester);
      await tester.pump();

      expect(w.read(), before);
    });

    testWidgets('한 번 갱신한 뒤 같은 날 다시 복귀하면 추가 갱신이 없다', (tester) async {
      var now = DateTime(2026, 7, 25, 23, 58);
      final w = watchReference();
      addTearDown(w.container.dispose);
      await pumpWatcher(tester, w.container, () => now);

      now = DateTime(2026, 7, 26, 0, 3);
      resumeApp(tester);
      await tester.pump();
      final afterFirst = w.read();

      now = DateTime(2026, 7, 26, 8, 10); // 같은 날 아침에 또 복귀
      resumeApp(tester);
      await tester.pump();

      expect(w.read(), afterFirst);
    });

    testWidgets('복귀가 아닌 상태 전이만으로는 갱신하지 않는다', (tester) async {
      var now = DateTime(2026, 7, 25, 23, 58);
      final w = watchReference();
      addTearDown(w.container.dispose);
      await pumpWatcher(tester, w.container, () => now);
      final before = w.read();

      now = DateTime(2026, 7, 26, 0, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(w.read(), before);
    });

    testWidgets('자식 위젯을 그대로 통과시킨다', (tester) async {
      final w = watchReference();
      addTearDown(w.container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: w.container,
          child: MidnightWatcher(
            clock: () => DateTime(2026, 7, 25),
            child: const MaterialApp(home: Text('본문')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('본문'), findsOneWidget);
    });
  });
}
