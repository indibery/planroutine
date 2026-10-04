import 'dart:typed_data';

/// ADTS AAC 파일을 앞에서부터 훑은 결과.
class AdtsScan {
  const AdtsScan({
    required this.completeLength,
    required this.frames,
    required this.durationMs,
  });

  /// 끝까지 온전히 쓰인 프레임들의 바이트 길이. 잘린 꼬리는 들어가지 않는다.
  final int completeLength;
  final int frames;
  final int durationMs;
}

const _sampleRates = [
  96000,
  88200,
  64000,
  48000,
  44100,
  32000,
  24000,
  22050,
  16000,
  12000,
  11025,
  8000,
  7350,
];

/// 녹음은 ADTS AAC로 쓴다 — 프레임마다 헤더가 있어 **중간에 끊겨도 그때까지는 재생된다**
/// (`.m4a`는 멈출 때 목차를 맨 끝에 써서, 방전·강제 종료로 끊기면 통째로 재생되지 않는다).
/// 끊긴 파일을 되살릴 때 마지막 잘린 프레임을 버리고 재생 시간을 프레임 수로 센다.
AdtsScan scanAdts(Uint8List bytes) {
  var i = 0;
  var frames = 0;
  var samples = 0.0;
  while (i + 7 <= bytes.length) {
    if (bytes[i] != 0xFF || (bytes[i + 1] & 0xF0) != 0xF0) break;
    final length =
        ((bytes[i + 3] & 0x03) << 11) |
        (bytes[i + 4] << 3) |
        ((bytes[i + 5] & 0xE0) >> 5);
    if (length < 7 || i + length > bytes.length) break;
    final index = (bytes[i + 2] >> 2) & 0x0F;
    if (index >= _sampleRates.length) break;
    // 프레임당 1024샘플 → 초 단위로 더해 두고 마지막에 밀리초로 바꾼다.
    samples += 1024 / _sampleRates[index];
    frames++;
    i += length;
  }
  return AdtsScan(
    completeLength: i,
    frames: frames,
    durationMs: (samples * 1000).round(),
  );
}
