// 명단 관리 화면은 없어졌다(실기기 피드백 2026-10-04). 이 파일은 그 자리를 대신하는 동작 —
// 저장할 때 관련인 이름을 명단에 자동으로 기억하고, 관련인 칸에서 추천으로 쓰는 것 — 을 지킨다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/core/router/app_router.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_list_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/participant_chips_field.dart';

import '../../../helpers/test_database.dart';

/// 보관(추천에서 지우기)이 항상 실패하는 명단 저장소.
class _FailingArchive extends GuidancePeopleRepository {
  _FailingArchive(DatabaseHelper db) : super(dbHelper: db);

  @override
  Future<void> archive(int id) async => throw StateError('archive 실패');
}

List<String> _paths(List<RouteBase> routes) => [
  for (final r in routes) ...[if (r is GoRoute) r.path, ..._paths(r.routes)],
];

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository people;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    people = GuidancePeopleRepository(dbHelper: db);
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  /// 고정 횟수 대신 조건이 될 때까지(상한 60회·25ms) 실제 I/O와 프레임을 번갈아 돌린다.
  Future<void> waitUntil(WidgetTester tester, bool Function() cond) async {
    for (var i = 0; i < 60 && !cond(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(cond(), isTrue, reason: '조건이 상한 안에 충족되지 않음');
  }

  Future<void> waitFor(WidgetTester tester, Finder f) =>
      waitUntil(tester, () => f.evaluate().isNotEmpty);

  final input = find.byKey(ParticipantChipsField.inputKey);
  Finder chip(String name) => find.widgetWithText(InputChip, name);
  Finder suggestion(String name) =>
      find.byKey(ParticipantChipsField.suggestionKey(name));

  /// 편집 화면을 push한 상태로 띄운다. 닫히면(`저장`) 첫 화면의 `열기`가 다시 보인다.
  Future<void> pumpEdit(
    WidgetTester tester, {
    int? recordId,
    GuidancePeopleRepository? peopleRepo,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => db.database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repo),
          guidancePeopleRepositoryProvider.overrideWithValue(
            peopleRepo ?? people,
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GuidanceEditScreen(recordId: recordId),
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
    await waitFor(tester, input);
    await tester.pumpAndSettle();
  }

  /// 저장하고 화면이 닫힐 때까지 — 닫히는 전환 애니메이션이 끝나야 하므로 시간도 흘린다.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    for (var i = 0; i < 60 && find.byType(GuidanceEditScreen).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GuidanceEditScreen), findsNothing, reason: '저장하면 화면이 닫힌다');
  }

  Future<List<Participant>> savedParticipants(
    WidgetTester tester,
    String title,
  ) async {
    final records =
        await tester.runAsync(repo.getActive) ?? const <GuidanceRecord>[];
    return records
        .firstWhere((r) => r.content.title == title)
        .content
        .participants;
  }

  testWidgets('저장하면 관련인 이름이 명단에 기억되고 personId가 채워진다', (tester) async {
    await pumpEdit(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.enterText(input, '김하늘, 박서준(5반),');
    await tester.pump();
    await save(tester);
    final saved = await savedParticipants(tester, '복도 다툼');
    expect(saved.map((p) => p.name), ['김하늘', '박서준(5반)']);
    final roster =
        await tester.runAsync(people.getActive) ?? const <GuidancePerson>[];
    expect(roster.map((p) => p.name).toSet(), {'김하늘', '박서준(5반)'});
    expect(
      saved.map((p) => p.personId).toSet(),
      roster.map((p) => p.id).toSet(),
    );
  });

  testWidgets('같은 이름으로 다른 기록을 쓰면 같은 personId가 붙는다', (tester) async {
    for (final title in ['첫 기록', '둘째 기록']) {
      await pumpEdit(tester);
      await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), title);
      await tester.enterText(input, '김하늘');
      await tester.pump();
      await save(tester);
    }
    final first = (await savedParticipants(tester, '첫 기록')).single;
    final second = (await savedParticipants(tester, '둘째 기록')).single;
    expect(first.personId, isNotNull);
    expect(second.personId, first.personId);
    expect(await tester.runAsync(people.getActive), hasLength(1));
  });

  testWidgets('이름을 치면 명단의 이름이 추천으로 뜨고, 누르면 칩이 된다', (tester) async {
    final kim = await tester.runAsync(
      () => people.add(const GuidancePerson(name: '김하늘')),
    );
    await pumpEdit(tester);
    await tester.enterText(input, '하늘');
    await waitFor(tester, suggestion('김하늘'));
    expect(find.text(GuidanceStrings.suggestionHint), findsOneWidget);
    await tester.tap(suggestion('김하늘'));
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '추천으로');
    await save(tester);
    expect((await savedParticipants(tester, '추천으로')).single.personId, kim?.id);
  });

  testWidgets('한 번에 여러 글자 늘어도 composing이 있으면 붙여넣기로 보지 않는다', (tester) async {
    await pumpEdit(tester);
    await tester.showKeyboard(input);
    // 조합 중인 `이도윤`이 쉼표 뒤에 있다 — 붙여넣기였다면 `이도윤`도 칩이 된다.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '김하늘, 이도윤',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 5, end: 8),
      ),
    );
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    expect(chip('이도윤'), findsNothing);
    expect(tester.widget<TextField>(input).controller?.text, '이도윤');
  });

  testWidgets('composing 없이 한 번에 늘면 붙여넣기라 마지막 이름도 칩이 된다', (tester) async {
    await pumpEdit(tester);
    await tester.showKeyboard(input);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '김하늘, 이도윤',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    await tester.pump();
    expect(chip('김하늘'), findsOneWidget);
    expect(chip('이도윤'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
  });

  testWidgets('이미 칩으로 넣은 이름은 추천에 없다', (tester) async {
    await tester.runAsync(() async {
      await people.add(const GuidancePerson(name: '김하늘'));
      await people.add(const GuidancePerson(name: '김하랑'));
    });
    await pumpEdit(tester);
    await tester.enterText(input, '김하늘,');
    await tester.pump();
    await tester.enterText(input, '김');
    await waitFor(tester, suggestion('김하랑'));
    expect(suggestion('김하늘'), findsNothing);
  });

  testWidgets('추천을 길게 눌러 지우면 추천에서 사라지고, 이미 쓴 기록의 이름은 그대로다', (tester) async {
    await tester.runAsync(() async {
      final kim = await people.add(const GuidancePerson(name: '김하늘'));
      await repo.create(
        GuidanceContent(title: '지난 기록', participants: [kim.toParticipant()]),
      );
    });
    await pumpEdit(tester);
    await tester.enterText(input, '김');
    await waitFor(tester, suggestion('김하늘'));
    await tester.longPress(suggestion('김하늘'));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.forgetSuggestionTitle), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.delete).last);
    await waitUntil(tester, () => suggestion('김하늘').evaluate().isEmpty);
    expect(await tester.runAsync(people.getActive), isEmpty);
    expect((await savedParticipants(tester, '지난 기록')).single.name, '김하늘');
  });

  testWidgets('추천 지우기가 실패하면 안내하고 추천이 남는다', (tester) async {
    await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘')));
    await pumpEdit(tester, peopleRepo: _FailingArchive(db));
    await tester.enterText(input, '김');
    await waitFor(tester, suggestion('김하늘'));
    await tester.longPress(suggestion('김하늘'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.delete).last);
    await waitFor(tester, find.text(GuidanceStrings.actionFailed));
    expect(suggestion('김하늘'), findsOneWidget);
  });

  testWidgets('명단 이전의 기록(personId 없음)을 그대로 저장하면 판이 생기지 않는다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(
        const GuidanceContent(
          title: '옛 기록',
          participants: [Participant(name: '김하늘')],
        ),
      ),
    );
    await pumpEdit(tester, recordId: id);
    expect(chip('김하늘'), findsOneWidget);
    await save(tester);
    expect(
      await tester.runAsync(() => repo.getRevisions(id ?? -1)),
      hasLength(1),
    );
  });

  testWidgets('목록 상단에 명단 관리 진입이 없다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [guidanceRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: GuidanceListScreen()),
      ),
    );
    await waitFor(tester, find.text(GuidanceStrings.empty));
    expect(find.byIcon(Icons.groups_outlined), findsNothing);
    expect(find.byKey(GuidanceListScreen.trashKey), findsOneWidget);
  });

  test('`/guidance/people` 라우트가 없다', () {
    final paths = _paths(
      createRouter(onboardingDone: true).configuration.routes,
    );
    expect(paths, contains(AppRoutes.guidance));
    expect(paths, isNot(contains('people')));
    expect(paths, isNot(contains('/guidance/people')));
  });
}
