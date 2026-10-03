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
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
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
  final discarded = <String>[];
  @override
  Future<PickedFile?> pickAudio() async => PickedFile(path: file.path, name: '음성 메모 1002.m4a');
  @override
  Future<PickedFile?> pickImage() async => PickedFile(path: file.path, name: 'IMG_0001.HEIC');
  @override
  Future<void> discard(PickedFile picked) async => discarded.add(picked.path);
}

/// 기록을 만들지 못하는 저장소 — 녹음 전 기록 확보가 실패하는 상황.
class FailingCreateRepository extends GuidanceRepository {
  FailingCreateRepository({super.dbHelper});
  @override
  Future<int> create(GuidanceContent content) async => throw StateError('저장 실패');
}

/// 만든 직후의 조회만 한 번 실패하는 저장소.
class FlakyGetRecordRepository extends GuidanceRepository {
  FlakyGetRecordRepository({super.dbHelper});
  var failNext = true;
  @override
  Future<GuidanceRecord?> getRecord(int id) async {
    if (failNext) {
      failNext = false;
      throw StateError('조회 실패');
    }
    return super.getRecord(id);
  }
}

/// 첫 `addAttachment`만 던지는 저장소 — 녹음 뒤 첨부가 실패하는 상황.
class FlakyRepository extends GuidanceRepository {
  FlakyRepository({super.dbHelper});
  var failNext = true;
  var failAlways = false;
  var attempts = 0;
  @override
  Future<GuidanceAttachment> addAttachment(GuidanceAttachment a) async {
    attempts++;
    if (failNext || failAlways) {
      failNext = false;
      throw StateError('저장 실패');
    }
    return super.addAttachment(a);
  }
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
      await tester.pump(const Duration(milliseconds: 50));
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

