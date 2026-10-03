import 'package:flutter/widgets.dart' show StringCharacters;

/// 일정 제목 상한(글자 수). 넘으면 잘라 `…`을 붙인다(사용자 결정 2026-10-03).
const memoEventTitleMax = 20;

/// 쪽지 글 → 일정 제목·설명. **첫 줄(빈 줄 건너뜀)이 제목, 나머지가 설명**이다.
///
/// 쪽지는 여러 줄로 쓰는 것이 보통이라 글 전체를 제목으로 쓰면 일정 제목에 줄바꿈이
/// 들어간다. 빠른 입력은 한 줄이라 줄글 쪽지도 많은데, 첫 줄이 [memoEventTitleMax]자를
/// 넘으면 앞부분만 제목으로 쓰고(가능하면 띄어쓰기에서 자른다) **글 전체를 설명에 남긴다**
/// — 잘린 제목만 남으면 내용을 잃는다. 나머지가 없으면 설명은 null.
({String title, String? description}) splitMemoForEvent(String text) {
  final all = text.trim();
  final lines = all.split('\n');
  final first = lines.first.trim();
  final chars = first.characters;
  if (chars.length > memoEventTitleMax) {
    var head = chars.take(memoEventTitleMax).toString();
    // 절반보다 뒤에 띄어쓰기가 있으면 거기서 자른다 — 단어 중간에서 끊기지 않게.
    final space = head.lastIndexOf(' ');
    if (space >= memoEventTitleMax ~/ 2) head = head.substring(0, space);
    return (title: '${head.trimRight()}…', description: all);
  }
  final rest = lines.skip(1).join('\n').trim();
  return (title: first, description: rest.isEmpty ? null : rest);
}
