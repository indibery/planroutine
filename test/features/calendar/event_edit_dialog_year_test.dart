import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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
            body: EventEditDialog(initialDate: DateTime(currentYear, 3, 2)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // 제목 입력칸은 첫 번째 TextFormField (두 번째는 설명).
  Finder titleField() => find.byType(TextFormField).first;

  group('캘린더 이벤트 편집 — 연도 바꾸기 칩', () {
    testWidgets('제목에 이전 연도를 입력하면 칩이 보인다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      expect(find.text('$oldYear → $currentYear'), findsOneWidget);
    });

    testWidgets('이전 연도가 없으면 칩이 없다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '졸업식 행사 협의');
      await tester.pump();

      expect(find.textContaining('→'), findsNothing);
    });

    testWidgets('칩을 탭하면 제목이 올해로 바뀌고 칩이 사라진다', (tester) async {
      await pumpDialog(tester);
      await tester.enterText(titleField(), '$oldYear학년도 졸업식');
      await tester.pump();

      await tester.tap(find.text('$oldYear → $currentYear'));
      await tester.pump();

      expect(find.text('$currentYear학년도 졸업식'), findsOneWidget);
      expect(find.text('$oldYear → $currentYear'), findsNothing);
    });
  });

  group('캘린더 이벤트 편집 — 색상 피커 제거', () {
    testWidgets('색상 선택 UI가 없다', (tester) async {
      await pumpDialog(tester);
      expect(find.text('색상'), findsNothing);
    });
  });
}
