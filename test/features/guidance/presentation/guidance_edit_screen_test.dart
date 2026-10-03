import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_edit_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/occurred_input.dart';

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// 편집 화면을 한 번 push한 상태로 띄운다 — 저장·취소가 pop하는지 보려고.
  Future<void> pump(
    WidgetTester tester, {
    int? recordId,
    double width = 390,
    GuidanceRepository? repository,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // DB를 fake-async 밖에서 미리 연다 — 화면이 처음 여는 순간 멈추지 않게.
    await tester.runAsync(() => db.database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidanceRepositoryProvider.overrideWithValue(repository ?? repo),
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

  testWidgets('관련인·들은 말·판단·조치 안내 문구가 보인다', (tester) async {
    await pump(tester);
    expect(find.text(GuidanceStrings.participantsHint), findsOneWidget);
    expect(find.text(GuidanceStrings.quotesHint), findsOneWidget);
    expect(find.text(GuidanceStrings.actionsHint), findsOneWidget);
    expect(find.text(GuidanceStrings.createdOnSave), findsOneWidget);
  });

  testWidgets('제목 없이 저장하면 막고 안내한다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(find.text(GuidanceStrings.titleRequired), findsOneWidget);
    expect(await tester.runAsync(repo.getActive), isEmpty);
  });

  testWidgets('새 기록을 저장하면 판 1이 생기고 화면이 닫힌다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.tap(find.byKey(GuidanceEditScreen.kindKey(GuidanceKind.infringement)));
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '밀침');
    await tester.enterText(find.byKey(GuidanceEditScreen.quotesKey), '"먼저 걸었어요"');
    await tester.enterText(find.byKey(GuidanceEditScreen.actionsKey), '분리 지도');
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final list = await tester.runAsync(repo.getActive);
    final c = list?.single.content;
    expect(c?.title, '복도 다툼');
    expect(c?.kind, GuidanceKind.infringement);
    expect(c?.quotes, '"먼저 걸었어요"');
    expect(c?.actions, '분리 지도');
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  testWidgets('고치기는 최신 판을 채워 열고, 저장하면 판 2가 된다', (tester) async {
    final id = await tester.runAsync(
      () => repo.create(const GuidanceContent(title: '처음', facts: '가')),
    );
    await pump(tester, recordId: id);
    expect(find.text('처음'), findsOneWidget);
    await tester.enterText(find.byKey(GuidanceEditScreen.factsKey), '가. 보건실 확인');
    await tester.tap(find.byKey(GuidanceEditScreen.statusKey(GuidanceStatus.closedAtSchool)));
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final revs = await tester.runAsync(() => repo.getRevisions(id ?? -1));
    expect(revs?.map((r) => r.revisionNo), [2, 1]);
    expect(revs?.first.content.status, GuidanceStatus.closedAtSchool);
  });

  testWidgets('아무것도 안 고치고 저장하면 판을 만들지 않는다', (tester) async {
    final id = await tester.runAsync(() => repo.create(const GuidanceContent(title: '처음')));
    await pump(tester, recordId: id);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(await tester.runAsync(() => repo.getRevisions(id ?? -1)), hasLength(1));
  });

  testWidgets('대략을 고르면 글로 적고, 그대로 저장된다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '반복된 놀림');
    await tester.tap(find.byKey(OccurredInput.precisionKey(OccurredPrecision.approx)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(OccurredInput.approxKey), '3월 초~여름방학 전');
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final c = (await tester.runAsync(repo.getActive))?.single.content;
    expect(c?.precision, OccurredPrecision.approx);
    expect(c?.occurredText, '3월 초~여름방학 전');
    expect(c?.occurredAt, isNull);
  });

  testWidgets('고친 내용이 있으면 취소할 때 묻고, 그대로 두기를 고르면 남는다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '쓰던 것');
    await tester.pump(); // 고침을 반영한 프레임 — 실제 화면에서는 탭 전에 늘 그려진다
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.discardTitle), findsOneWidget);
    // 앱바의 `취소`와 대화상자의 `취소`가 같은 글이라 마지막(대화상자) 것을 누른다
    await tester.tap(find.text(AppStrings.cancel).last);
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
    await tester.tap(find.byKey(GuidanceEditScreen.cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.discardConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(GuidanceEditScreen), findsNothing);
  });

  testWidgets('저장이 실패하면 안내하고 글을 남기며, 다시 누르면 저장된다', (tester) async {
    final flaky = _FailOnceRepository(db);
    await pump(tester, repository: flaky);
    await tester.enterText(find.byKey(GuidanceEditScreen.titleKey), '복도 다툼');
    await tester.pump();
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(find.text(GuidanceStrings.saveFailed), findsOneWidget);
    expect(find.byType(GuidanceEditScreen), findsOneWidget);
    expect(find.text('복도 다툼'), findsOneWidget);
    expect(await tester.runAsync(repo.getActive), isEmpty);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    expect(find.byType(GuidanceEditScreen), findsNothing);
    expect((await tester.runAsync(repo.getActive))?.single.content.title, '복도 다툼');
  });

  testWidgets('대략으로 바꿨다가 정확히로 되돌려도 사건 시각이 그대로다', (tester) async {
    final at = DateTime(2026, 9, 25, 12, 40);
    final id = await tester.runAsync(
      () => repo.create(GuidanceContent(title: '처음', occurredAt: at)),
    );
    await pump(tester, recordId: id);
    await tester.tap(find.byKey(OccurredInput.precisionKey(OccurredPrecision.approx)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OccurredInput.precisionKey(OccurredPrecision.exact)));
    await tester.pumpAndSettle();
    expect(find.text('12:40'), findsOneWidget);
    await tester.tap(find.byKey(GuidanceEditScreen.saveKey));
    await settle(tester);
    final revs = await tester.runAsync(() => repo.getRevisions(id ?? -1));
    expect(revs, hasLength(1), reason: '되돌렸으면 고친 것이 없다');
    expect(revs?.single.content.occurredAt, at);
  });

  testWidgets('320pt에서 넘치지 않는다', (tester) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}

/// 첫 `create`만 예외를 던지는 저장소 — 저장 실패 경로 확인용.
class _FailOnceRepository extends GuidanceRepository {
  _FailOnceRepository(DatabaseHelper db) : super(dbHelper: db);

  var _failed = false;

  @override
  Future<int> create(GuidanceContent content) {
    if (!_failed) {
      _failed = true;
      throw StateError('저장 실패');
    }
    return super.create(content);
  }
}
