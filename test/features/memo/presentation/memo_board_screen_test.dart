// test/features/memo/presentation/memo_board_screen_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/memo/presentation/screens/memo_board_screen.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_card.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_sheet.dart';

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

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MemoBoardScreen()),
      ),
    );
    // DB I/O는 fake-async 밖에서 끝나야 한다(리포 규칙)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('쪽지가 없으면 빈 상태 두 줄', (tester) async {
    await pump(tester);
    expect(find.text(MemoStrings.empty), findsOneWidget);
    expect(find.text(MemoStrings.emptyHint), findsOneWidget);
  });

  testWidgets('빠른 입력으로 붙이면 맨 앞에 쪽지가 생긴다', (tester) async {
    await tester.runAsync(() => repo.add('예전 것'));
    await pump(tester);
    await tester.enterText(find.byKey(MemoBoardScreen.quickFieldKey), '새 메모');
    await tester.tap(find.byKey(MemoBoardScreen.quickAddKey));
    // 저장 → 신호 → 다시 읽기, DB I/O가 두 번이라 한 번 더 비워 준다
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('새 메모'));
    final old = tester.getTopLeft(find.text('예전 것'));
    expect(first.dx < old.dx || first.dy < old.dy, isTrue);
    // 입력 칸은 비워진다
    final field = tester.widget<TextField>(find.byKey(MemoBoardScreen.quickFieldKey));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('빈 글은 붙지 않는다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(MemoBoardScreen.quickFieldKey), '   ');
    await tester.tap(find.byKey(MemoBoardScreen.quickAddKey));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byType(MemoCard), findsNothing);
  });

  testWidgets('짧게 누르면 쪽지 시트가 열린다', (tester) async {
    final m = await tester.runAsync(() => repo.add('열어 볼 것'));
    await pump(tester);
    await tester.tap(find.byKey(MemoCard.cardKey(m?.id ?? -1)));
    await tester.pumpAndSettle();
    expect(find.byType(MemoSheet), findsOneWidget);
  });

  testWidgets('꾹 눌러 끌면 순서가 바뀌고 저장된다', (tester) async {
    final a = await tester.runAsync(() => repo.add('a'));
    await tester.runAsync(() => repo.add('b'));
    final c = await tester.runAsync(() => repo.add('c')); // 보드: c, b, a
    await pump(tester);
    final from = tester.getCenter(find.byKey(MemoCard.cardKey(a?.id ?? -1)));
    final to = tester.getCenter(find.byKey(MemoCard.cardKey(c?.id ?? -1)));
    final g = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() => repo.getActive());
    expect(saved?.map((m) => m.text).toList(), ['a', 'c', 'b']);
    expect(find.byType(MemoSheet), findsNothing, reason: '끄는 중에는 시트가 열리지 않는다');
  });

  for (final w in [320.0, 390.0, 430.0]) {
    testWidgets('${w.toInt()}pt에서 넘치지 않는다', (tester) async {
      await tester.runAsync(() async {
        for (final t in ['짧음', '아주 긴 메모 ' * 12, '날짜 있는 것']) {
          final m = await repo.add(t);
          if (t == '날짜 있는 것') {
            await repo.update(m.copyWith(memoDate: DateTime(2026, 10, 17)));
          }
        }
      });
      await pump(tester, width: w);
      expect(tester.takeException(), isNull);
    });
  }
}
