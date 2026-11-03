import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/widgets/occurred_row.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';

import '../../../helpers/contrast.dart';
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

  Future<void> pump(WidgetTester tester, {double width = 390, int? recordId}) async {
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
                  MaterialPageRoute<void>(builder: (_) => GuidanceEditScreen(recordId: recordId)),
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

  double dy(WidgetTester t, Key k) => t.getTopLeft(find.byKey(k)).dy;

  testWidgets('정리표 → 첨부 버튼 → 경과 순서로 쌓인다', (tester) async {
    await pump(tester);
    final table = dy(tester, GuidanceEditScreen.placeKey);
    final attach = dy(tester, GuidanceEditScreen.recordKey);
    final facts = dy(tester, GuidanceEditScreen.factsKey);
    expect(table < attach, isTrue);
    expect(attach < facts, isTrue);
  });

  testWidgets('첨부 버튼 글자는 녹음 · 사진 · 녹음 파일이고 폭이 같다', (tester) async {
    await pump(tester);
    for (final t in ['녹음', '사진', '녹음 파일']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    final w = [
      for (final k in [GuidanceEditScreen.recordKey, GuidanceEditScreen.importImageKey, GuidanceEditScreen.importAudioKey])
        tester.getSize(find.byKey(k)).width,
    ];
    expect((w[0] - w[1]).abs() < 1 && (w[1] - w[2]).abs() < 1, isTrue, reason: '$w');
  });

  testWidgets('새 기록은 들은 말·판단·조치 칸이 없고 버튼을 누르면 칸이 열리며 포커스가 간다', (tester) async {
    await pump(tester);
    expect(find.byKey(GuidanceEditScreen.quotesKey), findsNothing);
    expect(find.byKey(GuidanceEditScreen.actionsKey), findsNothing);
    await tester.tap(find.byKey(GuidanceEditScreen.addQuotesKey));
    await settle(tester);
    expect(find.byKey(GuidanceEditScreen.quotesKey), findsOneWidget);
    expect(find.byKey(GuidanceEditScreen.addQuotesKey), findsNothing);
    expect(find.text(GuidanceStrings.quotesHint), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(GuidanceEditScreen.quotesKey));
    expect(field.focusNode?.hasFocus ?? false, isTrue);
    expect(find.byKey(GuidanceEditScreen.actionsKey), findsNothing);
    await tester.tap(find.byKey(GuidanceEditScreen.addActionsKey));
    await settle(tester);
    expect(find.byKey(GuidanceEditScreen.actionsKey), findsOneWidget);
    expect(find.text(GuidanceStrings.actionsHint), findsOneWidget);
  });

  testWidgets('펼친 칸은 비워도 접히지 않는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.addQuotesKey));
    await settle(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.quotesKey), '가');
    await tester.enterText(find.byKey(GuidanceEditScreen.quotesKey), '');
    await tester.pump();
    expect(find.byKey(GuidanceEditScreen.quotesKey), findsOneWidget);
    expect(find.byKey(GuidanceEditScreen.addQuotesKey), findsNothing);
  });

  testWidgets('들은 말이 있는 기록은 처음부터 펼쳐 열린다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: '복도', quotes: '"그만해"')),
    );
    await pump(tester, recordId: id);
    expect(find.byKey(GuidanceEditScreen.quotesKey), findsOneWidget);
    expect(find.byKey(GuidanceEditScreen.addQuotesKey), findsNothing);
    expect(find.byKey(GuidanceEditScreen.actionsKey), findsNothing);
    expect(find.byKey(GuidanceEditScreen.addActionsKey), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('${width.toInt()}pt에서 첨부 줄과 펼친 칸이 넘치지 않는다', (tester) async {
      await pump(tester, width: width);
      await tester.tap(find.byKey(GuidanceEditScreen.addQuotesKey));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320pt에서 관련인 칩 셋이 있어도 넘치지 않는다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(
        const GuidanceContent(
          title: '복도',
          participants: [Participant(name: '김하늘'), Participant(name: '박서준(5반)'), Participant(name: '이도윤')],
        ),
      ),
    );
    await pump(tester, width: 320, recordId: id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('언제 시트를 열었다 아무것도 안 바꾸고 닫아도 취소는 확인 창 없이 닫힌다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(OccurredRow.rowKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // 시트 바깥을 눌러 닫는다
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardTitle), findsNothing);
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('${b.name} 테마에서 녹음 버튼은 배경과 구별되는 채움이고 글자 대비 4.5 이상이다', (tester) async {
      AppColors.applyBrightness(b);
      addTearDown(() => AppColors.applyBrightness(Brightness.light));
      await pump(tester);
      final button = tester.widget<FilledButton>(find.byKey(GuidanceEditScreen.recordKey));
      final fill = button.style?.backgroundColor?.resolve({});
      final fg = button.style?.foregroundColor?.resolve({});
      expect(fill, isNotNull);
      expect(fg, isNotNull);
      expect(fill, isNot(AppColors.background));
      expect(contrastRatio(fg!, fill!), greaterThanOrEqualTo(4.5));
    });
  }
}
