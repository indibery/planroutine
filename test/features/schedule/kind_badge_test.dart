import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, EntryKind kind) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: KindBadge(kind: kind))),
      ),
    );
  }

  Color badgeTextColor(WidgetTester tester) {
    return tester.widget<Text>(find.byType(Text)).style!.color!;
  }

  group('KindBadge', () {
    testWidgets('업무는 짧은 라벨 "업무" + 회색 계열', (tester) async {
      await pump(tester, EntryKind.task);

      expect(find.text('업무'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.sub);
    });

    testWidgets('행사는 라벨 "행사" + 파랑 계열', (tester) async {
      await pump(tester, EntryKind.event);

      expect(find.text('행사'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.info);
    });
  });
}
