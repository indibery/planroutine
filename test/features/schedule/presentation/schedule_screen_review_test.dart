// 입력 탭 검토 영역 — **검토 대기만 보여준다.**
//
// 2026-09-03에 단순화했다(사용자 요청). 그 전에는 한 화면에 조작부가 넷이었다:
// 상태 칩(`검토 대기 N`/`확정됨 N`) · 종류 칩(`업무`/`행사`) · 카테고리 칩
// (`전체`/`일과운영`/…) · 접히는 `필터` 토글. 거기에 진행도 바와
// `확정됨 N건 보기` 링크까지 겹쳐 "무엇이 지금 목록을 정하는지" 읽기 어려웠다.
//
// 지금은 목록이 **항상 대기**다. 확정하면 캘린더로 넘어가고 이 목록에서 빠진다.
//
// ⚠️ **행을 지우는 것이 아니다.** `schedules` 행은 그대로 남는다 — 지우면 세 곳이
// 함께 깨진다: CSV 내보내기(`status='confirmed'`로 조회) · `작년` 배지
// (`calendar_events.schedule_id` → `schedules.source_id` 조인) · 중복 체크
// (`title`+`scheduled_date`). 아래 마지막 두 가드가 그 전제를 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/schedule/presentation/screens/schedule_screen.dart';

