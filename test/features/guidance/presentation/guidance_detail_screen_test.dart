import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_detail_screen.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/text_glyph.dart';

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

  Future<void> pump(WidgetTester tester, int id) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GuidanceDetailScreen(recordId: id)),
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

  testWidgets('사건 시각과 기록 시각, 칸 셋, 관련인을 보여 준다 — 명단 밖 표시는 없다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(
        GuidanceContent(
          title: '복도 다툼',
          occurredAt: DateTime(2026, 10, 2, 15, 30),
          participants: const [Participant(personId: 1, name: '김하늘'), Participant(name: '박서준', memo: '5반')],
          facts: '밀침',
          quotes: '"먼저 걸었어요"',
          actions: '분리 지도',
        ),
      ),
    );
    await pump(tester, id ?? -1);
    expect(find.text('복도 다툼'), findsOneWidget);
    expect(find.textContaining('15:30'), findsOneWidget);
    expect(find.text(GuidanceStrings.labelCreatedShort), findsOneWidget);
    expect(find.text('밀침'), findsOneWidget);
    expect(find.text('"먼저 걸었어요"'), findsOneWidget);
    expect(find.text('분리 지도'), findsOneWidget);
    expect(find.text('김하늘'), findsOneWidget);
    expect(find.text('박서준 · 5반'), findsOneWidget);
    expect(find.textContaining('명단 밖'), findsNothing);
    // 판이 하나면 수정 링크가 없다
    expect(find.byKey(GuidanceDetailScreen.historyKey), findsNothing);
  });

  testWidgets('칸 이름은 편집 화면과 같은 14pt다', (tester) async {
    // 편집 화면 입력칸 이름을 11 → 14로 올리면서(2026-10-04 디자인 점검) 보기 화면만 11로
    // 남아 있었다(verifier가 짚었다).
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: '복도 다툼', facts: '밀침')),
    );
    await pump(tester, id ?? -1);
    final style = textStyleOf(tester, find.text(GuidanceStrings.labelFacts));
    expect(style?.fontSize, 14);
  });

  testWidgets('고친 기록에는 수정 링크가 보인다', (tester) async {
    final id = await tester.runAsync(() async {
      final id = await repo.create(const GuidanceContent(title: 't'));
      await repo.saveRevision(id, const GuidanceContent(title: 't', facts: '덧붙임'));
      return id;
    });
    await pump(tester, id ?? -1);
    expect(find.byKey(GuidanceDetailScreen.historyKey), findsOneWidget);
    expect(find.textContaining('수정 1회'), findsOneWidget);
  });

  testWidgets('삭제는 묻고, 확인하면 삭제한 기록으로 가고 화면이 닫힌다', (tester) async {
    final id = await tester.runAsync(() => repo.create(const GuidanceContent(title: '지울 것')));
    await pump(tester, id ?? -1);
    // `⋯` 메뉴 없이 앱바의 삭제 아이콘 한 번으로 확인 창이 뜬다.
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byKey(GuidanceDetailScreen.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.deleteTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.delete).last);
    await settle(tester);
    expect(await tester.runAsync(repo.getActive), isEmpty);
    expect((await tester.runAsync(repo.getDeleted))?.single.id, id);
    expect(find.byType(GuidanceDetailScreen), findsNothing);
  });

  testWidgets('이관 상태는 배지로 보인다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: 't', status: GuidanceStatus.transferred)),
    );
    await pump(tester, id ?? -1);
    expect(find.text(GuidanceStrings.statusTransferredShort), findsOneWidget);
  });
}
