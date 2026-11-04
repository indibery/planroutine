import 'dart:convert';
import 'dart:typed_data';

/// 사진 원본에 적힌 촬영 시각(EXIF). 없거나 읽을 수 없으면 null.
///
/// JPEG(APP1)와 HEIC(Exif 항목) 모두 본문이 `Exif\0\0` 뒤의 TIFF라, 그 표식을 찾아 TIFF만 읽는다 —
/// 컨테이너 구조는 해석하지 않는다. `image` 패키지는 HEIC를 못 읽어 직접 읽는다.
/// DateTimeOriginal(0x9003)이 먼저, 없으면 IFD0의 DateTime(0x0132). 시간대 정보가 없어 기기 시각으로 본다.
DateTime? exifTakenAt(Uint8List bytes) {
  final start = _findExif(bytes);
  if (start == null) return null;
  try {
    final t = ByteData.sublistView(bytes, start);
    final Endian e;
    if (t.getUint8(0) == 0x49 && t.getUint8(1) == 0x49) {
      e = Endian.little;
    } else if (t.getUint8(0) == 0x4D && t.getUint8(1) == 0x4D) {
      e = Endian.big;
    } else {
      return null;
    }
    if (t.getUint16(2, e) != 42) return null;
    final ifd0 = t.getUint32(4, e);
    String? modified;
    int? exifIfd;
    _entries(t, ifd0, e, (tag, at) {
      if (tag == 0x0132) modified = _ascii(t, at, e);
      if (tag == 0x8769) exifIfd = t.getUint32(at + 8, e);
    });
    String? original;
    final sub = exifIfd;
    if (sub != null) {
      _entries(t, sub, e, (tag, at) {
        if (tag == 0x9003) original = _ascii(t, at, e);
      });
    }
    return _parse(original) ?? _parse(modified);
  } on RangeError {
    return null;
  }
}

final _marker = ascii.encode('Exif\u0000\u0000');

/// `Exif\0\0` 바로 뒤가 TIFF 머리(`II*\0`·`MM\0*`)인 첫 자리. HEIC에는 항목 종류 이름으로도
/// `Exif\0\0`이 먼저 나와서(실측: `infe` 상자) 머리까지 맞아야 본문으로 본다.
int? _findExif(Uint8List b) {
  outer:
  for (var i = 0; i + _marker.length + 8 <= b.length; i++) {
    for (var j = 0; j < _marker.length; j++) {
      if (b[i + j] != _marker[j]) continue outer;
    }
    final t = i + _marker.length;
    final little = b[t] == 0x49 && b[t + 1] == 0x49 && b[t + 2] == 42 && b[t + 3] == 0;
    final big = b[t] == 0x4D && b[t + 1] == 0x4D && b[t + 2] == 0 && b[t + 3] == 42;
    if (little || big) return t;
  }
  return null;
}

void _entries(
  ByteData t,
  int ifd,
  Endian e,
  void Function(int tag, int at) each,
) {
  final count = t.getUint16(ifd, e);
  for (var k = 0; k < count; k++) {
    final at = ifd + 2 + 12 * k;
    each(t.getUint16(at, e), at);
  }
}

/// ASCII 값(형식 2). 20바이트 날짜는 항상 4바이트를 넘으므로 오프셋에 있다.
String? _ascii(ByteData t, int at, Endian e) {
  if (t.getUint16(at + 2, e) != 2) return null;
  final n = t.getUint32(at + 4, e);
  if (n <= 4) return null;
  final off = t.getUint32(at + 8, e);
  final chars = [for (var i = 0; i < n; i++) t.getUint8(off + i)];
  return ascii.decode(
    chars.takeWhile((c) => c != 0).toList(),
    allowInvalid: true,
  );
}

final _datePattern = RegExp(
  r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
);

DateTime? _parse(String? s) {
  final m = s == null ? null : _datePattern.firstMatch(s);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i) ?? '0')];
  if (v[0] < 1900 || v[1] < 1 || v[1] > 12 || v[2] < 1 || v[2] > 31) {
    return null;
  }
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}
