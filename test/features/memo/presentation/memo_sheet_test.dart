// test/features/memo/presentation/memo_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    // [일정으로 등록 ▾]이 업무·행사 메뉴를 연다 — 고르는 순간 등록된다
    await tester.tap(find.byKey(MemoSheet.toEventKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MemoSheet.kindKey(EntryKind.event)));
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

  testWidgets('일정으로 등록을 연달아 두 번 눌러도 일정은 하나만 생긴다', (tester) async {
    final m = await tester.runAsync(() async {
      final x = await repo.add('두 번 누름');
      await repo.update(x.copyWith(memoDate: DateTime(2026, 10, 17)));
      return (await repo.getActive()).single;
    });
    await open(tester, m ?? const Memo(text: ''));
    await tester.tap(find.byKey(MemoSheet.toEventKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MemoSheet.kindKey(EntryKind.task)));
    await tester.pump();
    // 등록이 도는 동안 다시 메뉴를 열어 한 번 더 고른다
    await tester.tap(find.byKey(MemoSheet.toEventKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    if (find.byKey(MemoSheet.kindKey(EntryKind.task)).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(MemoSheet.kindKey(EntryKind.task)), warnIfMissed: false);
    }
    await settleDb(tester);
    final events = await tester.runAsync(
      () => CalendarRepository(dbHelper: db).getEventsByMonth(2026, 10),
    );
    expect(events, hasLength(1));
  });

  testWidgets('저장 전 새 쪽지에는 삭제와 일정으로 등록이 없다 — 저장만 있다', (tester) async {
    await open(tester, const Memo(text: '', color: MemoColor.blue));
    expect(find.byKey(MemoSheet.saveKey), findsOneWidget);
    expect(find.byKey(MemoSheet.removeKey), findsNothing);
    expect(find.byKey(MemoSheet.toEventKey), findsNothing);
  });

  testWidgets('삭제와 저장이 맨 아래 한 줄에 함께 보인다', (tester) async {
    final m = await tester.runAsync(() => repo.add('보이기'));
    await open(tester, m ?? const Memo(text: ''));
    final save = tester.getRect(find.byKey(MemoSheet.saveKey));
    final remove = tester.getRect(find.byKey(MemoSheet.removeKey));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(save.bottom, lessThanOrEqualTo(screen.height), reason: '스크롤하지 않아도 보인다');
    expect((save.center.dy - remove.center.dy).abs(), lessThan(4), reason: '같은 줄');
    expect(remove.left, lessThan(save.left));
  });

  testWidgets('키보드가 올라와도 저장 버튼이 키보드 위에 보인다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 346);
    addTearDown(tester.view.reset);
    final m = await tester.runAsync(() => repo.add('키보드'));
    await open(tester, m ?? const Memo(text: ''));
    expect(tester.takeException(), isNull);
    final save = tester.getRect(find.byKey(MemoSheet.saveKey));
    expect(save.bottom, lessThanOrEqualTo(844 - 346 + 0.5));
    final text = tester.getRect(find.byKey(MemoSheet.textKey));
    expect(text.height, greaterThanOrEqualTo(120), reason: '키보드가 있어도 쓰는 칸이 넉넉하다');
  });

  testWidgets('날짜가 있으면 320·390pt에서 날짜 글자가 잘리지 않고 다 보인다', (tester) async {
    // 날짜 칩과 색 점이 남은 폭을 나눠 가지면 칩이 줄어 글자가 0폭이 됐다(시뮬레이터에서 발견).
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final m = await tester.runAsync(() => repo.add('날짜 $width', memoDate: DateTime(2026, 10, 23)));
      await open(tester, m ?? const Memo(text: ''));
      expect(tester.takeException(), isNull);
      final label = find.descendant(of: find.byKey(MemoSheet.dateRowKey), matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: '$width pt에서 날짜가 말줄임됐다');
      expect(tester.getSize(label).width, greaterThan(60), reason: '$width pt에서 날짜 칸이 너무 좁다');
      await tester.pumpWidget(const SizedBox());
    }
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
