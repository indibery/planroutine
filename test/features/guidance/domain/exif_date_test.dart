import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/exif_date.dart';

import '../../../helpers/exif_bytes.dart';

void main() {
  const taken = '2026:11:02 09:12:30';

  test('JPEG의 DateTimeOriginal을 읽는다', () {
    expect(
      exifTakenAt(jpegWithExif(tiffWithDates(original: taken))),
      DateTime(2026, 11, 2, 9, 12, 30),
    );
  });

  test('빅 엔디언(MM)도 읽는다', () {
    expect(
      exifTakenAt(
        jpegWithExif(tiffWithDates(original: taken, bigEndian: true)),
      ),
      DateTime(2026, 11, 2, 9, 12, 30),
    );
  });

  test('HEIC처럼 Exif 항목이 파일 중간에 있어도 읽는다', () {
    expect(
      exifTakenAt(heicLikeWithExif(tiffWithDates(original: taken))),
      DateTime(2026, 11, 2, 9, 12, 30),
    );
  });

  test('촬영 시각이 둘 다 있으면 DateTimeOriginal이 이긴다', () {
    expect(
      exifTakenAt(
        jpegWithExif(
          tiffWithDates(original: taken, modified: '2026:11:04 18:00:00'),
        ),
      ),
      DateTime(2026, 11, 2, 9, 12, 30),
    );
  });

  test('DateTimeOriginal이 없으면 IFD0의 DateTime을 쓴다', () {
    expect(
      exifTakenAt(jpegWithExif(tiffWithDates(modified: '2026:11:04 18:00:00'))),
      DateTime(2026, 11, 4, 18),
    );
  });

  test('EXIF가 없거나 날짜가 깨졌으면 null', () {
    expect(exifTakenAt(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9])), isNull);
    expect(exifTakenAt(Uint8List(0)), isNull);
    expect(
      exifTakenAt(jpegWithExif(tiffWithDates(original: '0000:00:00 00:00:00'))),
      isNull,
    );
    expect(
      exifTakenAt(jpegWithExif(tiffWithDates(original: 'garbage-garbage-gar'))),
      isNull,
    );
  });

  test('오프셋이 파일 밖을 가리켜도 던지지 않고 null', () {
    final tiff = tiffWithDates(original: taken);
    // 마지막 문자열을 잘라 낸다 — 오프셋은 그대로 남는다
    final cut = Uint8List.sublistView(tiff, 0, tiff.length - 15);
    expect(exifTakenAt(jpegWithExif(cut)), isNull);
  });
}
