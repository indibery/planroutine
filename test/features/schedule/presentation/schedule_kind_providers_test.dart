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

/// 입력 탭의 종류 필터·종류별 일괄 등록이 의존하는 프로바이더 계약.
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
    container = ProviderContainer(overrides: [
      scheduleRepositoryProvider.overrideWithValue(repo),
      calendarRepositoryProvider.overrideWithValue(calendarRepo),
    ]);

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

  group('종류 필터', () {
    test('기본값은 전체(null)', () {
      expect(container.read(scheduleKindFilterProvider), isNull);
    });

    test('업무로 좁히면 목록에서 학교일정이 빠진다', () async {
      container.read(scheduleKindFilterProvider.notifier).state =
          EntryKind.task;

      final list = await container.read(schedulesProvider.future);

      expect(list, hasLength(2));
      expect(list.every((s) => s.kind == EntryKind.task), isTrue);
    });

    test('학교일정으로 좁히면 그것만 남는다', () async {
      container.read(scheduleKindFilterProvider.notifier).state =
          EntryKind.event;

      final list = await container.read(schedulesProvider.future);

      expect(list.single.title, '과학의 달 행사');
    });
  });

  group('종류별 대기 건수', () {
    test('업무·학교일정 대기 건수를 따로 센다', () async {
      final counts = await container.read(scheduleCountsProvider.future);

      expect(counts.pending, 3);
      expect(counts.pendingTask, 2);
      expect(counts.pendingEvent, 1);
    });

    test('종류 필터를 켜도 건수는 전역 기준이다', () async {
      container.read(scheduleKindFilterProvider.notifier).state =
          EntryKind.event;

      final counts = await container.read(scheduleCountsProvider.future);

      expect(counts.pendingTask, 2);
      expect(counts.pendingEvent, 1);
    });
  });

  group('종류별 일괄 확정', () {
    test('업무만 확정하면 학교일정은 대기로 남는다', () async {
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
  });
}
