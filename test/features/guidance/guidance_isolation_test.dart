import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 지도 기록은 잠금 안에만 있다. 잠금이 없는 화면·밖으로 나가는 경로가 이 기록을 읽으면
/// 잠금이 무의미해진다 — 그 코드들에 `guidance`라는 낱말 자체가 없어야 한다.
void main() {
  const forbidden = [
    'lib/features/calendar',
    'lib/features/today',
    'lib/features/notifications',
    'lib/features/google',
    'lib/features/trash',
    'lib/features/schedule',
    'lib/features/import',
    'lib/features/memo',
    'lib/core/app_intents',
    'lib/features/settings/data/schedule_csv_exporter.dart',
  ];

  test('캘린더·오늘·알림·Google·공용 휴지통·내보내기·단축어는 지도 기록을 모른다', () {
    for (final path in forbidden) {
      final entity = FileSystemEntity.typeSync(path);
      expect(entity, isNot(FileSystemEntityType.notFound), reason: '$path 없음');
      final files = entity == FileSystemEntityType.directory
          ? Directory(path)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
          : [File(path)];
      for (final f in files) {
        expect(
          f.readAsStringSync().toLowerCase().contains('guidance'),
          isFalse,
          reason: f.path,
        );
      }
    }
  });

  test('공용 휴지통의 30일 정리는 지도 기록 저장소를 부르지 않는다', () {
    final src = File(
      'lib/features/trash/presentation/providers/trash_providers.dart',
    ).readAsStringSync();
    expect(src.contains('Guidance'), isFalse);
  });
}
