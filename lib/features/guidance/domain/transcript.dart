import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript.freezed.dart';

/// 기기가 받아 적은 문단 하나. **저장하지 않는다** — 화면이 떠 있는 동안만 산다.
@freezed
abstract class TranscriptSegment with _$TranscriptSegment {
  const factory TranscriptSegment({
    required int startMs,
    required int endMs,
    required String text,
  }) = _TranscriptSegment;
}

/// 이보다 길게 글이 없으면 "글 없음" 줄을 끼운다 — 작게 말한 학생의 말이 대개 여기 빠진다(스펙 실측).
const transcriptGapMs = 8000;

sealed class TranscriptItem {
  const TranscriptItem();
}

class TranscriptParagraph extends TranscriptItem {
  const TranscriptParagraph(this.segment, this.index);
  final TranscriptSegment segment;

  /// [cleanSegments] 순서의 번호. 화면이 `indexOf`로 찾지 않게 들고 다닌다 — 같은 내용의 문단도 번호가 다르다.
  final int index;
}

class TranscriptGap extends TranscriptItem {
  const TranscriptGap({required this.startMs, required this.lengthMs});
  final int startMs;
  final int lengthMs;
}

/// 빈 글을 버리고 시작 시각 순으로 놓는다. 화면·복사·재생 표시가 모두 이 목록을 본다.
List<TranscriptSegment> cleanSegments(List<TranscriptSegment> segments) => [
  for (final s in segments)
    if (s.text.trim().isNotEmpty) s,
]..sort((a, b) => a.startMs.compareTo(b.startMs));

List<TranscriptItem> buildTranscriptView(
  List<TranscriptSegment> segments, {
  int gapMs = transcriptGapMs,
}) {
  final items = <TranscriptItem>[];
  var cursor = 0;
  final visible = cleanSegments(segments);
  for (var i = 0; i < visible.length; i++) {
    final s = visible[i];
    if (s.startMs - cursor >= gapMs) {
      items.add(TranscriptGap(startMs: cursor, lengthMs: s.startMs - cursor));
    }
    items.add(TranscriptParagraph(s, i));
    // 겹치거나 뒤섞여 와도 커서는 뒤로 가지 않는다 — 음수 길이를 막는다.
    if (s.endMs > cursor) cursor = s.endMs;
  }
  return items;
}

/// 재생 위치가 들어 있는 문단의 인덱스([visible]은 [cleanSegments] 결과). 문단 밖이면 null.
int? activeSegmentIndex(List<TranscriptSegment> visible, int positionMs) {
  for (var i = 0; i < visible.length; i++) {
    final s = visible[i];
    if (positionMs >= s.startMs && positionMs < s.endMs) return i;
  }
  return null;
}

/// 한 시간 미만은 `MM:SS`, 이상은 `H:MM:SS`.
String formatTranscriptTime(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// 전체 복사 — `[시각] 글`을 빈 줄로 잇는다.
String formatTranscriptForCopy(List<TranscriptSegment> segments) => [
  for (final s in cleanSegments(segments))
    '[${formatTranscriptTime(s.startMs)}] ${s.text.trim()}',
].join('\n\n');
