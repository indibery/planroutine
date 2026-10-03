import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

void main() {
  test('모르는 저장값은 안전한 기본값으로 떨어진다', () {
    expect(PersonRole.fromValue('teacher'), PersonRole.other);
    expect(GuidanceKind.fromValue(null), GuidanceKind.guidance);
    expect(GuidanceStatus.fromValue('x'), GuidanceStatus.open);
  });

  test('관련인 목록은 JSON으로 왕복한다', () {
    const list = [
      Participant(personId: 3, name: '김하늘'),
      Participant(name: '박서준', role: PersonRole.student, memo: '5반'),
    ];
    expect(Participant.decodeList(Participant.encodeList(list)), list);
  });

  test('깨진 관련인 JSON은 빈 목록이다', () {
    expect(Participant.decodeList('{oops'), isEmpty);
    expect(Participant.decodeList(null), isEmpty);
  });

  test('판 내용은 맵으로 왕복한다', () {
    final content = GuidanceContent(
      kind: GuidanceKind.infringement,
      status: GuidanceStatus.transferred,
      occurredAt: DateTime(2026, 10, 2, 15, 30),
      title: '학부모 전화',
      participants: const [Participant(name: '보호자', role: PersonRole.guardian)],
      quotes: '"가만두지 않겠다"',
      actions: '교감 보고 10.2 16:00',
    );
    final map = {
      'id': 1,
      'record_id': 9,
      'revision_no': 2,
      'saved_at': '2026-10-02T17:00:00.000',
      ...GuidanceRevision.contentToMap(content),
    };
    final back = GuidanceRevision.fromMap(map);
    expect(back.content, content.normalized());
    expect(back.revisionNo, 2);
  });

  test('날짜만인 사건 시각은 yyyy-MM-dd로 저장한다', () {
    final map = GuidanceRevision.contentToMap(
      GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2, 15),
      ),
    );
    expect(map['occurred_at'], '2026-10-02');
  });
}
