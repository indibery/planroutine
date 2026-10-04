import 'dart:isolate';
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
    final originals = <int, Uint8List>{
      for (final e in plan.entries)
        e.no: await (await fileStore.fileOf(
          e.attachment.fileName,
        )).readAsBytes(),
    };
    final photos = <int, Uint8List?>{};
    for (final e in plan.images) {
      final bytes = originals[e.no];
      // 축소가 가장 무겁다 — 화면이 멈추지 않게 다른 isolate에서.
      photos[e.no] = bytes == null
          ? null
          : await Isolate.run(() => shrinkPhotoForPdf(bytes));
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
