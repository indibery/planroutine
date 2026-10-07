import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'guidance_models.dart';
import 'guidance_types.dart';

/// 무엇을 내보내나 — PDF와 원본을 한 파일로 / 녹음 원본만 / PDF 한 장.
enum ExportKind { bundle, audioOnly, pdfOnly }

/// ZIP 안의 이름. Windows에서 한글 이름이 깨지는 일을 원천적으로 없앤다(스펙 "파일 이름").
final exportInnerNamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

final _extPattern = RegExp(r'^\.[a-z0-9]+$');

class ExportEntry {
  const ExportEntry({
    required this.no,
    required this.innerName,
    required this.attachment,
  });

  /// 1부터. PDF 첨부 표의 번호와 ZIP 안 이름의 번호가 같다.
  final int no;
  final String innerName;
  final GuidanceAttachment attachment;

  String get noLabel => no.toString().padLeft(2, '0');
}

/// PDF와 ZIP이 함께 보는 목록. 둘이 같은 목록을 봐야 번호가 어긋나지 않는다.
class ExportPlan {
  const ExportPlan({required this.baseName, required this.entries});

  final String baseName;
  final List<ExportEntry> entries;

  /// 제목은 넣지 않는다 — 메신저 목록에도 보이고, 제목에 학생 이름이 있을 수 있다.
  String get zipName => '지도기록_$baseName.zip';
  String get pdfName => '지도기록_$baseName.pdf';
  String get innerPdfName => '${baseName}_record.pdf';

  List<ExportEntry> get images => [
    for (final e in entries)
      if (e.attachment.type == AttachmentType.image) e,
  ];
}

String exportBaseName(String createdAtIso) {
  final d = DateTime.tryParse(createdAtIso);
  return d == null ? 'record' : DateFormat('yyyyMMdd-HHmm').format(d);
}

/// 제출 문서용 시각 — 앱 화면과 달리 올해여도 연도를 붙인다.
String formatExportStamp(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat('yyyy-MM-dd HH:mm').format(d);
}

ExportPlan buildExportPlan({
  required String createdAt,
  required List<GuidanceAttachment> attachments,
  required Set<int> selectedIds,
}) {
  final base = exportBaseName(createdAt);
  final picked =
      [
        for (final a in attachments)
          if (!a.isRemoved && selectedIds.contains(a.id)) a,
      ]..sort((a, b) {
        final byTime = a.attachedAt.compareTo(b.attachedAt);
        return byTime != 0 ? byTime : (a.id ?? 0).compareTo(b.id ?? 0);
      });
  return ExportPlan(
    baseName: base,
    entries: [
      for (var i = 0; i < picked.length; i++)
        ExportEntry(
          no: i + 1,
          innerName:
              '${base}_${(i + 1).toString().padLeft(2, '0')}${_safeExt(picked[i].fileName)}',
          attachment: picked[i],
        ),
    ],
  );
}

/// 녹음만 보낼 때의 파일 하나. 원본을 그대로 복사해 이 이름을 붙인다(바이트가 같아 SHA-256이 대조된다).
class AudioExportFile {
  const AudioExportFile({required this.attachment, required this.outName});
  final GuidanceAttachment attachment;
  final String outName;
}

List<AudioExportFile> buildAudioOnlyFiles({
  required String createdAt,
  required List<GuidanceAttachment> attachments,
  required Set<int> selectedIds,
}) {
  final plan = buildExportPlan(
    createdAt: createdAt,
    attachments: [
      for (final a in attachments)
        if (a.type == AttachmentType.audio) a,
    ],
    selectedIds: selectedIds,
  );
  // ZIP 안 이름과 같은 규칙에 바깥 접두만 붙인다 — 제목은 넣지 않는다.
  return [
    for (final e in plan.entries)
      AudioExportFile(attachment: e.attachment, outName: '지도기록_${e.innerName}'),
  ];
}

String _safeExt(String fileName) {
  final ext = p.extension(fileName).toLowerCase();
  return _extPattern.hasMatch(ext) ? ext : '.bin';
}
