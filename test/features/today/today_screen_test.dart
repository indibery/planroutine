import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/utils/date_utils.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:planroutine/features/today/presentation/providers/today_providers.dart';
import 'package:planroutine/features/today/presentation/screens/today_screen.dart';
import 'package:planroutine/features/today/presentation/widgets/today_body.dart';
import 'package:planroutine/shared/widgets/gold_fab.dart';

import '../../helpers/test_database.dart';

final _today = DateTime(2026, 7, 25);

void main() {
  setUpAll(() async {
    setUpFfiForTests();
    await initializeDateFormatting('ko_KR', null);
  });

  late DatabaseHelper db;
  late CalendarRepository repository;

  setUp(() {
    db = freshDatabaseHelper();
    repository = CalendarRepository(dbHelper: db);
  });

  tearDown(() async => db.close());

  /// 조건이 참이 될 때까지 실제 시간을 흘려보낸다.
  ///
  /// FFI DB 조회는 진짜 비동기라 testWidgets의 fake-async 안에서는 완료되지 않는다.
  /// 그대로 pumpAndSettle하면 로딩 인디케이터가 영원히 돌아 10분 타임아웃에 걸린다.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(repository),
          todayReferenceProvider.overrideWithValue(_today),
        ],
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await waitFor(tester, find.byType(TodayBody));
    await tester.pumpAndSettle();
  }

  group('오늘 탭 화면 — 다른 탭과 구조 통일', () {
    testWidgets('제목은 본문이 아니라 AppBar에 있다', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(TodayStrings.title),
        ),
        findsOneWidget,
      );
    });
  });

  group('오늘 탭 화면 — 일정 등록', () {
    testWidgets('골드 FAB가 있다', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(GoldFab), findsOneWidget);
    });

    testWidgets('FAB를 누르면 일정 등록 시트가 열린다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byType(GoldFab));
      await tester.pump();
      await waitFor(tester, find.byType(EventEditDialog));

      expect(find.byType(EventEditDialog), findsOneWidget);
    });
  });

  group('오늘 탭 화면 — 목록', () {
    testWidgets('오늘 이벤트가 보인다', (tester) async {
      // seed도 실제 DB I/O라 runAsync 안에서 해야 한다.
      // fake-async 존에서 그냥 await하면 완료되지 않아 테스트가 멈춘다.
      await tester.runAsync(() async {
        await repository.createEvent(
          CalendarEvent(title: '학년 협의회 자료 준비', eventDate: formatDate(_today)),
        );
      });

      await pumpScreen(tester);

      expect(find.text('학년 협의회 자료 준비'), findsOneWidget);
    });
  });
}
