import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';

void main() {
  late Directory base;
  late GuidanceFileStore store;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('guidance_store');
    store = GuidanceFileStore(baseDir: () async => base);
  });
  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  test('가져온 파일은 바이트 그대로 복사되고 SHA-256이 맞다', () async {
    final src = File('${base.path}/원본 녹음.m4a')..writeAsStringSync('abc');
    final stored = await store.importCopy(src.path);
    // 'abc'의 SHA-256(표준 시험 벡터)
    expect(stored.sha256, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(stored.byteSize, 3);
    expect(stored.fileName.endsWith('.m4a'), isTrue);
    final copied = await store.fileOf(stored.fileName);
    expect(await copied.readAsString(), 'abc');
    expect(copied.parent.path.endsWith(GuidanceFileStore.folder), isTrue);
  });

  test('확장자가 없으면 bin으로 저장한다', () async {
    final src = File('${base.path}/noext')..writeAsStringSync('x');
    expect((await store.importCopy(src.path)).fileName.endsWith('.bin'), isTrue);
  });

  test('녹음 경로는 첨부 폴더 안의 새 aac다 — 끊겨도 재생되는 ADTS', () async {
    final a = await store.newRecordingPath();
    final b = await store.newRecordingPath();
    expect(a, isNot(b));
    expect(a.endsWith('.aac'), isTrue);
    expect(File(a).parent.path, (await store.dir()).path);
  });

  test('deleteFiles는 고른 파일만 지운다', () async {
    final keep = await store.importCopy((File('${base.path}/k.jpg')..writeAsStringSync('k')).path);
    final drop = await store.importCopy((File('${base.path}/d.jpg')..writeAsStringSync('d')).path);
    await store.deleteFiles([drop.fileName, '없는파일.m4a']);
    expect(await (await store.fileOf(keep.fileName)).exists(), isTrue);
    expect(await (await store.fileOf(drop.fileName)).exists(), isFalse);
  });

  test('wipe는 첨부 폴더만 비운다', () async {
    final other = File('${base.path}/planroutine.db')..writeAsStringSync('db');
    await store.importCopy((File('${base.path}/x.jpg')..writeAsStringSync('x')).path);
    await store.wipe();
    expect(await Directory('${base.path}/${GuidanceFileStore.folder}').exists(), isFalse);
    expect(await other.exists(), isTrue);
  });
}
