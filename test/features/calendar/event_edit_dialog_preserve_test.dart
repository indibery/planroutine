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

  /// 시트를 열어 제목만 [newTitle]로 바꾸고 저장한 뒤, 반환된 이벤트를 준다.
  Future<CalendarEvent?> editTitleAndSave(
    WidgetTester tester, {
    required CalendarEvent seed,
    required String newTitle,
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
                    event: seed,
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

    await tester.enterText(find.byType(TextFormField).first, newTitle);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('편집 저장 — 손대지 않은 필드 보존 가드', () {
    // 이 테스트가 재발 방지선이다. _buildEvent()가 생성자로 CalendarEvent를 새로
    // 만들면 여기 적힌 필드들이 @Default/null로 되돌아가 DB를 덮는다.
    //   - kind 유실 → 학교일정이 업무가 되어 오늘 탭에 뜬다
    //   - googleEventId 유실 → 재저장 시 Google 캘린더에 중복 이벤트가 생긴다
    testWidgets('제목만 고쳐 저장해도 kind·googleEventId·deviceEventId·endDate가 남는다',
        (tester) async {
      const seed = CalendarEvent(
        id: 7,
        title: '2025학년도 가을 운동회',
        eventDate: '2026-03-02',
        endDate: '2026-03-04',
        googleEventId: 'g-abc123',
        deviceEventId: 'd-xyz789',
        kind: EntryKind.event,
        createdAt: '2026-01-01T00:00:00.000',
      );

      final result = await editTitleAndSave(
        tester,
        seed: seed,
        newTitle: '2026학년도 가을 운동회',
      );

      expect(result, isNotNull);
      expect(result!.title, '2026학년도 가을 운동회');
      expect(result.kind, EntryKind.event, reason: '학교일정이 업무로 바뀌면 안 된다');
      expect(result.googleEventId, 'g-abc123');
      expect(result.deviceEventId, 'd-xyz789');
      expect(result.endDate, '2026-03-04');
      expect(result.id, 7);
      expect(result.createdAt, '2026-01-01T00:00:00.000');
    });
  });

  group('종료 날짜 입력 제거', () {
    Future<void> pumpSheet(WidgetTester tester, {CalendarEvent? event}) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EventEditDialog(
                initialDate: DateTime(2026, 3, 2),
                event: event,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('시트에 "종료 날짜" 타일이 없다', (tester) async {
      await pumpSheet(tester);

      expect(find.text('종료 날짜'), findsNothing);
      expect(find.text('날짜'), findsOneWidget);
    });

    testWidgets('설명칸은 최소 4줄 높이로 열린다', (tester) async {
      await pumpSheet(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(TextField),
        ),
      );
      expect(field.minLines, 4);
      expect(field.maxLines, 6);
    });
  });
}
