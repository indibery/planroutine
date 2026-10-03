import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/date_utils.dart';
import 'guidance_content.dart';
import 'guidance_types.dart';
import 'participant.dart';

part 'guidance_models.freezed.dart';

/// 판 한 줄(`guidance_revisions`). **추가만 한다** — 고치거나 지우지 않는다.
@freezed
abstract class GuidanceRevision with _$GuidanceRevision {
  const GuidanceRevision._();

  const factory GuidanceRevision({
    int? id,
    required int recordId,
    required int revisionNo,
    required String savedAt,
    required GuidanceContent content,
  }) = _GuidanceRevision;

  factory GuidanceRevision.fromMap(Map<String, dynamic> m) {
    final at = m['occurred_at'] as String?;
    return GuidanceRevision(
      id: m['id'] as int?,
      recordId: m['record_id'] as int,
      revisionNo: m['revision_no'] as int,
      savedAt: m['saved_at'] as String,
      content: GuidanceContent(
        kind: GuidanceKind.fromValue(m['kind'] as String?),
        status: GuidanceStatus.fromValue(m['status'] as String?),
        precision: OccurredPrecision.fromValue(m['occurred_precision'] as String?),
        occurredAt: at == null ? null : DateTime.tryParse(at),
        occurredText: m['occurred_text'] as String?,
        title: (m['title'] as String?) ?? '',
        place: m['place'] as String?,
        participants: Participant.decodeList(m['participants'] as String?),
        facts: m['facts'] as String?,
        quotes: m['quotes'] as String?,
        actions: m['actions'] as String?,
      ),
    );
  }

  /// 판의 내용 칸만 맵으로. `record_id`·`revision_no`·`saved_at`은 저장소가 붙인다.
  static Map<String, dynamic> contentToMap(GuidanceContent c) {
    final n = c.normalized();
    final at = n.occurredAt;
    return {
      'kind': n.kind.dbValue,
      'status': n.status.dbValue,
      'occurred_precision': n.precision.dbValue,
      'occurred_at': at == null
          ? null
          : n.precision == OccurredPrecision.date
              ? formatDate(at)
              : at.toIso8601String(),
      'occurred_text': n.occurredText,
      'title': n.title,
      'place': n.place,
      'participants': Participant.encodeList(n.participants),
      'facts': n.facts,
      'quotes': n.quotes,
      'actions': n.actions,
    };
  }
}

/// 목록·보기용 — 기록 몸통 + 최신 판 + 개수.
@freezed
abstract class GuidanceRecord with _$GuidanceRecord {
  const GuidanceRecord._();

  const factory GuidanceRecord({
    required int id,
    required String createdAt,
    String? deletedAt,
    required GuidanceRevision latest,
    @Default(1) int revisionCount,
    @Default(0) int attachmentCount,
  }) = _GuidanceRecord;

  GuidanceContent get content => latest.content;
}

@freezed
abstract class GuidanceAttachment with _$GuidanceAttachment {
  const GuidanceAttachment._();

  const factory GuidanceAttachment({
    int? id,
    required int recordId,
    required AttachmentType type,
    required AttachmentSource source,
    required String fileName,
    String? originalName,
    required String sha256,
    required int byteSize,
    int? durationMs,
    String? capturedAt,
    required String attachedAt,
    String? removedAt,
  }) = _GuidanceAttachment;

  factory GuidanceAttachment.fromMap(Map<String, dynamic> m) => GuidanceAttachment(
    id: m['id'] as int?,
    recordId: m['record_id'] as int,
    type: AttachmentType.fromValue(m['type'] as String?),
    source: AttachmentSource.fromValue(m['source'] as String?),
    fileName: m['file_name'] as String,
    originalName: m['original_name'] as String?,
    sha256: m['sha256'] as String,
    byteSize: m['byte_size'] as int,
    durationMs: m['duration_ms'] as int?,
    capturedAt: m['captured_at'] as String?,
    attachedAt: m['attached_at'] as String,
    removedAt: m['removed_at'] as String?,
  );

  /// `removed_at`은 넣지 않는다 — 빼기는 전용 메서드만 만진다.
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'record_id': recordId,
    'type': type.dbValue,
    'source': source.dbValue,
    'file_name': fileName,
    'original_name': originalName,
    'sha256': sha256,
    'byte_size': byteSize,
    'duration_ms': durationMs,
    'captured_at': capturedAt,
    'attached_at': attachedAt,
  };

  bool get isRemoved => removedAt != null;
}

@freezed
abstract class GuidancePerson with _$GuidancePerson {
  const GuidancePerson._();

  const factory GuidancePerson({
    int? id,
    required String name,
    @Default(PersonRole.student) PersonRole role,
    String? memo,
    String? archivedAt,
    String? createdAt,
    String? updatedAt,
  }) = _GuidancePerson;

  factory GuidancePerson.fromMap(Map<String, dynamic> m) => GuidancePerson(
    id: m['id'] as int?,
    name: m['name'] as String,
    role: PersonRole.fromValue(m['role'] as String?),
    memo: m['memo'] as String?,
    archivedAt: m['archived_at'] as String?,
    createdAt: m['created_at'] as String?,
    updatedAt: m['updated_at'] as String?,
  );

  /// `archived_at`은 넣지 않는다 — 보관은 전용 메서드만 만진다.
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null) 'id': id,
      'name': name,
      'role': role.dbValue,
      'memo': memo,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  Participant toParticipant() =>
      Participant(personId: id, name: name, role: role, memo: memo);
}
