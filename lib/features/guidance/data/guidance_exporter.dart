import 'dart:typed_data';

import '../domain/guidance_export.dart';
import '../domain/guidance_models.dart';
import 'guidance_file_store.dart';
import 'guidance_pdf_builder.dart';
import 'guidance_zip_builder.dart';

class ExportOutput {
  const ExportOutput({required this.fileName, required this.bytes});
  final String fileName;
  final Uint8List bytes;
}

/// 기록 한 건을 내보낼 바이트로 만든다. 파일을 쓰거나 공유하지는 않는다 — 그건 시트의 몫이다.
class GuidanceExporter {
  GuidanceExporter({
    required this.fileStore,
    Future<GuidancePdfFonts> Function()? loadFonts,
    DateTime Function()? clock,
  }) : _loadFonts = loadFonts ?? loadGuidancePdfFonts,
       _clock = clock ?? DateTime.now;

  final GuidanceFileStore fileStore;
  final Future<GuidancePdfFonts> Function() _loadFonts;
  final DateTime Function() _clock;

  /// 안드로이드 백업 복원은 첨부 폴더를 빼고 DB만 살린다 — 파일이 없는 첨부는 고를 수 없다.
  Future<Set<int>> availableIds(List<GuidanceAttachment> attachments) async {
    final ids = <int>{};
    for (final a in attachments) {
      final id = a.id;
      if (id == null || a.isRemoved) continue;
      if (await (await fileStore.fileOf(a.fileName)).exists()) ids.add(id);
    }
    return ids;
  }

  Future<ExportOutput> build({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required ExportKind kind,
  }) async {
    final plan = buildExportPlan(
      createdAt: record.createdAt,
      attachments: attachments,
      selectedIds: selectedIds,
    );
    // PDF만이면 사진만 읽는다 — 녹음은 PDF에 쓰이지 않고, 한 시간짜리면 수십 MB다.
    // ⚠️ ZIP은 고른 원본 전부와 ZIP 사본을 메모리에 함께 든다(스트리밍은 다음 판, 원장 Ruling).
    final toRead = kind == ExportKind.pdfOnly ? plan.images : plan.entries;
    final originals = <int, Uint8List>{
      for (final e in toRead)
        e.no: await (await fileStore.fileOf(e.attachment.fileName)).readAsBytes(),
    };
    final photos = <int, Uint8List?>{};
    for (final e in plan.images) {
      final bytes = originals[e.no];
      // 디코드는 기기 코덱(네이티브), JPEG 인코드는 다른 isolate — 화면이 멈추지 않는다.
      photos[e.no] = bytes == null ? null : await shrinkPhotoForPdf(bytes);
    }
    final pdf = await buildGuidancePdf(
      record: record,
      plan: plan,
      kind: kind,
      photos: photos,
      generatedAt: _clock(),
      fonts: await _loadFonts(),
    );
    if (kind == ExportKind.pdfOnly) {
      return ExportOutput(fileName: plan.pdfName, bytes: pdf);
    }
    return ExportOutput(
      fileName: plan.zipName,
      bytes: buildGuidanceZip([
        (plan.innerPdfName, pdf),
        for (final e in plan.entries)
          (e.innerName, originals[e.no] ?? Uint8List(0)),
      ]),
    );
  }
}
