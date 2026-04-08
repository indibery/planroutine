// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imported_schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImportedSchedule _$ImportedScheduleFromJson(Map<String, dynamic> json) =>
    _ImportedSchedule(
      id: (json['id'] as num?)?.toInt(),
      documentNumber: json['document_number'] as String?,
      approvalType: json['approval_type'] as String?,
      title: json['title'] as String,
      drafter: json['drafter'] as String?,
      registrationDate: json['registration_date'] as String,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      retentionPeriod: json['retention_period'] as String?,
      sourceYear: (json['source_year'] as num?)?.toInt(),
      importedAt: json['imported_at'] as String?,
    );

Map<String, dynamic> _$ImportedScheduleToJson(_ImportedSchedule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'document_number': instance.documentNumber,
      'approval_type': instance.approvalType,
      'title': instance.title,
      'drafter': instance.drafter,
      'registration_date': instance.registrationDate,
      'category': instance.category,
      'sub_category': instance.subCategory,
      'retention_period': instance.retentionPeriod,
      'source_year': instance.sourceYear,
      'imported_at': instance.importedAt,
    };
