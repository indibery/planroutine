import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/presentation/widgets/kind_badge.dart';

void main() {
  Future<void> pump(WidgetTester tester, EntryKind kind) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: KindBadge(kind: kind)),
        ),
      ),
    );
  }

  Color badgeTextColor(WidgetTester tester) {
    return tester.widget<Text>(find.byType(Text)).style!.color!;
  }

  Color badgeFill(WidgetTester tester) {
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(KindBadge),
        matching: find.byType(Container),
      ),
    );
    return ((box.decoration as BoxDecoration).color)!;
  }

  group('KindBadge', () {
    testWidgets('업무는 짧은 라벨 "업무"', (tester) async {
      await pump(tester, EntryKind.task);

      expect(find.text('업무'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.onKindTaskFill);
    });

    testWidgets('행사는 라벨 "행사" + 파랑 계열', (tester) async {
      await pump(tester, EntryKind.event);

      expect(find.text('행사'), findsOneWidget);
      expect(badgeTextColor(tester), AppColors.kindEvent);
    });

    // 색만으로 가르면 라이트에서 둘이 1.39:1로 붙는다(사용자 신고 2026-08-14).
    // **세기 축**으로 가른다 — 업무는 채움(불투명), 행사는 틴트(반투명).
    // 업무가 강조여야 한다: 내가 처리할 일이고 오늘 탭의 주인공이다.
    testWidgets('업무는 채움, 행사는 틴트 — 세기로 갈린다', (tester) async {
      await pump(tester, EntryKind.task);
      final taskFill = badgeFill(tester);

      await pump(tester, EntryKind.event);
      final eventFill = badgeFill(tester);

      expect(taskFill.a, 1.0, reason: '업무 배지는 불투명 채움이어야 강조가 된다');
      expect(eventFill.a, lessThan(0.5), reason: '행사는 참고 정보라 틴트로 물러나야 한다');
      expect(taskFill, isNot(eventFill));
    });

    // `작년` 배지(`event_list_section`)가 회색 테두리형이다. 행사를 회색으로 빼면
    // 한 행에서 그 둘이 같은 표시로 읽힌다 — 색 축은 종류, 회색은 출처로 나눈다.
    testWidgets('행사 색은 `작년` 배지의 회색과 다르다', (tester) async {
      await pump(tester, EntryKind.event);

      expect(badgeTextColor(tester), isNot(AppColors.sub));
    });
  });
}
