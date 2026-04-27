import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar_event.freezed.dart';
part 'calendar_event.g.dart';

/// 캘린더 이벤트 모델
@freezed
abstract class CalendarEvent with _$CalendarEvent {
  const CalendarEvent._();

  const factory CalendarEvent({
    int? id,
    required String title,
    String? description,
    @JsonKey(name: 'event_date') required String eventDate,
    @JsonKey(name: 'end_date') String? endDate,
    @JsonKey(name: 'is_all_day') @Default(true) bool isAllDay,
    String? color,
    @JsonKey(name: 'schedule_id') int? scheduleId,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'deleted_at') String? deletedAt,
    @JsonKey(name: 'completed_at') String? completedAt,
    @JsonKey(name: 'google_event_id') String? googleEventId,
    @JsonKey(name: 'device_event_id') String? deviceEventId,
  }) = _CalendarEvent;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$CalendarEventFromJson(json);

  /// DB 결과에서 모델 생성
  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      eventDate: map['event_date'] as String,
      endDate: map['end_date'] as String?,
      isAllDay: (map['is_all_day'] as int?) == 1,
      color: map['color'] as String?,
      scheduleId: map['schedule_id'] as int?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
      completedAt: map['completed_at'] as String?,
      googleEventId: map['google_event_id'] as String?,
      deviceEventId: map['device_event_id'] as String?,
    );
  }

  /// 완료된 이벤트인지 (completedAt이 null이 아니면 완료)
  bool get isCompleted => completedAt != null;

  /// DB 삽입용 Map 변환 (deletedAt은 repository에서 별도 관리)
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'event_date': eventDate,
      'end_date': endDate,
      'is_all_day': isAllDay ? 1 : 0,
      'color': color,
      'schedule_id': scheduleId,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
      'google_event_id': googleEventId,
      'device_event_id': deviceEventId,
    };
  }

  /// 이벤트 날짜를 DateTime으로 변환
  DateTime get eventDateTime => DateTime.parse(eventDate);

  /// 종료 날짜를 DateTime으로 변환 (없으면 시작일 반환)
  DateTime get endDateTime =>
      endDate != null ? DateTime.parse(endDate!) : eventDateTime;

  /// 색상 hex 문자열을 Color 객체로 변환
  Color get eventColor {
    if (color == null || color!.isEmpty) {
      return const Color(0xFF4A6FA5);
    }
    final hex = color!.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF4A6FA5);
  }

  /// Color 객체를 hex 문자열로 변환 (저장용)
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}
