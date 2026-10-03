import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFile {
  const StoredFile({required this.fileName, required this.sha256, required this.byteSize});
  final String fileName;
  final String sha256;
  final int byteSize;
}

/// 지도 기록 첨부 파일. 앱 전용 `Application Support/guidance/`에 둔다 —
/// 파일 앱·사진 앱에 보이지 않는다.
///
/// **가져온 파일은 변환 없이 바이트 그대로 복사**하고 SHA-256을 남긴다. 사본의 증거능력은
/// 원본과 같음을 보여야 하고, 그 방법으로 해시 비교가 원칙이다(대법원 2022도1864).
///
/// ⚠️ Android에서는 이 폴더가 클라우드 백업에서 빠진다(`res/xml/backup_rules.xml`) —
/// 자동 백업 25MB 상한을 넘으면 DB 백업까지 멈추기 때문이다.
class GuidanceFileStore {
  GuidanceFileStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  static const folder = 'guidance';

  Future<Directory> dir() async {
    final d = Directory(p.join((await _baseDir()).path, folder));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  var _seq = 0;

  /// 같은 마이크로초에 둘을 만들어도 겹치지 않게 순번을 붙인다.
  String _newName(String ext) =>
      '${DateTime.now().microsecondsSinceEpoch}_${_seq++}.$ext';

  Future<StoredFile> importCopy(String sourcePath) async {
    final rawExt = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final name = _newName(rawExt.isEmpty ? 'bin' : rawExt);
    await File(sourcePath).copy(p.join((await dir()).path, name));
    return describe(name);
  }

  Future<String> newRecordingPath() async => p.join((await dir()).path, _newName('m4a'));

  /// 폴더 안 파일의 해시·크기. 녹음이 끝난 파일에도 쓴다.
  Future<StoredFile> describe(String fileName) async {
    final f = await fileOf(fileName);
    final digest = await sha256.bind(f.openRead()).first;
    return StoredFile(fileName: fileName, sha256: digest.toString(), byteSize: await f.length());
  }

  Future<File> fileOf(String fileName) async => File(p.join((await dir()).path, fileName));

  Future<void> deleteFiles(Iterable<String> names) async {
    for (final n in names) {
      final f = await fileOf(n);
      if (await f.exists()) await f.delete();
    }
  }

  /// 전체 초기화 — 첨부 폴더만 통째로 지운다.
  Future<void> wipe() async {
    final d = Directory(p.join((await _baseDir()).path, folder));
    if (await d.exists()) await d.delete(recursive: true);
  }
}
