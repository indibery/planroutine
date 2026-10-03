import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/database/database_helper.dart';
import 'package:planroutine/features/guidance/data/guidance_people_repository.dart';
import 'package:planroutine/features/guidance/data/guidance_repository.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

import '../../../helpers/test_database.dart';

GuidanceAttachment _att(int recordId, String name) => GuidanceAttachment(
  recordId: recordId,
  type: AttachmentType.audio,
  source: AttachmentSource.recorded,
  fileName: name,
  sha256: 'abc',
  byteSize: 3,
  attachedAt: DateTime.now().toIso8601String(),
);

void main() {
  setUpAll(setUpFfiForTests);
  late DatabaseHelper db;
  late GuidanceRepository repo;

  setUp(() {
    db = freshDatabaseHelper();
    repo = GuidanceRepository(dbHelper: db);
  });
  tearDown(() async => db.close());

  test('새 기록은 판 1이고 목록에 뜬다', () async {
    final id = await repo.create(const GuidanceContent(title: '복도 다툼'));
    final list = await repo.getActive();
    expect(list.single.id, id);
    expect(list.single.latest.revisionNo, 1);
    expect(list.single.revisionCount, 1);
    expect(list.single.content.title, '복도 다툼');
  });

  test('저장할 때마다 판이 늘고 이전 판은 그대로 남는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't', facts: '처음'));
    expect(await repo.saveRevision(id, const GuidanceContent(title: 't', facts: '고침')), isTrue);
    final revs = await repo.getRevisions(id);
    expect(revs.map((r) => r.revisionNo), [2, 1]);
    expect(revs.last.content.facts, '처음');
    expect((await repo.getRecord(id))?.revisionCount, 2);
  });

  test('같은 내용(공백만 다름)이면 판을 만들지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't', facts: '가'));
    expect(await repo.saveRevision(id, const GuidanceContent(title: ' t ', facts: '가\n')), isFalse);
    expect(await repo.getRevisions(id), hasLength(1));
  });

  test('기록 시각은 판을 더해도 바뀌지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    final before = (await repo.getRecord(id))?.createdAt;
    await repo.saveRevision(id, const GuidanceContent(title: 't2'));
    expect((await repo.getRecord(id))?.createdAt, before);
  });

  test('관련인은 사본이라 옛 판의 이름은 그대로다', () async {
    final id = await repo.create(
      const GuidanceContent(title: 't', participants: [Participant(personId: 1, name: '김하늘')]),
    );
    await repo.saveRevision(
      id,
      const GuidanceContent(title: 't', participants: [Participant(personId: 1, name: '김하늘(바뀜)')]),
    );
    final revs = await repo.getRevisions(id);
    expect(revs.last.content.participants.single.name, '김하늘');
  });

  test('삭제하면 삭제한 기록으로 가고, 되살리면 돌아온다', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    await repo.softDelete(id);
    expect(await repo.getActive(), isEmpty);
    expect((await repo.getDeleted()).single.id, id);
    await repo.restore(id);
    expect((await repo.getActive()).single.id, id);
  });

  test('첨부는 붙이고 빼도 행이 남는다(빼기 = removed_at)', () async {
    final id = await repo.create(const GuidanceContent(title: 't'));
    final a = await repo.addAttachment(_att(id, 'a.m4a'));
    await repo.addAttachment(_att(id, 'b.m4a'));
    await repo.removeAttachment(a.id ?? -1);
    final atts = await repo.getAttachments(id);
    expect(atts.map((x) => x.fileName), ['a.m4a', 'b.m4a']);
    expect(atts.first.isRemoved, isTrue);
    // 목록의 첨부 수는 뺀 것을 세지 않는다
    expect((await repo.getRecord(id))?.attachmentCount, 1);
  });

  test('영구 삭제는 그 기록의 판·첨부만 지우고 파일 이름을 돌려준다', () async {
    final a = await repo.create(const GuidanceContent(title: 'a'));
    final b = await repo.create(const GuidanceContent(title: 'b'));
    await repo.addAttachment(_att(a, 'a1.m4a'));
    await repo.addAttachment(_att(b, 'b1.m4a'));
    await repo.softDelete(a);
    final names = await repo.permanentDelete(a);
    expect(names, ['a1.m4a']);
    expect(await repo.getDeleted(), isEmpty);
    expect(await repo.getRevisions(a), isEmpty);
    expect((await repo.getAttachments(b)).single.fileName, 'b1.m4a');
  });

  test('counts는 삭제한 기록·뺀 첨부까지 센다(초기화 경고용)', () async {
    final a = await repo.create(const GuidanceContent(title: 'a'));
    final x = await repo.addAttachment(_att(a, 'x.m4a'));
    await repo.removeAttachment(x.id ?? -1);
    await repo.softDelete(a);
    final c = await repo.counts();
    expect(c.records, 1);
    expect(c.attachments, 1);
  });

  test('counts는 명단(보관한 사람 포함)도 센다 — 기록이 0건이어도 초기화가 명단을 지운다', () async {
    final people = GuidancePeopleRepository(dbHelper: db);
    await people.remember(['김하늘', '이도윤']);
    final p = await people.add(const GuidancePerson(name: '최민서', role: PersonRole.guardian));
    await people.archive(p.id ?? -1);
    final c = await repo.counts();
    expect(c.records, 0);
    expect(c.people, 3);
  });

  test('다시 삭제해도 처음 삭제한 시각을 덮어쓰지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 'a'));
    await repo.softDelete(id);
    final first = (await repo.getDeleted()).single.deletedAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.softDelete(id);
    expect((await repo.getDeleted()).single.deletedAt, first);
  });

  test('다시 빼도 처음 뺀 시각을 덮어쓰지 않는다', () async {
    final id = await repo.create(const GuidanceContent(title: 'a'));
    final a = await repo.addAttachment(_att(id, 'a.m4a'));
    await repo.removeAttachment(a.id ?? -1);
    final first = (await repo.getAttachments(id)).single.removedAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.removeAttachment(a.id ?? -1);
    expect((await repo.getAttachments(id)).single.removedAt, first);
  });

  test('되살리기는 삭제 시각을 지운다(softDelete의 조건이 되살리기를 막지 않는다)', () async {
    final id = await repo.create(const GuidanceContent(title: 'a'));
    await repo.softDelete(id);
    await repo.restore(id);
    expect((await repo.getActive()).single.id, id);
  });
}
