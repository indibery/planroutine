// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImportedScheduleData _$ImportedScheduleDataFromJson(
  Map<String, dynamic> json,
) => _ImportedScheduleData(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  registrationDate: json['registration_date'] as String,
  category: json['category'] as String?,
  subCategory: json['sub_category'] as String?,
  sourceYear: (json['source_year'] as num?)?.toInt(),
);

Map<String, dynamic> _$ImportedScheduleDataToJson(
  _ImportedScheduleData instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'registration_date': instance.registrationDate,
  'category': instance.category,
  'sub_category': instance.subCategory,
  'source_year': instance.sourceYear,
};

_ScheduleData _$ScheduleDataFromJson(Map<String, dynamic> json) =>
    _ScheduleData(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      scheduledDate: json['scheduled_date'] as String,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      status: json['status'] as String,
    );

Map<String, dynamic> _$ScheduleDataToJson(_ScheduleData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'scheduled_date': instance.scheduledDate,
      'category': instance.category,
      'sub_category': instance.subCategory,
      'status': instance.status,
    };

_CompareItem _$CompareItemFromJson(Map<String, dynamic> json) => _CompareItem(
  lastYearItem: json['lastYearItem'] == null
      ? null
      : ImportedScheduleData.fromJson(
          json['lastYearItem'] as Map<String, dynamic>,
        ),
  thisYearItem: json['thisYearItem'] == null
      ? null
      : ScheduleData.fromJson(json['thisYearItem'] as Map<String, dynamic>),
  matchType: $enumDecode(_$MatchTypeEnumMap, json['matchType']),
  sortMonth: (json['sortMonth'] as num).toInt(),
);

Map<String, dynamic> _$CompareItemToJson(_CompareItem instance) =>
    <String, dynamic>{
      'lastYearItem': instance.lastYearItem,
      'thisYearItem': instance.thisYearItem,
      'matchType': _$MatchTypeEnumMap[instance.matchType]!,
      'sortMonth': instance.sortMonth,
    };

const _$MatchTypeEnumMap = {
  MatchType.exact: 'exact',
  MatchType.similar: 'similar',
  MatchType.onlyLastYear: 'onlyLastYear',
  MatchType.onlyThisYear: 'onlyThisYear',
};
