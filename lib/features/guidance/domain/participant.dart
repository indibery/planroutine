import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'guidance_types.dart';

part 'participant.freezed.dart';

/// 판에 들어가는 관련인 **사본**. 명단에서 이름을 고쳐도 옛 판은 이 사본을 그대로 보여 준다.
/// [personId]가 없으면 명단 밖 이름이다.
@freezed
abstract class Participant with _$Participant {
  const Participant._();

  const factory Participant({
    int? personId,
    required String name,
    @Default(PersonRole.student) PersonRole role,
    String? memo,
  }) = _Participant;

  factory Participant.fromMap(Map<String, dynamic> m) => Participant(
    personId: m['personId'] as int?,
    name: (m['name'] as String?) ?? '',
    role: PersonRole.fromValue(m['role'] as String?),
    memo: m['memo'] as String?,
  );

  Map<String, dynamic> toMap() => {
    if (personId != null) 'personId': personId,
    'name': name,
    'role': role.dbValue,
    if (memo != null) 'memo': memo,
  };

  /// `박서준 · 5반`처럼 메모를 붙인 이름. 메모가 없으면 이름만.
  String get displayName {
    final m = memo;
    return (m == null || m.isEmpty) ? name : '$name · $m';
  }

  static String encodeList(List<Participant> list) =>
      jsonEncode([for (final p in list) p.toMap()]);

  /// 깨진 값이면 빈 목록 — 판 하나가 깨졌다고 화면 전체가 죽지 않게.
  static List<Participant> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) Participant.fromMap(e),
      ];
    } on FormatException {
      return const [];
    }
  }
}
