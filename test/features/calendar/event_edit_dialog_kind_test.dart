import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  const kindSelector = Key('kind_selector');

  Future<CalendarEvent?> openAndSave(
    WidgetTester tester, {
    CalendarEvent? event,
    bool allowKindChange = true,
    String? title,
    Future<void> Function(WidgetTester tester)? beforeSave,
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
                    allowKindChange: allowKindChange,
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

    if (title != null) {
      await tester.enterText(find.byType(TextFormField).first, title);
    }
    if (beforeSave != null) {
      await beforeSave(tester);
    }
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('종류 선택 — 캘린더 경로(선택 가능)', () {
    testWidgets('종류 행이 보이고 기본값은 업무', (tester) async {
      final result = await openAndSave(
        tester,
        title: '교육계획 수립',
        // 저장하면 시트가 닫혀 위젯 트리에서 사라지므로, 행이 "보이는지"는
        // 닫히기 전(beforeSave)에 확인해야 한다.
        beforeSave: (tester) async {
          expect(find.byKey(kindSelector), findsOneWidget);
        },
      );

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.task);
    });

    testWidgets('학교일정을 고르고 저장하면 kind=event', (tester) async {
      final result = await openAndSave(
        tester,
        title: '가을 운동회',
        beforeSave: (tester) async {
          await tester.tap(find.text('행사'));
          await tester.pumpAndSettle();
        },
      );

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });

    testWidgets('기존 학교일정을 열면 학교일정이 선택돼 있고 저장해도 유지된다',
        (tester) async {
      final result = await openAndSave(
        tester,
        event: const CalendarEvent(
          id: 3,
          title: '학예회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      );

      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });
  });

  group('종류 선택 — 오늘 탭 경로(잠금)', () {
    // 오늘 탭은 업무만 담는 화면이다. 여기서 학교일정을 만들면 저장 직후
    // 목록에서 사라져 "저장이 안 됐나?"로 읽힌다 — 아예 못 고르게 잠근다.
    testWidgets('종류 행이 없고 신규는 업무로 저장된다', (tester) async {
      final result = await openAndSave(
        tester,
        allowKindChange: false,
        title: '주간학습안내 작성',
      );

      expect(find.byKey(kindSelector), findsNothing);
      expect(result, isNotNull);
      expect(result!.kind, EntryKind.task);
    });

    testWidgets('종류 행이 없어도 기존 이벤트의 kind는 보존된다', (tester) async {
      final result = await openAndSave(
        tester,
        allowKindChange: false,
        event: const CalendarEvent(
          id: 9,
          title: '체육대회',
          eventDate: '2026-03-02',
          kind: EntryKind.event,
        ),
      );

      expect(find.byKey(kindSelector), findsNothing);
      expect(result, isNotNull);
      expect(result!.kind, EntryKind.event);
    });
  });
}
