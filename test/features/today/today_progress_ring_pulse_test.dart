import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/features/today/presentation/widgets/today_progress_ring.dart';

/// 스펙의 완주 연출: 링 골드 펄스 + **heavyImpact 햅틱** + 숫자 카운트업.
///
/// 개별 체크는 mediumImpact(행), 완주는 heavyImpact(화면)로 보상 강도를 나눈 설계라
/// 완주 햅틱이 빠지면 마지막 한 건도 다른 건과 똑같이 느껴진다.
void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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
  }

  String ringText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(TodayProgressRing),
          matching: find.byType(Text),
        ),
      )
      .first
      .data!;

  group('완주 연출', () {
    testWidgets('마지막 한 건을 채우면 heavyImpact 햅틱이 온다', (tester) async {
      await pumpRing(tester, 1, 2);
      await tester.pumpAndSettle();
      haptics.clear();

      await pumpRing(tester, 2, 2); // 완주
      await tester.pumpAndSettle();

      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    });

    testWidgets('아직 남았으면 완주 햅틱이 오지 않는다', (tester) async {
      await pumpRing(tester, 0, 3);
      await tester.pumpAndSettle();
      haptics.clear();

      await pumpRing(tester, 1, 3);
      await tester.pumpAndSettle();

      expect(haptics, isEmpty);
    });

    testWidgets('이미 완주한 상태로 다시 그려도 햅틱이 반복되지 않는다', (tester) async {
      await pumpRing(tester, 2, 2);
      await tester.pumpAndSettle();
      haptics.clear();

      await pumpRing(tester, 2, 2);
      await tester.pumpAndSettle();

      expect(haptics, isEmpty);
    });
  });

  group('숫자 카운트업', () {
    testWidgets('숫자가 즉시 튀지 않고 링과 함께 올라간다', (tester) async {
      await pumpRing(tester, 0, 4);
      await tester.pumpAndSettle();
      expect(ringText(tester), '0/4');

      await pumpRing(tester, 4, 4);
      // 충전 중간(550ms의 절반)에는 아직 최종값이 아니어야 한다.
      await tester.pump(const Duration(milliseconds: 120));
      expect(ringText(tester), isNot('4/4'));

      await tester.pumpAndSettle();
      expect(ringText(tester), '4/4');
    });
  });
}
