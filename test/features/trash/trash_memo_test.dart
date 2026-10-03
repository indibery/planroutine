import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/calendar/data/calendar_repository.dart';
import 'package:planroutine/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/presentation/providers/memo_providers.dart';
import 'package:planroutine/features/schedule/data/schedule_repository.dart';
import 'package:planroutine/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:planroutine/features/trash/presentation/providers/trash_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late MemoRepository memos;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        memoRepositoryProvider.overrideWithValue(memos),
        calendarRepositoryProvider.overrideWithValue(CalendarRepository(dbHelper: db)),
        scheduleRepositoryProvider.overrideWithValue(ScheduleRepository(dbHelper: db)),
      ],
    );
    addTearDown(c.dispose);
    // 휴지통 provider가 watch하는 목록들이 로딩을 끝내면 이 provider는 dirty가 되는데,
    // Riverpod은 리스너가 없는 dirty provider를 다시 빌드하지 않아 read(...future)가
    // 끝나지 않는다. 실제 화면은 watch하므로 운영에서는 문제없다 — 화면처럼 listen한다.
    c.listen(trashSnapshotProvider, (_, _) {});
    return c;
  }

  setUp(() {
    db = freshDatabaseHelper();
    memos = MemoRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('뗀 쪽지가 휴지통 목록에 있다', () async {
    final m = await memos.add('뗀 것');
    await memos.softDelete(m.id ?? -1);
    final snap = await container().read(trashSnapshotProvider.future);
    expect(snap.memos.single.text, '뗀 것');
    expect(snap.total, 1);
  });

  test('휴지통에서 되살리면 보드로 돌아온다', () async {
    final m = await memos.add('되살림');
    await memos.softDelete(m.id ?? -1);
    final c = container();
    await c.read(trashSnapshotProvider.future);
    await c.read(trashSnapshotProvider.notifier).restoreMemo(m.id ?? -1);
    expect((await memos.getActive()).single.text, '되살림');
    expect((await c.read(trashSnapshotProvider.future)).memos, isEmpty);
  });

  test('영구 삭제하면 어디에도 없다', () async {
    final m = await memos.add('영구');
    await memos.softDelete(m.id ?? -1);
    final c = container();
    await c.read(trashSnapshotProvider.future);
    await c.read(trashSnapshotProvider.notifier).permanentDeleteMemo(m.id ?? -1);
    expect(await memos.getDeleted(), isEmpty);
  });

  test('30일 정리가 쪽지도 지운다', () async {
    final m = await memos.add('오래됨');
    await memos.softDelete(m.id ?? -1);
    final database = await db.database;
    await database.update(
      DatabaseHelper.tableMemos,
      {'deleted_at': DateTime.now().subtract(const Duration(days: 31)).toIso8601String()},
      where: 'id = ?',
      whereArgs: [m.id],
    );
    final result = await purgeExpiredTrash(container());
    expect(result.memos, 1);
    expect(await memos.getDeleted(), isEmpty);
  });
}
