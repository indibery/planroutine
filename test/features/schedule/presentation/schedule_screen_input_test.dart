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
    await repo.insertConfirmedOrPending(
      Schedule(
        title: title,
        scheduledDate: date,
        kind: kind,
        createdAt: now,
        updatedAt: now,
      ),
    );
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
    // 사라진 `검토 대기 N` 칩을 기다리면 100회를 헛돌다 그대로 통과한다 —
    // 로딩이 끝났는지로 본다.
    bool loading() =>
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && loading(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
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

  group('일괄 확정을 종류별로 나눈다', () {
    // pill 라벨과 그 pill이 여는 다이얼로그가 **같은 낱말**을 써야 한다.
    // 한동안 pill만 `등록`이고 다이얼로그는 제목·본문·버튼이 전부 `확정`이었다 —
    // 버튼과 그 버튼이 여는 창이 서로 다른 이름을 부르는 상태였다.
    // `등록`은 CSV 가져오기 스낵바에서 **검토 대기로 넣기**를 가리키므로,
    // 확정에까지 쓰면 한 낱말이 파이프라인의 두 단계를 동시에 진다.
    test('pill 라벨은 다이얼로그와 같은 낱말을 쓴다', () {
      final label = ScheduleStrings.bulkConfirm(EntryKind.event.label, 2);

      // 낱말 일치는 이제 `bulkConfirm`이 `confirm`을 보간해 **구조로** 지킨다.
      // 여기서는 그 결과가 `등록`으로 돌아가지 않았는지만 본다 — 인자를 그대로
      // 흘리는지(`kindLabel`·`n`)는 시그니처가 이미 보장한다.
      expect(label, isNot(contains('등록')), reason: '`등록`은 검토 대기로 넣는 단계의 낱말이다');
    });

    testWidgets('업무·행사 대기가 있으면 pill이 각각 건수를 달고 보인다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('나이스 자료 정리', '2026-03-05', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      expect(
        find.text(ScheduleStrings.bulkConfirm(EntryKind.task.label, 2)),
        findsOneWidget,
      );
      expect(
        find.text(ScheduleStrings.bulkConfirm(EntryKind.event.label, 1)),
        findsOneWidget,
      );
    });

    // pill의 **존재 여부**는 문구가 아니라 Key로 본다. 문자열로 검사하면 라벨을
    // 한 번만 손봐도 findsNothing이 '0건' pill을 보고도 통과한다.
    testWidgets('업무 대기가 0이면 업무 pill은 숨는다', (tester) async {
      await tester.runAsync(() async {
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      expect(find.byKey(ScheduleScreen.bulkRegisterEventKey), findsOneWidget);
      expect(find.byKey(ScheduleScreen.bulkRegisterTaskKey), findsNothing);
    });

    testWidgets('행사 대기가 0이면 행사 pill은 숨는다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
      });
      await pumpScreen(tester);

      expect(find.byKey(ScheduleScreen.bulkRegisterTaskKey), findsOneWidget);
      expect(find.byKey(ScheduleScreen.bulkRegisterEventKey), findsNothing);
    });

    testWidgets('일괄 업무 확정은 업무만 확정한다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      await tester.tap(find.byKey(ScheduleScreen.bulkRegisterTaskKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, ScheduleStrings.confirm),
      );
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 && find.text('학급편성 결과 제출').evaluate().isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final pending = await tester.runAsync(
        () => repo.getSchedules(status: ScheduleStatus.pending),
      );
      expect(pending!.single.kind, EntryKind.event, reason: '행사는 대기로 남아야 한다');
    });
  });

  /// 종류 칩으로 목록을 좁히던 그룹이 여기 있었다. 칩이 없어졌으므로
  /// 대신 **두 종류가 한 목록에 함께 있다**는 것과 조작부가 둘뿐이라는 것을 지킨다.
  group('한 목록에서 함께 검토한다', () {
    testWidgets('업무와 행사가 같은 목록에 나란히 있다', (tester) async {
      // 기본 600pt 화면에서는 히어로(약 210pt)와 안내 바에 밀려 두 번째 달
      // 그룹이 뷰포트 밖으로 나간다 — 두 종류가 함께 있다는 것이 요지라 화면을
      // 키워서 본다. 좁은 폭에서의 넘침은 `visual_check` 도구가 따로 훑는다.
      tester.view.physicalSize = const Size(400 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
        await seed('과학의 달 행사', '2026-04-10', EntryKind.event);
      });
      await pumpScreen(tester);

      expect(find.text('학급편성 결과 제출'), findsOneWidget);
      expect(find.text('과학의 달 행사'), findsOneWidget);
    });

    testWidgets('목록 위 조작부는 일괄 삭제 pill 하나뿐이다', (tester) async {
      await tester.runAsync(() async {
        await seed('학급편성 결과 제출', '2026-03-02', EntryKind.task);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.deletePending(1)), findsOneWidget);
      // 상태·종류·카테고리 칩과 `필터` 토글이 모두 없다.
      for (final gone in ['필터', '전체', '확정됨']) {
        expect(find.text(gone), findsNothing, reason: '$gone 조작부는 없앴다');
      }
    });
  });
}
