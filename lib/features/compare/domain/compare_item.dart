import 'package:freezed_annotation/freezed_annotation.dart';

part 'compare_item.freezed.dart';
part 'compare_item.g.dart';

/// 비교 매칭 유형
enum MatchType {
  exact,
  similar,
  onlyLastYear,
  onlyThisYear,
}

/// 비교 뷰에서 가져온 작년 일정 데이터 (imported_schedules 테이블)
@freezed
abstract class ImportedScheduleData with _$ImportedScheduleData {
  const ImportedScheduleData._();

  const factory ImportedScheduleData({
    required int id,
    required String title,
    @JsonKey(name: 'registration_date') required String registrationDate,
    String? category,
    @JsonKey(name: 'sub_category') String? subCategory,
    @JsonKey(name: 'source_year') int? sourceYear,
  }) = _ImportedScheduleData;

  factory ImportedScheduleData.fromJson(Map<String, dynamic> json) =>
      _$ImportedScheduleDataFromJson(json);

  /// DB 결과에서 모델 생성
  factory ImportedScheduleData.fromMap(Map<String, dynamic> map) {
    return ImportedScheduleData(
      id: map['id'] as int,
      title: map['title'] as String,
      registrationDate: map['registration_date'] as String,
      category: map['category'] as String?,
      subCategory: map['sub_category'] as String?,
      sourceYear: map['source_year'] as int?,
    );
  }
}

/// 비교 뷰에서 올해 일정 데이터 (schedules 테이블)
@freezed
abstract class ScheduleData with _$ScheduleData {
  const ScheduleData._();

  const factory ScheduleData({
    required int id,
    required String title,
    @JsonKey(name: 'scheduled_date') required String scheduledDate,
    String? category,
    @JsonKey(name: 'sub_category') String? subCategory,
    required String status,
  }) = _ScheduleData;

  factory ScheduleData.fromJson(Map<String, dynamic> json) =>
      _$ScheduleDataFromJson(json);

  /// DB 결과에서 모델 생성
  factory ScheduleData.fromMap(Map<String, dynamic> map) {
    return ScheduleData(
      id: map['id'] as int,
      title: map['title'] as String,
      scheduledDate: map['scheduled_date'] as String,
      category: map['category'] as String?,
      subCategory: map['sub_category'] as String?,
      status: map['status'] as String? ?? 'pending',
    );
  }
}

/// 작년 항목과 올해 항목을 쌍으로 묶은 비교 모델
@freezed
abstract class CompareItem with _$CompareItem {
  const CompareItem._();

  const factory CompareItem({
    ImportedScheduleData? lastYearItem,
    ScheduleData? thisYearItem,
    required MatchType matchType,
    /// 정렬용 날짜 (월 기준)
    required int sortMonth,
  }) = _CompareItem;

  factory CompareItem.fromJson(Map<String, dynamic> json) =>
      _$CompareItemFromJson(json);
}
