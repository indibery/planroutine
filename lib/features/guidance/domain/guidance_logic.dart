import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import 'guidance_content.dart';
import 'guidance_models.dart';
import 'guidance_types.dart';
import 'participant.dart';

/// 수정 이력에서 "무엇이 바뀌었나"를 말할 때 쓰는 칸 이름.
enum ContentField {
  kind(GuidanceStrings.fieldKind),
  status(GuidanceStrings.fieldStatus),
  occurred(GuidanceStrings.fieldOccurred),
  title(GuidanceStrings.fieldTitle),
  place(GuidanceStrings.fieldPlace),
  participants(GuidanceStrings.fieldParticipants),
  facts(GuidanceStrings.fieldFacts),
  quotes(GuidanceStrings.fieldQuotes),
  actions(GuidanceStrings.fieldActions);

  const ContentField(this.label);
  final String label;
}

/// 비교용으로 다듬는다. 관련인의 `personId`는 뺀다 — 저장할 때 이름으로 채워지는 값이라
/// (같은 이름 = 같은 사람) 그것만 달라진 것은 고친 것이 아니다. 옛 기록을 그대로 저장해도
/// id가 새로 채워졌다는 이유로 판이 생기거나 이력에 `관련인`이 바뀐 칸으로 뜨지 않게.
GuidanceContent _comparable(GuidanceContent c) {
  final n = c.normalized();
  return n.copyWith(participants: [for (final p in n.participants) p.copyWith(personId: null)]);
}

/// 다듬은 뒤 같으면 같은 내용이다 — 이때는 새 판을 만들지 않는다.
bool sameContent(GuidanceContent a, GuidanceContent b) => _comparable(a) == _comparable(b);

Set<ContentField> changedFields(GuidanceContent before, GuidanceContent after) {
  final a = _comparable(before);
  final b = _comparable(after);
  return {
    if (a.kind != b.kind) ContentField.kind,
    if (a.status != b.status) ContentField.status,
    if (a.precision != b.precision ||
        a.occurredAt != b.occurredAt ||
        a.occurredText != b.occurredText)
      ContentField.occurred,
    if (a.title != b.title) ContentField.title,
    if (a.place != b.place) ContentField.place,
    if (!listEquals(a.participants, b.participants)) ContentField.participants,
    if (a.facts != b.facts) ContentField.facts,
    if (a.quotes != b.quotes) ContentField.quotes,
    if (a.actions != b.actions) ContentField.actions,
  };
}

String _day(DateTime d, DateTime now) {
  final head = d.year == now.year ? '${d.month}.${d.day}' : '${d.year}.${d.month}.${d.day}';
  return '$head (${DateFormat.E('ko').format(d)})';
}

String _time(DateTime d) => DateFormat('HH:mm').format(d);

/// 사건 시각 한 줄. 올해가 아니면 연도를 붙인다.
String formatOccurred(GuidanceContent c, {required DateTime now}) {
  final at = c.occurredAt;
  return switch (c.precision) {
    OccurredPrecision.approx => c.occurredText ?? GuidanceStrings.occurredUnknown,
    OccurredPrecision.date =>
      at == null ? GuidanceStrings.occurredUnknown : _day(at, now),
    OccurredPrecision.exact =>
      at == null ? GuidanceStrings.occurredUnknown : '${_day(at, now)} ${_time(at)}',
  };
}

/// 기록 시각·저장 시각처럼 ISO 문자열로 저장된 시각 한 줄.
String formatStamp(String iso, {required DateTime now}) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_day(d, now)} ${_time(d)}';
}

DateTime _sortKey(GuidanceRecord r) =>
    r.content.occurredAt ?? DateTime.tryParse(r.createdAt) ?? DateTime(1970);

/// 사건 시각이 최근인 것이 위. 사건 시각이 없으면(대략) 기록 시각으로.
List<GuidanceRecord> sortRecords(List<GuidanceRecord> records) {
  final list = [...records];
  list.sort((a, b) {
    final byTime = _sortKey(b).compareTo(_sortKey(a));
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  return list;
}

/// 같은 이름(앞뒤 공백 정리 후)이면 같은 사람이다 — `personId`는 보지 않는다.
/// 이름은 저장할 때 명단에 기억되고 그 id가 붙지만, 명단 이전에 쓴 기록은 id가 없다.
bool sameParticipant(Participant a, Participant b) => a.name.trim() == b.name.trim();

List<GuidanceRecord> filterRecords(
  List<GuidanceRecord> records, {
  GuidanceKind? kind,
  Participant? person,
}) => [
  for (final r in records)
    if ((kind == null || r.content.kind == kind) &&
        (person == null || r.content.participants.any((p) => sameParticipant(p, person))))
      r,
];

/// 목록의 `사람` 고르기에 쓸 후보 — 기록에 등장한 이름, 처음 등장 순.
List<Participant> collectParticipants(List<GuidanceRecord> records) {
  final out = <Participant>[];
  for (final r in records) {
    for (final p in r.content.participants) {
      if (!out.any((q) => sameParticipant(q, p))) out.add(p);
    }
  }
  return out;
}

// 번호 뒤에 구분자(`.`·`)`·탭·공백)가 있을 때만 번호로 본다 — `1반 김하늘`의 `1`은 이름의 일부다.
final _leadingNumber = RegExp(r'^\d+(?:\s*[.)]\s*|\t\s*|\s+)');

/// 명단 붙여넣기 — 줄마다 한 명. 앞의 번호(`1.`·`2\t`·`10)`)·빈 줄·중복을 걷어낸다.
List<String> parseRosterPaste(String raw) {
  final out = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final name = line.trim().replaceFirst(_leadingNumber, '').trim();
    if (name.isNotEmpty && !out.contains(name)) out.add(name);
  }
  return out;
}

/// 명단 관리 화면의 `기록 N` — 명단 사람(personId 있음)만 센다.
Map<int, int> countRecordsByPerson(List<GuidanceRecord> records) {
  final counts = <int, int>{};
  for (final r in records) {
    final ids = {for (final p in r.content.participants) ?p.personId};
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}

/// 관련인 칸의 구분자 — 쉼표와 전각 쉼표.
final nameSeparator = RegExp('[,，]');

/// 관련인 칸에 친 글을 이름들로 나눈다(`김하늘, 이도윤，박서준` → 셋). 빈 조각은 버린다.
List<String> splitNames(String text) => [
  for (final part in text.split(nameSeparator))
    if (part.trim().isNotEmpty) part.trim(),
];

/// 이름들을 관련인 끝에 더한다. 빈 이름·이미 있는 이름(같은 이름 = 같은 사람)은 건너뛴다.
List<Participant> addParticipantNames(List<Participant> current, Iterable<String> names) {
  final out = [...current];
  for (final raw in names) {
    final p = Participant(name: raw.trim());
    if (p.name.isEmpty || out.any((q) => sameParticipant(q, p))) continue;
    out.add(p);
  }
  return out;
}

/// 관련인 칸 아래 추천 — 명단에서 [query]를 포함하는 이름, 이미 넣은 사람은 빼고 [limit]개까지.
/// 친 글이 없으면 추천하지 않는다.
List<GuidancePerson> suggestPeople(
  List<GuidancePerson> roster,
  String query,
  List<Participant> taken, {
  int limit = 5,
}) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return [
    for (final person in roster)
      if (person.name.contains(q) &&
          !taken.any((p) => sameParticipant(p, Participant(name: person.name))))
        person,
  ].take(limit).toList();
}
