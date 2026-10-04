import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/memo/presentation/screens/memo_board_screen.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_calendar_card.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_card.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_sheet.dart';

import '../../../helpers/test_database.dart';

/// 포스트잇의 누를 수 있는 것들은 **이름 있는 버튼**으로 읽혀야 한다.
///
/// 보드의 쪽지는 두 시뮬레이터 자동화 도구 모두에서 글자(`교실 환기 확인 10.4 (일)`)로만
/// 잡혀 누를 대상으로 보이지 않았다(2026-10-04 실측).
///
/// 시트의 `날짜 삭제`는 mobile MCP에서만 날짜 줄에 합쳐져 보였다. Flutter 트리에서는
/// 원래부터 따로 된 버튼이라 아래 검사는 **고치기 전에도 통과했다** — 도구 쪽 현상이고,
/// 이 검사는 그 구조를 지키는 가드로만 둔다.
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

  group('memoCardSemanticsLabel', () {
    test('글만 있으면 글', () {
      expect(memoCardSemanticsLabel(const Memo(text: '교실 환기 확인')), '교실 환기 확인');
    });

    test('날짜가 붙어 있으면 날짜를 뒤에 붙인다', () {
      expect(
        memoCardSemanticsLabel(
          Memo(text: '교실 환기 확인', memoDate: DateTime(2026, 10, 4)),
        ),
        '교실 환기 확인, 10월 4일 (일)',
      );
    });
  });

  testWidgets('보드의 쪽지가 버튼이고 시맨틱스 탭이 시트를 연다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.runAsync(() => repo.add('교실 환기 확인'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MemoBoardScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('교실 환기 확인')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('교실 환기 확인'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoSheet), findsOneWidget);
    handle.dispose();
  });

  testWidgets('캘린더의 쪽지 카드가 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoCalendarCard(
            memo: const Memo(id: 1, text: '교실 환기 확인'),
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    const label = '교실 환기 확인, ${MemoStrings.calendarBadge}';
    expect(
      tester.getSemantics(find.bySemanticsLabel(label)),
      isSemantics(isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel(label));
    expect(tapped, 1);
    handle.dispose();
  });

  testWidgets('시트의 날짜 삭제가 날짜 줄과 따로 누를 수 있는 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    final memo = await tester.runAsync(() async {
      final x = await repo.add('날짜');
      await repo.update(x.copyWith(memoDate: DateTime(2026, 10, 17)));
      return (await repo.getActive()).single;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoRepositoryProvider.overrideWithValue(repo),
          calendarRepositoryProvider.overrideWithValue(
            CalendarRepository(dbHelper: db),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    MemoSheet.show(context, memo ?? const Memo(text: '')),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final remove = tester.getSemantics(
      find.bySemanticsLabel(MemoStrings.dateRemove),
    );
    expect(remove, isSemantics(isButton: true, hasTapAction: true));
    final row = tester.getSemantics(find.byKey(MemoSheet.dateRowKey));
    expect(remove.id, isNot(row.id), reason: '날짜 삭제가 날짜 줄 노드에 합쳐지면 따로 못 누른다');
    expect(row.label, isNot(contains(MemoStrings.dateRemove)));
    handle.dispose();
  });
}
