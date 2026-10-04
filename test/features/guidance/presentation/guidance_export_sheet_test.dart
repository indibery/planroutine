import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_exporter.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_export.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/guidance_export_sheet.dart';

class FakeExporter extends GuidanceExporter {
  FakeExporter() : super(fileStore: GuidanceFileStore());
  final calls = <(Set<int>, ExportKind)>[];
  var fail = false;

  @override
  Future<ExportOutput> build({
    required GuidanceRecord record,
    required List<GuidanceAttachment> attachments,
    required Set<int> selectedIds,
    required ExportKind kind,
  }) async {
    calls.add(({...selectedIds}, kind));
    if (fail) throw StateError('실패');
    return ExportOutput(
      fileName: kind == ExportKind.bundle ? 'a.zip' : 'a.pdf',
      bytes: Uint8List(1),
    );
  }
}

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

GuidanceAttachment att(int id, AttachmentType type) => GuidanceAttachment(
  id: id,
  recordId: 1,
  type: type,
  source: AttachmentSource.recorded,
  fileName: '$id',
  sha256: 'a' * 64,
  byteSize: 10,
  durationMs: 1000,
  attachedAt: '2026-10-04T15:3$id:00',
);

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  late FakeExporter exporter;
  late List<String> shared;
  late List<String> saved;

  setUp(() {
    exporter = FakeExporter();
    shared = [];
    saved = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    List<GuidanceAttachment> attachments = const [],
    Set<int>? available,
    bool isAndroid = false,
    Duration shareDelay = Duration.zero,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceExporterProvider.overrideWithValue(exporter)],
        child: MaterialApp(
          home: Scaffold(
            body: GuidanceExportSheet(
              key: ValueKey(isAndroid),
              record: record,
              attachments: attachments,
              availableIds:
                  available ?? {for (final a in attachments) a.id ?? -1},
              isAndroid: isAndroid,
              share: (out, _) async {
                shared.add(out.fileName);
                await Future<void>.delayed(shareDelay);
                return true;
              },
              save: (out) async {
                saved.add(out.fileName);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton shareButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(GuidanceExportSheet.shareKey));

  testWidgets('첨부가 있으면 ZIP이 기본이고 첨부가 전부 골라져 있다', (tester) async {
    await pump(
      tester,
      attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.image)],
    );
    expect(
      find.text(GuidanceStrings.exportBundleSubtitle(1, 1)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$1, {1, 2});
    expect(exporter.calls.single.$2, ExportKind.bundle);
    expect(shared, ['a.zip']);
  });

  testWidgets('첨부가 없으면 ZIP 줄이 없고 PDF만이 기본이다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceExportSheet.bundleKey), findsNothing);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$2, ExportKind.pdfOnly);
  });

  testWidgets('ZIP에서 첨부를 다 빼면 보내기가 꺼지고, PDF만으로 바꾸면 다시 켜진다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio)]);
    await tester.tap(find.byKey(GuidanceExportSheet.attachmentKey(1)));
    await tester.pumpAndSettle();
    expect(shareButton(tester).onPressed, isNull);
    await tester.tap(find.byKey(GuidanceExportSheet.pdfOnlyKey));
    await tester.pumpAndSettle();
    expect(shareButton(tester).onPressed, isNotNull);
  });

  testWidgets('파일이 없는 첨부는 꺼져 있고 고를 수 없다', (tester) async {
    await pump(
      tester,
      attachments: [att(1, AttachmentType.audio), att(2, AttachmentType.audio)],
      available: {1},
    );
    expect(find.text(GuidanceStrings.attachmentMissing), findsOneWidget);
    await tester.tap(find.byKey(GuidanceExportSheet.attachmentKey(2)));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$1, {1});
  });

  testWidgets('만드는 동안 다시 누를 수 없다', (tester) async {
    await pump(tester, shareDelay: const Duration(seconds: 1));
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pump();
    expect(shareButton(tester).onPressed, isNull);
    await tester.tap(
      find.byKey(GuidanceExportSheet.shareKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(shared, hasLength(1));
  });

  testWidgets('아이폰은 공유 하나와 아이폰 안내 — 케이블 없음', (tester) async {
    await pump(tester, isAndroid: false);
    expect(find.byKey(GuidanceExportSheet.saveKey), findsNothing);
    await tester.tap(find.byKey(GuidanceExportSheet.guideKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(GuidanceStrings.exportPcGuideIos.first),
      findsOneWidget,
    );
    expect(find.textContaining('USB 케이블'), findsNothing);
  });

  testWidgets('안드로이드는 기기에 저장과 안드로이드 안내 — 케이블이 마지막', (tester) async {
    await pump(tester, isAndroid: true);
    await tester.tap(find.byKey(GuidanceExportSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved, ['a.pdf']);
    await tester.tap(find.byKey(GuidanceExportSheet.guideKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(GuidanceStrings.exportPcGuideAndroid.first),
      findsOneWidget,
    );
    expect(find.textContaining('USB 케이블'), findsOneWidget);
  });

  testWidgets('안내 한 줄이 있다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.exportNotice), findsOneWidget);
  });
  testWidgets('실패하면 시트 안에 실패 안내가 남고 버튼이 다시 켜진다', (tester) async {
    exporter.fail = true;
    await pump(tester);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(GuidanceExportSheet), matching: find.text(GuidanceStrings.exportFailed)),
      findsOneWidget,
    );
    expect(shareButton(tester).onPressed, isNotNull);
    expect(shared, isEmpty);
  });
  testWidgets('첨부 파일이 모두 없으면 ZIP 줄이 꺼지고 PDF만이 기본이다', (tester) async {
    await pump(tester, attachments: [att(1, AttachmentType.audio)], available: {});
    final bundle = tester.widget<RadioListTile<ExportKind>>(find.byKey(GuidanceExportSheet.bundleKey));
    expect(bundle.enabled, isFalse);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(exporter.calls.single.$2, ExportKind.pdfOnly);
  });

  test('공유가 끝나면(실패해도) 임시 파일을 지운다 — 기록 내용이 담긴 파일이다', () async {
    final tmp = await Directory.systemTemp.createTemp('export_share');
    addTearDown(() => tmp.delete(recursive: true));
    final out = ExportOutput(fileName: '지도기록_x.zip', bytes: Uint8List.fromList([1, 2, 3]));
    String? seen;
    await shareViaSheet(out, null, tempDir: () async => tmp, share: (path, _) async {
      seen = path;
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
      return true;
    });
    expect(seen, isNotNull);
    expect(File(seen ?? '').existsSync(), isFalse);

    await expectLater(
      shareViaSheet(out, null, tempDir: () async => tmp, share: (path, _) async => throw StateError('취소')),
      throwsStateError,
    );
    expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
  });
  Future<void> openFromScreen(WidgetTester tester, {required Future<bool> Function() share, bool isAndroid = false}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceExporterProvider.overrideWithValue(exporter)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showGuidanceExportSheet(
                  context,
                  ref,
                  record: record,
                  attachments: const [],
                  isAndroid: isAndroid,
                  share: (out, _) => share(),
                  save: (out) async {
                    saved.add(out.fileName);
                    return true;
                  },
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('공유를 마치면 시트가 닫히고 화면에 공유했다고 알린다', (tester) async {
    await openFromScreen(tester, share: () async => true);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceExportSheet), findsNothing);
    expect(find.text(GuidanceStrings.exportShared), findsOneWidget);
  });

  testWidgets('공유 창에서 취소하면 시트가 그대로 남는다 — 다른 방법으로 다시 보낼 수 있다', (tester) async {
    await openFromScreen(tester, share: () async => false);
    await tester.tap(find.byKey(GuidanceExportSheet.shareKey));
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceExportSheet), findsOneWidget);
    expect(find.text(GuidanceStrings.exportShared), findsNothing);
  });

  testWidgets('기기에 저장하면 시트가 닫히고 화면에 저장했다고 알린다', (tester) async {
    await openFromScreen(tester, share: () async => true, isAndroid: true);
    await tester.tap(find.byKey(GuidanceExportSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved, ['a.pdf']);
    expect(find.byType(GuidanceExportSheet), findsNothing);
    expect(find.text(GuidanceStrings.exportSaved), findsOneWidget);
  });

  testWidgets('시트 맨 위에 끌어 내리는 손잡이가 있다 — 닫는 방법이 보인다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceExportSheet.handleKey), findsOneWidget);
  });
}
