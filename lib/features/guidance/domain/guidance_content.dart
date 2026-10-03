import 'package:freezed_annotation/freezed_annotation.dart';

import 'guidance_types.dart';
import 'participant.dart';

part 'guidance_content.freezed.dart';

/// 판 하나의 내용 — 사용자가 고칠 수 있는 칸 전부. 구분·상태·사건 시각도 여기 있어서
/// 그것을 바꾼 것도 이력에 남는다.
@freezed
abstract class GuidanceContent with _$GuidanceContent {
  const GuidanceContent._();

  const factory GuidanceContent({
    @Default(GuidanceKind.guidance) GuidanceKind kind,
    @Default(GuidanceStatus.open) GuidanceStatus status,
    @Default(OccurredPrecision.exact) OccurredPrecision precision,
    DateTime? occurredAt,
    String? occurredText,
    @Default('') String title,
    String? place,
    @Default(<Participant>[]) List<Participant> participants,
    String? facts,
    String? quotes,
    String? actions,
  }) = _GuidanceContent;

  /// 저장·비교 전에 다듬는다 — 앞뒤 공백 제거, 빈 글은 null, 정밀도에 맞지 않는 시각 정보 제거.
  /// 이것 없이 비교하면 공백 하나 고친 저장이 새 판이 된다(Review Focus 4).
  GuidanceContent normalized() {
    String? clean(String? s) {
      final t = s?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final at = occurredAt;
    return copyWith(
      title: title.trim(),
      place: clean(place),
      facts: clean(facts),
      quotes: clean(quotes),
      actions: clean(actions),
      occurredText: precision == OccurredPrecision.approx ? clean(occurredText) : null,
      occurredAt: switch (precision) {
        OccurredPrecision.exact => at == null
            ? null
            : DateTime(at.year, at.month, at.day, at.hour, at.minute),
        OccurredPrecision.date => at == null ? null : DateTime(at.year, at.month, at.day),
        OccurredPrecision.approx => null,
      },
      participants: [
        for (final p in participants)
          if (p.name.trim().isNotEmpty) p.copyWith(name: p.name.trim(), memo: clean(p.memo)),
      ],
    );
  }
}
