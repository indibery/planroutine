import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_trash_screen.dart';

import '../../../helpers/test_database.dart';

/// 영구 삭제만 항상 실패하는 저장소.
class _FailingPurge extends GuidanceRepository {
  _FailingPurge(DatabaseHelper db) : super(dbHelper: db);

  @override
  Future<List<String>> permanentDelete(int id) async => throw StateError('purge 실패');
}

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;
  late Directory base;
  late GuidanceFileStore files;

  setUp(() async {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
    base = await Directory.systemTemp.createTemp('g_trash');
    files = GuidanceFileStore(baseDir: () async => base);
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

  Future<void> waitFor(WidgetTester tester, Finder f) => waitUntil(tester, () => f.evaluate().isNotEmpty);

  Future<void> pump(WidgetTester tester, {GuidanceRepository? repository, required Finder ready}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repository ?? repo),
          guidanceFileStoreProvider.overrideWithValue(files),
        ],
        child: const MaterialApp(home: GuidanceTrashScreen()),
      ),
    );
    await waitFor(tester, ready);
  }

  testWidgets('비어 있으면 안내 문구', (tester) async {
    await pump(tester, ready: find.text(GuidanceStrings.trashEmpty));
    expect(find.text(GuidanceStrings.trashEmpty), findsOneWidget);
    expect(find.text(GuidanceStrings.trashIntro), findsOneWidget);
  });

  testWidgets('되살리면 목록으로 돌아간다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      await repo.softDelete(id);
      return id;
    });
    await pump(tester, ready: find.text('지운 것'));
    await tester.tap(find.byKey(GuidanceTrashScreen.restoreKey(id ?? -1)));
    await waitFor(tester, find.text(GuidanceStrings.trashEmpty));
    expect((await tester.runAsync(repo.getActive))?.single.id, id);
    expect(find.text('지운 것'), findsNothing);
  });

  testWidgets('영구 삭제는 묻고, 확인하면 기록과 첨부 파일을 지운다', (tester) async {
    late GuidanceAttachment att;
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      final stored = await files.importCopy((File('${base.path}/a.jpg')..writeAsStringSync('a')).path);
      att = await repo.addAttachment(
        GuidanceAttachment(
          recordId: id,
          type: AttachmentType.image,
          source: AttachmentSource.imported,
          fileName: stored.fileName,
          sha256: stored.sha256,
          byteSize: stored.byteSize,
          attachedAt: DateTime.now().toIso8601String(),
        ),
      );
      await repo.softDelete(id);
      return id;
    });
    await pump(tester, ready: find.text('지운 것'));
    await tester.tap(find.byKey(GuidanceTrashScreen.purgeKey(id ?? -1)));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.purgeTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.purge).last);
    await waitFor(tester, find.text(GuidanceStrings.trashEmpty));
    expect(await tester.runAsync(repo.getDeleted), isEmpty);
    final file = await tester.runAsync(() => files.fileOf(att.fileName));
    expect(await tester.runAsync(() async => file?.exists()), isFalse);
  });

  testWidgets('영구 삭제를 취소하면 아무것도 지우지 않는다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      await repo.softDelete(id);
      return id;
    });
    await pump(tester, ready: find.text('지운 것'));
    await tester.tap(find.byKey(GuidanceTrashScreen.purgeKey(id ?? -1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(repo.getDeleted))?.length, 1);
    expect(find.text('지운 것'), findsOneWidget);
  });

  testWidgets('영구 삭제가 실패해도 화면은 죽지 않고 안내 문구를 보인다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: '지운 것'));
      await repo.softDelete(id);
      return id;
    });
    await pump(tester, repository: _FailingPurge(db), ready: find.text('지운 것'));
    await tester.tap(find.byKey(GuidanceTrashScreen.purgeKey(id ?? -1)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.purge).last);
    await waitFor(tester, find.text(GuidanceStrings.actionFailed));
    expect(find.text('지운 것'), findsOneWidget);
  });
}
