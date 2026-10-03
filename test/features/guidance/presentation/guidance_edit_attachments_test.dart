import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/recording/attachment_importer.dart';
import 'package:planroutine/features/guidance/presentation/recording/guidance_recorder.dart';
import 'package:planroutine/features/guidance/presentation/recording/recording_screen.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/attachment_tile.dart';

import '../../../helpers/test_database.dart';

class FakeImporter implements AttachmentImporter {
  FakeImporter(this.file);
  final File file;
  @override
  Future<PickedFile?> pickAudio() async => PickedFile(path: file.path, name: '음성 메모 1002.m4a');
  @override
  Future<PickedFile?> pickImage() async => PickedFile(path: file.path, name: 'IMG_0001.HEIC');
}

class FakeRecorder implements GuidanceRecorder {
  String? path;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> start(String p) async {
    path = p;
    File(p).writeAsStringSync('rec');
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;
  late Directory base;
  late File source;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    base = await Directory.systemTemp.createTemp('edit_att');
    source = File('${base.path}/pick.bin')..writeAsStringSync('abc');
  });
  tearDown(() async {
    await db.close();
    await base.delete(recursive: true);
  });

  /// 고정 횟수 대신 조건이 될 때까지(상한 60회·25ms) 실제 I/O와 프레임을 번갈아 돌린다.
  Future<void> waitUntil(WidgetTester tester, bool Function() cond) async {
    for (var i = 0; i < 60 && !cond(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(cond(), isTrue, reason: '조건이 상한 안에 충족되지 않음');
  }

  Future<void> settle(WidgetTester tester) => waitUntil(
    tester,
    () =>
        find.byType(GuidanceEditScreen).evaluate().isNotEmpty &&
        find.byKey(GuidanceEditScreen.titleKey).evaluate().isNotEmpty,
  );

  Future<void> waitForTiles(WidgetTester tester, int n) =>
      waitUntil(tester, () => find.byType(AttachmentTile).evaluate().length == n);

  Future<void> pump(WidgetTester tester, {AttachmentImporter? importer}) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          attachmentImporterProvider.overrideWithValue(importer ?? FakeImporter(source)),
          guidanceRecorderFactoryProvider.overrideWithValue(FakeRecorder.new),
        ],
        child: const MaterialApp(home: GuidanceEditScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('가져오기 안내 두 줄이 보인다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.importHintSchoolPhone), findsOneWidget);
    expect(find.text(GuidanceStrings.importHintCallRecording), findsOneWidget);
  });

  testWidgets('새 기록에 사진을 붙이면 그 순간 기록이 저장되고, 쓰던 글은 남는다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '쓰던 경과');
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitForTiles(tester, 1);
    final list = await tester.runAsync(repo.getActive);
    expect(list?.single.content.title, GuidanceStrings.untitled);
    expect(list?.single.content.facts, '쓰던 경과');
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.type, AttachmentType.image);
    expect(atts?.single.originalName, 'IMG_0001.HEIC');
    expect(find.text('쓰던 경과'), findsOneWidget);
    expect(find.byType(AttachmentTile), findsOneWidget);
  });

  testWidgets('녹음을 마치면 기록이 저장되고 녹음이 붙는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    expect(find.byType(RecordingScreen), findsOneWidget);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitForTiles(tester, 1);
    final list = await tester.runAsync(repo.getActive);
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.source, AttachmentSource.recorded);
    expect(atts?.single.type, AttachmentType.audio);
  });

  testWidgets('첨부를 빼면 묻고, 빼면 목록에서 사라지되 행은 남는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.importAudioKey));
    await waitForTiles(tester, 1);
    final id = (await tester.runAsync(repo.getActive))?.single.id ?? -1;
    final att = (await tester.runAsync(() => repo.getAttachments(id)))?.single;
    await tester.tap(find.byKey(AttachmentTile.removeKey(att?.id ?? -1)));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.removeAttachmentTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.removeAttachmentConfirm));
    await waitForTiles(tester, 0);
    expect(find.byType(AttachmentTile), findsNothing);
    final after = await tester.runAsync(() => repo.getAttachments(id));
    expect(after?.single.isRemoved, isTrue);
  });

  testWidgets('붙이다 실패하면 저장 실패 안내를 띄우고 화면과 쓰던 글을 지킨다', (tester) async {
    await pump(tester, importer: FakeImporter(File('${base.path}/없는파일.bin')));
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '쓰던 경과');
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitUntil(tester, () => find.text(GuidanceStrings.saveFailed).evaluate().isNotEmpty);
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
    expect(find.text('쓰던 경과'), findsOneWidget);
    expect(find.byType(AttachmentTile), findsNothing);
  });
}
