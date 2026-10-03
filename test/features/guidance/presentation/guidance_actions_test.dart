import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late Directory base;
  late ProviderContainer c;
  late GuidanceFileStore files;

  setUp(() async {
    db = freshDatabaseHelper();
    base = await Directory.systemTemp.createTemp('guidance_actions');
    files = GuidanceFileStore(baseDir: () async => base);
    c = ProviderContainer(
      overrides: [
        guidanceRepositoryProvider.overrideWithValue(GuidanceRepository(dbHelper: db)),
        guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
        guidanceFileStoreProvider.overrideWithValue(files),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    await base.delete(recursive: true);
  });

  test('가져온 사진은 원래 이름과 해시를 갖고 붙는다', () async {
    final actions = c.read(guidanceActionsProvider);
    final id = await actions.create(const GuidanceContent(title: 't'));
    final src = File('${base.path}/IMG_0001.HEIC')..writeAsStringSync('abc');
    final a = await actions.attachImported(
      recordId: id,
      sourcePath: src.path,
      type: AttachmentType.image,
      originalName: 'IMG_0001.HEIC',
    );
    expect(a.originalName, 'IMG_0001.HEIC');
    expect(a.sha256, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(a.source, AttachmentSource.imported);
    expect(a.capturedAt, isNull);
  });

  test('녹음은 첨부 폴더 안의 파일로 붙고 시작 시각을 남긴다', () async {
    final actions = c.read(guidanceActionsProvider);
    final id = await actions.create(const GuidanceContent(title: 't'));
    final path = await files.newRecordingPath();
    File(path).writeAsStringSync('abc');
    final started = DateTime(2026, 10, 2, 15, 41);
    final a = await actions.attachRecording(
      recordId: id,
      path: path,
      durationMs: 768000,
      startedAt: started,
    );
    expect(a.source, AttachmentSource.recorded);
    expect(a.durationMs, 768000);
    expect(a.capturedAt, started.toIso8601String());
  });

  test('영구 삭제는 그 기록의 파일만 지운다', () async {
    final actions = c.read(guidanceActionsProvider);
    final keepId = await actions.create(const GuidanceContent(title: 'keep'));
    final dropId = await actions.create(const GuidanceContent(title: 'drop'));
    final keep = await actions.attachImported(
      recordId: keepId,
      sourcePath: (File('${base.path}/k.jpg')..writeAsStringSync('k')).path,
      type: AttachmentType.image,
    );
    final drop = await actions.attachImported(
      recordId: dropId,
      sourcePath: (File('${base.path}/d.jpg')..writeAsStringSync('d')).path,
      type: AttachmentType.image,
    );
    await actions.delete(dropId);
    await actions.permanentDelete(dropId);
    expect(await (await files.fileOf(keep.fileName)).exists(), isTrue);
    expect(await (await files.fileOf(drop.fileName)).exists(), isFalse);
  });

  test('변경마다 신호가 오른다', () async {
    final actions = c.read(guidanceActionsProvider);
    final before = c.read(guidanceChangedProvider);
    await actions.create(const GuidanceContent(title: 't'));
    expect(c.read(guidanceChangedProvider), before + 1);
  });
}
