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

  test('기억한 이름은 구분을 묻지 않아 학생 기본값으로 들어간다', () async {
    await repo.remember(['김하늘', '이도윤']);
    final people = await repo.getActive();
    expect(people.map((p) => p.name), ['김하늘', '이도윤']);
    expect(people.every((p) => p.role == PersonRole.student), isTrue);
  });

  test('기억할 이름이 없으면 아무것도 넣지 않는다', () async {
    expect(await repo.remember(const ['', '  ']), isEmpty);
    expect(await repo.getActive(), isEmpty);
  });

  test('보관하면 현재 명단(이름 추천)에서 빠진다', () async {
    final p = await repo.add(const GuidancePerson(name: '김하늘'));
    await repo.add(const GuidancePerson(name: '이도윤'));
    await repo.archive(p.id ?? -1);
    expect((await repo.getActive()).map((x) => x.name), ['이도윤']);
  });

  test('명단 화면 시절에 넣은 구분·메모는 읽을 때 그대로다', () async {
    await repo.add(const GuidancePerson(name: '이도윤 보호자', role: PersonRole.guardian, memo: '어머니'));
    final got = (await repo.getActive()).single;
    expect(got.role, PersonRole.guardian);
    expect(got.memo, '어머니');
  });

  test('현재 명단은 구분(학생 먼저) → 이름 순이다', () async {
    await repo.add(const GuidancePerson(name: '나보호자', role: PersonRole.guardian));
    await repo.add(const GuidancePerson(name: '하학생'));
    await repo.add(const GuidancePerson(name: '가학생'));
    expect((await repo.getActive()).map((p) => p.name), ['가학생', '하학생', '나보호자']);
  });

  group('remember — 저장한 관련인 이름을 명단에 기억한다', () {
    test('없는 이름은 넣고, 같은 이름(앞뒤 공백 무시)은 한 사람으로 같은 id를 준다', () async {
      final first = await repo.remember(['김하늘', ' 이도윤 ', '', '김하늘']);
      expect(first.keys, ['김하늘', '이도윤']);
      final again = await repo.remember(['이도윤', '박서준']);
      expect(again['이도윤'], first['이도윤']);
      expect((await repo.getActive()).map((p) => p.name), ['김하늘', '박서준', '이도윤']);
    });

    test('보관한(추천에서 지운) 이름은 되살리지 않고 그 id를 쓴다', () async {
      final p = await repo.add(const GuidancePerson(name: '김하늘'));
      await repo.archive(p.id ?? -1);
      final got = await repo.remember(['김하늘']);
      expect(got['김하늘'], p.id);
      expect(await repo.getActive(), isEmpty, reason: '지운 추천이 다시 뜨면 안 된다');
    });

    test('같은 이름이 여럿이면 보관 안 된 것을 쓴다', () async {
      final old = await repo.add(const GuidancePerson(name: '김하늘'));
      await repo.archive(old.id ?? -1);
      final current = await repo.add(const GuidancePerson(name: '김하늘', memo: '3반'));
      expect((await repo.remember(['김하늘']))['김하늘'], current.id);
    });
  });
}
