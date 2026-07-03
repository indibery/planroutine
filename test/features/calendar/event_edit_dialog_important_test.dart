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

  const importantToggle = Key('important_toggle');

  // show()로 다이얼로그를 띄우고, 저장 시 반환되는 이벤트를 캡처한다.
  Future<CalendarEvent?> openAndReturn(
    WidgetTester tester, {
    CalendarEvent? event,
  }) async {
    CalendarEvent? captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await EventEditDialog.show(
                    context,
                    initialDate: DateTime(2026, 3, 2),
                    event: event,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('캘린더 이벤트 편집 — 중요 표시 토글', () {
    testWidgets('토글이 보이고 기존 이벤트의 isImportant를 반영한다', (tester) async {
      await openAndReturn(
        tester,
        event: const CalendarEvent(
          id: 1,
          title: '입학식',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      );

      final sw = tester.widget<SwitchListTile>(find.byKey(importantToggle));
      expect(sw.value, true);
    });

    testWidgets('토글을 켜고 저장하면 isImportant=true인 이벤트 반환', (tester) async {
      CalendarEvent? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await EventEditDialog.show(
                      context,
                      initialDate: DateTime(2026, 3, 2),
                      event: const CalendarEvent(
                        id: 1,
                        title: '입학식',
                        eventDate: '2026-03-02',
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(importantToggle));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isImportant, true);
    });
  });
}
