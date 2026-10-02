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

  // Xcode 27은 배포 타깃 15.0 미만을 **오류**로 거부한다. 플러그인 Pods는 자기
  // podspec 값(9.0~13.0)을 그대로 들고 오므로, Pods를 새로 설치하는 순간 빌드가
  // 깨진다(2026-10-02 실측). post_install이 낮은 타깃을 앱 하한으로 올려야 한다.
  test('Podfile post_install이 낮은 Pods 배포 타깃을 platform 값으로 올린다', () {
    final src = File('ios/Podfile').readAsStringSync();
    final platform = RegExp(
      r"^platform :ios, '([\d.]+)'",
      multiLine: true,
    ).firstMatch(src)?.group(1);
    final postInstall = RegExp(
      r'^post_install do .*?^end',
      multiLine: true,
      dotAll: true,
    ).firstMatch(src)?.group(0);

    expect(postInstall, isNotNull, reason: 'Podfile에 post_install 블록이 없다');
    final floor = RegExp(
      r"IPHONEOS_DEPLOYMENT_TARGET'\]\.to_f < ([\d.]+)",
    ).firstMatch(postInstall!)?.group(1);
    final raised = RegExp(
      r"IPHONEOS_DEPLOYMENT_TARGET'\] = '([\d.]+)'",
    ).firstMatch(postInstall)?.group(1);

    expect(floor, isNotNull, reason: '낮은 타깃을 가려내는 비교가 없다');
    expect(raised, isNotNull, reason: '배포 타깃을 올리는 대입이 없다');
    // 숫자가 Podfile에 세 번 적힌다. 하나만 고치면 Pods가 앱과 다른 하한으로 빌드된다.
    expect(double.parse(floor!), double.parse(platform!));
    expect(raised, platform);
  });
}
