import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/data/guidance_file_store.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/settings/data/app_reset_repository.dart';
import 'package:planroutine/features/settings/presentation/widgets/reset_list_tile.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);

  test('전체 초기화는 지도 기록 테이블과 첨부 폴더를 비운다', () async {
    final db = freshDatabaseHelper();
    final base = await Directory.systemTemp.createTemp('reset_guidance');
    final files = GuidanceFileStore(baseDir: () async => base);
    final repo = GuidanceRepository(dbHelper: db);
    await repo.create(const GuidanceContent(title: 't'));
    await files.importCopy((File('${base.path}/a.jpg')..writeAsStringSync('a')).path);

    await AppResetRepository(dbHelper: db, guidanceFiles: files).resetAll();

    expect(await repo.getActive(), isEmpty);
    expect(await Directory('${base.path}/${GuidanceFileStore.folder}').exists(), isFalse);
    await db.close();
    await base.delete(recursive: true);
  });

  test('경고 문구는 건수를 말한다', () {
    expect(GuidanceStrings.resetWarning(3, 2), '지도 기록 3건과 첨부 2개도 지워집니다.');
  });

  testWidgets('지도 기록이 있으면 초기화 확인 창에 건수가 나온다', (tester) async {
    final db = freshDatabaseHelper();
    final repo = GuidanceRepository(dbHelper: db);
    await tester.runAsync(() => repo.create(const GuidanceContent(title: 't')));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: ResetListTile())),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('지도 기록 1건과 첨부 0개'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('지도 기록이 없으면 경고 줄이 없다', (tester) async {
    final db = freshDatabaseHelper();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(GuidanceRepository(dbHelper: db))],
        child: const MaterialApp(home: Scaffold(body: ResetListTile())),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    // 기본 문구에도 `지도 기록`이 들어 있으므로 경고 줄만의 낱말로 찾는다
    expect(find.textContaining('건과 첨부'), findsNothing);
    await tester.runAsync(db.close);
  });
}
