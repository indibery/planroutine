// test/shared/main_shell_snack_fab_test.dart
//
// 탭 화면의 알림(스낵바)이 그 화면의 + 버튼을 덮지 않는다.
//
// Flutter는 Scaffold가 겹쳐 있으면 스낵바를 **가장 바깥 Scaffold에만** 띄운다
// (`ScaffoldMessengerState._isRoot`). 바깥이 탭바를 가진 `MainShell`이고 + 버튼은
// 탭 화면 안쪽 Scaffold에 있어, 스낵바가 떠도 버튼이 비키지 않고 4초 동안 덮였다
// (시뮬레이터 실측 2026-11-03, 캘린더에서 포스트잇을 일정으로 등록한 직후).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/memo/presentation/widgets/memo_sheet.dart';
import 'package:planroutine/shared/widgets/main_shell.dart';

import '../helpers/test_database.dart';

const _fabKey = Key('tab_fab');
const _tabScaffoldKey = Key('tab_scaffold');

/// 탭 화면 하나를 `MainShell` 안에 띄운다 — 실제 앱처럼 ShellRoute로 감싼다.
Widget _shell({
  required Widget Function(BuildContext) body,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.today,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.today,
            builder: (context, state) => Scaffold(
              key: _tabScaffoldKey,
              body: Builder(builder: body),
              floatingActionButton: FloatingActionButton(
                key: _fabKey,
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// 스낵바의 **보이는 면**. `SnackBar`의 rect는 margin까지 포함한 레이아웃 영역이라
/// 화면 맨 아래까지 뻗는다 — 그것을 재면 정상도 겹침으로 읽힌다(CLAUDE.md 입력 탭 절).
Rect _snackSurface(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
      .first,
);

void _expectFabClear(WidgetTester tester) {
  expect(find.byType(SnackBar), findsOneWidget);
  final fab = tester.getRect(find.byKey(_fabKey));
  final snack = _snackSurface(tester);
  expect(
    fab.bottom <= snack.top,
    isTrue,
    reason: '+ 버튼($fab)이 스낵바($snack) 위로 비켜야 한다',
  );
  expect(
    find.descendant(
      of: find.byKey(_tabScaffoldKey),
      matching: find.byType(SnackBar),
    ),
    findsOneWidget,
    reason: '스낵바는 + 버튼이 있는 탭 화면의 Scaffold에 떠야 버튼이 비킨다',
  );
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);

  testWidgets('탭 화면에서 띄운 스낵바는 + 버튼을 덮지 않는다', (tester) async {
    await tester.pumpWidget(
      _shell(
        body: (context) => Center(
          child: TextButton(
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('알림'))),
            child: const Text('띄우기'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('띄우기'));
    await tester.pumpAndSettle();
    _expectFabClear(tester);
  });

  group('포스트잇 시트 — 탭바 위(루트 내비게이터)에 뜨는 시트', () {
    late DatabaseHelper db;
    late MemoRepository repo;
    setUp(() {
      db = freshDatabaseHelper();
      repo = MemoRepository(dbHelper: db);
    });
    tearDown(() async => db.close());

    testWidgets('떼고 닫힌 뒤의 스낵바가 연 화면의 + 버튼을 덮지 않는다', (tester) async {
      final memo =
          await tester.runAsync(() => repo.add('뗄 것')) ?? const Memo(text: '');
      await tester.pumpWidget(
        _shell(
          overrides: [
            memoRepositoryProvider.overrideWithValue(repo),
            calendarRepositoryProvider.overrideWithValue(
              CalendarRepository(dbHelper: db),
            ),
          ],
          body: (context) => Center(
            child: TextButton(
              onPressed: () => MemoSheet.show(context, memo),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MemoSheet.removeKey));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(MemoSheet), findsNothing);
      _expectFabClear(tester);
    });
  });
}
