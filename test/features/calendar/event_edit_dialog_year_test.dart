import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  final currentYear = DateTime.now().year;
  final oldYear = currentYear - 1;

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventEditDialog(
              initialDate: DateTime(currentYear, 3, 2),
              // 연도 칩은 수정 경로에서만 뜬다 — 기존 이벤트를 넘겨 편집 모드로 만든다.
              event: CalendarEvent(
                id: 1,
                title: '초기 제목',
                eventDate: '$currentYear-03-02',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // 제목 입력칸은 첫 번째 TextFormField (두 번째는 설명).
  Finder titleField() => find.byType(TextFormField).first;

  group('캘린더 이벤트 편집 — 연도 바꾸기 칩', () {
    testWidgets('제목에 이전 연도를 입력하면 한 해 뒤로 미는 칩이 보인다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      expect(find.text('$oldYear → $currentYear'), findsOneWidget);
    });

    testWidgets('올해 연도에도 칩이 보인다 — 내년으로 민다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$currentYear 졸업식 행사 관련 협의');
      await tester.pump();

      expect(find.text('$currentYear → ${currentYear + 1}'), findsOneWidget);
    });

    testWidgets('연도가 없으면 칩이 없다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '졸업식 행사 협의');
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });

    testWidgets('연도가 둘이면 개별 값 대신 "연도 모두" 문구를 쓴다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 안건[$currentYear학년도 개정]');
      await tester.pump();

      expect(find.text('연도 모두 +1년'), findsOneWidget);
      expect(find.text('$oldYear → $currentYear'), findsNothing);
    });

    testWidgets('칩을 탭하면 제목의 모든 연도가 한 해씩 밀린다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 안건[$currentYear학년도 개정]');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(
        find.text('$currentYear학년도 안건[${currentYear + 1}학년도 개정]'),
        findsOneWidget,
      );
    });

    testWidgets('두 번 탭하면 두 해 밀린다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(find.text('${currentYear + 1}학년도 졸업식'), findsOneWidget);
    });
  });

  group('캘린더 이벤트 편집 — 색상 피커 제거', () {
    testWidgets('색상 선택 UI가 없다', (tester) async {
      await pumpDialog(tester);
      expect(find.text('색상'), findsNothing);
    });
  });

  group('캘린더 이벤트 편집 — 연도 칩은 수정 경로에서만', () {
    testWidgets('신규 생성 경로에서는 연도가 있어도 칩이 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(initialDate: DateTime(currentYear, 3, 2)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).first,
        '$currentYear학년도 운동회',
      );
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });
  });
}
