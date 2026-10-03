import '../../../core/database/database_helper.dart';
import '../domain/guidance_models.dart';
import '../domain/guidance_types.dart';

/// 지도 기록 명단. 지우지 않고 **보관**한다 — 옛 기록은 판의 사본으로 이름을 보여 준다.
class GuidancePeopleRepository {
  GuidancePeopleRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  static const _table = DatabaseHelper.tableGuidancePeople;

  /// 구분 순서(학생 먼저) → 이름.
  static const _order =
      "CASE role WHEN 'student' THEN 0 WHEN 'guardian' THEN 1 WHEN 'staff' THEN 2 ELSE 3 END, name";

  Future<GuidancePerson> add(GuidancePerson p) async {
    final db = await _dbHelper.database;
    final id = await db.insert(_table, p.toMap());
    return p.copyWith(id: id);
  }

  /// 기록을 저장할 때 관련인 이름을 명단에 기억하고 `이름 → id`를 돌려준다(이름 추천용).
  /// 같은 이름(앞뒤 공백 정리 후) = 같은 사람이라 있으면 그 id, 없으면 새로 넣는다.
  /// 보관한 이름(추천에서 지운 것)은 **되살리지 않고** 그 id만 쓴다 — 지운 선택을 지킨다.
  /// 같은 이름이 여럿이면(명단 화면 시절의 데이터) 보관 안 된 것 → 먼저 넣은 것 순으로 고른다.
  Future<Map<String, int>> remember(Iterable<String> names) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.query(_table, columns: ['id', 'name', 'archived_at'], orderBy: 'id');
      final known = <String, int>{};
      for (final active in const [true, false]) {
        for (final r in rows) {
          if ((r['archived_at'] == null) != active) continue;
          known.putIfAbsent((r['name'] as String).trim(), () => r['id'] as int);
        }
      }
      final out = <String, int>{};
      for (final raw in names) {
        final name = raw.trim();
        if (name.isEmpty || out.containsKey(name)) continue;
        var id = known[name];
        id ??= await txn.insert(_table, GuidancePerson(name: name).toMap());
        known[name] = id;
        out[name] = id;
      }
      return out;
    });
  }

  /// 붙여넣은 이름을 한 번에. 현재 명단에 같은 이름이 있으면 건너뛴다.
  Future<int> addNames(List<String> names, {PersonRole role = PersonRole.student}) async {
    final db = await _dbHelper.database;
    final existing = {for (final p in await getActive()) p.name};
    var added = 0;
    await db.transaction((txn) async {
      for (final name in names) {
        if (existing.contains(name)) continue;
        await txn.insert(_table, GuidancePerson(name: name, role: role).toMap());
        existing.add(name);
        added++;
      }
    });
    return added;
  }

  Future<void> update(GuidancePerson p) async {
    final id = p.id;
    if (id == null) return;
    final db = await _dbHelper.database;
    final map = p.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    await db.update(_table, map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archive(int id) => _setArchived(id, DateTime.now().toIso8601String());

  Future<void> unarchive(int id) => _setArchived(id, null);

  Future<void> _setArchived(int id, String? at) async {
    final db = await _dbHelper.database;
    await db.update(_table, {'archived_at': at}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GuidancePerson>> getActive() async {
    final db = await _dbHelper.database;
    final rows = await db.query(_table, where: 'archived_at IS NULL', orderBy: _order);
    return rows.map(GuidancePerson.fromMap).toList();
  }

  Future<List<GuidancePerson>> getArchived() async {
    final db = await _dbHelper.database;
    final rows = await db.query(_table, where: 'archived_at IS NOT NULL', orderBy: _order);
    return rows.map(GuidancePerson.fromMap).toList();
  }
}
