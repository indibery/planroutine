import 'package:freezed_annotation/freezed_annotation.dart';

part 'imported_schedule.freezed.dart';
part 'imported_schedule.g.dart';

/// CSV에서 가져온 작년 일정 모델
@freezed
abstract class ImportedSchedule with _$ImportedSchedule {
  const ImportedSchedule._();

  const factory ImportedSchedule({
    int? id,
    @JsonKey(name: 'document_number') String? documentNumber,
    @JsonKey(name: 'approval_type') String? approvalType,
    required String title,
    String? drafter,
    @JsonKey(name: 'registration_date') required String registrationDate,
    String? category,
    @JsonKey(name: 'sub_category') String? subCategory,
    @JsonKey(name: 'retention_period') String? retentionPeriod,
    @JsonKey(name: 'source_year') int? sourceYear,
    @JsonKey(name: 'imported_at') String? importedAt,
  }) = _ImportedSchedule;

  factory ImportedSchedule.fromJson(Map<String, dynamic> json) =>
      _$ImportedScheduleFromJson(json);

  /// CSV 행에서 모델 생성
  factory ImportedSchedule.fromCsvRow(Map<String, dynamic> row) {
    final registrationDate = (row['등록일자'] as String? ?? '').trim();
    int? sourceYear;
    if (registrationDate.length >= 4) {
      sourceYear = int.tryParse(registrationDate.substring(0, 4));
    }

    return ImportedSchedule(
      documentNumber: (row['문서번호'] as String?)?.trim(),
      approvalType: (row['결재유형'] as String?)?.trim(),
      title: (row['제목'] as String? ?? '').trim(),
      drafter: (row['기안(접수)자'] as String?)?.trim(),
      registrationDate: registrationDate,
      category: (row['과제명'] as String?)?.trim(),
      subCategory: (row['과제카드명'] as String?)?.trim(),
      retentionPeriod: (row['보존기한'] as String?)?.trim(),
      sourceYear: sourceYear,
      importedAt: DateTime.now().toIso8601String(),
    );
  }

  /// DB 삽입용 Map 변환
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_number': documentNumber,
      'approval_type': approvalType,
      'title': title,
      'drafter': drafter,
      'registration_date': registrationDate,
      'category': category,
      'sub_category': subCategory,
      'retention_period': retentionPeriod,
      'source_year': sourceYear,
      'imported_at': importedAt ?? DateTime.now().toIso8601String(),
    };
  }

  /// DB 결과에서 모델 생성
  factory ImportedSchedule.fromMap(Map<String, dynamic> map) {
    return ImportedSchedule(
      id: map['id'] as int?,
      documentNumber: map['document_number'] as String?,
      approvalType: map['approval_type'] as String?,
      title: map['title'] as String,
      drafter: map['drafter'] as String?,
      registrationDate: map['registration_date'] as String,
      category: map['category'] as String?,
      subCategory: map['sub_category'] as String?,
      retentionPeriod: map['retention_period'] as String?,
      sourceYear: map['source_year'] as int?,
      importedAt: map['imported_at'] as String?,
    );
  }
}
