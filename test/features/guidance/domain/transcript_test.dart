import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/transcript.dart';

TranscriptSegment seg(int s, int e, [String t = '말']) =>
    TranscriptSegment(startMs: s, endMs: e, text: t);

void main() {
  group('formatTranscriptTime', () {
    test('한 시간 미만은 MM:SS', () {
      expect(formatTranscriptTime(0), '00:00');
      expect(formatTranscriptTime(75 * 1000 + 900), '01:15');
    });
    test('한 시간 이상은 H:MM:SS — 62:15가 되면 안 된다', () {
      expect(formatTranscriptTime((3600 + 135) * 1000), '1:02:15');
    });
  });

  group('cleanSegments', () {
    test('빈 글·공백 글을 버리고 시작 시각 순으로 놓는다', () {
      final out = cleanSegments([
        seg(9000, 12000, 'B'),
        seg(0, 3000, '  '),
        seg(1000, 4000, 'A'),
      ]);
      expect(out.map((s) => s.text), ['A', 'B']);
    });
  });

  group('buildTranscriptView', () {
    test('사이가 8초 이상이면 글 없음 줄을 끼운다', () {
      final items = buildTranscriptView([seg(0, 5000), seg(13000, 15000)]);
      expect(items, hasLength(3));
      final gap = items[1] as TranscriptGap;
      expect(gap.startMs, 5000);
      expect(gap.lengthMs, 8000);
    });
    test('8초 미만이면 끼우지 않는다', () {
      expect(
        buildTranscriptView([
          seg(0, 5000),
          seg(12999, 15000),
        ]).whereType<TranscriptGap>(),
        isEmpty,
      );
    });
    test('녹음 맨 앞이 8초 이상 비면 처음에 글 없음 줄', () {
      final items = buildTranscriptView([seg(9000, 10000)]);
      expect(items.first, isA<TranscriptGap>());
      expect((items.first as TranscriptGap).startMs, 0);
    });
    test('겹치거나 뒤섞여 와도 음수 길이가 생기지 않는다', () {
      final items = buildTranscriptView([seg(4000, 9000), seg(0, 6000)]);
      expect(items.whereType<TranscriptGap>(), isEmpty);
      expect(items.whereType<TranscriptParagraph>(), hasLength(2));
    });
    test('문단이 0개면 빈 목록', () {
      expect(buildTranscriptView(const []), isEmpty);
    });
  });

  group('activeSegmentIndex', () {
    final segs = [seg(0, 5000), seg(15000, 20000)];
    test('시작 전·글 없음 구간 안·끝 뒤는 null', () {
      expect(activeSegmentIndex(segs, 9000), isNull);
      expect(activeSegmentIndex(segs, 25000), isNull);
    });
    test('문단 안이면 그 인덱스', () {
      expect(activeSegmentIndex(segs, 0), 0);
      expect(activeSegmentIndex(segs, 16000), 1);
    });
  });

  test('전체 복사는 [시각] 글을 빈 줄로 잇는다', () {
    expect(
      formatTranscriptForCopy([
        seg(15000, 16000, '둘째'),
        seg(0, 1000, '첫째'),
        seg(2000, 3000, ' '),
      ]),
      '[00:00] 첫째\n\n[00:15] 둘째',
    );
  });
}
