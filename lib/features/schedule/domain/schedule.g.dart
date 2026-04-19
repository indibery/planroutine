// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Schedule _$ScheduleFromJson(Map<String, dynamic> json) => _Schedule(
  id: (json['id'] as num?)?.toInt(),
  title: json['title'] as String,
  description: json['description'] as String?,
  scheduledDate: json['scheduled_date'] as String,
  category: json['category'] as String?,
  subCategory: json['sub_category'] as String?,
  sourceId: (json['source_id'] as num?)?.toInt(),
  status:
      $enumDecodeNullable(_$ScheduleStatusEnumMap, json['status']) ??
      ScheduleStatus.pending,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  deletedAt: json['deleted_at'] as String?,
);

Map<String, dynamic> _$ScheduleToJson(_Schedule instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'scheduled_date': instance.scheduledDate,
  'category': instance.category,
  'sub_category': instance.subCategory,
  'source_id': instance.sourceId,
  'status': _$ScheduleStatusEnumMap[instance.status]!,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'deleted_at': instance.deletedAt,
};

const _$ScheduleStatusEnumMap = {
  ScheduleStatus.pending: 'pending',
  ScheduleStatus.confirmed: 'confirmed',
};
