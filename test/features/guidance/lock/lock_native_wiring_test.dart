import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';

void main() {
  final kt = File('android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt').readAsStringSync();

  test('MainActivity는 FragmentActivity다(local_auth 요구)', () {
    expect(kt, contains('class MainActivity : FlutterFragmentActivity()'));
  });

  test('보안 창 채널 이름이 양쪽에서 같다', () {
    expect(kt, contains('"${PlatformSecureWindow.channel.name}"'));
    expect(kt, contains('FLAG_SECURE'));
  });

  test('LaunchTheme가 두 테마 모두 AppCompat이다', () {
    for (final f in ['values', 'values-night']) {
      final xml = File('android/app/src/main/res/$f/styles.xml').readAsStringSync();
      expect(RegExp(r'name="LaunchTheme" parent="Theme\.AppCompat').hasMatch(xml), isTrue, reason: f);
    }
  });

  test('iOS Face ID 사용 문구가 있다', () {
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('NSFaceIDUsageDescription'));
  });
}
