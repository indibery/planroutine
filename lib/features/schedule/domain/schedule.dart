import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

/// 일정 상태
enum ScheduleStatus {
  pending,
  confirmed;

  /// DB 저장용 문자열
  String get value => name;

  /// 문자열에서 상태로 변환
  static ScheduleStatus fromValue(String value) {
    return ScheduleStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ScheduleStatus.pending,
    );
  }
}

/// 올해 확정 일정 모델
@freezed
abstract class Schedule with _$Schedule {
  const Schedule._();

  const factory Schedule({
    int? id,
    required String title,
    String? description,
    @JsonKey(name: 'scheduled_date') required String scheduledDate,
    String? category,
    @JsonKey(name: 'sub_category') String? subCategory,
    @JsonKey(name: 'source_id') int? sourceId,
    @Default(ScheduleStatus.pending) ScheduleStatus status,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'deleted_at') String? deletedAt,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);

  /// DB 삽입용 Map 변환
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'scheduled_date': scheduledDate,
      'category': category,
      'sub_category': subCategory,
      'source_id': sourceId,
      'status': status.value,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }

  /// DB 결과에서 모델 생성
  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      scheduledDate: map['scheduled_date'] as String,
      category: map['category'] as String?,
      subCategory: map['sub_category'] as String?,
      sourceId: map['source_id'] as int?,
      status: ScheduleStatus.fromValue(map['status'] as String? ?? 'pending'),
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }
}
