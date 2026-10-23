// test/features/memo/presentation/memo_board_screen_test.dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo_color.dart';
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

  Future<void> pump(WidgetTester tester, {double width = 390, math.Random? random}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoRepositoryProvider.overrideWithValue(repo),
          if (random != null) memoColorRandomProvider.overrideWithValue(random),
        ],
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

  testWidgets('날짜를 붙이지 않은 쪽지에는 만든 날이 보이지 않는다 — 붙인 날짜만 보인다', (tester) async {
    // 실기기 피드백(2026-10-24): 쪽지 밑의 만든 날(10.24)은 뜻이 없다.
    await tester.runAsync(() => repo.add('날짜 없음'));
    await tester.runAsync(() => repo.add('날짜 있음', memoDate: DateTime(2026, 10, 23)));
    await pump(tester);
    final now = DateTime.now();
    expect(find.text('${now.month}.${now.day}'), findsNothing);
    expect(find.text('10.23 (금)'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });

  testWidgets('만든 날은 보이지 않고, 붙인 날짜는 쪽지 오른쪽 아래에 붙는다', (tester) async {
    // 실기기 피드백(2026-10-24): 쪽지 밑의 만든 날(10.13)은 뜻이 없고, 붙인 날짜는 오른쪽 아래에 고정.
    await tester.runAsync(() => repo.add('날짜 없음'));
    await tester.runAsync(() => repo.add('날짜 있음', memoDate: DateTime(2026, 10, 23)));
    await pump(tester);
    final now = DateTime.now();
    expect(find.text('${now.month}.${now.day}'), findsNothing, reason: '만든 날이 보인다');
    final date = find.text('10.23 (금)');
    expect(date, findsOneWidget);
    final card = tester.getRect(find.ancestor(of: date, matching: find.byType(MemoCard)));
    expect(card.bottom - tester.getRect(date).bottom, lessThan(16), reason: '날짜가 아래에 붙지 않았다');
    expect(card.right - tester.getRect(date).right, lessThan(16), reason: '날짜가 오른쪽에 붙지 않았다');
  });

  Future<void> settleDb(WidgetTester tester) async {
    // 저장 → 신호 → 다시 읽기, DB I/O가 두 번이라 여러 번 비워 준다
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('오른쪽 아래 +로 시트를 열어 쓰고 저장하면 맨 앞에 쪽지가 생긴다', (tester) async {
    await tester.runAsync(() => repo.add('예전 것'));
    await pump(tester);
    await tester.tap(find.byKey(MemoBoardScreen.addKey));
    await tester.pumpAndSettle();
    expect(find.byType(MemoSheet), findsOneWidget);
    await tester.enterText(find.byKey(MemoSheet.textKey), '새 메모');
    await tester.tap(find.byKey(MemoSheet.saveKey));
    await settleDb(tester);
    expect(find.byType(MemoSheet), findsNothing, reason: '저장하면 닫힌다');
    final first = tester.getTopLeft(find.text('새 메모'));
    final old = tester.getTopLeft(find.text('예전 것'));
    expect(first.dx < old.dx || first.dy < old.dy, isTrue);
  });

  testWidgets('빈 글로 저장하면 쪽지가 생기지 않는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(MemoBoardScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(MemoSheet.textKey), '   ');
    await tester.tap(find.byKey(MemoSheet.saveKey));
    await settleDb(tester);
    expect(await tester.runAsync(() => repo.getActive()), isEmpty);
  });

  testWidgets('보드에는 줄글 입력칸이 없다 — 쓰기는 +로 여는 쪽지에서 한다', (tester) async {
    await pump(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(MemoBoardScreen.addKey), findsOneWidget);
  });

  testWidgets('+로 연 새 쪽지는 맨 앞 쪽지와 다른 색으로 저장된다', (tester) async {
    await tester.runAsync(() => repo.add('맨 앞 노랑')); // 저장소 기본은 노랑
    await pump(tester, random: math.Random(5));
    await tester.tap(find.byKey(MemoBoardScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(MemoSheet.textKey), '새 색');
    await tester.tap(find.byKey(MemoSheet.saveKey));
    await settleDb(tester);
    final saved = await tester.runAsync(() => repo.getActive());
    final created = saved?.firstWhere((m) => m.text == '새 색');
    expect(created?.color, isNot(MemoColor.yellow));
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
