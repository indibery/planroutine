import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    // 종류 세그먼트(Task 5)가 성격 카드에 더해지며 시트가 길어져, 기본 테스트
    // 뷰포트(800x600)에서는 저장 버튼이 스크롤 밖으로 밀린다 — 눈에 보이게 당긴다.
    await tester.ensureVisible(find.text('저장'));
    await tester.pumpAndSettle();
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

  group('편집 저장 — 날짜를 종료일 뒤로 옮기면 기간을 정리한다', () {
    // Task 4가 종료 날짜 입력을 없애며, 옛 _pickDate(isStart: true)가 갖고 있던
    // "endDate가 새 시작일보다 앞서면 시작일로 당긴다" 클램프도 함께 사라졌다.
    // 지금은 copyWith가 endDate를 보존만 하므로, 시작일을 옛 종료일보다 뒤로
    // 옮기면 모순된 기간(end < start)이 그대로 DB에 남는다. 모순되면 버린다.
    testWidgets('종료일보다 뒤로 날짜를 옮겨 저장하면 endDate가 사라진다', (tester) async {
      const seed = CalendarEvent(
        id: 21,
        title: '수련회',
        eventDate: '2026-03-02',
        endDate: '2026-03-04',
      );

      CalendarEvent? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ko', 'KR')],
            locale: const Locale('ko', 'KR'),
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

      await tester.tap(find.text('날짜'));
      await tester.pumpAndSettle();

      // 종료일(3월 4일)보다 뒤인 3월 15일을 고른다.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.eventDate, '2026-03-15');
      expect(captured!.endDate, isNull,
          reason: '새 시작일(3/15)이 옛 종료일(3/4)보다 뒤라 기간이 모순되므로 버려야 한다');
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

  group('편집 저장 — 검토 시각 기록', () {
    testWidgets('칩을 누르지 않고 저장해도 reviewedAt이 채워진다', (tester) async {
      const seed = CalendarEvent(
        id: 11,
        title: '2025학년도 재학생 진급 사정 협의',
        eventDate: '2026-03-02',
      );

      final result = await editTitleAndSave(
        tester,
        seed: seed,
        newTitle: '2025학년도 재학생 진급 사정 협의(수정)',
      );

      expect(result, isNotNull);
      expect(
        result!.reviewedAt,
        isNotNull,
        reason: '열어보고 고칠 게 없다고 판단한 것도 검토다 — 아니면 연도 없는 제목의 '
            '배지를 지울 방법이 영원히 없다',
      );
    });

    testWidgets('신규 생성 저장에는 reviewedAt이 없다', (tester) async {
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

      await tester.enterText(find.byType(TextFormField).first, '새 일정');
      await tester.ensureVisible(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(
        captured!.reviewedAt,
        isNull,
        reason: '생성 시점에 검토란 개념이 없다',
      );
    });
  });
}
