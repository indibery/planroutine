import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:planroutine/features/guidance/data/guidance_exporter.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_pdf_builder.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

pw.Font font(String path) =>
    pw.Font.ttf(File(path).readAsBytesSync().buffer.asByteData());

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late Directory base;
  late GuidanceFileStore store;
  late GuidanceExporter exporter;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('guidance_export');
    store = GuidanceFileStore(baseDir: () async => base);
    exporter = GuidanceExporter(
      fileStore: store,
      loadFonts: () async => GuidancePdfFonts(
        base: font('assets/fonts/PretendardVariable.ttf'),
        bold: font('assets/fonts/Pretendard-Bold.ttf'),
      ),
      clock: () => DateTime(2026, 10, 6, 8),
    );
  });
  tearDown(() async => base.delete(recursive: true));

  const record = GuidanceRecord(
    id: 1,
    createdAt: '2026-10-04T15:30:00',
    latest: GuidanceRevision(
      recordId: 1,
      revisionNo: 1,
      savedAt: '2026-10-04T15:30:00',
      content: GuidanceContent(title: '복도 다툼'),
    ),
  );

  Future<GuidanceAttachment> stored(int id, String content) async {
    final src = File('${base.path}/src_$id.aac')..writeAsStringSync(content);
    final s = await store.importCopy(src.path);
    return GuidanceAttachment(
      id: id,
      recordId: 1,
      type: AttachmentType.audio,
      source: AttachmentSource.recorded,
      fileName: s.fileName,
      sha256: s.sha256,
      byteSize: s.byteSize,
      attachedAt: '2026-10-04T15:3$id:00',
    );
  }

  test('묶음은 ZIP 이름이고, 풀면 PDF와 원본이 영문 이름·원래 해시로 들어 있다', () async {
    final a = await stored(1, 'abc');
    final out = await exporter.build(
      record: record,
      attachments: [a],
      selectedIds: {1},
      kind: ExportKind.bundle,
    );
    expect(out.fileName, '지도기록_20261004-1530.zip');
    final files = ZipDecoder().decodeBytes(out.bytes).files;
    expect(files.map((f) => f.name), [
      '20261004-1530_record.pdf',
      '20261004-1530_01.aac',
    ]);
    for (final f in files) {
      expect(exportInnerNamePattern.hasMatch(f.name), isTrue);
    }
    expect(
      sha256.convert(files[1].readBytes() ?? const []).toString(),
      a.sha256,
    );
    expect(
      latin1.decode((files[0].readBytes() ?? const <int>[]).take(5).toList()),
      '%PDF-',
    );
  });

  test('PDF만은 PDF 바이트 하나다', () async {
    final out = await exporter.build(
      record: record,
      attachments: const [],
      selectedIds: const {},
      kind: ExportKind.pdfOnly,
    );
    expect(out.fileName, '지도기록_20261004-1530.pdf');
    expect(latin1.decode(out.bytes.sublist(0, 5)), '%PDF-');
  });

  test('디스크에 파일이 있는 첨부만 고를 수 있다', () async {
    final a = await stored(1, 'abc');
    final missing = a.copyWith(id: 2, fileName: 'gone.aac');
    expect(await exporter.availableIds([a, missing]), {1});
  });
  test('PDF만은 녹음 원본을 읽지 않는다 — PDF에 쓰이지 않는다', () async {
    final a = await stored(1, 'abc');
    final ids = await exporter.availableIds([a]);
    // 고른 뒤 녹음 파일이 사라져도(읽으려 들면 예외) PDF만은 만들어져야 한다.
    await (await store.fileOf(a.fileName)).delete();
    final out = await exporter.build(record: record, attachments: [a], selectedIds: ids, kind: ExportKind.pdfOnly);
    expect(latin1.decode(out.bytes.sublist(0, 5)), '%PDF-');
  });
}
