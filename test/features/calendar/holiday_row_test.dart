// 공휴일은 **수정할 수 없는 일정**으로 목록에 뜬다(사용자 요구 2026-08-18).
//
// 캘린더에서 빨간 날은 보이는데 무슨 휴일인지 알 수 없었다. 이름을 목록에 넣되,
// 사용자 일정과 같은 취급을 하면 안 된다 — 스와이프로 확정·완료·삭제할 대상이
// 아니고, 탭해서 편집할 것도 아니다.
//
// 연휴는 **첫날에만** 범위와 함께 뜬다. 둘째 날부터 `koreanHolidayRunAt`이 null을
// 주므로 이 위젯에는 조건문이 없다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko_KR', null));

  Future<void> pump(
    WidgetTester tester,
    DateTime date, {
    List<CalendarEvent> events = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventListSection(
                selectedDate: date,
                events: events,
                onEventTap: (_) {},
                onEventSaveToGoogle: (_) {},
                onEventToggleCompleted: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('공휴일 행', () {
    testWidgets('하루짜리 공휴일은 이름만 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(find.text('개천절'), findsOneWidget);
    });

    testWidgets('연휴 첫날은 이름과 날짜 범위가 함께 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 9, 24));

      expect(find.text('추석 연휴'), findsOneWidget);
      expect(find.textContaining('9.24'), findsOneWidget);
      expect(find.textContaining('9.26'), findsOneWidget);
    });

    testWidgets('연휴 둘째 날에는 행이 없다 — 첫날 범위가 말해준다', (tester) async {
      await pump(tester, DateTime(2026, 9, 25));

      expect(find.text('추석 연휴'), findsNothing);
    });

    testWidgets('공휴일이 아니면 행이 없다', (tester) async {
      await pump(tester, DateTime(2026, 7, 2));

      expect(find.byKey(const Key('holiday_row')), findsNothing);
    });

    // **급소**: 사용자 일정과 같은 취급을 받으면 스와이프로 확정·삭제된다.
    testWidgets('수정할 수 없다 — Dismissible이 아니다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(
        find.descendant(
          of: find.byKey(const Key('holiday_row')),
          matching: find.byType(Dismissible),
        ),
        findsNothing,
        reason: '공휴일은 스와이프 대상이 아니다',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('holiday_row')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
        reason: '탭해서 편집할 것도 아니다',
      );
    });

    testWidgets('일정이 없어도 빈 상태 문구 대신 공휴일 행이 뜬다', (tester) async {
      await pump(tester, DateTime(2026, 10, 3));

      expect(find.byKey(const Key('holiday_row')), findsOneWidget);
      expect(find.text('일정이 없습니다'), findsNothing);
    });
  });

  // 라이트에서 붉은 틴트가 과했다(실기기 신고 2026-08-18) — 흰 배경 위에서는 7%
  // 채움이 분홍 띠로 읽힌다. 다크에서는 같은 값이 거의 안 보여 괜찮았다.
  //
  // **라이트의 `inkRed`가 다크보다 진하기 때문이다**(#C0392B 대 #E08978). 그래서
  // 알파 하나로 두 테마를 맞출 수 없고, 채움 여부 자체를 팔레트가 정해야 한다.
  //
  // 테두리와 글씨는 양쪽 다 붉게 남는다 — 채움을 빼도 "누를 수 없는 배경 사실"이라는
  // 신호는 형태(테두리)와 색(붉은 글씨)이 그대로 진다.
  group('행 배경 — 라이트에서는 채우지 않는다', () {
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('holiday_row')),
          matching: find.byType(Container),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    testWidgets('라이트: 배경을 채우지 않는다', (tester) async {
      AppColors.applyBrightness(Brightness.light);
      await pump(tester, DateTime(2026, 10, 3));

      expect(
        decorationOf(tester).color?.a ?? 0,
        0,
        reason: '흰 배경 위 붉은 채움은 분홍 띠로 읽힌다 — 테두리와 글씨로만 강조한다',
      );
    });

    testWidgets('라이트: 채움을 빼도 테두리와 글씨는 붉다', (tester) async {
      AppColors.applyBrightness(Brightness.light);
      await pump(tester, DateTime(2026, 10, 3));

      final border = decorationOf(tester).border! as Border;
      expect(
        border.top.color.a,
        greaterThan(0),
        reason: '테두리가 없으면 이 행이 무엇인지 알려주는 형태 단서가 사라진다',
      );
      expect(
        tester.widget<Text>(find.text('개천절')).style?.color,
        AppColors.inkRed,
      );
    });

    testWidgets('다크: 옅은 붉은 틴트가 남는다', (tester) async {
      AppColors.applyBrightness(Brightness.dark);
      await pump(tester, DateTime(2026, 10, 3));

      final alpha = decorationOf(tester).color?.a ?? 0;
      expect(alpha, greaterThan(0), reason: '다크는 괜찮다는 확인을 받았다');
      expect(alpha, lessThan(0.15), reason: '틴트지 채움이 아니다');
    });
  });
}
