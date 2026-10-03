import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/memo/data/memo_repository.dart';
import 'package:planroutine/features/memo/domain/memo_color.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late MemoRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = MemoRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('새 쪽지는 노랑이고 맨 앞에 붙는다', () async {
    final a = await repo.add('첫째');
    final b = await repo.add('둘째');
    expect(a.color, MemoColor.yellow);
    final active = await repo.getActive();
    expect(active.map((m) => m.id), [b.id, a.id]);
  });

  test('고친 글·색·날짜가 저장된다', () async {
    final a = await repo.add('처음');
    await repo.update(
      a.copyWith(
        text: '고침',
        color: MemoColor.blue,
        memoDate: DateTime(2026, 10, 17),
      ),
    );
    final got = (await repo.getActive()).single;
    expect(got.text, '고침');
    expect(got.color, MemoColor.blue);
    expect(got.memoDate, DateTime(2026, 10, 17));
  });

  test('날짜를 빼면 null로 저장된다', () async {
    final a = await repo.add('날짜');
    await repo.update(a.copyWith(memoDate: DateTime(2026, 10, 17)));
    final dated = (await repo.getActive()).single;
    await repo.update(dated.copyWith(memoDate: null));
    expect((await repo.getActive()).single.memoDate, isNull);
  });

  test('떼면 활성에서 빠지고 휴지통에 있다', () async {
    final a = await repo.add('뗄 것');
    await repo.softDelete(a.id ?? -1);
    expect(await repo.getActive(), isEmpty);
    expect((await repo.getDeleted()).single.id, a.id);
  });

  test('되살리면 다시 활성이다', () async {
    final a = await repo.add('되살릴 것');
    await repo.softDelete(a.id ?? -1);
    await repo.restore(a.id ?? -1);
    expect((await repo.getActive()).single.id, a.id);
    expect(await repo.getDeleted(), isEmpty);
  });

  test('영구 삭제하면 어디에도 없다', () async {
    final a = await repo.add('영구');
    await repo.softDelete(a.id ?? -1);
    await repo.permanentDelete(a.id ?? -1);
    expect(await repo.getActive(), isEmpty);
    expect(await repo.getDeleted(), isEmpty);
  });

  test('30일 정리는 휴지통에서 오래된 것만 지운다', () async {
    final a = await repo.add('오래됨');
    final b = await repo.add('최근');
    await repo.softDelete(a.id ?? -1);
    await repo.softDelete(b.id ?? -1);
    // a만 31일 전에 뗀 것으로 만든다
    final database = await db.database;
    await database.update(
      DatabaseHelper.tableMemos,
      {'deleted_at': DateTime.now().subtract(const Duration(days: 31)).toIso8601String()},
      where: 'id = ?',
      whereArgs: [a.id],
    );
    final purged = await repo.purgeOlderThan(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    expect(purged, 1);
    expect((await repo.getDeleted()).single.id, b.id);
  });

  test('날짜 범위 조회는 그 달의 활성 쪽지만 준다', () async {
    final a = await repo.add('10월');
    final b = await repo.add('11월');
    final c = await repo.add('날짜 없음');
    await repo.update(a.copyWith(memoDate: DateTime(2026, 10, 17)));
    await repo.update(b.copyWith(memoDate: DateTime(2026, 11, 3)));
    final d = await repo.add('10월 뗀 것');
    await repo.update(d.copyWith(memoDate: DateTime(2026, 10, 20)));
    await repo.softDelete(d.id ?? -1);
    final got = await repo.getByDateRange(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    expect(got.map((m) => m.id), [a.id]);
    expect(c.memoDate, isNull);
  });

  test('saveOrder로 저장한 순서가 다시 읽어도 그대로다', () async {
    final a = await repo.add('a');
    final b = await repo.add('b');
    final c = await repo.add('c');
    // 지금 순서는 c, b, a — a를 맨 앞으로
    await repo.saveOrder([a.id ?? -1, c.id ?? -1, b.id ?? -1]);
    final again = MemoRepository(dbHelper: db);
    expect((await again.getActive()).map((m) => m.id), [a.id, c.id, b.id]);
  });

  test('전체 초기화가 쪽지도 지운다', () async {
    await repo.add('지워질 것');
    await db.resetAllData();
    expect(await repo.getActive(), isEmpty);
  });
}
