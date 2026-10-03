import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/screens/guidance_people_screen.dart';
import 'package:planroutine/features/guidance/presentation/widgets/person_edit_sheet.dart';

import '../../../helpers/test_database.dart';

/// 저장·보관이 항상 실패하는 명단 저장소.
class _FailingPeople extends GuidancePeopleRepository {
  _FailingPeople(DatabaseHelper db) : super(dbHelper: db);

  @override
  Future<GuidancePerson> add(GuidancePerson p) async => throw StateError('add 실패');

  @override
  Future<void> archive(int id) async => throw StateError('archive 실패');
}

void main() {
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
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(cond(), isTrue, reason: '조건이 상한 안에 충족되지 않음');
  }

  Future<void> waitFor(WidgetTester tester, Finder f) => waitUntil(tester, () => f.evaluate().isNotEmpty);

  Future<void> pump(WidgetTester tester, {GuidancePeopleRepository? peopleRepo, Finder? ready}) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidancePeopleRepositoryProvider.overrideWithValue(peopleRepo ?? people),
          guidanceRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: GuidancePeopleScreen()),
      ),
    );
    // 처음 읽기가 끝나기 전에 테스트가 끝나면 진행 중인 DB 호출이 남는다.
    final container = ProviderScope.containerOf(tester.element(find.byType(GuidancePeopleScreen)));
    await waitUntil(
      tester,
      () =>
          container.read(guidancePeopleProvider).hasValue &&
          container.read(guidanceArchivedPeopleProvider).hasValue &&
          container.read(guidanceRecordsProvider).hasValue,
    );
    if (ready != null) await waitFor(tester, ready);
  }

  testWidgets('여러 명 붙여넣기 — 번호를 걷어내고 학생으로 넣는다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidancePeopleScreen.pasteKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1. 김하늘\n2. 이도윤\n');
    await tester.pump();
    expect(find.text(GuidanceStrings.pastePreview(2)), findsOneWidget);
    await tester.tap(find.text(GuidanceStrings.pasteConfirm));
    await waitFor(tester, find.text(GuidanceStrings.studentsHeader(2)));
    expect(find.text('김하늘'), findsOneWidget);
    expect(find.text('이도윤'), findsOneWidget);
  });

  testWidgets('사람마다 등장한 기록 수가 보인다', (tester) async {
    await tester.runAsync(() async {
      final p = await people.add(const GuidancePerson(name: '김하늘'));
      await repo.create(GuidanceContent(title: 'a', participants: [p.toParticipant()]));
      await repo.create(
        GuidanceContent(title: 'b', participants: [p.toParticipant(), const Participant(name: '박서준')]),
      );
    });
    await pump(tester, ready: find.text(GuidanceStrings.recordCount(2)));
    expect(find.text(GuidanceStrings.recordCount(2)), findsOneWidget);
  });

  testWidgets('사람을 추가하고 고치고 보관하면 보관 묶음으로 간다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(GuidancePeopleScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(PersonEditSheet.nameKey), '이도윤 보호자');
    await tester.tap(find.byKey(PersonEditSheet.roleKey(PersonRole.guardian)));
    await tester.enterText(find.byKey(PersonEditSheet.memoKey), '어머니');
    await tester.tap(find.byKey(PersonEditSheet.saveKey));
    await waitFor(tester, find.text(GuidanceStrings.othersHeader));
    await tester.pumpAndSettle();
    expect(find.text('이도윤 보호자'), findsOneWidget);

    await tester.tap(find.text('이도윤 보호자'));
    await tester.pumpAndSettle();
    expect(find.text(GuidanceStrings.archiveNote), findsOneWidget);
    await tester.tap(find.byKey(PersonEditSheet.archiveKey));
    await waitFor(tester, find.text(GuidanceStrings.archivedHeader(1)));
    expect((await tester.runAsync(people.getArchived))?.single.name, '이도윤 보호자');
  });

  testWidgets('사람을 고치면 이름·역할·메모가 바뀐다', (tester) async {
    final p = await tester.runAsync(() => people.add(const GuidancePerson(name: '박서준')));
    await pump(tester, ready: find.text('박서준'));
    await tester.tap(find.text('박서준'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(PersonEditSheet.nameKey), '박서준 선생님');
    await tester.tap(find.byKey(PersonEditSheet.roleKey(PersonRole.staff)));
    await tester.tap(find.byKey(PersonEditSheet.saveKey));
    await waitFor(tester, find.text(GuidanceStrings.othersHeader));
    final got = (await tester.runAsync(people.getActive))?.single;
    expect(got?.id, p?.id);
    expect(got?.name, '박서준 선생님');
    expect(got?.role, PersonRole.staff);
  });

  testWidgets('보관된 사람을 되살린다', (tester) async {
    await tester.runAsync(() async {
      final p = await people.add(const GuidancePerson(name: '지난해 학생'));
      await people.archive(p.id ?? -1);
    });
    await pump(tester, ready: find.byKey(GuidancePeopleScreen.archivedKey));
    await tester.tap(find.byKey(GuidancePeopleScreen.archivedKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GuidanceStrings.unarchive));
    // 보관 묶음이 사라지는 것이 되살림이 화면에 반영됐다는 신호다.
    await waitUntil(tester, () => find.byKey(GuidancePeopleScreen.archivedKey).evaluate().isEmpty);
    expect((await tester.runAsync(people.getActive))?.single.name, '지난해 학생');
    expect(find.text('지난해 학생'), findsOneWidget);
  });

  testWidgets('저장이 실패하면 시트가 열린 채 오류 문구가 보이고 다시 누를 수 있다', (tester) async {
    await pump(tester, peopleRepo: _FailingPeople(db));
    await tester.tap(find.byKey(GuidancePeopleScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(PersonEditSheet.nameKey), '김하늘');
    await tester.tap(find.byKey(PersonEditSheet.saveKey));
    await waitFor(tester, find.text(GuidanceStrings.saveFailed));
    expect(find.byKey(PersonEditSheet.nameKey), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byKey(PersonEditSheet.saveKey));
    expect(save.onPressed, isNotNull);
  });

  testWidgets('보관이 실패하면 시트가 열린 채 오류 문구가 보이고 다시 누를 수 있다', (tester) async {
    await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘')));
    await pump(tester, peopleRepo: _FailingPeople(db), ready: find.byType(Scaffold));
    // 실패 저장소는 add만 막으므로 목록은 같은 DB에서 읽힌다.
    await waitFor(tester, find.text('김하늘'));
    await tester.tap(find.text('김하늘'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PersonEditSheet.archiveKey));
    await waitFor(tester, find.text(GuidanceStrings.actionFailed));
    final archive = tester.widget<TextButton>(find.byKey(PersonEditSheet.archiveKey));
    expect(archive.onPressed, isNotNull);
  });
}
