import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  test('v9 → v10: 기존 데이터는 그대로, 지도 기록 테이블 넷이 빈 채로 생긴다', () async {
    final dir = await Directory.systemTemp.createTemp('guidance_mig');
    final path = '${dir.path}/v9.db';
    // v9 스키마를 흉내 낸다 — 이번 마이그레이션에 필요한 것은 기존 테이블이 남는지뿐이다.
    final v9 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE memos (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, '
            "color TEXT NOT NULL DEFAULT 'yellow', memo_date TEXT, sort_order INTEGER NOT NULL DEFAULT 0, "
            'created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT)',
          );
          await db.insert('memos', {
            'text': '남아야 할 쪽지',
            'created_at': '2026-10-01T00:00:00.000',
            'updated_at': '2026-10-01T00:00:00.000',
          });
        },
      ),
    );
    await v9.close();

    final helper = DatabaseHelper.forTesting(path: path);
    final db = await helper.database;
    expect(await db.getVersion(), 10);
    expect((await db.query('memos')).single['text'], '남아야 할 쪽지');
    for (final t in [
      DatabaseHelper.tableGuidancePeople,
      DatabaseHelper.tableGuidanceRecords,
      DatabaseHelper.tableGuidanceRevisions,
      DatabaseHelper.tableGuidanceAttachments,
    ]) {
      expect(await db.query(t), isEmpty, reason: t);
    }
    await helper.close();
    await dir.delete(recursive: true);
  });
}
