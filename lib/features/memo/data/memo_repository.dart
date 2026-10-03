import '../../../core/database/database_helper.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/memo.dart';

/// `memos` 저장소. 삭제는 soft-delete(휴지통)이고 활성 조회는 늘 `deleted_at IS NULL`이다.
class MemoRepository {
  MemoRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  static const _active = 'deleted_at IS NULL';

  /// 새 쪽지는 노랑이고 **맨 앞**이다 — 활성 최소 `sort_order`보다 하나 작게.
  Future<Memo> add(String text) async {
    final db = await _dbHelper.database;
    final row = await db.rawQuery(
      'SELECT MIN(sort_order) AS m FROM ${DatabaseHelper.tableMemos} WHERE $_active',
    );
    final min = row.first['m'] as int?;
    final memo = Memo(text: text, sortOrder: min == null ? 0 : min - 1);
    final id = await db.insert(DatabaseHelper.tableMemos, memo.toMap());
    return memo.copyWith(id: id);
  }

  Future<void> update(Memo memo) async {
    final id = memo.id;
    if (id == null) return;
    final db = await _dbHelper.database;
    final map = memo.toMap()
      ..['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      DatabaseHelper.tableMemos,
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Memo>> getActive() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableMemos,
      where: _active,
      orderBy: 'sort_order ASC, id DESC',
    );
    return rows.map(Memo.fromMap).toList();
  }

  /// 캘린더용 — [start]~[end](양 끝 포함)에 날짜가 붙은 활성 쪽지.
  Future<List<Memo>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableMemos,
      where: 'memo_date >= ? AND memo_date <= ? AND $_active',
      whereArgs: [formatDate(start), formatDate(end)],
      orderBy: 'memo_date ASC, sort_order ASC',
    );
    return rows.map(Memo.fromMap).toList();
  }

  Future<void> softDelete(int id) => _setDeleted(id, DateTime.now().toIso8601String());

  Future<void> restore(int id) => _setDeleted(id, null);

  Future<void> _setDeleted(int id, String? at) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableMemos,
      {'deleted_at': at},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> permanentDelete(int id) async {
    final db = await _dbHelper.database;
    await db.delete(DatabaseHelper.tableMemos, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Memo>> getDeleted() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableMemos,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(Memo.fromMap).toList();
  }

  Future<int> purgeOlderThan(DateTime cutoff) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableMemos,
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// 보드 순서를 한 번에 저장한다 — 앞에서부터 0, 1, 2…
  Future<void> saveOrder(List<int> idsInOrder) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final (i, id) in idsInOrder.indexed) {
        await txn.update(
          DatabaseHelper.tableMemos,
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }
}
