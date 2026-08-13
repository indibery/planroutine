import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/presentation/widgets/today_progress_ring.dart';

void main() {
  Future<void> pumpRing(WidgetTester tester, int done, int total) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TodayProgressRing(done: done, total: total),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('진행도 링', () {
    testWidgets('완료/전체 건수가 링 안에 표시된다', (tester) async {
      await pumpRing(tester, 1, 3);

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('하나도 완료하지 않은 상태도 표시된다', (tester) async {
      await pumpRing(tester, 0, 2);

      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('모두 완료한 상태가 표시된다', (tester) async {
      await pumpRing(tester, 4, 4);

      expect(find.text('4/4'), findsOneWidget);
    });
  });
}
