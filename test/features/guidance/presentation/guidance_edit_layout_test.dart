import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/text_glyph.dart';

/// 편집 화면 B안 — 위쪽은 제목 + 정리표 카드. 설명 문장은 ⓘ 뒤로 갔다.
void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => db.database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(GuidancePeopleRepository(dbHelper: db)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GuidanceEditScreen()),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
  }

  testWidgets('제목이 정리표(구분 행)보다 위에 있다', (tester) async {
    await pump(tester);
    final title = tester.getTopLeft(find.byKey(GuidanceEditScreen.titleKey)).dy;
    final kind = tester.getTopLeft(find.byKey(GuidanceEditScreen.kindKey(GuidanceKind.guidance))).dy;
    expect(title < kind, isTrue);
  });

  testWidgets('범위 안내·관련인 안내는 화면에 없고 ⓘ를 누르면 뜬다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.scopeNote), findsNothing);
    expect(find.text(GuidanceStrings.participantsHint), findsNothing);
    await tester.tap(find.byKey(GuidanceEditScreen.kindInfoKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.scopeNote), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // 배경을 눌러 닫는다
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.scopeNote), findsNothing);
    await tester.tap(find.byKey(GuidanceEditScreen.participantsInfoKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.participantsHint), findsOneWidget);
  });

  testWidgets('구분·상태 칩을 누르면 저장값에 반영된다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.tap(find.byKey(GuidanceEditScreen.kindKey(GuidanceKind.infringement)));
    await tester.tap(find.byKey(GuidanceEditScreen.statusKey(GuidanceStatus.closedAtSchool)));
    await tester.pump();
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final c = (await tester.runAsync(repo.getActive))?.single.content;
    expect(c?.kind, GuidanceKind.infringement);
    expect(c?.status, GuidanceStatus.closedAtSchool);
  });

  testWidgets('새 기록을 열고 바로 취소하면 확인 창 없이 닫힌다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardTitle), findsNothing);
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('${width.toInt()}pt에서 정리표가 넘치지 않는다', (tester) async {
      await pump(tester, width: width);
      expect(tester.takeException(), isNull);
      expect(find.byKey(GuidanceEditScreen.kindInfoKey), findsOneWidget);
    });
  }

  testWidgets('정리표 행 이름은 14pt다', (tester) async {
    await pump(tester);
    for (final label in [
      GuidanceStrings.labelKind,
      GuidanceStrings.labelStatusShort,
      GuidanceStrings.labelWhen,
      GuidanceStrings.labelWhere,
      GuidanceStrings.labelWho,
    ]) {
      expect(textStyleOf(tester, find.text(label))?.fontSize, 14, reason: label);
    }
  });
}
