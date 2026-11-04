import 'dart:convert';
import 'dart:typed_data';

/// 테스트용 TIFF(EXIF 본문). [original]은 Exif IFD의 DateTimeOriginal(0x9003),
/// [modified]는 IFD0의 DateTime(0x0132). 값은 `YYYY:MM:DD HH:MM:SS`.
Uint8List tiffWithDates({
  String? original,
  String? modified,
  bool bigEndian = false,
}) {
  final e = bigEndian ? Endian.big : Endian.little;
  final out = BytesBuilder();
  void u16(int v) =>
      out.add((ByteData(2)..setUint16(0, v, e)).buffer.asUint8List());
  void u32(int v) =>
      out.add((ByteData(4)..setUint32(0, v, e)).buffer.asUint8List());

  // 배치: 헤더(8) · IFD0(2 + 12n + 4) · ExifIFD(2 + 12 + 4) · 문자열들
  final ifd0Count = (modified != null ? 1 : 0) + (original != null ? 1 : 0);
  final ifd0Size = 2 + 12 * ifd0Count + 4;
  final exifOffset = 8 + ifd0Size;
  final exifSize = original != null ? 2 + 12 + 4 : 0;
  var strOffset = exifOffset + exifSize;
  final modifiedAt = strOffset;
  if (modified != null) strOffset += 20;
  final originalAt = strOffset;

  out.add(bigEndian ? ascii.encode('MM') : ascii.encode('II'));
  u16(42);
  u32(8);
  u16(ifd0Count);
  if (modified != null) {
    u16(0x0132);
    u16(2);
    u32(20);
    u32(modifiedAt);
  }
  if (original != null) {
    u16(0x8769);
    u16(4);
    u32(1);
    u32(exifOffset);
  }
  u32(0);
  if (original != null) {
    u16(1);
    u16(0x9003);
    u16(2);
    u32(20);
    u32(originalAt);
    u32(0);
  }
  if (modified != null) {
    out
      ..add(ascii.encode(modified))
      ..addByte(0);
  }
  if (original != null) {
    out
      ..add(ascii.encode(original))
      ..addByte(0);
  }
  return out.toBytes();
}

/// JPEG 파일처럼: SOI · APP1("Exif\0\0" + TIFF) · 몇 바이트 더.
Uint8List jpegWithExif(Uint8List tiff) {
  final payload = [...ascii.encode('Exif'), 0, 0, ...tiff];
  final len = payload.length + 2;
  return Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE1,
    len >> 8,
    len & 0xFF,
    ...payload,
    0xFF,
    0xD9,
  ]);
}

/// HEIC처럼: 앞에 상자들이 있고, Exif 항목은 4바이트 오프셋 뒤에 "Exif\0\0" + TIFF.
Uint8List heicLikeWithExif(Uint8List tiff) => Uint8List.fromList([
  ...List<int>.filled(300, 7),
  // 실제 HEIC는 infe 상자에 항목 종류 이름으로 `Exif\0\0`을 먼저 적는다(뒤는 TIFF가 아니다)
  ...ascii.encode('Exif'), 0, 0, 0, 0, ...ascii.encode(')infe'),
  ...List<int>.filled(100, 7),
  0,
  0,
  0,
  6,
  ...ascii.encode('Exif'),
  0,
  0,
  ...tiff,
  ...List<int>.filled(50, 9),
]);
