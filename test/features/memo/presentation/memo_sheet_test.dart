// test/features/memo/presentation/memo_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/memo/domain/memo_color.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_sheet.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late MemoRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = MemoRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<Memo> open(WidgetTester tester, Memo memo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoRepositoryProvider.overrideWithValue(repo),
          calendarRepositoryProvider.overrideWithValue(CalendarRepository(dbHelper: db)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => MemoSheet.show(context, memo),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return memo;
  }

  Future<void> settleDb(WidgetTester tester) async {
    // 저장 → 목록 재조회가 이어서 실제 I/O를 하므로 한 번으로는 모자란다.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('선택된 색에는 체크 아이콘이 있다 — 색만으로 두지 않는다', (tester) async {
    final m = await tester.runAsync(() => repo.add('색'));
    await open(tester, m ?? const Memo(text: ''));
    expect(
      find.descendant(
        of: find.byKey(MemoSheet.colorKey(MemoColor.yellow)),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(MemoSheet.colorKey(MemoColor.blue)),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('글과 색을 바꿔 저장하면 저장소에 남는다', (tester) async {
    final m = await tester.runAsync(() => repo.add('처음'));
    await open(tester, m ?? const Memo(text: ''));
    await tester.enterText(find.byKey(MemoSheet.textKey), '고친 글');
    await tester.tap(find.byKey(MemoSheet.colorKey(MemoColor.pink)));
    await tester.pump();
    await tester.tap(find.byKey(MemoSheet.saveKey));
    await settleDb(tester);
    final got = (await tester.runAsync(() => repo.getActive()))?.single;
    expect(got?.text, '고친 글');
    expect(got?.color, MemoColor.pink);
    expect(find.byType(MemoSheet), findsNothing, reason: '저장하면 닫힌다');
  });

  testWidgets('떼면 휴지통으로 가고 시트가 닫힌다', (tester) async {
    final m = await tester.runAsync(() => repo.add('뗄 것'));
    await open(tester, m ?? const Memo(text: ''));
    await tester.tap(find.byKey(MemoSheet.removeKey));
    await settleDb(tester);
    expect(await tester.runAsync(() => repo.getActive()), isEmpty);
    expect(find.byType(MemoSheet), findsNothing);
  });

  testWidgets('일정으로 등록 — 고른 종류로 일정이 생기고 쪽지는 떼진다', (tester) async {
    final m = await tester.runAsync(() async {
      final x = await repo.add('공개수업 지도안');
      await repo.update(x.copyWith(memoDate: DateTime(2026, 10, 17)));
      return (await repo.getActive()).single;
    });
    await open(tester, m ?? const Memo(text: ''));
    await tester.tap(find.byKey(MemoSheet.kindKey(EntryKind.event)));
    await tester.pump();
    await tester.ensureVisible(find.byKey(MemoSheet.toEventKey));
    await tester.tap(find.byKey(MemoSheet.toEventKey));
    await settleDb(tester);
    final events = await tester.runAsync(
      () => CalendarRepository(dbHelper: db).getEventsByMonth(2026, 10),
    );
    expect(events?.single.kind, EntryKind.event);
    expect(events?.single.eventDate, '2026-10-17');
    expect(await tester.runAsync(() => repo.getActive()), isEmpty);
  });

  testWidgets('날짜가 있으면 날짜 빼기가 보이고, 누르면 날짜 없음으로 저장된다', (tester) async {
    final m = await tester.runAsync(() async {
      final x = await repo.add('날짜');
      await repo.update(x.copyWith(memoDate: DateTime(2026, 10, 17)));
      return (await repo.getActive()).single;
    });
    await open(tester, m ?? const Memo(text: ''));
    await tester.tap(find.byKey(MemoSheet.dateRemoveKey));
    await tester.pump();
    await tester.tap(find.byKey(MemoSheet.saveKey));
    await settleDb(tester);
    expect((await tester.runAsync(() => repo.getActive()))?.single.memoDate, isNull);
  });

  testWidgets('키보드 인셋이 음수여도 터지지 않는다', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: -10);
    addTearDown(tester.view.reset);
    final m = await tester.runAsync(() => repo.add('인셋'));
    await open(tester, m ?? const Memo(text: ''));
    expect(tester.takeException(), isNull);
    expect(find.byType(MemoSheet), findsOneWidget);
  });
}
