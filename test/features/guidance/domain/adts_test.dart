import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/adts.dart';

/// ADTS 프레임 하나(헤더 7바이트 + 본문). 44.1kHz = 샘플링 인덱스 4.
List<int> frame(int length, {int samplingIndex = 4}) {
  final h = List<int>.filled(length, 0);
  h[0] = 0xFF;
  h[1] = 0xF1;
  h[2] = (1 << 6) | (samplingIndex << 2); // AAC LC, 채널 비트 상위는 0
  h[3] = (1 << 6) | ((length >> 11) & 0x03); // 모노
  h[4] = (length >> 3) & 0xFF;
  h[5] = ((length & 0x07) << 5) | 0x1F;
  h[6] = 0xFC;
  return h;
}

void main() {
  test('온전한 프레임만 있으면 전체 길이와 프레임 수만큼의 재생 시간을 돌려준다', () {
    final bytes = Uint8List.fromList([
      ...frame(200),
      ...frame(180),
      ...frame(190),
    ]);
    final scan = scanAdts(bytes);
    expect(scan.completeLength, 570);
    expect(scan.frames, 3);
    // 프레임당 1024샘플 ÷ 44100Hz
    expect(scan.durationMs, (3 * 1024 * 1000 / 44100).round());
  });

  test('끝에 잘린 프레임은 빼고 센다 — 앱이 쓰는 도중 꺼진 파일', () {
    final tail = frame(200).sublist(0, 50);
    final bytes = Uint8List.fromList([...frame(200), ...frame(200), ...tail]);
    final scan = scanAdts(bytes);
    expect(scan.completeLength, 400);
    expect(scan.frames, 2);
  });

  test('헤더 7바이트도 다 못 쓴 꼬리도 뺀다', () {
    final bytes = Uint8List.fromList([...frame(200), 0xFF, 0xF1, 0x50]);
    expect(scanAdts(bytes).completeLength, 200);
  });

  test('동기 신호가 깨진 자리에서 멈춘다', () {
    final bytes = Uint8List.fromList([
      ...frame(200),
      0x00,
      0x01,
      ...frame(200),
    ]);
    expect(scanAdts(bytes).completeLength, 200);
  });

  test('빈 파일은 0이다', () {
    final scan = scanAdts(Uint8List(0));
    expect((scan.completeLength, scan.frames, scan.durationMs), (0, 0, 0));
  });

  test('다른 샘플링 주파수도 헤더에서 읽는다', () {
    // 48kHz = 인덱스 3
    final bytes = Uint8List.fromList([
      ...frame(100, samplingIndex: 3),
      ...frame(100, samplingIndex: 3),
    ]);
    expect(scanAdts(bytes).durationMs, (2 * 1024 * 1000 / 48000).round());
  });
}
