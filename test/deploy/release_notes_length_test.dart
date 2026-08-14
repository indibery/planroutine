// 릴리즈 노트가 스토어 상한을 넘지 않는지.
//
// **2026-08-14에 실제로 났다.** `android beta`가 clean 빌드를 다 돌고 **업로드
// 마지막 단계에서** 거부됐다:
//
//   Google Api Error: Invalid request - The release created has notes in
//   language ko-KR with length 787, which is too long (max: 500).
//
// 기존 가드(`fastlane_lane_docs_test`의 가드 E 계열)는 릴리즈 노트의 **존재**만
// 본다. 길이는 아무도 안 봐서, 검사가 있는데 정작 실패하는 축을 안 재고 있었다.
// 값은 clean 빌드 수 분 + versionCode 소비 위험이다(이번엔 Play edit이 commit에서
// 거부돼 번호는 안 먹혔지만, 그건 운이지 설계가 아니다).
//
// **`.strip` 기준으로 잰다** — `android/fastlane/Fastfile`의 `stage_changelog`가
// `File.read(src).strip`으로 쓴다. 끝 개행을 빼고 세야 Play가 세는 값과 같다
// (실측: `wc -m` 788 ↔ Play 787).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Play Console `이번 버전의 새로운 기능` 상한. 오류 메시지가 `max: 500`으로 알려줬다.
const _playMaxChars = 500;

/// App Store `새로운 기능` 상한은 4000자로 훨씬 넉넉하다 — 같은 사고가 나기 어렵다.
const _appStoreMaxChars = 4000;

void main() {
  final dir = Directory('docs/release_notes');

  test('릴리즈 노트 디렉터리가 있다', () {
    expect(dir.existsSync(), isTrue, reason: '경로가 바뀌면 아래 검사가 조용히 0건이 된다');
  });

  final notes = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList();

  test('검사할 노트가 하나 이상 있다', () {
    expect(notes, isNotEmpty, reason: '한 건도 못 찾으면 이 파일 전체가 무의미하다');
  });

  for (final f in notes) {
    final name = f.uri.pathSegments.last;
    // 파일명 `<버전>-android.ko.txt`가 Play용, `<버전>.ko.txt`가 App Store용이다
    // (`Fastfile:207`이 android 접미사를 먼저 찾는다).
    final isAndroid = name.contains('-android');
    final max = isAndroid ? _playMaxChars : _appStoreMaxChars;
    final store = isAndroid ? 'Play' : 'App Store';

    test('$name — $store 상한 $max자 이내', () {
      // Fastfile이 `.strip`으로 쓰므로 같은 기준으로 잰다.
      final length = f.readAsStringSync().trim().length;

      expect(
        length,
        lessThanOrEqualTo(max),
        reason:
            '$name 이 $length자다. $store는 $max자를 넘으면 **업로드 마지막 단계에서** '
            '거부한다 — clean 빌드를 다 돌고 나서 터진다',
      );
    });
  }
}
