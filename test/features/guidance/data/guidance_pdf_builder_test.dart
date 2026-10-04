import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planroutine/features/guidance/data/guidance_pdf_builder.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

GuidanceRecord record(GuidanceContent c, {int revisions = 1}) => GuidanceRecord(
  id: 1,
  createdAt: '2026-10-04T15:30:00',
  revisionCount: revisions,
  latest: GuidanceRevision(
    recordId: 1,
    revisionNo: revisions,
    savedAt: '2026-10-05T09:12:00',
    content: c,
  ),
);

GuidanceAttachment image(int id) => GuidanceAttachment(
  id: id,
  recordId: 1,
  type: AttachmentType.image,
  source: AttachmentSource.imported,
  fileName: '$id.jpg',
  sha256: 'b' * 64,
  byteSize: 100,
  attachedAt: '2026-10-04T15:4$id:00',
);

/// 압축하지 않은 PDF에서 쪽 객체를 센다(`/Type /Pages`는 빼고).
int pageCount(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(latin1.decode(pdf)).length;

pw.Font font(String path) =>
    pw.Font.ttf(File(path).readAsBytesSync().buffer.asByteData());

void main() {
  // 엔진 이미지 코덱(dart:ui)을 쓰려면 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => initializeDateFormatting('ko', null));
  late GuidancePdfFonts fonts;
  setUpAll(() {
    fonts = GuidancePdfFonts(
      base: font('assets/fonts/PretendardVariable.ttf'),
      bold: font('assets/fonts/Pretendard-Bold.ttf'),
    );
  });

  ExportPlan emptyPlan() => buildExportPlan(
    createdAt: '2026-10-04T15:30:00',
    attachments: const [],
    selectedIds: const {},
  );

  Future<Uint8List> build(
    GuidanceRecord r,
    ExportPlan plan,
    Map<int, Uint8List?> photos, {
    ExportKind kind = ExportKind.bundle,
  }) => buildGuidancePdf(
    record: r,
    plan: plan,
    kind: kind,
    photos: photos,
    generatedAt: DateTime(2026, 10, 6, 8),
    fonts: fonts,
    compress: false,
  );

  test('빈 기록 — 제목만 있어도 한 쪽짜리 PDF가 나온다', () async {
    final pdf = await build(
      record(const GuidanceContent(title: '확인')),
      emptyPlan(),
      const {},
      kind: ExportKind.pdfOnly,
    );
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    expect(pageCount(pdf), 1);
  });

  test('사진마다 붙임 한 쪽이 더해진다', () async {
    final jpg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 40, height: 30)),
    );
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [image(1), image(2)],
      selectedIds: {1, 2},
    );
    final pdf = await build(
      record(const GuidanceContent(title: '사진 둘', facts: '경과')),
      plan,
      {1: await shrinkPhotoForPdf(jpg), 2: await shrinkPhotoForPdf(jpg)},
    );
    expect(pageCount(pdf), 3);
  });

  test('디코드할 수 없는 사진(HEIC 등)은 축소 결과가 null이고, 그래도 붙임 쪽은 생긴다', () async {
    expect(
      await shrinkPhotoForPdf(Uint8List.fromList(utf8.encode('not an image'))),
      isNull,
    );
    final plan = buildExportPlan(
      createdAt: '2026-10-04T15:30:00',
      attachments: [image(1)],
      selectedIds: {1},
    );
    final pdf = await build(
      record(const GuidanceContent(title: 'heic')),
      plan,
      {1: null},
    );
    expect(pageCount(pdf), 2);
  });

  test('줄바꿈 없는 긴 글은 예외 없이 여러 쪽으로 나뉜다', () async {
    final pdf = await build(
      record(GuidanceContent(title: '긴 글', facts: '가' * 6000)),
      emptyPlan(),
      const {},
      kind: ExportKind.pdfOnly,
    );
    expect(pageCount(pdf), greaterThan(1));
  });

  test('축소본은 긴 변이 maxSide를 넘지 않고 EXIF 방향을 반영한다', () async {
    final wide = img.Image(width: 3000, height: 1000);
    wide.exif.imageIfd.orientation = 6; // 90도 돌려서 보여야 하는 사진
    final out = img.decodeJpg(
      await shrinkPhotoForPdf(Uint8List.fromList(img.encodeJpg(wide))) ??
          Uint8List(0),
    );
    expect(out, isNotNull);
    expect(out?.height, 2000); // 돌린 뒤 세로가 긴 변
    expect(out?.width, closeTo(667, 1));
  });

  test('작은 사진은 키우지 않는다', () async {
    final small = img.Image(width: 400, height: 300);
    final out = img.decodeJpg(
      await shrinkPhotoForPdf(Uint8List.fromList(img.encodeJpg(small))) ??
          Uint8List(0),
    );
    expect(out?.width, 400);
    expect(out?.height, 300);
  });
  test('단락은 줄바꿈에서만 나눈다 — 제출 문서 문장 중간에 줄이 끊기지 않는다', () {
    expect(pdfParagraphs('가' * 350), hasLength(1));
    expect(pdfParagraphs('첫 줄\n둘째 줄'), ['첫 줄', '둘째 줄']);
  });
  test('첨부 표에 SHA-256 64자리가 그대로 들어간다 — 받는 쪽이 원본과 대조한다', () async {
    final plan = buildExportPlan(createdAt: '2026-10-04T15:30:00', attachments: [image(1)], selectedIds: {1});
    final pdf = await build(record(const GuidanceContent(title: '해시')), plan, {1: null});
    // Courier(PDF 기본 글꼴)라 압축하지 않은 PDF에 글자가 그대로 남는다.
    expect(latin1.decode(pdf).contains('b' * 64), isTrue);
  });
}
