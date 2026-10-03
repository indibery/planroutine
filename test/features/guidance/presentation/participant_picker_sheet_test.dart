// 관련인을 시트에서 고르던 방식(`ParticipantPickerSheet`)은 없어졌다(실기기 피드백 2026-10-04).
// 이 파일은 그 자리를 대신하는 관련인 칸(`ParticipantChipsField`)의 칩 입력을 지킨다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/participant_chips_field.dart';

import '../../../helpers/test_database.dart';

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

  final input = find.byKey(ParticipantChipsField.inputKey);
  Finder chip(String name) => find.widgetWithText(InputChip, name);
  String typed(WidgetTester tester) =>
      tester.widget<TextField>(input).controller?.text ?? '';

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // DB를 fake-async 밖에서 미리 연다 — 화면이 처음 여는 순간 멈추지 않게.
    await tester.runAsync(() => db.database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(
            GuidancePeopleRepository(dbHelper: db),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GuidanceEditScreen(),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    for (var i = 0; i < 60 && input.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('쉼표를 치면 그 앞의 이름이 칩이 된다 — 전각 쉼표도', (tester) async {
    await pump(tester);
    await tester.enterText(input, '김하늘');
    await tester.enterText(input, '김하늘,');
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    expect(typed(tester), isEmpty);
    await tester.enterText(input, '이도윤');
    await tester.enterText(input, '이도윤，');
    await tester.enterText(input, '박서');
    await tester.pump();
    expect(chip('이도윤'), findsOneWidget);
    expect(typed(tester), '박서', reason: '아직 치는 중인 이름은 칸에 남는다');
    expect(chip('박서'), findsNothing);
  });

  testWidgets('붙여 넣은 여러 이름은 한 번에 모두 칩이 된다', (tester) async {
    await pump(tester);
    await tester.enterText(input, '김하늘, 이도윤, 박서준(5반)');
    await tester.pump();
    for (final name in ['김하늘', '이도윤', '박서준(5반)']) {
      expect(chip(name), findsOneWidget, reason: name);
    }
    expect(typed(tester), isEmpty);
  });

  testWidgets('엔터(완료)를 누르면 남은 글이 칩이 된다', (tester) async {
    await pump(tester);
    await tester.showKeyboard(input);
    await tester.enterText(input, '김하늘');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    expect(typed(tester), isEmpty);
  });

  testWidgets('빈 이름·이미 있는 이름은 무시한다', (tester) async {
    await pump(tester);
    await tester.enterText(input, '김하늘, , 김하늘,');
    await tester.pump();
    await tester.enterText(input, ' 김하늘 ');
    await tester.enterText(input, ' 김하늘 ,');
    await tester.pump();
    expect(find.byType(InputChip), findsOneWidget);
    expect(chip('김하늘'), findsOneWidget);
  });

  testWidgets('칩의 ×를 누르면 관련인에서 빠진다', (tester) async {
    await pump(tester);
    await tester.enterText(input, '김하늘, 이도윤,');
    await tester.pump();
    await tester.tap(
      find.descendant(of: chip('김하늘'), matching: find.byType(Icon)),
    );
    await tester.pump();
    expect(chip('김하늘'), findsNothing);
    expect(chip('이도윤'), findsOneWidget);
  });

  testWidgets('칩이 안 된 이름만 치고 저장해도 관련인으로 저장된다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.enterText(input, '김하늘,');
    await tester.enterText(input, '박서준');
    await tester.pump();
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    for (
      var i = 0;
      i < 60 && find.byType(GuidanceEditScreen).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GuidanceEditScreen), findsNothing);
    final c = (await tester.runAsync(repo.getActive))?.single.content;
    expect(c?.participants.map((p) => p.name), ['김하늘', '박서준']);
  });

  testWidgets('관련인 칸에만 쳐도 나가기 전에 묻는다 — 칩도, 칩이 안 된 글도', (tester) async {
    await pump(tester);
    await tester.enterText(input, '김하늘');
    await tester.pump();
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(
      find.text(GuidanceStrings.discardTitle),
      findsOneWidget,
      reason: '칩이 안 된 글',
    );
    await tester.tap(find.text(AppStrings.cancel).last);
    await tester.pumpAndSettle();

    await tester.enterText(input, '김하늘,');
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(
      find.text(GuidanceStrings.discardTitle),
      findsOneWidget,
      reason: '칩',
    );
  });

  testWidgets('학생·보호자 구분을 묻지 않는다', (tester) async {
    await pump(tester);
    // 입력칸 안내는 칩이 없을 때 보인다 — 칩이 생기면 칩과 같은 줄의 좁은 칸이 된다.
    expect(find.text(GuidanceStrings.participantsInputHint), findsOneWidget);
    await tester.enterText(input, '김하늘,');
    await tester.pump();
    for (final label in [
      GuidanceStrings.roleStudent,
      GuidanceStrings.roleGuardian,
      GuidanceStrings.roleStaff,
      GuidanceStrings.roleOther,
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text(GuidanceStrings.participantsHint), findsOneWidget);
  });
}
