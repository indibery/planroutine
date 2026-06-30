import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_edit_sheet.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  final currentYear = DateTime.now().year;
  final oldYear = currentYear - 1;

  Future<void> pumpSheet(WidgetTester tester, String title) async {
    final schedule = Schedule(
      id: 1,
      title: title,
      scheduledDate: '$currentYear-03-02',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ScheduleEditSheet(schedule: schedule)),
        ),
      ),
    );
    await tester.pump();
  }

  group('편집 시트 연도 바꾸기 칩', () {
    testWidgets('제목에 이전 연도가 있으면 칩이 보인다', (tester) async {
      await pumpSheet(tester, '$oldYear학년도 겨울방학 운영 계획');
      expect(find.text('$oldYear → $currentYear'), findsOneWidget);
    });

    testWidgets('제목에 이전 연도가 없으면 칩이 없다', (tester) async {
      await pumpSheet(tester, '종업식 및 졸업식 안내장');
      expect(find.textContaining('→'), findsNothing);
    });

    testWidgets('칩을 탭하면 제목이 올해로 바뀌고 칩이 사라진다', (tester) async {
      await pumpSheet(tester, '$oldYear학년도 겨울방학 운영 계획');

      await tester.tap(find.text('$oldYear → $currentYear'));
      await tester.pump();

      expect(find.text('$currentYear학년도 겨울방학 운영 계획'), findsOneWidget);
      expect(find.text('$oldYear → $currentYear'), findsNothing);
    });
  });
}