  /// [show]를 false로 바꾸면 MaterialApp 아래 트리가 통째로 사라진다 — 다른 탭으로 옮겨
  /// 셸이 dispose되는 것을 흉내 낸다(ProviderScope는 남는다, 앱의 루트처럼).
  Future<void> pump(
    WidgetTester tester, {
    AttachmentImporter? importer,
    GuidanceRepository? repository,
    ValueNotifier<bool>? show,
  }) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // DB를 fake-async 밖에서 미리 연다.
    await tester.runAsync(() => db.database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repository ?? repo),
          guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
          guidanceFileStoreProvider.overrideWithValue(GuidanceFileStore(baseDir: () async => base)),
          attachmentImporterProvider.overrideWithValue(importer ?? FakeImporter(source)),
          guidanceRecorderFactoryProvider.overrideWithValue(FakeRecorder.new),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: show ?? ValueNotifier(true),
          builder: (_, on, _) => !on
              ? const SizedBox.shrink()
              : MaterialApp(
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => const GuidanceEditScreen())),
                        child: const Text('열기'),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
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

  testWidgets('녹음 뒤 첨부가 실패하면 보관 줄이 보이고, 다시 붙이면 첨부가 생기고 줄이 사라진다', (tester) async {
    await pump(tester, repository: FlakyRepository(dbHelper: db));
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => find.text(GuidanceStrings.unattachedRecording(1)).evaluate().isNotEmpty);
    // 홈 화면의 Scaffold도 같은 메신저의 스낵바를 그려 한 개 이상으로 잡힌다.
    expect(find.text(GuidanceStrings.attachFailedKept), findsWidgets);
    expect(find.byType(AttachmentTile), findsNothing);

    await tester.tap(find.byKey(GuidanceEditScreen.retryAttachKey));
    await waitForTiles(tester, 1);
    await waitUntil(tester, () => find.text(GuidanceStrings.unattachedRecording(1)).evaluate().isEmpty);
    final list = await tester.runAsync(repo.getActive);
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.source, AttachmentSource.recorded);
    expect(find.byKey(GuidanceEditScreen.retryAttachKey), findsNothing);
  });

  testWidgets('붙이지 못한 녹음이 있으면 저장 없이 나갈 때 묻는다', (tester) async {
    await pump(tester, repository: FlakyRepository(dbHelper: db));
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => find.byKey(GuidanceEditScreen.retryAttachKey).evaluate().isNotEmpty);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardTitle), findsOneWidget);
  });

  testWidgets('녹음 버튼을 빠르게 두 번 눌러도 녹음 화면은 하나만 열린다', (tester) async {
    await pump(tester);
    final button = find.byKey(GuidanceEditScreen.recordKey);
    // 탭은 첫 번째가 화면을 덮은 뒤라 두 번째가 닿지 않는다 — 콜백을 같은 프레임에 두 번 부른다.
    final onPressed = tester.widget<OutlinedButton>(button).onPressed!;
    onPressed();
    onPressed();
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    expect(find.byType(RecordingScreen), findsOneWidget);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitForTiles(tester, 1);
    expect(find.byType(RecordingScreen), findsNothing);
  });

  Future<void> recordAndFail(WidgetTester tester) async {
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitUntil(tester, () => find.byKey(GuidanceEditScreen.retryAttachKey).evaluate().isNotEmpty);
  }

  testWidgets('붙이지 못한 녹음이 있을 때 저장하면 먼저 붙이고, 붙으면 저장하고 닫는다', (tester) async {
    await pump(tester, repository: FlakyRepository(dbHelper: db));
    await recordAndFail(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await waitUntil(tester, () => find.byType(GuidanceEditScreen).evaluate().isEmpty);
    final list = await tester.runAsync(repo.getActive);
    final atts = await tester.runAsync(() => repo.getAttachments(list?.single.id ?? -1));
    expect(atts?.single.source, AttachmentSource.recorded);
  });

  testWidgets('계속 붙지 않으면 저장해도 화면과 보관 줄이 남는다', (tester) async {
    final flaky = FlakyRepository(dbHelper: db);
    await pump(tester, repository: flaky);
    await recordAndFail(tester);
    flaky.failAlways = true;
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    // 기록 때의 스낵바가 이미 떠 있어 문구로는 기다릴 수 없다 — 저장이 다시 붙여 본 횟수로 기다린다.
    await waitUntil(tester, () => flaky.attempts >= 2);
    await waitUntil(
      tester,
      () => tester.widget<FilledButton>(find.byKey(GuidanceEditScreen.saveKey)).onPressed != null,
    );
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
    expect(find.text(GuidanceStrings.unattachedRecording(1)), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(find.byKey(GuidanceEditScreen.saveKey));
    expect(saveButton.onPressed, isNotNull, reason: '다시 누를 수 있게 풀려야 한다');
  });

  /// DB에서 조건이 될 때까지 기다린다(조건 자체가 비동기 조회라 [waitUntil]을 못 쓴다).
  Future<T?> pollDb<T>(WidgetTester tester, Future<T> Function() read, bool Function(T) done) async {
    T? last;
    for (var i = 0; i < 60; i++) {
      last = await tester.runAsync(read);
      final v = last;
      if (v != null && done(v)) return v;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    return last;
  }

  Future<List<GuidanceAttachment>> attachmentsOfOnlyRecord() async {
    final list = await repo.getActive();
    return list.length == 1 ? repo.getAttachments(list.single.id) : const <GuidanceAttachment>[];
  }

  testWidgets('녹음은 기록을 먼저 만든 뒤 시작한다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    final list = await tester.runAsync(repo.getActive);
    expect(list, hasLength(1), reason: '녹음 화면이 뜬 시점에 이미 기록이 있다');
    expect(tester.widget<RecordingScreen>(find.byType(RecordingScreen)).recordId, list?.single.id);
  });

  testWidgets('녹음 중 화면 트리가 통째로 사라져도(탭 이동) 녹음이 그 기록에 붙는다', (tester) async {
    final show = ValueNotifier(true);
    await pump(tester, show: show);
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    show.value = false;
    await tester.pump();
    expect(find.byType(RecordingScreen), findsNothing);
    final atts = await pollDb(tester, attachmentsOfOnlyRecord, (a) => a.isNotEmpty);
    expect(atts, hasLength(1));
    expect(atts?.single.source, AttachmentSource.recorded);
    expect((await tester.runAsync(repo.getActive))?.length, 1, reason: '기록이 둘 생기지 않는다');
  });

  testWidgets('녹음을 정상으로 마친 뒤 화면이 사라져도 녹음은 한 번만 붙는다', (tester) async {
    final show = ValueNotifier(true);
    await pump(tester, show: show);
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.byKey(RecordingScreen.stopKey).evaluate().isNotEmpty);
    await tester.tap(find.byKey(RecordingScreen.stopKey));
    await waitForTiles(tester, 1);
    show.value = false;
    await tester.pump();
    // 혹시 두 번째 첨부가 들어온다면 이 사이에 들어온다.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(await tester.runAsync(attachmentsOfOnlyRecord), hasLength(1));
  });

  testWidgets('녹음 전에 기록을 만들지 못하면 녹음 화면을 열지 않고 저장 실패를 알린다', (tester) async {
    await pump(tester, repository: FailingCreateRepository(dbHelper: db));
    await tester.tap(find.byKey(GuidanceEditScreen.recordKey));
    await waitUntil(tester, () => find.text(GuidanceStrings.saveFailed).evaluate().isNotEmpty);
    expect(find.byType(RecordingScreen), findsNothing);
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
  });

  testWidgets('붙이지 못한 녹음이 있으면 나가기 확인 창이 그 녹음을 말한다', (tester) async {
    await pump(tester, repository: FlakyRepository(dbHelper: db));
    await recordAndFail(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardUnattachedMessage(1)), findsOneWidget);
    expect(find.text(GuidanceStrings.discardMessage), findsNothing);
  });

  testWidgets('붙이지 못한 녹음이 없으면 나가기 확인 창은 원래 문구다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '쓰던 경과');
    await tester.pump();
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardMessage), findsOneWidget);
  });

  testWidgets('가져오기가 끝나면 고르기 창의 사본을 지운다', (tester) async {
    final importer = FakeImporter(source);
    await pump(tester, importer: importer);
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitForTiles(tester, 1);
    expect(importer.discarded, [source.path]);
  });

  testWidgets('가져오기가 실패해도 고르기 창의 사본을 지운다', (tester) async {
    final importer = FakeImporter(File('${base.path}/없는파일.bin'));
    await pump(tester, importer: importer);
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitUntil(tester, () => find.text(GuidanceStrings.saveFailed).evaluate().isNotEmpty);
    expect(importer.discarded, ['${base.path}/없는파일.bin']);
  });

  testWidgets('기록을 만든 직후 조회가 실패해도 다시 붙일 때 기록이 둘 생기지 않는다', (tester) async {
    await pump(tester, repository: FlakyGetRecordRepository(dbHelper: db));
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitUntil(tester, () => find.text(GuidanceStrings.saveFailed).evaluate().isNotEmpty);
    await tester.tap(find.byKey(GuidanceEditScreen.importImageKey));
    await waitForTiles(tester, 1);
    final list = await tester.runAsync(repo.getActive);
    expect(list, hasLength(1));
  });
}
