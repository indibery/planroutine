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

  // 1.4.2 재제출(2026-10-22): 제출 2초 뒤 한 번 읽은 값이 옛 빌드 v183이었고 14초 뒤엔 v184였다.
  // 옛 객체로 떨어지는 길(`|| edit`)과 예외를 삼키는 `edit_version`을 제출 확인에서 빼고, 다시 읽는다.
  group('제출 확인은 한 번 읽고 끝내지 않는다', () {
    final helperStart = fastfile.indexOf('def read_linked_build');
    // `_codeOnly`를 쓰지 않는다 — `#{e.class}` 같은 문자열 보간의 `#`부터 잘라 낸다. 본문에 주석은 없다.
    final helper = helperStart < 0
        ? ''
        : fastfile.substring(
            helperStart,
            fastfile.indexOf('\nend\n', helperStart),
          );

    test('제출 경로는 read_linked_build로 읽는다', () {
      final start = release.indexOf('if submit');
      final submitBranch = release.substring(
        start,
        release.indexOf('else', start),
      );
      expect(submitBranch, contains('read_linked_build'));
      expect(
        submitBranch,
        isNot(contains('|| edit')),
        reason: '레인 시작 때 읽은 옛 객체는 철회 전 빌드를 들고 있다',
      );
    });

    test('다시 읽기를 반복하고 사이에 기다린다', () {
      expect(helper, isNotEmpty, reason: 'read_linked_build가 없다');
      expect(helper, contains('attempts.times'));
      expect(helper, contains('sleep('));
    });

    test('조회 예외를 삼키는 edit_version을 쓰지 않고 예외를 로그에 남긴다', () {
      expect(helper, isNot(contains('edit_version(')));
      expect(helper, contains('get_edit_app_store_version'));
      expect(helper, contains('rescue StandardError => e'));
      expect(helper, contains('e.class'));
    });
  });
}
