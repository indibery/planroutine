import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_strings.dart';
import '../domain/guidance_export.dart';
import '../domain/guidance_logic.dart';
import '../domain/guidance_models.dart';

class GuidancePdfFonts {
  const GuidancePdfFonts({required this.base, required this.bold});
  final pw.Font base;
  final pw.Font bold;
}

/// 본문은 앱 글꼴(가변 폰트), 굵은 글씨는 정적 Bold — pdf 패키지는 가변 폰트를 기본 굵기(400)로만
/// 그린다(실측 2026-10-04). Bold 파일은 PDF 전용이라 폰트 패밀리로 등록하지 않았다.
Future<GuidancePdfFonts> loadGuidancePdfFonts() async => GuidancePdfFonts(
  base: pw.Font.ttf(
    await rootBundle.load('assets/fonts/PretendardVariable.ttf'),
  ),
  bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf')),
);

/// PDF에 넣을 축소본. 원본은 손대지 않는다 — 해시는 원본 기준이다.
/// 읽을 수 없는 형식(아이폰 HEIC 등)이면 null.
Uint8List? shrinkPhotoForPdf(Uint8List bytes, {int maxSide = 2000}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final landscape = upright.width >= upright.height;
  final longest = landscape ? upright.width : upright.height;
  final resized = longest <= maxSide
      ? upright
      : img.copyResize(
          upright,
          width: landscape ? maxSide : null,
          height: landscape ? null : maxSide,
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

/// 한 위젯이 한 쪽을 넘으면 pdf가 예외를 던진다 — 줄로 나누고, 긴 줄은 다시 자른다.
List<String> _chunks(String text, {int size = 300}) => [
  for (final line in text.split('\n'))
    if (line.length <= size)
      line
    else
      for (var i = 0; i < line.length; i += size)
        line.substring(i, (i + size).clamp(0, line.length)),
];

Future<Uint8List> buildGuidancePdf({
  required GuidanceRecord record,
  required ExportPlan plan,
  required ExportKind kind,
  required Map<int, Uint8List?> photos,
  required DateTime generatedAt,
  required GuidancePdfFonts fonts,
  bool compress = true,
}) async {
  final c = record.content;
  final mono = pw.Font.courier();
  const small = pw.TextStyle(fontSize: 9, color: PdfColors.grey800);
  const label = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
  final heading = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  final stamp = formatExportStamp(generatedAt.toIso8601String());
  const cell = pw.EdgeInsets.all(4);
  final border = pw.TableBorder.all(color: PdfColors.grey600, width: 0.5);

  pw.TableRow infoRow(String k, String v) => pw.TableRow(
    children: [
      pw.Padding(
        padding: cell,
        child: pw.Text(k, style: label),
      ),
      pw.Padding(padding: cell, child: pw.Text(v)),
    ],
  );

  List<pw.Widget> section(String title, String? body) => body == null
      ? const []
      : [
          pw.SizedBox(height: 12),
          pw.Text(title, style: heading),
          pw.SizedBox(height: 4),
          for (final line in _chunks(body)) pw.Text(line),
        ];

  final edits = record.revisionCount - 1;
  // formatOccurred는 올해면 연도를 뺀다 — 제출 문서는 늘 연도를 붙이려고 기준 연도를 0으로 준다.
  final occurred = formatOccurred(c, now: DateTime(0));

  final doc = pw.Document(
    compress: compress,
    theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          GuidanceStrings.pdfFooter(stamp, ctx.pageNumber, ctx.pagesCount),
          style: small,
        ),
      ),
      build: (ctx) => [
        pw.Text(
          GuidanceStrings.pdfTitle,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('${c.kind.label} · ${c.status.label}', style: label),
        pw.SizedBox(height: 12),
        pw.Table(
          border: border,
          columnWidths: const {
            0: pw.FixedColumnWidth(80),
            1: pw.FlexColumnWidth(),
          },
          children: [
            infoRow(
              GuidanceStrings.labelTitle,
              c.title.isEmpty ? GuidanceStrings.untitled : c.title,
            ),
            infoRow(GuidanceStrings.labelOccurred, occurred),
            if (c.place case final place?)
              infoRow(GuidanceStrings.labelPlace, place),
            if (c.participants.isNotEmpty)
              infoRow(
                GuidanceStrings.labelParticipants,
                c.participants.map((p) => p.name).join(', '),
              ),
            infoRow(
              GuidanceStrings.labelCreated,
              formatExportStamp(record.createdAt),
            ),
            infoRow(
              GuidanceStrings.pdfLastEdited,
              edits == 0
                  ? GuidanceStrings.pdfEdits(0)
                  : '${formatExportStamp(record.latest.savedAt)} · ${GuidanceStrings.pdfEdits(edits)}',
            ),
          ],
        ),
        ...section(GuidanceStrings.labelFacts, c.facts),
        ...section(GuidanceStrings.labelQuotes, c.quotes),
        ...section(GuidanceStrings.labelActions, c.actions),
        if (plan.entries.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(GuidanceStrings.pdfAttachments, style: heading),
          pw.SizedBox(height: 4),
          pw.Table(
            border: border,
            columnWidths: const {
              0: pw.FixedColumnWidth(32),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final e in plan.entries)
                pw.TableRow(
                  children: [
                    pw.Padding(padding: cell, child: pw.Text(e.noLabel)),
                    pw.Padding(
                      padding: cell,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_entryLine(e)),
                          pw.Text(
                            'SHA-256 ${e.attachment.sha256}',
                            style: pw.TextStyle(font: mono, fontSize: 7.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            kind == ExportKind.bundle
                ? GuidanceStrings.pdfOriginalsInZip
                : GuidanceStrings.pdfOriginalsHint,
            style: small,
          ),
          pw.Text(GuidanceStrings.pdfCertutil, style: small),
        ],
        for (final (i, e) in plan.images.indexed) ...[
          pw.NewPage(),
          pw.Text(
            GuidanceStrings.pdfAppendixTitle(i + 1, e.noLabel),
            style: heading,
          ),
          pw.SizedBox(height: 8),
          if (photos[e.no] case final bytes?)
            pw.Container(
              height: 560,
              alignment: pw.Alignment.topCenter,
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
            )
          else
            pw.Text(GuidanceStrings.pdfPhotoUnsupported),
          pw.SizedBox(height: 8),
          pw.Text(GuidanceStrings.pdfPhotoNote, style: small),
        ],
      ],
    ),
  );
  return doc.save();
}

String _entryLine(ExportEntry e) {
  final a = e.attachment;
  final ms = a.durationMs;
  final size = ms == null
      ? GuidanceStrings.sizeLabel(a.byteSize)
      : GuidanceStrings.durationLabel(ms);
  return '${a.type.label}(${a.source.label}) · ${e.innerName} · $size · ${formatExportStamp(a.capturedAt ?? a.attachedAt)}';
}
