// 8GB 맥에서 Gradle 데몬이 시뮬레이터·에뮬레이터와 메모리를 다툰다(2026-10-09 실측).
//
// release AAB 빌드 중 데몬 최대 RSS는 상한 8G·3G와 무관하게 2.3~2.7GB였고, **빌드가 끝난 뒤에도
// 데몬이 약 1.2GB를 쥔 채 몇 시간 남는다** — 예전에 시뮬레이터 SpringBoard가 반복 종료된 원인이다.
// 그래서 상한을 3G로 두고(빌드 성공·시간 차이 없음 확인), 배포 레인이 빌드 뒤 데몬을 스스로 멈춘다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _codeOnly(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  test('Gradle 힙 상한은 3G다 — 8G면 최악의 경우 시뮬레이터 몫까지 가져간다', () {
    final props = File('android/gradle.properties').readAsStringSync();
    expect(RegExp(r'^org\.gradle\.jvmargs=-Xmx3G\b', multiLine: true).hasMatch(props), isTrue);
  });

  test('build_aab는 끝나면(실패해도) Gradle 데몬을 멈춘다', () {
    final fastfile = _codeOnly(File('android/fastlane/Fastfile').readAsStringSync());
    final lane = fastfile.substring(fastfile.indexOf('lane :build_aab'), fastfile.indexOf('AAB 준비 완료'));
    expect(lane, contains('ensure'));
    expect(lane, contains('stop_gradle_daemons'));
    expect(fastfile, contains('--stop'));
  });
}
