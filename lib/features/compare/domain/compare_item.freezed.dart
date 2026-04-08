// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'compare_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImportedScheduleData {

 int get id; String get title;@JsonKey(name: 'registration_date') String get registrationDate; String? get category;@JsonKey(name: 'sub_category') String? get subCategory;@JsonKey(name: 'source_year') int? get sourceYear;
/// Create a copy of ImportedScheduleData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportedScheduleDataCopyWith<ImportedScheduleData> get copyWith => _$ImportedScheduleDataCopyWithImpl<ImportedScheduleData>(this as ImportedScheduleData, _$identity);

  /// Serializes this ImportedScheduleData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportedScheduleData&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.sourceYear, sourceYear) || other.sourceYear == sourceYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,registrationDate,category,subCategory,sourceYear);

@override
String toString() {
  return 'ImportedScheduleData(id: $id, title: $title, registrationDate: $registrationDate, category: $category, subCategory: $subCategory, sourceYear: $sourceYear)';
}


}

/// @nodoc
abstract mixin class $ImportedScheduleDataCopyWith<$Res>  {
  factory $ImportedScheduleDataCopyWith(ImportedScheduleData value, $Res Function(ImportedScheduleData) _then) = _$ImportedScheduleDataCopyWithImpl;
@useResult
$Res call({
 int id, String title,@JsonKey(name: 'registration_date') String registrationDate, String? category,@JsonKey(name: 'sub_category') String? subCategory,@JsonKey(name: 'source_year') int? sourceYear
});




}
/// @nodoc
class _$ImportedScheduleDataCopyWithImpl<$Res>
    implements $ImportedScheduleDataCopyWith<$Res> {
  _$ImportedScheduleDataCopyWithImpl(this._self, this._then);

  final ImportedScheduleData _self;
  final $Res Function(ImportedScheduleData) _then;

/// Create a copy of ImportedScheduleData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? registrationDate = null,Object? category = freezed,Object? subCategory = freezed,Object? sourceYear = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,sourceYear: freezed == sourceYear ? _self.sourceYear : sourceYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ImportedScheduleData].
extension ImportedScheduleDataPatterns on ImportedScheduleData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImportedScheduleData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImportedScheduleData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImportedScheduleData value)  $default,){
final _that = this;
switch (_that) {
case _ImportedScheduleData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImportedScheduleData value)?  $default,){
final _that = this;
switch (_that) {
case _ImportedScheduleData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'source_year')  int? sourceYear)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImportedScheduleData() when $default != null:
return $default(_that.id,_that.title,_that.registrationDate,_that.category,_that.subCategory,_that.sourceYear);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'source_year')  int? sourceYear)  $default,) {final _that = this;
switch (_that) {
case _ImportedScheduleData():
return $default(_that.id,_that.title,_that.registrationDate,_that.category,_that.subCategory,_that.sourceYear);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'source_year')  int? sourceYear)?  $default,) {final _that = this;
switch (_that) {
case _ImportedScheduleData() when $default != null:
return $default(_that.id,_that.title,_that.registrationDate,_that.category,_that.subCategory,_that.sourceYear);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ImportedScheduleData extends ImportedScheduleData {
  const _ImportedScheduleData({required this.id, required this.title, @JsonKey(name: 'registration_date') required this.registrationDate, this.category, @JsonKey(name: 'sub_category') this.subCategory, @JsonKey(name: 'source_year') this.sourceYear}): super._();
  factory _ImportedScheduleData.fromJson(Map<String, dynamic> json) => _$ImportedScheduleDataFromJson(json);

@override final  int id;
@override final  String title;
@override@JsonKey(name: 'registration_date') final  String registrationDate;
@override final  String? category;
@override@JsonKey(name: 'sub_category') final  String? subCategory;
@override@JsonKey(name: 'source_year') final  int? sourceYear;

/// Create a copy of ImportedScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImportedScheduleDataCopyWith<_ImportedScheduleData> get copyWith => __$ImportedScheduleDataCopyWithImpl<_ImportedScheduleData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImportedScheduleDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImportedScheduleData&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.sourceYear, sourceYear) || other.sourceYear == sourceYear));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,registrationDate,category,subCategory,sourceYear);

@override
String toString() {
  return 'ImportedScheduleData(id: $id, title: $title, registrationDate: $registrationDate, category: $category, subCategory: $subCategory, sourceYear: $sourceYear)';
}


}

/// @nodoc
abstract mixin class _$ImportedScheduleDataCopyWith<$Res> implements $ImportedScheduleDataCopyWith<$Res> {
  factory _$ImportedScheduleDataCopyWith(_ImportedScheduleData value, $Res Function(_ImportedScheduleData) _then) = __$ImportedScheduleDataCopyWithImpl;
@override @useResult
$Res call({
 int id, String title,@JsonKey(name: 'registration_date') String registrationDate, String? category,@JsonKey(name: 'sub_category') String? subCategory,@JsonKey(name: 'source_year') int? sourceYear
});




}
/// @nodoc
class __$ImportedScheduleDataCopyWithImpl<$Res>
    implements _$ImportedScheduleDataCopyWith<$Res> {
  __$ImportedScheduleDataCopyWithImpl(this._self, this._then);

  final _ImportedScheduleData _self;
  final $Res Function(_ImportedScheduleData) _then;

/// Create a copy of ImportedScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? registrationDate = null,Object? category = freezed,Object? subCategory = freezed,Object? sourceYear = freezed,}) {
  return _then(_ImportedScheduleData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,sourceYear: freezed == sourceYear ? _self.sourceYear : sourceYear // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ScheduleData {

 int get id; String get title;@JsonKey(name: 'scheduled_date') String get scheduledDate; String? get category;@JsonKey(name: 'sub_category') String? get subCategory; String get status;
/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleDataCopyWith<ScheduleData> get copyWith => _$ScheduleDataCopyWithImpl<ScheduleData>(this as ScheduleData, _$identity);

  /// Serializes this ScheduleData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleData&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.scheduledDate, scheduledDate) || other.scheduledDate == scheduledDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,scheduledDate,category,subCategory,status);

@override
String toString() {
  return 'ScheduleData(id: $id, title: $title, scheduledDate: $scheduledDate, category: $category, subCategory: $subCategory, status: $status)';
}


}

/// @nodoc
abstract mixin class $ScheduleDataCopyWith<$Res>  {
  factory $ScheduleDataCopyWith(ScheduleData value, $Res Function(ScheduleData) _then) = _$ScheduleDataCopyWithImpl;
@useResult
$Res call({
 int id, String title,@JsonKey(name: 'scheduled_date') String scheduledDate, String? category,@JsonKey(name: 'sub_category') String? subCategory, String status
});




}
/// @nodoc
class _$ScheduleDataCopyWithImpl<$Res>
    implements $ScheduleDataCopyWith<$Res> {
  _$ScheduleDataCopyWithImpl(this._self, this._then);

  final ScheduleData _self;
  final $Res Function(ScheduleData) _then;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? scheduledDate = null,Object? category = freezed,Object? subCategory = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleData].
extension ScheduleDataPatterns on ScheduleData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleData value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleData value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title, @JsonKey(name: 'scheduled_date')  String scheduledDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that.id,_that.title,_that.scheduledDate,_that.category,_that.subCategory,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title, @JsonKey(name: 'scheduled_date')  String scheduledDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory,  String status)  $default,) {final _that = this;
switch (_that) {
case _ScheduleData():
return $default(_that.id,_that.title,_that.scheduledDate,_that.category,_that.subCategory,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title, @JsonKey(name: 'scheduled_date')  String scheduledDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory,  String status)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleData() when $default != null:
return $default(_that.id,_that.title,_that.scheduledDate,_that.category,_that.subCategory,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduleData extends ScheduleData {
  const _ScheduleData({required this.id, required this.title, @JsonKey(name: 'scheduled_date') required this.scheduledDate, this.category, @JsonKey(name: 'sub_category') this.subCategory, required this.status}): super._();
  factory _ScheduleData.fromJson(Map<String, dynamic> json) => _$ScheduleDataFromJson(json);

@override final  int id;
@override final  String title;
@override@JsonKey(name: 'scheduled_date') final  String scheduledDate;
@override final  String? category;
@override@JsonKey(name: 'sub_category') final  String? subCategory;
@override final  String status;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleDataCopyWith<_ScheduleData> get copyWith => __$ScheduleDataCopyWithImpl<_ScheduleData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduleDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleData&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.scheduledDate, scheduledDate) || other.scheduledDate == scheduledDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,scheduledDate,category,subCategory,status);

@override
String toString() {
  return 'ScheduleData(id: $id, title: $title, scheduledDate: $scheduledDate, category: $category, subCategory: $subCategory, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ScheduleDataCopyWith<$Res> implements $ScheduleDataCopyWith<$Res> {
  factory _$ScheduleDataCopyWith(_ScheduleData value, $Res Function(_ScheduleData) _then) = __$ScheduleDataCopyWithImpl;
@override @useResult
$Res call({
 int id, String title,@JsonKey(name: 'scheduled_date') String scheduledDate, String? category,@JsonKey(name: 'sub_category') String? subCategory, String status
});




}
/// @nodoc
class __$ScheduleDataCopyWithImpl<$Res>
    implements _$ScheduleDataCopyWith<$Res> {
  __$ScheduleDataCopyWithImpl(this._self, this._then);

  final _ScheduleData _self;
  final $Res Function(_ScheduleData) _then;

/// Create a copy of ScheduleData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? scheduledDate = null,Object? category = freezed,Object? subCategory = freezed,Object? status = null,}) {
  return _then(_ScheduleData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,scheduledDate: null == scheduledDate ? _self.scheduledDate : scheduledDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CompareItem {

 ImportedScheduleData? get lastYearItem; ScheduleData? get thisYearItem; MatchType get matchType;/// 정렬용 날짜 (월 기준)
 int get sortMonth;
/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompareItemCopyWith<CompareItem> get copyWith => _$CompareItemCopyWithImpl<CompareItem>(this as CompareItem, _$identity);

  /// Serializes this CompareItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompareItem&&(identical(other.lastYearItem, lastYearItem) || other.lastYearItem == lastYearItem)&&(identical(other.thisYearItem, thisYearItem) || other.thisYearItem == thisYearItem)&&(identical(other.matchType, matchType) || other.matchType == matchType)&&(identical(other.sortMonth, sortMonth) || other.sortMonth == sortMonth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastYearItem,thisYearItem,matchType,sortMonth);

@override
String toString() {
  return 'CompareItem(lastYearItem: $lastYearItem, thisYearItem: $thisYearItem, matchType: $matchType, sortMonth: $sortMonth)';
}


}

/// @nodoc
abstract mixin class $CompareItemCopyWith<$Res>  {
  factory $CompareItemCopyWith(CompareItem value, $Res Function(CompareItem) _then) = _$CompareItemCopyWithImpl;
@useResult
$Res call({
 ImportedScheduleData? lastYearItem, ScheduleData? thisYearItem, MatchType matchType, int sortMonth
});


$ImportedScheduleDataCopyWith<$Res>? get lastYearItem;$ScheduleDataCopyWith<$Res>? get thisYearItem;

}
/// @nodoc
class _$CompareItemCopyWithImpl<$Res>
    implements $CompareItemCopyWith<$Res> {
  _$CompareItemCopyWithImpl(this._self, this._then);

  final CompareItem _self;
  final $Res Function(CompareItem) _then;

/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastYearItem = freezed,Object? thisYearItem = freezed,Object? matchType = null,Object? sortMonth = null,}) {
  return _then(_self.copyWith(
lastYearItem: freezed == lastYearItem ? _self.lastYearItem : lastYearItem // ignore: cast_nullable_to_non_nullable
as ImportedScheduleData?,thisYearItem: freezed == thisYearItem ? _self.thisYearItem : thisYearItem // ignore: cast_nullable_to_non_nullable
as ScheduleData?,matchType: null == matchType ? _self.matchType : matchType // ignore: cast_nullable_to_non_nullable
as MatchType,sortMonth: null == sortMonth ? _self.sortMonth : sortMonth // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImportedScheduleDataCopyWith<$Res>? get lastYearItem {
    if (_self.lastYearItem == null) {
    return null;
  }

  return $ImportedScheduleDataCopyWith<$Res>(_self.lastYearItem!, (value) {
    return _then(_self.copyWith(lastYearItem: value));
  });
}/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleDataCopyWith<$Res>? get thisYearItem {
    if (_self.thisYearItem == null) {
    return null;
  }

  return $ScheduleDataCopyWith<$Res>(_self.thisYearItem!, (value) {
    return _then(_self.copyWith(thisYearItem: value));
  });
}
}


/// Adds pattern-matching-related methods to [CompareItem].
extension CompareItemPatterns on CompareItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompareItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompareItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompareItem value)  $default,){
final _that = this;
switch (_that) {
case _CompareItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompareItem value)?  $default,){
final _that = this;
switch (_that) {
case _CompareItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ImportedScheduleData? lastYearItem,  ScheduleData? thisYearItem,  MatchType matchType,  int sortMonth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompareItem() when $default != null:
return $default(_that.lastYearItem,_that.thisYearItem,_that.matchType,_that.sortMonth);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ImportedScheduleData? lastYearItem,  ScheduleData? thisYearItem,  MatchType matchType,  int sortMonth)  $default,) {final _that = this;
switch (_that) {
case _CompareItem():
return $default(_that.lastYearItem,_that.thisYearItem,_that.matchType,_that.sortMonth);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ImportedScheduleData? lastYearItem,  ScheduleData? thisYearItem,  MatchType matchType,  int sortMonth)?  $default,) {final _that = this;
switch (_that) {
case _CompareItem() when $default != null:
return $default(_that.lastYearItem,_that.thisYearItem,_that.matchType,_that.sortMonth);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompareItem extends CompareItem {
  const _CompareItem({this.lastYearItem, this.thisYearItem, required this.matchType, required this.sortMonth}): super._();
  factory _CompareItem.fromJson(Map<String, dynamic> json) => _$CompareItemFromJson(json);

@override final  ImportedScheduleData? lastYearItem;
@override final  ScheduleData? thisYearItem;
@override final  MatchType matchType;
/// 정렬용 날짜 (월 기준)
@override final  int sortMonth;

/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompareItemCopyWith<_CompareItem> get copyWith => __$CompareItemCopyWithImpl<_CompareItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompareItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompareItem&&(identical(other.lastYearItem, lastYearItem) || other.lastYearItem == lastYearItem)&&(identical(other.thisYearItem, thisYearItem) || other.thisYearItem == thisYearItem)&&(identical(other.matchType, matchType) || other.matchType == matchType)&&(identical(other.sortMonth, sortMonth) || other.sortMonth == sortMonth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastYearItem,thisYearItem,matchType,sortMonth);

@override
String toString() {
  return 'CompareItem(lastYearItem: $lastYearItem, thisYearItem: $thisYearItem, matchType: $matchType, sortMonth: $sortMonth)';
}


}

/// @nodoc
abstract mixin class _$CompareItemCopyWith<$Res> implements $CompareItemCopyWith<$Res> {
  factory _$CompareItemCopyWith(_CompareItem value, $Res Function(_CompareItem) _then) = __$CompareItemCopyWithImpl;
@override @useResult
$Res call({
 ImportedScheduleData? lastYearItem, ScheduleData? thisYearItem, MatchType matchType, int sortMonth
});


@override $ImportedScheduleDataCopyWith<$Res>? get lastYearItem;@override $ScheduleDataCopyWith<$Res>? get thisYearItem;

}
/// @nodoc
class __$CompareItemCopyWithImpl<$Res>
    implements _$CompareItemCopyWith<$Res> {
  __$CompareItemCopyWithImpl(this._self, this._then);

  final _CompareItem _self;
  final $Res Function(_CompareItem) _then;

/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastYearItem = freezed,Object? thisYearItem = freezed,Object? matchType = null,Object? sortMonth = null,}) {
  return _then(_CompareItem(
lastYearItem: freezed == lastYearItem ? _self.lastYearItem : lastYearItem // ignore: cast_nullable_to_non_nullable
as ImportedScheduleData?,thisYearItem: freezed == thisYearItem ? _self.thisYearItem : thisYearItem // ignore: cast_nullable_to_non_nullable
as ScheduleData?,matchType: null == matchType ? _self.matchType : matchType // ignore: cast_nullable_to_non_nullable
as MatchType,sortMonth: null == sortMonth ? _self.sortMonth : sortMonth // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImportedScheduleDataCopyWith<$Res>? get lastYearItem {
    if (_self.lastYearItem == null) {
    return null;
  }

  return $ImportedScheduleDataCopyWith<$Res>(_self.lastYearItem!, (value) {
    return _then(_self.copyWith(lastYearItem: value));
  });
}/// Create a copy of CompareItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleDataCopyWith<$Res>? get thisYearItem {
    if (_self.thisYearItem == null) {
    return null;
  }

  return $ScheduleDataCopyWith<$Res>(_self.thisYearItem!, (value) {
    return _then(_self.copyWith(thisYearItem: value));
  });
}
}

// dart format on
