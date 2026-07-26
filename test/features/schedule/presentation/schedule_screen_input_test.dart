import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/import/presentation/widgets/photo_input_hero.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:planroutine/features/schedule/presentation/widgets/schedule_filter_bar.dart';

import '../../../helpers/test_database.dart';

/// 입력 탭 — 넣기가 주인공, 검토는 그 아래.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  late CalendarRepository calendarRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    calendarRepo = CalendarRepository(dbHelper: db);
  });

  tearDown(() async => db.close());

  Future<void> seed(String title, String date, EntryKind kind) async {
    final now = DateTime.now().toIso8601String();
    await repo.insertConfirmedOrPending(Schedule(
      title: title,
      scheduledDate: date,
      kind: kind,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(repo),
          calendarRepositoryProvider.overrideWithValue(calendarRepo),
        ],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    bool chipHasCount() => find
        .byWidgetPredicate(
            (w) => w is Text && (w.data?.startsWith('검토 대기 ') ?? false))
        .evaluate()
        .isNotEmpty;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !chipHasCount(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  /// 필터는 접힘이 기본 — 칩을 만지는 테스트는 먼저 펼친다.
  Future<void> expandFilters(WidgetTester tester) async {
    if (find.byKey(ScheduleFilterBar.chipRowsKey).evaluate().isEmpty) {
      await tester.tap(find.byKey(ScheduleFilterBar.toggleKey));
      await tester.pumpAndSettle();
    }
  }

  group('입력이 주인공', () {
    testWidgets('화면 제목은 입력이고 사진 히어로가 맨 위에 있다', (tester) async {
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.title), findsOneWidget);
      expect(find.text('INPUT'), findsOneWidget);
      expect(find.byType(PhotoInputHero), findsOneWidget);
    });

    testWidgets('AppBar의 가져오기 아이콘은 사라지고 보조 링크가 그 역할을 한다', (tester) async {
      await pumpScreen(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.file_download_outlined),
        ),
        findsNothing,
      );
      expect(find.text(ImportStrings.heroCsvLink), findsOneWidget);
    });
  });

  group('일괄 등록을 종류별로 나눈다', () {
    testWidgets('업무·행사 대기가 있으면 pill이 각각 건수를 달고 보인다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('나이스 자료 정리', '2026-03-05', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.bulkRegisterTask(2)), findsOneWidget);
      expect(find.text(ScheduleStrings.bulkRegisterEvent(1)), findsOneWidget);
    });

    testWidgets('해당 종류 대기가 0이면 그 pill은 숨는다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.bulkRegisterTask(1)), findsOneWidget);
      // 건수까지 특정하면 가드가 깨져 '…0건'으로 렌더돼도 findsNothing이 통과해버린다
      // (0건은 이 매처가 찾는 문자열과 다르므로). 접두만 봐서 pill의 존재 자체를 검사한다.
      expect(
        find.textContaining(ScheduleStrings.bulkRegisterEventPrefix),
        findsNothing,
      );
    });

    testWidgets('일괄 업무 등록은 업무만 확정한다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      await tester.tap(find.text(ScheduleStrings.bulkRegisterTask(1)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, ScheduleStrings.confirm),
      );
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 && find.text('학급편성 결과 제출').evaluate().isNotEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final pending = await tester.runAsync(
        () => repo.getSchedules(status: ScheduleStatus.pending),
      );
      expect(pending!.single.kind, EntryKind.event,
          reason: '행사는 대기로 남아야 한다');
    });
  });

  group('종류 필터', () {
    testWidgets('행사 칩을 누르면 업무가 빠진다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);
      await expandFilters(tester);

      // 대기 뷰에서는 칩에 건수가 붙는다 — '행사 1'.
      // '행사' ⊂ '학교행사'라 부분 일치로 찾으면 카테고리 칩(에듀파인 분류명)과
      // 충돌할 수 있다 — 건수까지 포함한 정확 매칭으로 칩 자체를 특정한다.
      await tester.tap(find.text('${EntryKind.event.label} 1'));
      // 필터 변경 → 실제 DB 재조회. 로딩 스피너가 남은 채 pumpAndSettle하면
      // fake-async가 DB future를 못 끝내 영원히 안 멎는다 → runAsync에서 대기.
      await tester.runAsync(() async {
        for (var i = 0;
            i < 100 &&
                (find.text('과학의 달 행사').evaluate().isEmpty ||
                    find
                        .byType(CircularProgressIndicator)
                        .evaluate()
                        .isNotEmpty);
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      expect(find.text('과학의 달 행사'), findsOneWidget);
      expect(find.text('학급편성 결과 제출'), findsNothing);
    });
  });
}
