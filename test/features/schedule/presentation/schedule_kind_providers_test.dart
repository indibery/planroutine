// 입력 탭 목록·일괄 확정/삭제가 의존하는 프로바이더 계약.
//
// 2026-09-03에 **필터가 전부 없어졌다**(사용자 요청). 그 전 이 파일은
// `scheduleKindFilterProvider`·`scheduleCategoryFilterProvider`·
// `scheduleCountsProvider`를 검사했는데 셋 다 사라졌다. 지금 남은 계약은 둘이다:
//
//   ① 목록은 **항상 검토 대기**다 — 확정·휴지통은 섞이지 않는다.
//   ② 일괄 확정은 **종류별**(하단 pill 둘), 일괄 삭제는 **대기 전체**다.
//      범위 조립이 `_updateAllPending` 한 곳이라 둘이 어긋날 수 없다.
//
// ⚠️ 종류는 필터가 아니라 **눌린 pill**에서 온다. 그래서 `confirmAllPending(kind:)`은
// 남고 `deleteAllPending()`은 인자가 없다 — 비대칭으로 보이지만 화면이 그렇다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;
  late CalendarRepository calendarRepo;
  late ProviderContainer container;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
    calendarRepo = CalendarRepository(dbHelper: db);
    container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repo),
        calendarRepositoryProvider.overrideWithValue(calendarRepo),
      ],
    );

    // 업무 2 + 행사 1.
    await repo.insertConfirmedOrPending(
      const Schedule(title: '학급편성 결과 제출', scheduledDate: '2026-03-02'),
    );
    await repo.insertConfirmedOrPending(
      const Schedule(title: '나이스 자료 정리', scheduledDate: '2026-03-05'),
    );
    await repo.insertConfirmedOrPending(
      const Schedule(
        title: '과학의 달 행사',
        scheduledDate: '2026-04-10',
        kind: EntryKind.event,
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('검토 대기 목록 — 필터가 없다', () {
    test('목록은 항상 대기다 — 확정도 휴지통도 섞이지 않는다', () async {
      final all = await repo.getSchedules();
      await repo.updateStatus(all.first.id!, ScheduleStatus.confirmed);
      await repo.deleteSchedule(all[1].id!);

      final list = await container.read(schedulesProvider.future);

      expect(list.map((s) => s.title), ['과학의 달 행사']);
    });

    test('확정하면 목록에서 빠진다', () async {
      final before = await container.read(schedulesProvider.future);
      expect(before, hasLength(3));

      await container
          .read(schedulesProvider.notifier)
          .updateStatus(before.first.id!, ScheduleStatus.confirmed);

      final after = await container.read(schedulesProvider.future);
      expect(after, hasLength(2));
      expect(after.map((s) => s.title), isNot(contains('학급편성 결과 제출')));
    });

    test('대기로 되돌리면 목록에 다시 나타난다', () async {
      final before = await container.read(schedulesProvider.future);
      final id = before.first.id!;
      final notifier = container.read(schedulesProvider.notifier);

      await notifier.updateStatus(id, ScheduleStatus.confirmed);
      expect(await container.read(schedulesProvider.future), hasLength(2));

      await notifier.updateStatus(id, ScheduleStatus.pending);
      expect(await container.read(schedulesProvider.future), hasLength(3));
    });

    test('휴지통으로 보내면 빠지고, 복구하면 돌아온다', () async {
      final before = await container.read(schedulesProvider.future);
      final id = before.first.id!;
      final notifier = container.read(schedulesProvider.notifier);

      await notifier.deleteSchedule(id);
      expect(await container.read(schedulesProvider.future), hasLength(2));

      await notifier.restoreSchedule(id);
      expect(await container.read(schedulesProvider.future), hasLength(3));
    });
  });

  group('종류별 일괄 확정', () {
    test('업무만 확정하면 행사는 대기로 남는다', () async {
      await container.read(schedulesProvider.future);
      await container
          .read(schedulesProvider.notifier)
          .confirmAllPending(kind: EntryKind.task);

      final pending = await repo.getSchedules(status: ScheduleStatus.pending);
      expect(pending.single.kind, EntryKind.event);
    });

    test('확정한 업무만 캘린더 이벤트가 생긴다', () async {
      await container.read(schedulesProvider.future);
      await container
          .read(schedulesProvider.notifier)
          .confirmAllPending(kind: EntryKind.task);

      final events = await calendarRepo.getEventsByDateRange(
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );
      expect(events, hasLength(2));
      expect(events.every((e) => e.kind == EntryKind.task), isTrue);
    });

    test('확정 후 목록에는 행사만 남는다 — 확정분이 사라진 게 아니라 넘어갔다', () async {
      await container.read(schedulesProvider.future);
      await container
          .read(schedulesProvider.notifier)
          .confirmAllPending(kind: EntryKind.task);

      final list = await container.read(schedulesProvider.future);
      expect(list.map((s) => s.title), ['과학의 달 행사']);
      // 넘어간 쪽은 캘린더에 있고 `schedules` 행도 살아 있다.
      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed, hasLength(2));
    });

    test('kind 없이 부르면 대기 전체가 확정된다', () async {
      await container.read(schedulesProvider.future);
      await container.read(schedulesProvider.notifier).confirmAllPending();

      expect(await container.read(schedulesProvider.future), isEmpty);
    });
  });

  group('종류별 일괄 삭제 — 확정과 대칭', () {
    test('대기 전체가 삭제된다 — 좁힐 인자가 없다', () async {
      await container.read(schedulesProvider.future);

      await container.read(schedulesProvider.notifier).deleteAllPending();

      expect(await repo.getSchedules(status: ScheduleStatus.pending), isEmpty);
      expect(await repo.getDeletedSchedules(), hasLength(3));
    });

    test('확정본은 건드리지 않는다', () async {
      final before = await container.read(schedulesProvider.future);
      await container
          .read(schedulesProvider.notifier)
          .updateStatus(before.first.id!, ScheduleStatus.confirmed);

      await container.read(schedulesProvider.notifier).deleteAllPending();

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.map((s) => s.title), ['학급편성 결과 제출']);
      expect(confirmed.single.deletedAt, isNull);
    });

    test('확정과 삭제가 같은 종류 범위를 잡는다', () async {
      // `_updateAllPending` 하나를 감싸므로 어긋날 수 없다는 것을 건수로 고정한다.
      final deleted = await repo.deleteAllPending(kind: EntryKind.task);
      for (final s in await repo.getDeletedSchedules()) {
        await repo.restoreSchedule(s.id!);
      }
      final confirmed = await repo.confirmAllPending(kind: EntryKind.task);

      expect(deleted, confirmed);
      expect(deleted, 2, reason: '업무 2건');
    });
  });
}
