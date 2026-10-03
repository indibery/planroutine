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

  group('iOS 앱 전환기 가림막', () {
    // 주석을 걷어낸 코드만 본다 — 주석이 채널 이름을 설명만 해도 통과하면 안 된다.
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final app = code('ios/Runner/AppDelegate.swift');
    final scene = code('ios/Runner/SceneDelegate.swift');

    test('AppDelegate가 Dart와 같은 채널 이름·메서드를 받는다', () {
      expect(app, contains('"${PlatformSecureWindow.channel.name}"'));
      expect(app, contains('"${PlatformSecureWindow.method}"'));
    });

    test('채널은 didInitializeImplicitFlutterEngine 안에서 잡는다', () {
      final start = app.indexOf('func didInitializeImplicitFlutterEngine');
      expect(start, greaterThanOrEqualTo(0));
      expect(app.indexOf('"${PlatformSecureWindow.channel.name}"', start), greaterThan(start));
    });

    test('SceneDelegate가 비활성 때 가림막을 올리고 활성 때 내린다(super 호출 포함)', () {
      expect(scene, contains('override func sceneWillResignActive'));
      expect(scene, contains('super.sceneWillResignActive(scene)'));
      expect(scene, contains('override func sceneDidBecomeActive'));
      expect(scene, contains('super.sceneDidBecomeActive(scene)'));
    });
  });
}
