import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
  });

  tearDown(() async {
    await db.close();
  });

  /// imported_schedules에 테스트용 row 삽입 후 id 반환
  Future<int> seedImportedSchedule({
    String title = '작년 회의록',
    String date = '2025-03-15',
    String category = '일과운영관리',
  }) async {
    final database = await db.database;
    return database.insert(DatabaseHelper.tableImportedSchedules, {
      'title': title,
      'registration_date': date,
      'category': category,
      'source_year': 2025,
      'imported_at': DateTime.now().toIso8601String(),
    });
  }

  group('createFromImported', () {
    test('imported_schedule에서 pending 상태 Schedule 생성', () async {
      final importedId = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      expect(scheduleId, greaterThan(0));

      final schedules = await repo.getSchedules();
      expect(schedules.length, 1);
      expect(schedules.first.title, '작년 회의록');
      expect(schedules.first.status, ScheduleStatus.pending);
      expect(schedules.first.scheduledDate, '2026-03-15');
    });

    test('같은 source_id로 두 번 호출 시 두 번째는 중복 스킵(-1)', () async {
      final importedId = await seedImportedSchedule();
      await repo.createFromImported(importedId, DateTime(2026, 3, 15));
      final second = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 20),
      );
      expect(second, -1);
    });

    test('source schedule이 soft-delete되면 재생성 가능', () async {
      final importedId = await seedImportedSchedule();
      final first = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      await repo.deleteSchedule(first);

      final second = await repo.createFromImported(
        importedId,
        DateTime(2026, 4, 1),
      );
      expect(second, greaterThan(0));
    });
  });

  group('createBulkFromImported', () {
    test('여러 항목 일괄 등록 + 중복 스킵 카운트', () async {
      final id1 = await seedImportedSchedule(title: 'A', date: '2025-01-10');
      final id2 = await seedImportedSchedule(title: 'B', date: '2025-02-20');

      // 한 번째 호출: 둘 다 등록
      final first = await repo.createBulkFromImported([
        (importedId: id1, date: DateTime(2026, 1, 10)),
        (importedId: id2, date: DateTime(2026, 2, 20)),
      ]);
      expect(first.created, 2);
      expect(first.skipped, 0);

      // 두 번째 호출: 둘 다 중복 스킵
      final second = await repo.createBulkFromImported([
        (importedId: id1, date: DateTime(2026, 1, 10)),
        (importedId: id2, date: DateTime(2026, 2, 20)),
      ]);
      expect(second.created, 0);
      expect(second.skipped, 2);
    });

    test('재임포트(새 source_id, 같은 title+date)는 내용 중복으로 스킵', () async {
      final id1 = await seedImportedSchedule(title: 'C', date: '2025-05-05');
      final first = await repo.createBulkFromImported([
        (importedId: id1, date: DateTime(2026, 5, 5)),
      ]);
      expect(first.created, 1);

      // 같은 CSV 재임포트 → imported_schedules에 새 행(다른 id), 내용은 동일
      final id2 = await seedImportedSchedule(title: 'C', date: '2025-05-05');
      final second = await repo.createBulkFromImported([
        (importedId: id2, date: DateTime(2026, 5, 5)),
      ]);
      expect(second.created, 0, reason: '내용(title+date) 중복이므로 미생성');
      expect(second.skipped, 1);

      final schedules = await repo.getSchedules();
      expect(schedules.where((s) => s.title == 'C').length, 1);
    });

    test('1차분을 확정한 뒤 재임포트해도 확정+대기 중복이 안 생김', () async {
      final id1 = await seedImportedSchedule(title: 'D', date: '2025-06-06');
      await repo.createBulkFromImported([
        (importedId: id1, date: DateTime(2026, 6, 6)),
      ]);
      final sched = (await repo.getSchedules()).firstWhere(
        (s) => s.title == 'D',
      );
      await repo.updateStatus(sched.id!, ScheduleStatus.confirmed);

      // 재임포트
      final id2 = await seedImportedSchedule(title: 'D', date: '2025-06-06');
      final second = await repo.createBulkFromImported([
        (importedId: id2, date: DateTime(2026, 6, 6)),
      ]);
      expect(second.created, 0);

      final ds = (await repo.getSchedules())
          .where((s) => s.title == 'D')
          .toList();
      expect(ds.length, 1, reason: '확정+대기 중복 없음');
      expect(ds.first.status, ScheduleStatus.confirmed, reason: '확정본 유지');
    });
  });

  group('insertConfirmedOrPending (PlanRoutine 재임포트용)', () {
    Schedule buildSchedule({
      String title = '확정 일정',
      String date = '2026-06-01',
      ScheduleStatus status = ScheduleStatus.confirmed,
    }) {
      final now = DateTime.now().toIso8601String();
      return Schedule(
        title: title,
        scheduledDate: date,
        status: status,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('동일 (title,date)가 없으면 insert 성공', () async {
      final id = await repo.insertConfirmedOrPending(buildSchedule());
      expect(id, greaterThan(0));

      final schedules = await repo.getSchedules();
      expect(schedules.length, 1);
      expect(schedules.first.status, ScheduleStatus.confirmed);
    });

    test('동일 (title,date) 활성 일정이 있으면 -1 반환', () async {
      await repo.insertConfirmedOrPending(buildSchedule());
      final second = await repo.insertConfirmedOrPending(buildSchedule());
      expect(second, -1);
    });

    test('기존 일정이 soft-delete되면 재삽입 가능', () async {
      final first = await repo.insertConfirmedOrPending(buildSchedule());
      await repo.deleteSchedule(first);
      final second = await repo.insertConfirmedOrPending(buildSchedule());
      expect(second, greaterThan(0));
    });
  });

  group('updateStatus / updateSchedule', () {
    test('updateStatus로 pending → confirmed 변경 후 필터 조회 가능', () async {
      final id = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        id,
        DateTime(2026, 3, 15),
      );
      await repo.updateStatus(scheduleId, ScheduleStatus.confirmed);

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.length, 1);
      final pending = await repo.getSchedules(status: ScheduleStatus.pending);
      expect(pending, isEmpty);
    });

    test('updateSchedule로 title, date, description 수정', () async {
      final importedId = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      await repo.updateSchedule(
        scheduleId,
        title: '수정된 제목',
        date: DateTime(2026, 4, 1),
        description: '설명 추가',
      );

      final schedules = await repo.getSchedules();
      expect(schedules.first.title, '수정된 제목');
      expect(schedules.first.scheduledDate, '2026-04-01');
      expect(schedules.first.description, '설명 추가');
    });
  });

  group('soft-delete / restore / permanentDelete', () {
    test('deleteSchedule은 soft-delete (활성 목록에서 제외)', () async {
      final importedId = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      await repo.deleteSchedule(scheduleId);

      expect(await repo.getSchedules(), isEmpty);
      final deleted = await repo.getDeletedSchedules();
      expect(deleted.length, 1);
      expect(deleted.first.deletedAt, isNotNull);
    });

    test('restoreSchedule로 다시 활성 목록에', () async {
      final importedId = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      await repo.deleteSchedule(scheduleId);
      await repo.restoreSchedule(scheduleId);

      final schedules = await repo.getSchedules();
      expect(schedules.length, 1);
      expect(schedules.first.deletedAt, isNull);
    });

    test('permanentDeleteSchedule은 완전 제거', () async {
      final importedId = await seedImportedSchedule();
      final scheduleId = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      await repo.deleteSchedule(scheduleId);
      await repo.permanentDeleteSchedule(scheduleId);

      expect(await repo.getDeletedSchedules(), isEmpty);
    });
  });

  group('deleteAll / confirmAllPending', () {
    test('deleteAll은 soft-delete가 아닌 hard delete (테스트/초기화용)', () async {
      final id = await seedImportedSchedule();
      await repo.createFromImported(id, DateTime(2026, 3, 15));
      await repo.deleteAll();
      expect(await repo.getSchedules(), isEmpty);
      expect(await repo.getDeletedSchedules(), isEmpty);
    });

    test('confirmAllPending은 pending 전체를 confirmed로 전환', () async {
      final id1 = await seedImportedSchedule(title: 'A');
      final id2 = await seedImportedSchedule(title: 'B');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      await repo.confirmAllPending();

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.length, 2);
    });

    test('confirmAllPending은 soft-delete된 항목을 건너뜀', () async {
      final id1 = await seedImportedSchedule(title: 'A');
      final sid1 = await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.deleteSchedule(sid1);

      await repo.confirmAllPending();

      // 휴지통 항목은 여전히 pending 상태 (확정되지 않음)
      final deleted = await repo.getDeletedSchedules();
      expect(deleted.first.status, ScheduleStatus.pending);
    });

    test('confirmAllPending(category: null)은 모든 pending 확정 (기존 동작)', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      await repo.confirmAllPending();

      final all = await repo.getSchedules(status: ScheduleStatus.confirmed);
      expect(all.length, 2);
    });

    test('deleteAllPending은 pending 전체를 휴지통으로(soft-delete), 확정은 유지', () async {
      final id1 = await seedImportedSchedule(title: 'A');
      final id2 = await seedImportedSchedule(title: 'B');
      final id3 = await seedImportedSchedule(title: 'C');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));
      final sid3 = await repo.createFromImported(id3, DateTime(2026, 3, 1));
      await repo.updateStatus(sid3, ScheduleStatus.confirmed); // C만 확정

      final n = await repo.deleteAllPending();

      expect(n, 2, reason: '대기 2건(A,B)만 삭제');
      // 활성 목록엔 확정된 C만 남음
      final active = await repo.getSchedules();
      expect(active.length, 1);
      expect(active.first.title, 'C');
      // 삭제분은 휴지통에 (영구 삭제 아님)
      final deleted = await repo.getDeletedSchedules();
      expect(deleted.length, 2);
    });

    // ── 카테고리로 범위를 좁히는 인자는 없어졌다(2026-09-03) ──────────────
    // 입력 탭의 카테고리 필터를 없애면서 `getSchedules`·`confirmAllPending`·
    // `deleteAllPending`의 `category` 인자와 `getDistinctCategories`가 함께 죽었다.
    // 아래 여섯 건이 그 자리를 대신한다 — 새 계약과, 지우지 않기로 한 것을 지킨다.

    test('getSchedules(status: pending)은 카테고리를 가리지 않는다', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      final pending = await repo.getSchedules(status: ScheduleStatus.pending);
      expect(pending.map((s) => s.title), ['A', 'B']);
    });

    test('confirmAllPending()은 카테고리와 무관하게 대기 전체를 확정한다', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      expect(await repo.confirmAllPending(), 2);
      expect(await repo.getSchedules(status: ScheduleStatus.pending), isEmpty);
    });

    test('deleteAllPending()은 카테고리와 무관하게 대기 전체를 삭제한다', () async {
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B', category: '학생학적관리');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      expect(await repo.deleteAllPending(), 2);
      expect(await repo.getSchedules(), isEmpty);
      expect(await repo.getDeletedSchedules(), hasLength(2));
    });

    test('확정과 삭제는 같은 집합을 잡는다 — 범위 조립이 한 곳이다', () async {
      // `_updateAllPending` 하나를 감싸므로 어긋날 수 없다. 예전에 한쪽에만
      // 필터를 더해 갈렸던 것이 실제 버그였다.
      final id1 = await seedImportedSchedule(title: 'A', category: '일과운영관리');
      final id2 = await seedImportedSchedule(title: 'B');
      await repo.createFromImported(id1, DateTime(2026, 1, 1));
      await repo.createFromImported(id2, DateTime(2026, 2, 1));

      final wouldDelete = await repo.deleteAllPending();
      // 같은 시드로 다시 세워 확정 건수를 비교한다.
      await repo.restoreSchedule(
        (await repo.getDeletedSchedules()).first.id!,
      );
      await repo.restoreSchedule(
        (await repo.getDeletedSchedules()).first.id!,
      );
      final wouldConfirm = await repo.confirmAllPending();

      expect(wouldDelete, wouldConfirm);
    });

    test('확정해도 category 값은 컬럼에 남는다 — CSV 내보내기가 쓴다', () async {
      final id = await seedImportedSchedule(title: 'A', category: '학생학적관리');
      await repo.createFromImported(id, DateTime(2026, 1, 1));

      await repo.confirmAllPending();

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.single.category, '학생학적관리');
    });

    test('확정 행은 deleted_at이 NULL이라 내보내기 조회에 걸린다', () async {
      final id = await seedImportedSchedule(title: 'A');
      await repo.createFromImported(id, DateTime(2026, 1, 1));

      await repo.confirmAllPending();

      final confirmed = await repo.getSchedules(
        status: ScheduleStatus.confirmed,
      );
      expect(confirmed.single.deletedAt, isNull);
      expect(await repo.getDeletedSchedules(), isEmpty);
    });
  });

  group('purgeOlderThan', () {
    test('cutoff 이전에 soft-delete된 일정만 영구 삭제', () async {
      final database = await db.database;
      final importedId = await seedImportedSchedule();
      final sid = await repo.createFromImported(
        importedId,
        DateTime(2026, 3, 15),
      );
      // 오래된 deleted_at 수동 주입
      await database.update(
        DatabaseHelper.tableSchedules,
        {'deleted_at': '2025-01-01T00:00:00.000Z'},
        where: 'id = ?',
        whereArgs: [sid],
      );

      final purged = await repo.purgeOlderThan(DateTime(2025, 6, 1));
      expect(purged, 1);
      expect(await repo.getDeletedSchedules(), isEmpty);
    });
  });

  group('getSchedulesByMonth', () {
    test('해당 월의 활성 일정만 반환', () async {
      final id1 = await seedImportedSchedule(title: 'Jan');
      final id2 = await seedImportedSchedule(title: 'Mar');
      await repo.createFromImported(id1, DateTime(2026, 1, 15));
      await repo.createFromImported(id2, DateTime(2026, 3, 15));

      final march = await repo.getSchedulesByMonth(2026, 3);
      expect(march.length, 1);
      expect(march.first.title, 'Mar');
    });
  });
}
