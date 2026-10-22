// Android `production` 승격 출처는 내부 테스트다(사용자 결정 2026-10-22).
//
// 프로덕션 액세스(2026-08-25 승인) 뒤로 비공개 테스트 12명·14일 요건이 더는 걸리지 않는다.
// 실기기 확인은 심사 없는 내부 테스트에서 하고, 그 바이너리를 그대로 프로덕션으로 올린다 —
// 비공개 테스트를 거치면 같은 바이너리로 심사를 두 번 기다린다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 주석을 걷어낸 Ruby — 스캐너는 언급과 사용을 구별하지 못한다(리포 함정).
String _codeOnly(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  final fastfile = File('android/fastlane/Fastfile').readAsStringSync();
  final start = fastfile.indexOf('lane :production do');
  final production = _codeOnly(fastfile.substring(start));

  test('production 레인이 있다', () {
    expect(start, greaterThanOrEqualTo(0));
  });

  test('기본 출처는 내부 테스트 트랙이다', () {
    expect(fastfile, contains('INTERNAL_TRACK = "internal"'));
    expect(
      production,
      contains('options[:from] || INTERNAL_TRACK'),
      reason: '출처를 정하는 자리는 한 곳이고 기본값이 internal이어야 한다',
    );
  });

  test('승격 호출과 가드가 같은 출처를 본다', () {
    expect(production, contains('track: source,'));
    expect(production, contains('track_codes(source)'));
    expect(
      production,
      isNot(contains('track: CLOSED_TRACK')),
      reason: '가드는 internal을 보는데 승격은 alpha에서 하면 검증한 번호와 다른 곳을 찾는다',
    );
  });
}
