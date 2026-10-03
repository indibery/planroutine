import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidancePeopleRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidancePeopleRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('여러 명을 한 번에 넣으면 학생으로 들어간다', () async {
    expect(await repo.addNames(['김하늘', '이도윤']), 2);
    final people = await repo.getActive();
    expect(people.map((p) => p.name), ['김하늘', '이도윤']);
    expect(people.every((p) => p.role == PersonRole.student), isTrue);
  });

  test('이미 있는 이름(현재 명단)은 다시 넣지 않는다', () async {
    await repo.addNames(['김하늘']);
    expect(await repo.addNames(['김하늘', '최민서']), 1);
    expect(await repo.getActive(), hasLength(2));
  });

  test('보관하면 현재 명단에서 빠지고 보관 목록에 있다', () async {
    final p = await repo.add(const GuidancePerson(name: '김하늘'));
    await repo.archive(p.id ?? -1);
    expect(await repo.getActive(), isEmpty);
    expect((await repo.getArchived()).single.name, '김하늘');
    await repo.unarchive(p.id ?? -1);
    expect((await repo.getActive()).single.name, '김하늘');
  });

  test('고친 이름·구분·메모가 저장된다', () async {
    final p = await repo.add(const GuidancePerson(name: '보호자'));
    await repo.update(p.copyWith(name: '이도윤 보호자', role: PersonRole.guardian, memo: '어머니'));
    final got = (await repo.getActive()).single;
    expect(got.name, '이도윤 보호자');
    expect(got.role, PersonRole.guardian);
    expect(got.memo, '어머니');
  });

  test('현재 명단은 구분(학생 먼저) → 이름 순이다', () async {
    await repo.add(const GuidancePerson(name: '나보호자', role: PersonRole.guardian));
    await repo.add(const GuidancePerson(name: '하학생'));
    await repo.add(const GuidancePerson(name: '가학생'));
    expect((await repo.getActive()).map((p) => p.name), ['가학생', '하학생', '나보호자']);
  });
}
