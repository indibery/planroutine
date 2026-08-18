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
              // 칩은 `작년` 배지(`showsImportBadge`)가 붙은 항목에만 뜬다 —
              // 에듀파인 CSV로 들어왔고(`fromImport`) 아직 검토 안 한 것.
              event: CalendarEvent(
                id: 1,
                title: '초기 제목',
                eventDate: '$currentYear-03-02',
                fromImport: true,
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
      await tester.enterText(
        titleField(),
        '$oldYear학년도 안건[$currentYear학년도 개정]',
      );
      await tester.pump();

      expect(find.text('연도 모두 +1년'), findsOneWidget);
      expect(find.text('$oldYear → $currentYear'), findsNothing);
    });

    testWidgets('칩을 탭하면 제목의 모든 연도가 한 해씩 밀린다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(
        titleField(),
        '$oldYear학년도 안건[$currentYear학년도 개정]',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(
        find.text('$currentYear학년도 안건[${currentYear + 1}학년도 개정]'),
        findsOneWidget,
      );
    });

    testWidgets('칩을 한 번 탭하면 칩이 사라진다 — 두 번 밀 수 없다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();

      expect(find.text('$currentYear학년도 졸업식'), findsOneWidget);
      expect(
        find.byKey(const Key('year_shift_chip')),
        findsNothing,
        reason: '연도 밀기는 한 번으로 끝난다 — 계속 눌러 연도가 올라가면 안 된다',
      );
    });

    testWidgets('칩을 탭한 뒤 제목을 다시 고쳐도 칩은 돌아오지 않는다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.byKey(const Key('year_shift_chip')));
      await tester.pump();
      await tester.enterText(titleField(), '$oldYear학년도 종업식');
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });

    // 사용자 신고(2026-08-18): 사진 AI로 올해 공문을 등록했는데 편집 시트에
    // `2026 → 2027` 칩이 떴다. 연도 밀기가 필요한 이유는 "작년 CSV를 가져와
    // 제목에 옛 연도가 남았다"인데, 그 조건을 안 보고 **연도가 있는지만** 봤다.
    //
    // 원인은 커밋 7643967(올해로 맞추기 → 한 해 밀기)의 부수 효과다. 옛
    // `bumpTitleYear(title, currentYear)`의 `if (year < currentYear)`가 치환
    // 로직과 가시성을 **겸하고** 있었고, 로직만 상대 이동으로 바꾸면서 관문이
    // 함께 사라졌다.
    testWidgets('가져온 자료가 아니면(사진 AI·수기) 연도가 있어도 칩이 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(
                initialDate: DateTime(currentYear, 8, 25),
                event: CalendarEvent(
                  id: 3,
                  title: '$currentYear 하반기 학교 현황 제출',
                  eventDate: '$currentYear-08-25',
                  // 사진 AI 경로는 `source_id`가 없어 `from_import`가 0이다.
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
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

    testWidgets('이미 검토한 항목(reviewedAt 있음)에는 칩이 없다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(
                initialDate: DateTime(currentYear, 3, 2),
                // `fromImport`를 켜 둬야 이 테스트가 **검토 여부**를 검사한다.
                // 끄면 출처 때문에 안 뜨는 것이라 단정이 공허해진다.
                event: CalendarEvent(
                  id: 2,
                  title: '$oldYear학년도 졸업식',
                  eventDate: '$currentYear-03-02',
                  fromImport: true,
                  reviewedAt: '$currentYear-03-03T10:00:00.000',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('year_shift_chip')), findsNothing);
    });
  });
}
