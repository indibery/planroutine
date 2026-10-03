import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/participant_picker_sheet.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository people;

  setUp(() {
    db = freshDatabaseHelper();
    people = GuidancePeopleRepository(dbHelper: db);
  });

  /// DB를 fake-async 밖에서 미리 연다 — 시트가 처음 여는 순간 멈추지 않게.
  Future<void> openDb(WidgetTester tester) async {
    await tester.runAsync(() => db.database);
  }
  tearDown(() async => db.close());

  Future<Participant?> Function() openPicker(
    WidgetTester tester,
    void Function(Participant?) onResult, {
    List<Participant> exclude = const [],
  }) {
    return () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [guidancePeopleRepositoryProvider.overrideWithValue(people)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    onResult(await showParticipantPicker(context, exclude: exclude)),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await settle(tester);
      return null;
    };
  }

  testWidgets('명단에서 고르면 그 사람의 사본이 돌아온다', (tester) async {
    await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘', memo: '3반')));
    Participant? got;
    await openDb(tester);
    await openPicker(tester, (p) => got = p)();
    await tester.tap(find.text('김하늘'));
    await tester.pumpAndSettle();
    expect(got?.name, '김하늘');
    expect(got?.personId, isNotNull);
    expect(got?.memo, '3반');
  });

  testWidgets('이미 넣은 사람은 목록에 나오지 않는다', (tester) async {
    final p = await tester.runAsync(() => people.add(const GuidancePerson(name: '김하늘')));
    await openPicker(tester, (_) {}, exclude: [Participant(personId: p?.id, name: '김하늘')])();
    expect(find.text('김하늘'), findsNothing);
  });

  testWidgets('명단 밖 이름은 구분·소속을 붙여 넣고, 명단에도 더할 수 있다', (tester) async {
    Participant? got;
    await openDb(tester);
    await openPicker(tester, (p) => got = p)();
    await tester.enterText(find.byKey(ParticipantPickerSheet.queryKey), '박서준');
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.outsideKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ParticipantPickerSheet.memoKey), '5반');
    await tester.tap(find.byKey(ParticipantPickerSheet.addToRosterKey));
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.confirmKey));
    await settle(tester);
    expect(got?.name, '박서준');
    expect(got?.memo, '5반');
    expect(got?.role, PersonRole.student);
    expect(got?.personId, isNotNull, reason: '명단에 더했으면 id가 붙는다');
    final roster = await tester.runAsync(people.getActive);
    expect(roster?.single.name, '박서준');
  });

  testWidgets('명단에 더하지 않으면 id 없이 돌아온다', (tester) async {
    Participant? got;
    await openDb(tester);
    await openPicker(tester, (p) => got = p)();
    await tester.enterText(find.byKey(ParticipantPickerSheet.queryKey), '이도윤 보호자');
    await tester.pump();
    await tester.tap(find.byKey(ParticipantPickerSheet.outsideKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParticipantPickerSheet.roleKey(PersonRole.guardian)));
    await tester.tap(find.byKey(ParticipantPickerSheet.confirmKey));
    await settle(tester);
    expect(got?.personId, isNull);
    expect(got?.role, PersonRole.guardian);
  });
}

/// DB 왕복(runAsync) 뒤 프레임을 돌린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
