// iOS `release submit:true` 오탐 가드(2026-10-09).
//
// 제출 경로에서는 deliver가 제출 흐름 안에서 빌드를 이미 붙인다. 레인이 그 뒤에 `select_build`를 또 부르면
// 이미 심사 대기(WAITING_FOR_REVIEW)인 버전이라 거부되고 `fastlane finished with errors`로 끝났다 — 제출은
// 정상인데 실패처럼 보였다(1.4.0·1.4.1 두 번 밟음). 제출 경로는 다시 붙이지 않고 **읽어서 확인**한다.
// submit:false(기본)는 deliver가 빌드를 붙이지 않으므로 레인이 직접 붙여야 한다 — 그 경로는 남는다.
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
  final fastfile = File('ios/fastlane/Fastfile').readAsStringSync();
  final release = _codeOnly(
    fastfile.substring(
      fastfile.indexOf('lane :release do'),
      fastfile.indexOf('lane :withdraw_review'),
    ),
  );

  test('제출 경로에서는 select_build를 다시 부르지 않는다', () {
    final start = release.indexOf('if submit');
    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'select_build를 submit으로 갈라야 한다',
    );
    final submitBranch = release.substring(
      start,
      release.indexOf('else', start),
    );
    expect(submitBranch, isNot(contains('select_build')));
  });

  test('submit:false 경로는 여전히 빌드를 직접 붙인다', () {
    final start = release.indexOf('if submit');
    final elseBranch = release.substring(release.indexOf('else', start));
    expect(elseBranch, contains('select_build'));
  });

  test('제출 경로는 연결된 빌드가 목표와 다르면 실패로 끝낸다 — 조용히 넘어가지 않는다', () {
    expect(release, contains('submit && linked'));
  });
}
