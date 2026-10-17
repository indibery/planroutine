import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/source_scan.dart';

const _feature = 'lib/features/schoolbook';

void main() {
  test('캘린더·오늘·알림·Google·휴지통·입력·포스트잇·지도 기록·단축어는 장소 예약을 모른다', () {
    const forbidden = [
      'lib/features/calendar',
      'lib/features/today',
      'lib/features/notifications',
      'lib/features/google',
      'lib/features/trash',
      'lib/features/schedule',
      'lib/features/import',
      'lib/features/memo',
      'lib/features/guidance',
      'lib/core/app_intents',
      'lib/features/settings/data/schedule_csv_exporter.dart',
    ];
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
        expect(f.readAsStringSync().toLowerCase().contains('schoolbook'), isFalse,
            reason: f.path);
      }
    }
  });

  test('스쿨북 API는 다섯 가지만 부른다 — 설정을 바꾸는 API가 없다', () {
    final code = strippedCode('$_feature/data/schoolbook_api_client.dart');
    expect(code, isNot(contains('.put(')));
    expect(code, isNot(contains('.patch(')));
    for (final word in ['timetables', 'periods/', 'notices', 'tools', 'register']) {
      expect(code, isNot(contains(word)), reason: word);
    }
    // 그 밖의 파일은 HTTP를 직접 부르지 않는다
    for (final f in libDartFiles().where((f) => f.path.contains(_feature))) {
      if (f.path.endsWith('schoolbook_api_client.dart')) continue;
      expect(strippedCode(f.path), isNot(contains('package:http')), reason: f.path);
    }
  });

  test('설정 JSON 모델에는 비밀번호가 없다', () {
    expect(
      strippedCode('$_feature/domain/schoolbook_settings.dart').toLowerCase(),
      isNot(contains('password')),
    );
  });

  test('비밀번호 보안 저장소를 만지는 파일은 하나뿐이다', () {
    final users = [
      for (final f in libDartFiles())
        if (strippedCode(f.path).contains('FlutterSecureStorage') ||
            strippedCode(f.path).contains('schoolbook_password_v1'))
          f.path,
    ];
    expect(users, ['$_feature/data/schoolbook_password_store.dart']);
  });

  test('취소 시트는 저장한 비밀번호를 채우지 않는다', () {
    final code = strippedCode('$_feature/presentation/widgets/cancel_sheet.dart');
    expect(code, isNot(contains('PasswordStore')));
    expect(code, isNot(contains('initialPassword')));
  });
}
