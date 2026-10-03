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

/// 다듬은 뒤 같으면 같은 내용이다 — 이때는 새 판을 만들지 않는다.
bool sameContent(GuidanceContent a, GuidanceContent b) =>
    a.normalized() == b.normalized();

Set<ContentField> changedFields(GuidanceContent before, GuidanceContent after) {
  final a = before.normalized();
  final b = after.normalized();
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

/// 명단 사람은 id로, 명단 밖 사람은 이름으로 같은 사람을 판정한다.
bool sameParticipant(Participant a, Participant b) {
  final ai = a.personId;
  final bi = b.personId;
  if (ai != null || bi != null) return ai == bi;
  return a.name == b.name;
}

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

/// 목록의 `사람` 고르기에 쓸 후보 — 기록에 등장한 사람(명단 밖 포함), 처음 등장 순.
List<Participant> collectParticipants(List<GuidanceRecord> records) {
  final out = <Participant>[];
  for (final r in records) {
    for (final p in r.content.participants) {
      if (!out.any((q) => sameParticipant(q, p))) out.add(p);
    }
  }
  return out;
}

final _leadingNumber = RegExp(r'^\d+\s*[.)\t]?\s*');

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