import '../../../helpers/test_database.dart';

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

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(
    String title,
    String date,
    ScheduleStatus status, {
    String? category,
    EntryKind kind = EntryKind.task,
  }) async {
    final now = DateTime.now().toIso8601String();
    await repo.insertConfirmedOrPending(
      Schedule(
        title: title,
        scheduledDate: date,
        status: status,
        category: category,
        kind: kind,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repo),
        calendarRepositoryProvider.overrideWithValue(calendarRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 화면을 띄우고 **비동기 조회가 끝날 때까지** 기다린다.
  ///
  /// 필터 토글을 눌러 칩을 펼치던 단계는 없어졌다 — 펼칠 칩이 없다.
  /// 대기 조건도 `검토 대기 N` 칩이 아니라 **로딩이 끝났는지**로 바꿨다. 그 칩은
  /// 사라졌고, 사라진 문자열을 기다리면 100회를 헛돌다 그대로 통과한다.
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

  group('입력 탭 검토 영역 — 대기만 보여준다', () {
    test('목록 조회는 항상 검토 대기다 — 상태 필터라는 개념이 없다', () async {
      await seed('대기 업무', '2026-03-02', ScheduleStatus.pending);
      await seed('확정된 업무', '2026-03-03', ScheduleStatus.confirmed);

      final container = makeContainer();
      final list = await container.read(schedulesProvider.future);

      expect(list.map((s) => s.title), ['대기 업무']);
      expect(
        list.every((s) => s.status == ScheduleStatus.pending),
        isTrue,
        reason: '확정된 항목이 섞이면 "검토 대기만"이 깨진다',
      );
    });

    test('확정하면 목록에서 빠진다 — 캘린더로 넘어갔기 때문', () async {
      await seed('검토할 업무', '2026-03-02', ScheduleStatus.pending);
      final container = makeContainer();
      final before = await container.read(schedulesProvider.future);
      expect(before, hasLength(1));
      final id = before.single.id!;

      await container
          .read(schedulesProvider.notifier)
          .updateStatus(id, ScheduleStatus.confirmed);
      final after = await container.read(schedulesProvider.future);

      expect(after, isEmpty, reason: '확정된 것은 이 목록의 관심 밖이다');
    });

    test('확정해도 schedules 행은 살아 있다 — CSV 내보내기의 전제', () async {
      await seed('검토할 업무', '2026-03-02', ScheduleStatus.pending);
      final container = makeContainer();
      final id = (await container.read(schedulesProvider.future)).single.id!;

      await container
          .read(schedulesProvider.notifier)
          .updateStatus(id, ScheduleStatus.confirmed);

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.map((s) => s.title), ['검토할 업무']);
      expect(
        confirmed.single.deletedAt,
        isNull,
        reason:
            '내보내기는 `status=confirmed AND deleted_at IS NULL`로 조회한다 — '
            '여기서 soft-delete하면 내보내기가 0건이 된다',
      );
    });

    test('확정된 행이 중복 체크에 계속 걸린다 — 재임포트가 사본을 만들지 않는다', () async {
      await seed('학급편성 결과 제출', '2026-03-02', ScheduleStatus.confirmed);

      // 같은 제목·날짜를 다시 넣으면 중복으로 걸러져야 한다.
      final inserted = await repo.insertConfirmedOrPending(
        const Schedule(title: '학급편성 결과 제출', scheduledDate: '2026-03-02'),
      );

      expect(
        inserted,
        -1,
        reason:
            '확정 행을 지웠다면 이 검사가 통과해(새 row id) '
            '같은 CSV가 매번 사본을 만든다',
      );
    });

    testWidgets('기본 뷰: 대기만 보이고 확정은 안 보인다', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 업무', '2026-03-02', ScheduleStatus.pending);
        await seed('확정된 업무', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      expect(find.text('대기 업무'), findsOneWidget);
      expect(find.text('확정된 업무'), findsNothing);
    });

    testWidgets('확정된 항목을 볼 수 있는 경로가 없다', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 업무', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      // 상태 칩·확정 요약·보기 링크가 모두 없어졌다. 하나라도 살아 있으면
      // "검토 대기만"이라는 약속이 화면에서 깨진다.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('확정됨') ?? false),
        ),
        findsNothing,
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('필터 칩·요약·토글이 없다', (tester) async {
      await tester.runAsync(() async {
        await seed(
          '대기 업무',
          '2026-03-02',
          ScheduleStatus.pending,
          category: '학생학적관리',
        );
      });
      await pumpScreen(tester);

      // ⚠️ 이 문자열들은 상수와 함께 **lib에서 삭제됐다** — 다른 문안
      // (`필터링`·`분류`)으로 필터를 되살리면 이 루프는 통과한다.
      // **문안 회귀 감지용**이고, 반증 가능한 무게는 아래 `FractionallySizedBox`
      // 부재와 `확정된 항목을 볼 수 있는 경로가 없다`의 `TextButton` 부재가 진다.
      for (final gone in ['필터', '전체', '일과운영', '교육과정', '조직통계', '학생학적']) {
        expect(find.text(gone), findsNothing, reason: '$gone — 필터 조작부는 전부 없앴다');
      }
    });

    testWidgets('진행도 바가 없다 — 확정 건수를 아는 유일한 장식이었다', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 업무', '2026-03-02', ScheduleStatus.pending);
        await seed('확정된 업무', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      // 진행도 바는 `lib/` 전체에서 유일한 `FractionallySizedBox`였다.
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('목록 행에 카테고리 배지가 없다', (tester) async {
      await tester.runAsync(() async {
        await seed(
          '학급편성 결과 제출',
          '2026-03-02',
          ScheduleStatus.pending,
          category: '학생학적관리',
        );
      });
      await pumpScreen(tester);

      expect(find.text('학급편성 결과 제출'), findsOneWidget);
      // ⚠️ **원본 값으로 검사한다.** `학생학적`(축약형)은 삭제된
      // `shortenCategory()`만 만들던 문자열이라, 그것만 보면 행에
      // `Text(schedule.category)`를 그대로 되살려도 통과한다(실증됨).
      for (final shown in ['학생학적관리', '학생학적']) {
        expect(
          find.textContaining(shown),
          findsNothing,
          reason: '행에 남는 것은 종류 배지·제목·날짜뿐이다 (`$shown` 발견)',
        );
      }
    });

    testWidgets('대기가 없으면 빈 상태 문구 하나만', (tester) async {
      await tester.runAsync(() async {
        await seed('확정된 업무', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.empty), findsOneWidget);
      // 넣기 CTA를 여기 다시 세우지 않는다 — 히어로가 바로 위에 있다.
      // (`ScheduleStrings.goImport`로 검사하던 단정은 지웠다. 그 문자열을
      //  렌더하는 곳이 없어 `findsNothing`이 **반증 불가**했다.)
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('AppBar에는 가져오기 아이콘을 두지 않는다 (히어로 보조 링크로 대체)', (tester) async {
      await pumpScreen(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.file_download_outlined),
        ),
        findsNothing,
      );
    });

    testWidgets('일괄 삭제 pill: 대기 있으면 노출', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 A', '2026-03-02', ScheduleStatus.pending);
        await seed('대기 B', '2026-03-03', ScheduleStatus.pending);
      });
      await pumpScreen(tester);

      expect(find.text(ScheduleStrings.deletePending(2)), findsOneWidget);
      // 확정은 하단 종류별 일괄 확정 pill로 옮겼다.
      expect(
        find.text(ScheduleStrings.bulkConfirm(EntryKind.task.label, 2)),
        findsOneWidget,
      );
    });

    testWidgets('스낵바가 하단 일괄 확정 pill을 가리지 않는다', (tester) async {
      // 사용자 신고 2026-08-14, **2026-09-03 재신고**. 값(behavior·margin)이 아니라
      // **두 사각형이 겹치는지**를 잰다 — 신고된 증상이 "가린다"이기 때문이다.
      //
      // 여기 걸리는 스낵바는 ← 스와이프 삭제의 `되돌리기`다. 가려지면 되돌릴
      // 방법 자체가 없어져, 단순히 안 보이는 것보다 나쁘다.
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await seed('지울 업무', '2026-03-02', ScheduleStatus.pending);
        await seed('남을 업무', '2026-03-03', ScheduleStatus.pending);
      });
      await pumpScreen(tester);

      // ← 스와이프로 삭제 → 되돌리기 스낵바가 뜬다.
      await tester.drag(find.text('지울 업무'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget, reason: '스낵바가 떠야 이 가드가 의미가 있다');
      // ⚠️ **`find.byType(SnackBar)`를 재면 안 된다.** 그건 margin을 포함한
      // 레이아웃 영역이라 floating이어도 화면 맨 아래까지 뻗는다
      // (실측 `LTRB(0, 736, 390, 844)`). 실제로 보이는 면은 그 안의 첫 `Material`
      // 이다(`LTRB(8, 736, 382, 784)`). 바깥 상자를 재면 정상인 코드를 버그로
      // 오진한다 — 날짜 선택 대비 가드가 "칠하는 짝이 아닌 짝"을 쟀던 것과 같다.
      final snackRect = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final pillRect = tester.getRect(
        find.byKey(ScheduleScreen.bulkRegisterTaskKey),
      );

      expect(
        snackRect.overlaps(pillRect),
        isFalse,
        reason:
            '스낵바($snackRect)가 일괄 확정 pill($pillRect)과 겹친다 — '
            '스낵바가 떠 있는 4초 동안 확정을 누를 수 없다',
      );

      // 기하만으로는 부족하다 — 겹치지 않아도 히트테스트가 막히면 못 누른다.
      // 사용자가 신고한 그대로 **스낵바가 떠 있는 동안 확정을 눌러 본다.**
      await tester.tap(find.byKey(ScheduleScreen.bulkRegisterTaskKey));
      await tester.pumpAndSettle();
      expect(
        find.text(ScheduleStrings.bulkConfirmTitle),
        findsOneWidget,
        reason: '스낵바가 떠 있는 동안에도 일괄 확정이 눌려야 한다',
      );
      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await tester.pumpAndSettle();

      // 되돌리기 액션 자체가 눌리는지는 `test/shared/bulk_bar_snack_test.dart`가
      // 지킨다 — 여기서 이어 누르면 다이얼로그를 여닫는 사이 스낵바가 만료돼
      // 시간 의존 테스트가 된다. 이 테스트는 신고된 증상(확정을 못 누른다)에 붙는다.
    });

    testWidgets('삭제 pill의 건수가 실제로 지워지는 범위와 같다', (tester) async {
      // **종류를 섞어** 심는다. 섞지 않으면 pill이 종류로 좁혀도 건수가 같아
      // 어긋남이 드러나지 않는다 — 그래서 기존 삭제 테스트 둘이 이 회귀를
      // 놓쳤다(실증: pill 건수를 `kind == task`로 좁혀도 22건 전부 green).
      //
      // 지키는 것: `행사 4건 삭제`를 눌러 대기 21건이 전부 휴지통으로 가고
      // 스낵바는 `4건을 옮겼어요`라 말한 그 버그(CLAUDE.md 기념비).
      await tester.runAsync(() async {
        await seed('업무 A', '2026-03-02', ScheduleStatus.pending);
        await seed('업무 B', '2026-03-03', ScheduleStatus.pending);
        await seed(
          '행사 C',
          '2026-03-04',
          ScheduleStatus.pending,
          kind: EntryKind.event,
        );
      });
      await pumpScreen(tester);

      // pill이 약속한 수 = 대기 전체 3건.
      expect(find.text(ScheduleStrings.deletePending(3)), findsOneWidget);

      await tester.tap(find.text(ScheduleStrings.deletePending(3)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.delete));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 && find.text('업무 A').evaluate().isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      // 스낵바는 **DB가 옮긴 수**를 말한다 — 화면이 센 수가 아니다.
      expect(
        find.text(ScheduleStrings.bulkDeletedSnack(3)),
        findsOneWidget,
        reason: 'pill이 3건이라 했으면 3건이 옮겨졌다고 말해야 한다',
      );
      final trashed = await tester.runAsync(repo.getDeletedSchedules);
      expect(
        trashed!.map((s) => s.title).toList()..sort(),
        ['업무 A', '업무 B', '행사 C'],
        reason: '한쪽만 종류로 좁히면 여기서 건수가 갈린다',
      );
    });

    testWidgets('일괄 삭제 → 대기는 휴지통으로, 확정은 유지', (tester) async {
      await tester.runAsync(() async {
        await seed('대기 A', '2026-03-02', ScheduleStatus.pending);
        await seed('확정 B', '2026-03-03', ScheduleStatus.confirmed);
      });
      await pumpScreen(tester);

      await tester.tap(find.text(ScheduleStrings.deletePending(1)));
      await tester.pumpAndSettle();
      expect(find.text(ScheduleStrings.bulkDeleteTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, ScheduleStrings.delete));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 && find.text('대기 A').evaluate().isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      expect(find.text('대기 A'), findsNothing);
      // 확정된 항목은 애초에 이 목록에 없다 — 삭제 대상이 아니었음을 DB로 확인한다.
      final confirmed = await tester.runAsync(
        () => repo.getSchedules(status: ScheduleStatus.confirmed),
      );
      expect(confirmed!.map((s) => s.title), ['확정 B']);
    });
  });
}
