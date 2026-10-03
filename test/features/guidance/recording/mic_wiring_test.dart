import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 마이크 사용 문구가 있다', () {
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('NSMicrophoneUsageDescription'));
  });

  test('Android가 RECORD_AUDIO를 선언한다', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android.permission.RECORD_AUDIO'),
    );
  });
}
