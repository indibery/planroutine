// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CalendarEvent _$CalendarEventFromJson(Map<String, dynamic> json) =>
    _CalendarEvent(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: json['event_date'] as String,
      endDate: json['end_date'] as String?,
      isAllDay: json['is_all_day'] as bool? ?? true,
      color: json['color'] as String?,
      scheduleId: (json['schedule_id'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      deletedAt: json['deleted_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );

Map<String, dynamic> _$CalendarEventToJson(_CalendarEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'event_date': instance.eventDate,
      'end_date': instance.endDate,
      'is_all_day': instance.isAllDay,
      'color': instance.color,
      'schedule_id': instance.scheduleId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'deleted_at': instance.deletedAt,
      'completed_at': instance.completedAt,
    };
