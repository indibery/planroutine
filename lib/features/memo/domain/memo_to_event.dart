/// 쪽지 글 → 일정 제목·설명. **첫 줄(빈 줄 건너뜀)이 제목, 나머지가 설명**이다.
///
/// 쪽지는 여러 줄로 쓰는 것이 보통이라 글 전체를 제목으로 쓰면 일정 제목에 줄바꿈이
/// 들어간다(사용자 결정 2026-10-03). 나머지가 없으면 설명은 null.
({String title, String? description}) splitMemoForEvent(String text) {
  final lines = text.trim().split('\n');
  final title = lines.first.trim();
  final rest = lines.skip(1).join('\n').trim();
  return (title: title, description: rest.isEmpty ? null : rest);
}
