import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_logic.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';

GuidanceRecord _rec(
  int id, {
  DateTime? at,
  OccurredPrecision precision = OccurredPrecision.exact,
  String createdAt = '2026-10-01T09:00:00.000',
  GuidanceKind kind = GuidanceKind.guidance,
  List<Participant> people = const [],
}) => GuidanceRecord(
  id: id,
  createdAt: createdAt,
  latest: GuidanceRevision(
    recordId: id,
    revisionNo: 1,
    savedAt: createdAt,
    content: GuidanceContent(
      title: '기록 $id',
      kind: kind,
      precision: precision,
      occurredAt: at,
      participants: people,
    ),
  ),
);

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));
  final now = DateTime(2026, 10, 3, 12);

  group('sameContent', () {
    test('앞뒤 공백·빈 글만 다르면 같은 내용이다', () {
      const a = GuidanceContent(title: '복도 다툼', facts: '밀침', place: '');
      const b = GuidanceContent(title: ' 복도 다툼 ', facts: '밀침\n', place: null);
      expect(sameContent(a, b), isTrue);
    });

    test('글 하나가 바뀌면 다른 내용이다', () {
      const a = GuidanceContent(title: '복도 다툼', facts: '밀침');
      const b = GuidanceContent(title: '복도 다툼', facts: '밀침. 보건실 확인');
      expect(sameContent(a, b), isFalse);
    });

    test('관련인의 personId만 다르면 같은 내용이다 — 저장 때 이름으로 채워지는 값이라', () {
      const a = GuidanceContent(title: 't', participants: [Participant(name: '김하늘')]);
      const b = GuidanceContent(title: 't', participants: [Participant(personId: 3, name: '김하늘')]);
      expect(sameContent(a, b), isTrue);
      expect(changedFields(a, b.copyWith(facts: '덧붙임')), {ContentField.facts});
    });

    test('날짜만이면 시각 차이는 무시한다', () {
      final a = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2, 9),
      );
      final b = a.copyWith(occurredAt: DateTime(2026, 10, 2, 18));
      expect(sameContent(a, b), isTrue);
    });
  });

  test('changedFields는 바뀐 칸만 돌려준다', () {
    const a = GuidanceContent(title: 't', facts: '가');
    final b = a.copyWith(facts: '나', status: GuidanceStatus.transferred);
    expect(changedFields(a, b), {ContentField.facts, ContentField.status});
  });

  group('formatOccurred', () {
    test('정확히 — 월.일 (요일) 시:분', () {
      final c = GuidanceContent(title: 't', occurredAt: DateTime(2026, 10, 2, 15, 30));
      expect(formatOccurred(c, now: now), '10.2 (금) 15:30');
    });

    test('날짜만 — 시각 없이', () {
      final c = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.date,
        occurredAt: DateTime(2026, 10, 2),
      );
      expect(formatOccurred(c, now: now), '10.2 (금)');
    });

    test('다른 해면 연도를 붙인다', () {
      final c = GuidanceContent(title: 't', occurredAt: DateTime(2025, 3, 4, 9, 5));
      expect(formatOccurred(c, now: now), '2025.3.4 (화) 09:05');
    });

    test('대략 — 적은 글 그대로, 없으면 시각 모름', () {
      const c = GuidanceContent(
        title: 't',
        precision: OccurredPrecision.approx,
        occurredText: '3월 초~여름방학 전',
      );
      expect(formatOccurred(c, now: now), '3월 초~여름방학 전');
      expect(
        formatOccurred(c.copyWith(occurredText: null), now: now),
        '시각 모름',
      );
    });
  });

  test('sortRecords — 사건 시각이 최근인 것이 위, 대략은 기록 시각으로', () {
    final sorted = sortRecords([
      _rec(1, at: DateTime(2026, 9, 25)),
      _rec(2, precision: OccurredPrecision.approx, createdAt: '2026-10-02T08:00:00.000'),
      _rec(3, at: DateTime(2026, 9, 30)),
    ]);
    expect(sorted.map((r) => r.id), [2, 3, 1]);
  });

  group('filterRecords', () {
    const kim = Participant(personId: 7, name: '김하늘');
    const park = Participant(name: '박서준', memo: '5반');
    final records = [
      _rec(1, people: [kim]),
      _rec(2, people: [park], kind: GuidanceKind.infringement),
      _rec(3, people: [kim, park]),
    ];

    test('같은 이름이면 같은 사람이다 — personId가 없거나 달라도', () {
      final got = filterRecords(records, person: const Participant(name: ' 김하늘 '));
      expect(got.map((r) => r.id), [1, 3]);
      final other = filterRecords(records, person: const Participant(personId: 99, name: '김하늘'));
      expect(other.map((r) => r.id), [1, 3]);
    });

    test('명단에 없던 사람도 이름으로 찾는다', () {
      final got = filterRecords(records, person: const Participant(name: '박서준'));
      expect(got.map((r) => r.id), [2, 3]);
    });

    test('구분으로 거른다', () {
      final got = filterRecords(records, kind: GuidanceKind.infringement);
      expect(got.map((r) => r.id), [2]);
    });
  });

  test('collectParticipants — 겹치지 않게 모은다', () {
    const kim = Participant(personId: 7, name: '김하늘');
    final got = collectParticipants([
      _rec(1, people: [kim]),
      _rec(2, people: [kim, const Participant(name: '박서준')]),
    ]);
    expect(got.map((p) => p.name), ['김하늘', '박서준']);
  });

  test('parseRosterPaste — 번호·빈 줄·중복을 걷어낸다', () {
    const raw = '1. 김하늘\n2\t이도윤\n\n  최민서  \n김하늘\n10) 박서준';
    expect(parseRosterPaste(raw), ['김하늘', '이도윤', '최민서', '박서준']);
  });

  test('parseRosterPaste — 번호 뒤 구분자가 없으면 이름의 일부로 둔다', () {
    expect(parseRosterPaste('1반 김하늘'), ['1반 김하늘']);
    expect(parseRosterPaste('3 박서준\n7\t최민서'), ['박서준', '최민서']);
  });

  test('countRecordsByPerson — 명단 사람만 센다', () {
    const kim = Participant(personId: 7, name: '김하늘');
    final got = countRecordsByPerson([
      _rec(1, people: [kim]),
      _rec(2, people: [kim, const Participant(name: '박서준')]),
    ]);
    expect(got, {7: 2});
  });

  test('splitNames — 쉼표·전각 쉼표로 나누고 빈 조각을 버린다', () {
    expect(splitNames('김하늘, 이도윤，박서준(5반) , ,'), ['김하늘', '이도윤', '박서준(5반)']);
    expect(splitNames('   '), isEmpty);
  });

  test('addParticipantNames — 빈 이름·이미 있는 이름(앞뒤 공백 무시)은 건너뛴다', () {
    const kim = Participant(personId: 7, name: '김하늘');
    final got = addParticipantNames([kim], ['이도윤', ' 김하늘 ', '', '이도윤', '박서준']);
    expect(got.map((p) => p.name), ['김하늘', '이도윤', '박서준']);
    expect(got.first, kim, reason: '있던 사람은 그대로 둔다');
  });

  group('suggestPeople', () {
    const roster = [
      GuidancePerson(id: 1, name: '김하늘'),
      GuidancePerson(id: 2, name: '김하랑'),
      GuidancePerson(id: 3, name: '이도윤'),
    ];

    test('친 글을 포함하는 이름만, 이미 넣은 사람은 빼고', () {
      final got = suggestPeople(roster, '하', const [Participant(name: '김하늘')]);
      expect(got.map((p) => p.name), ['김하랑']);
    });

    test('친 글이 없으면 추천하지 않고, 개수 상한을 지킨다', () {
      expect(suggestPeople(roster, ' ', const []), isEmpty);
      expect(suggestPeople(roster, '김', const [], limit: 1).map((p) => p.name), ['김하늘']);
    });
  });
}
