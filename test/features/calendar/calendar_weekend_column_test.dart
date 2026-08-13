import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_sizes.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_day_cell.dart';
import 'package:planroutine/features/calendar/presentation/widgets/calendar_grid.dart';

void main() {
  // AppColors는 전역 팔레트라 테스트가 바꾸면 되돌려야 한다(기본 다크).
  tearDown(() => AppColors.applyBrightness(Brightness.dark));

  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarGrid(
            year: 2026,
            month: 7,
            selectedDate: DateTime(2026, 7, 23),
            eventsMap: const {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Color? columnColor(WidgetTester tester, String key) {
    final box = tester.widget<DecoratedBox>(find.byKey(Key(key)));
    return (box.decoration as BoxDecoration).color;
  }

  group('주말 열 배경', () {
    testWidgets('일요일·토요일 열 배경이 그려진다', (tester) async {
      await pumpGrid(tester);

      expect(find.byKey(const Key('weekend_column_sun')), findsOneWidget);
      expect(find.byKey(const Key('weekend_column_sat')), findsOneWidget);
    });

    testWidgets('열 배경은 요일 헤더보다 뒤에 깔린다 (헤더부터 이어짐)', (tester) async {
      await pumpGrid(tester);

      // 열 배경 Row가 헤더/그리드와 같은 Stack 안에 있어야 세로로 이어진다.
      final stack = find.ancestor(
        of: find.byKey(const Key('calendar_weekend_columns')),
        matching: find.byType(Stack),
      );
      expect(stack, findsWidgets);
      expect(
        find.descendant(of: stack.first, matching: find.text('토')),
        findsOneWidget,
      );
    });

    testWidgets('열 배경은 마지막 주에서 끝난다 (빈 주 아래로 새지 않는다)', (tester) async {
      // 실제 조건 재현: pager가 6행 기준 고정 높이(230)를 주는데 2026년 7월은 5행이다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 230,
              child: CalendarGrid(
                year: 2026,
                month: 7,
                selectedDate: DateTime(2026, 7, 23),
                eventsMap: const {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 26일은 마지막 주 일요일 — 열 배경은 그 셀 바로 아래에서 끝나야 한다.
      final lastRowBottom = tester.getRect(find.text('26')).bottom;
      final columnBottom = tester
          .getRect(find.byKey(const Key('weekend_column_sun')))
          .bottom;

      expect(columnBottom - lastRowBottom, lessThan(20));
    });

    testWidgets('6행짜리 달에서도 열 배경이 마지막 주에서 끝난다', (tester) async {
      // 2026년 8월 1일은 토요일 → 선행 6칸 + 31일 = 37셀 = 6행.
      // pager의 고정 높이(6행 기준)에 딱 맞는 달이라 여유가 가장 적다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: AppSizes.calendarGridHeight,
              child: CalendarGrid(
                year: 2026,
                month: 8,
                selectedDate: DateTime(2026, 8, 1),
                eventsMap: const {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 8월은 선행 셀에 7월 30·31일이 들어와 날짜 텍스트로는 특정할 수 없다.
      // 셀은 생성 순서대로 배치되므로 마지막 셀이 곧 마지막 주다.
      final lastRowBottom = tester
          .getRect(find.byType(CalendarDayCell).last)
          .bottom;
      final columnBottom = tester
          .getRect(find.byKey(const Key('weekend_column_sun')))
          .bottom;

      expect(columnBottom - lastRowBottom, lessThan(20));
    });

    testWidgets('6행짜리 달이 고정 높이 안에 들어간다 (마지막 주가 잘리지 않는다)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: AppSizes.calendarGridHeight,
              child: CalendarGrid(
                year: 2026,
                month: 8,
                selectedDate: DateTime(2026, 8, 1),
                eventsMap: const {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 그리드가 고정 높이를 넘으면 RenderFlex 오버플로가 나고 마지막 주가 잘린다.
      // 셀 높이를 키울 때 pager 높이 상수가 따라오지 않으면 여기서 먼저 걸린다.
      final gridHeight = tester
          .getRect(find.byKey(const Key('weekend_column_sun')))
          .height;
      expect(gridHeight, lessThanOrEqualTo(AppSizes.calendarGridHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('일요일과 토요일 열 색은 서로 다르다', (tester) async {
      await pumpGrid(tester);

      expect(
        columnColor(tester, 'weekend_column_sun'),
        isNot(columnColor(tester, 'weekend_column_sat')),
      );
    });

    testWidgets('열 배경은 라이트 테마에서도 투명하지 않다', (tester) async {
      AppColors.applyBrightness(Brightness.light);
      await pumpGrid(tester);

      expect(
        columnColor(tester, 'weekend_column_sun'),
        isNot(Colors.transparent),
      );
      expect(
        columnColor(tester, 'weekend_column_sat'),
        isNot(Colors.transparent),
      );
    });
  });

  group('요일 헤더 가시성', () {
    testWidgets('평일 요일은 본문색(진한 잉크) + w700로 그려진다', (tester) async {
      await pumpGrid(tester);

      final monday = tester.widget<Text>(find.text('월'));
      expect(monday.style?.color, AppColors.textPrimary);
      expect(monday.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('일요일 요일은 빨강, 토요일은 중립 파랑', (tester) async {
      await pumpGrid(tester);

      expect(
        tester.widget<Text>(find.text('일')).style?.color,
        AppColors.calendarWeekend,
      );
      expect(
        tester.widget<Text>(find.text('토')).style?.color,
        AppColors.calendarSaturday,
      );
    });

    testWidgets('요일 헤더도 Pretendard를 쓴다', (tester) async {
      await pumpGrid(tester);

      expect(
        tester.widget<Text>(find.text('수')).style?.fontFamily,
        'Pretendard',
      );
    });
  });

  group('토요일 색 — 중립 파랑', () {
    test('토요일 색은 골드 강조색과 겹치지 않는다', () {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        AppColors.applyBrightness(brightness);
        final saturday = AppColors.calendarSaturday;

        expect(saturday, isNot(AppColors.gold), reason: '$brightness');
        expect(saturday, isNot(AppColors.goldFill), reason: '$brightness');
        expect(saturday, isNot(AppColors.goldGlow), reason: '$brightness');
      }
    });

    test('토요일 색은 파랑 계열이다 (골드는 붉은 기가 강하다)', () {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        AppColors.applyBrightness(brightness);
        final saturday = AppColors.calendarSaturday;

        expect(
          saturday.b,
          greaterThan(saturday.r),
          reason: '$brightness — 파랑이 빨강보다 강해야 한다',
        );
        expect(saturday.b, greaterThan(saturday.g), reason: '$brightness');
      }
    });
  });
}
