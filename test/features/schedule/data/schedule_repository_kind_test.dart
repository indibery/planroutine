import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/domain/entry_kind.dart';
import 'package:planroutine/features/schedule/domain/schedule.dart';

import '../../../helpers/test_database.dart';

/// 종류별 조회·일괄 확정.
///
/// 입력 탭에서 `일괄 업무 등록` / `일괄 행사 등록`을 따로 누르므로, 한쪽을 확정할 때
/// 다른 쪽이 함께 넘어가지 않아야 한다.
void main() {
  setUpAll(setUpFfiForTests);

  late DatabaseHelper db;
  late ScheduleRepository repo;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = ScheduleRepository(dbHelper: db);
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
  tearDown(() async => db.close());

  group('getSchedules(kind:)', () {
    test('업무만 조회한다', () async {
      final list = await repo.getSchedules(kind: EntryKind.task);

      expect(list, hasLength(2));
      expect(list.every((s) => s.kind == EntryKind.task), isTrue);
    });

    test('학교일정만 조회한다', () async {
      final list = await repo.getSchedules(kind: EntryKind.event);

      expect(list.single.title, '과학의 달 행사');
    });

    test('kind를 주지 않으면 둘 다 나온다', () async {
      expect(await repo.getSchedules(), hasLength(3));
    });
  });

  group('confirmAllPending(kind:)', () {
    test('업무만 확정하면 학교일정은 대기로 남는다', () async {
      final changed = await repo.confirmAllPending(kind: EntryKind.task);
      expect(changed, 2);

      final pending = await repo.getSchedules(status: ScheduleStatus.pending);
      expect(pending.single.kind, EntryKind.event);
    });

    test('학교일정만 확정하면 업무는 대기로 남는다', () async {
      final changed = await repo.confirmAllPending(kind: EntryKind.event);
      expect(changed, 1);

      final pending = await repo.getSchedules(status: ScheduleStatus.pending);
      expect(pending, hasLength(2));
      expect(pending.every((s) => s.kind == EntryKind.task), isTrue);
    });

    test('kind를 주지 않으면 전부 확정된다 (기존 동작)', () async {
      expect(await repo.confirmAllPending(), 3);
      expect(
        await repo.getSchedules(status: ScheduleStatus.pending),
        isEmpty,
      );
    });

    test('카테고리와 종류를 함께 좁힐 수 있다', () async {
      await repo.insertConfirmedOrPending(
        const Schedule(
          title: '체육대회 준비',
          scheduledDate: '2026-05-01',
          category: '교육과정',
          kind: EntryKind.event,
        ),
      );

      final changed = await repo.confirmAllPending(
        category: '교육과정',
        kind: EntryKind.event,
      );

      expect(changed, 1);
    });
  });
}
