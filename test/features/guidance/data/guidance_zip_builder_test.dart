import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_zip_builder.dart';

void main() {
  test('다시 풀면 같은 이름·같은 바이트이고, 원본은 store로 들어간다', () {
    final audio = utf8.encode('abc'); // SHA-256 표준 시험 벡터
    final pdf = utf8.encode('%PDF-1.4 fake');
    final zip = buildGuidanceZip([
      ('20261004-1530_record.pdf', pdf),
      ('20261004-1530_01.aac', audio),
    ]);

    final archive = ZipDecoder().decodeBytes(zip);
    expect(archive.files.map((f) => f.name), [
      '20261004-1530_record.pdf',
      '20261004-1530_01.aac',
    ]);
    final a = archive.files.firstWhere((f) => f.name.endsWith('.aac'));
    expect(
      sha256.convert(a.readBytes() ?? const []).toString(),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    for (final f in archive.files) {
      expect(f.compression, CompressionType.none, reason: f.name);
    }
  });
}
