// App Intents는 iOS 16+에서만 존재한다. 배포 타깃이 낮아지면 인텐트가
// **빌드에서 조용히 빠지고** 단축어 앱에서 앱이 사라진다 — 컴파일은 통과한다.
// 그래서 값 자체를 가드로 고정한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pbxproj의 배포 타깃이 모두 16.0 이상이다', () {
    final src = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final matches = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
    ).allMatches(src).toList();

    expect(matches, isNotEmpty, reason: '배포 타깃 설정을 찾지 못했다');
    for (final m in matches) {
      final value = double.parse(m.group(1)!);
      expect(
        value,
        greaterThanOrEqualTo(16.0),
        reason: 'App Intents는 iOS 16+ 전용이다. $value로는 인텐트가 빌드에서 빠진다',
      );
    }
  });

  test('Podfile의 platform 선언이 16.0 이상이다', () {
    final src = File('ios/Podfile').readAsStringSync();
    final m = RegExp(
      r"^platform :ios, '([\d.]+)'",
      multiLine: true,
    ).firstMatch(src);

    expect(m, isNotNull, reason: 'Podfile에 platform 선언이 없다(주석 해제 필요)');
    expect(double.parse(m!.group(1)!), greaterThanOrEqualTo(16.0));
  });
}
