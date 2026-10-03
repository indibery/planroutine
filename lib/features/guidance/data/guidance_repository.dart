import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../domain/guidance_content.dart';
import '../domain/guidance_logic.dart';
import '../domain/guidance_models.dart';
import '../domain/participant.dart';

/// 지도 기록 저장소 — 기록 몸통·판·첨부.
///
/// ⚠️ **`guidance_revisions`는 추가만 한다.** UPDATE를 쓰지 않고, DELETE는
/// [permanentDelete] 한 곳뿐이다(`guidance_append_only_guard_test.dart`).
class GuidanceRepository {
  GuidanceRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  static const _records = DatabaseHelper.tableGuidanceRecords;
  static const _revisions = DatabaseHelper.tableGuidanceRevisions;
  static const _attachments = DatabaseHelper.tableGuidanceAttachments;

  /// 기록 + 판 1. 기록 시각(`created_at`)은 여기서 한 번 찍고 다시 쓰지 않는다.
  Future<int> create(GuidanceContent content) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert(_records, {'created_at': now});
      await txn.insert(_revisions, {
        'record_id': id,
        'revision_no': 1,
        'saved_at': now,
        ...GuidanceRevision.contentToMap(content),
      });
      return id;
    });
  }

  /// 최신 판과 같은 내용이면 아무것도 하지 않고 false.
  Future<bool> saveRevision(int recordId, GuidanceContent content) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        _revisions,
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'revision_no DESC',
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final latest = GuidanceRevision.fromMap(rows.first);
      if (sameContent(latest.content, content)) return false;
      await txn.insert(_revisions, {
        'record_id': recordId,
        'revision_no': latest.revisionNo + 1,
        'saved_at': DateTime.now().toIso8601String(),
        ...GuidanceRevision.contentToMap(content),
      });
      return true;
    });
  }

  /// 기록 + 최신 판 + 판 수 + (빼지 않은) 첨부 수. [where]는 `r.` 별칭 기준.
  Future<List<GuidanceRecord>> _query(
    String where,
    List<Object?> args, {
    String orderBy = 'r.id DESC',
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT v.*, r.created_at AS r_created_at, r.deleted_at AS r_deleted_at,
        (SELECT COUNT(*) FROM $_revisions x WHERE x.record_id = r.id) AS rev_count,
        (SELECT COUNT(*) FROM $_attachments a
           WHERE a.record_id = r.id AND a.removed_at IS NULL) AS att_count
      FROM $_records r
      JOIN $_revisions v ON v.record_id = r.id
        AND v.revision_no = (SELECT MAX(y.revision_no) FROM $_revisions y WHERE y.record_id = r.id)
      WHERE $where
      ORDER BY $orderBy
    ''', args);
    return [
      for (final m in rows)
        GuidanceRecord(
          id: m['record_id'] as int,
          createdAt: m['r_created_at'] as String,
          deletedAt: m['r_deleted_at'] as String?,
          latest: GuidanceRevision.fromMap(m),
          revisionCount: m['rev_count'] as int,
          attachmentCount: m['att_count'] as int,
        ),
    ];
  }

  Future<List<GuidanceRecord>> getActive() => _query('r.deleted_at IS NULL', const []);

  Future<List<GuidanceRecord>> getDeleted() => _query(
    'r.deleted_at IS NOT NULL',
    const [],
    orderBy: 'r.deleted_at DESC',
  );

  Future<GuidanceRecord?> getRecord(int id) async {
    final list = await _query('r.id = ?', [id]);
    return list.isEmpty ? null : list.first;
  }

  Future<List<GuidanceRevision>> getRevisions(int recordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _revisions,
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'revision_no DESC',
    );
    return rows.map(GuidanceRevision.fromMap).toList();
  }

  /// 이미 삭제한 기록이면 처음 삭제한 시각을 덮어쓰지 않는다.
  Future<void> softDelete(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      _records,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> restore(int id) async {
    final db = await _dbHelper.database;
    await db.update(_records, {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  /// 사용자가 `삭제한 기록`에서 직접 지울 때만. 판 테이블 DELETE는 **여기 한 곳뿐**이다.
  /// 지운 첨부의 파일 이름을 돌려준다 — 파일은 호출부(`GuidanceActions`)가 지운다.
  Future<List<String>> permanentDelete(int id) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        _attachments,
        columns: ['file_name'],
        where: 'record_id = ?',
        whereArgs: [id],
      );
      final gone = await _participantNames(txn, 'record_id = ?', [id]);
      await txn.delete(_attachments, where: 'record_id = ?', whereArgs: [id]);
      await txn.delete(DatabaseHelper.tableGuidanceRevisions, where: 'record_id = ?', whereArgs: [id]);
      await txn.delete(_records, where: 'id = ?', whereArgs: [id]);
      // 이 기록에만 나왔던 이름의 추천(명단 행)도 함께 지운다 — 남은 기록(삭제한 기록 포함)에
      // 나오는 이름은 지우지 않는다. 같은 사람인지는 [sameParticipant]처럼 앞뒤 공백을 뗀 이름으로 본다.
      final stay = await _participantNames(txn, null, null);
      final orphans = gone.difference(stay);
      if (orphans.isNotEmpty) {
        final people = await txn.query(DatabaseHelper.tableGuidancePeople, columns: ['id', 'name']);
        for (final r in people) {
          if (orphans.contains((r['name'] as String).trim())) {
            await txn.delete(DatabaseHelper.tableGuidancePeople, where: 'id = ?', whereArgs: [r['id']]);
          }
        }
      }
      return [for (final r in rows) r['file_name'] as String];
    });
  }

  /// 판들의 관련인 이름(앞뒤 공백 뗀 것) 집합. [where]가 null이면 모든 판.
  Future<Set<String>> _participantNames(DatabaseExecutor db, String? where, List<Object?>? args) async {
    final rows = await db.query(_revisions, columns: ['participants'], where: where, whereArgs: args);
    return {
      for (final r in rows)
        for (final p in Participant.decodeList(r['participants'] as String?))
          if (p.name.trim().isNotEmpty) p.name.trim(),
    };
  }

  Future<GuidanceAttachment> addAttachment(GuidanceAttachment a) async {
    final db = await _dbHelper.database;
    final id = await db.insert(_attachments, a.toMap());
    return a.copyWith(id: id);
  }

  /// 첨부에서 빼기 — 행과 파일은 남기고 시각만 찍는다(이력에 보인다).
  /// 이미 뺀 첨부면 처음 뺀 시각을 덮어쓰지 않는다.
  Future<void> removeAttachment(int attachmentId) async {
    final db = await _dbHelper.database;
    await db.update(
      _attachments,
      {'removed_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND removed_at IS NULL',
      whereArgs: [attachmentId],
    );
  }

  Future<List<GuidanceAttachment>> getAttachments(int recordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _attachments,
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'attached_at ASC, id ASC',
    );
    return rows.map(GuidanceAttachment.fromMap).toList();
  }

  /// 전체 초기화 확인 창용. 명단(보관한 사람 포함)도 초기화가 지우므로 함께 센다.
  Future<({int records, int attachments, int people})> counts() async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $_records');
    final a = await db.rawQuery('SELECT COUNT(*) AS c FROM $_attachments');
    final p = await db.rawQuery('SELECT COUNT(*) AS c FROM ${DatabaseHelper.tableGuidancePeople}');
    return (
      records: r.first['c'] as int,
      attachments: a.first['c'] as int,
      people: p.first['c'] as int,
    );
  }
}
