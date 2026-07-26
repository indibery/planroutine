import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  final currentYear = DateTime.now().year;
  final oldYear = currentYear - 1;

  Future<void> pumpEvents(WidgetTester tester, List<CalendarEvent> events) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventListSection(
              selectedDate: DateTime(currentYear, 1, 3),
              events: events,
              onEventTap: (_) {},
              onEventSaveToGoogle: null,
              onEventToggleCompleted: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('캘린더 리스트 — 색상 통일', () {
    testWidgets('저장된 색과 무관하게 막대는 기본 액센트색으로 렌더', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 3,
          title: '행사 계획',
          eventDate: '$currentYear-01-03',
          color: '#EF4444', // 빨강이 저장돼 있어도 렌더는 기본색이어야 함
        ),
      ]);

      final bar = tester.widget<Container>(
        find.byKey(const Key('event_accent_bar_3')),
      );
      final deco = bar.decoration as BoxDecoration;
      expect(deco.color, AppColors.eventAccent);
    });
  });

  group('캘린더 리스트 — 가져온 자료 배지', () {
    testWidgets('가져온 자료면 작년 배지가 보인다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 1,
          title: '$oldYear학년도 1차 학급편성 결과 제출',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_1')), findsOneWidget);
      expect(find.text('작년'), findsOneWidget);
    });

    testWidgets('제목에 연도가 없어도 가져온 자료면 배지가 붙는다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 2,
          title: '졸업식 학사일정 변경 안내',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_2')), findsOneWidget);
    });

    testWidgets('손으로 넣은 항목은 옛 연도가 있어도 배지가 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 3,
          title: '$oldYear학년도 겨울방학 계획',
          eventDate: '$currentYear-01-03',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_3')), findsNothing);
      expect(find.text('작년'), findsNothing);
    });

    testWidgets('검토한 항목(reviewedAt 있음)에는 배지가 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 5,
          title: '$oldYear학년도 재학생 진급 사정 협의',
          eventDate: '$currentYear-01-03',
          fromImport: true,
          reviewedAt: '$currentYear-01-04T10:00:00.000',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_5')), findsNothing);
      expect(find.text('작년'), findsNothing);
    });

    testWidgets('같은 목록에서 미검토는 배지, 검토 완료는 배지 없음', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 6,
          title: '아직 안 본 항목',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
        CalendarEvent(
          id: 7,
          title: '정리한 항목',
          eventDate: '$currentYear-01-03',
          fromImport: true,
          reviewedAt: '$currentYear-01-04T10:00:00.000',
        ),
      ]);

      expect(find.byKey(const Key('event_import_badge_6')), findsOneWidget);
      expect(find.byKey(const Key('event_import_badge_7')), findsNothing);
      expect(
        find.text('작년'),
        findsOneWidget,
        reason: '남아 있는 배지가 곧 아직 정리 안 한 목록이다',
      );
    });
  });

  group('캘린더 리스트 — 골드 연도 배지 제거', () {
    testWidgets('옛 연도가 있어도 연도 바꾸기 배지는 더 이상 없다', (tester) async {
      await pumpEvents(tester, [
        CalendarEvent(
          id: 4,
          title: '$oldYear학년도 겨울방학 계획',
          eventDate: '$currentYear-01-03',
          fromImport: true,
        ),
      ]);

      expect(find.byKey(const Key('year_bump_badge_4')), findsNothing);
      expect(find.textContaining('→'), findsNothing);
    });
  });
}
