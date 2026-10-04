import 'dart:typed_data';

import 'package:archive/archive.dart';

/// PDF와 원본을 한 ZIP으로. 원본은 바이트 그대로 **store**로 넣는다 — 녹음·사진은 이미 압축된
/// 형식이라 다시 압축해 얻는 것이 없고, 받는 쪽이 해시를 대조할 바이트가 그대로 남는다.
Uint8List buildGuidanceZip(List<(String, List<int>)> files) {
  final archive = Archive();
  for (final (name, bytes) in files) {
    archive.addFile(
      ArchiveFile.bytes(name, bytes)..compression = CompressionType.none,
    );
  }
  return ZipEncoder().encodeBytes(archive);
}
