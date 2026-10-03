import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';

/// 첨부 폴더 이름과 백업 제외 경로가 어긋나면 녹음이 클라우드 백업에 들어가
/// 25MB 상한을 넘기고, 그 순간 일정 DB 백업까지 멈춘다 — 증상 없이.
void main() {
  const res = 'android/app/src/main/res/xml';
  final excluded = 'path="${GuidanceFileStore.folder}/"';

  test('두 백업 규칙 파일이 첨부 폴더를 뺀다', () {
    for (final f in ['backup_rules.xml', 'data_extraction_rules.xml']) {
      expect(File('$res/$f').readAsStringSync(), contains(excluded), reason: f);
    }
  });

  test('매니페스트가 두 규칙 파일을 가리킨다', () {
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(m, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });
}
