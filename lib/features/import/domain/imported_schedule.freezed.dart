// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imported_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImportedSchedule {

 int? get id;@JsonKey(name: 'document_number') String? get documentNumber;@JsonKey(name: 'approval_type') String? get approvalType; String get title; String? get drafter;@JsonKey(name: 'registration_date') String get registrationDate; String? get category;@JsonKey(name: 'sub_category') String? get subCategory;@JsonKey(name: 'retention_period') String? get retentionPeriod;@JsonKey(name: 'source_year') int? get sourceYear;@JsonKey(name: 'imported_at') String? get importedAt;
/// Create a copy of ImportedSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportedScheduleCopyWith<ImportedSchedule> get copyWith => _$ImportedScheduleCopyWithImpl<ImportedSchedule>(this as ImportedSchedule, _$identity);

  /// Serializes this ImportedSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportedSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.approvalType, approvalType) || other.approvalType == approvalType)&&(identical(other.title, title) || other.title == title)&&(identical(other.drafter, drafter) || other.drafter == drafter)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.retentionPeriod, retentionPeriod) || other.retentionPeriod == retentionPeriod)&&(identical(other.sourceYear, sourceYear) || other.sourceYear == sourceYear)&&(identical(other.importedAt, importedAt) || other.importedAt == importedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,documentNumber,approvalType,title,drafter,registrationDate,category,subCategory,retentionPeriod,sourceYear,importedAt);

@override
String toString() {
  return 'ImportedSchedule(id: $id, documentNumber: $documentNumber, approvalType: $approvalType, title: $title, drafter: $drafter, registrationDate: $registrationDate, category: $category, subCategory: $subCategory, retentionPeriod: $retentionPeriod, sourceYear: $sourceYear, importedAt: $importedAt)';
}


}

/// @nodoc
abstract mixin class $ImportedScheduleCopyWith<$Res>  {
  factory $ImportedScheduleCopyWith(ImportedSchedule value, $Res Function(ImportedSchedule) _then) = _$ImportedScheduleCopyWithImpl;
@useResult
$Res call({
 int? id,@JsonKey(name: 'document_number') String? documentNumber,@JsonKey(name: 'approval_type') String? approvalType, String title, String? drafter,@JsonKey(name: 'registration_date') String registrationDate, String? category,@JsonKey(name: 'sub_category') String? subCategory,@JsonKey(name: 'retention_period') String? retentionPeriod,@JsonKey(name: 'source_year') int? sourceYear,@JsonKey(name: 'imported_at') String? importedAt
});




}
/// @nodoc
class _$ImportedScheduleCopyWithImpl<$Res>
    implements $ImportedScheduleCopyWith<$Res> {
  _$ImportedScheduleCopyWithImpl(this._self, this._then);

  final ImportedSchedule _self;
  final $Res Function(ImportedSchedule) _then;

/// Create a copy of ImportedSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? documentNumber = freezed,Object? approvalType = freezed,Object? title = null,Object? drafter = freezed,Object? registrationDate = null,Object? category = freezed,Object? subCategory = freezed,Object? retentionPeriod = freezed,Object? sourceYear = freezed,Object? importedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,documentNumber: freezed == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String?,approvalType: freezed == approvalType ? _self.approvalType : approvalType // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,drafter: freezed == drafter ? _self.drafter : drafter // ignore: cast_nullable_to_non_nullable
as String?,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,retentionPeriod: freezed == retentionPeriod ? _self.retentionPeriod : retentionPeriod // ignore: cast_nullable_to_non_nullable
as String?,sourceYear: freezed == sourceYear ? _self.sourceYear : sourceYear // ignore: cast_nullable_to_non_nullable
as int?,importedAt: freezed == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ImportedSchedule].
extension ImportedSchedulePatterns on ImportedSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImportedSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImportedSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImportedSchedule value)  $default,){
final _that = this;
switch (_that) {
case _ImportedSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImportedSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _ImportedSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'document_number')  String? documentNumber, @JsonKey(name: 'approval_type')  String? approvalType,  String title,  String? drafter, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'retention_period')  String? retentionPeriod, @JsonKey(name: 'source_year')  int? sourceYear, @JsonKey(name: 'imported_at')  String? importedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImportedSchedule() when $default != null:
return $default(_that.id,_that.documentNumber,_that.approvalType,_that.title,_that.drafter,_that.registrationDate,_that.category,_that.subCategory,_that.retentionPeriod,_that.sourceYear,_that.importedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'document_number')  String? documentNumber, @JsonKey(name: 'approval_type')  String? approvalType,  String title,  String? drafter, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'retention_period')  String? retentionPeriod, @JsonKey(name: 'source_year')  int? sourceYear, @JsonKey(name: 'imported_at')  String? importedAt)  $default,) {final _that = this;
switch (_that) {
case _ImportedSchedule():
return $default(_that.id,_that.documentNumber,_that.approvalType,_that.title,_that.drafter,_that.registrationDate,_that.category,_that.subCategory,_that.retentionPeriod,_that.sourceYear,_that.importedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id, @JsonKey(name: 'document_number')  String? documentNumber, @JsonKey(name: 'approval_type')  String? approvalType,  String title,  String? drafter, @JsonKey(name: 'registration_date')  String registrationDate,  String? category, @JsonKey(name: 'sub_category')  String? subCategory, @JsonKey(name: 'retention_period')  String? retentionPeriod, @JsonKey(name: 'source_year')  int? sourceYear, @JsonKey(name: 'imported_at')  String? importedAt)?  $default,) {final _that = this;
switch (_that) {
case _ImportedSchedule() when $default != null:
return $default(_that.id,_that.documentNumber,_that.approvalType,_that.title,_that.drafter,_that.registrationDate,_that.category,_that.subCategory,_that.retentionPeriod,_that.sourceYear,_that.importedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ImportedSchedule extends ImportedSchedule {
  const _ImportedSchedule({this.id, @JsonKey(name: 'document_number') this.documentNumber, @JsonKey(name: 'approval_type') this.approvalType, required this.title, this.drafter, @JsonKey(name: 'registration_date') required this.registrationDate, this.category, @JsonKey(name: 'sub_category') this.subCategory, @JsonKey(name: 'retention_period') this.retentionPeriod, @JsonKey(name: 'source_year') this.sourceYear, @JsonKey(name: 'imported_at') this.importedAt}): super._();
  factory _ImportedSchedule.fromJson(Map<String, dynamic> json) => _$ImportedScheduleFromJson(json);

@override final  int? id;
@override@JsonKey(name: 'document_number') final  String? documentNumber;
@override@JsonKey(name: 'approval_type') final  String? approvalType;
@override final  String title;
@override final  String? drafter;
@override@JsonKey(name: 'registration_date') final  String registrationDate;
@override final  String? category;
@override@JsonKey(name: 'sub_category') final  String? subCategory;
@override@JsonKey(name: 'retention_period') final  String? retentionPeriod;
@override@JsonKey(name: 'source_year') final  int? sourceYear;
@override@JsonKey(name: 'imported_at') final  String? importedAt;

/// Create a copy of ImportedSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImportedScheduleCopyWith<_ImportedSchedule> get copyWith => __$ImportedScheduleCopyWithImpl<_ImportedSchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImportedScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImportedSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.approvalType, approvalType) || other.approvalType == approvalType)&&(identical(other.title, title) || other.title == title)&&(identical(other.drafter, drafter) || other.drafter == drafter)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.retentionPeriod, retentionPeriod) || other.retentionPeriod == retentionPeriod)&&(identical(other.sourceYear, sourceYear) || other.sourceYear == sourceYear)&&(identical(other.importedAt, importedAt) || other.importedAt == importedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,documentNumber,approvalType,title,drafter,registrationDate,category,subCategory,retentionPeriod,sourceYear,importedAt);

@override
String toString() {
  return 'ImportedSchedule(id: $id, documentNumber: $documentNumber, approvalType: $approvalType, title: $title, drafter: $drafter, registrationDate: $registrationDate, category: $category, subCategory: $subCategory, retentionPeriod: $retentionPeriod, sourceYear: $sourceYear, importedAt: $importedAt)';
}


}

/// @nodoc
abstract mixin class _$ImportedScheduleCopyWith<$Res> implements $ImportedScheduleCopyWith<$Res> {
  factory _$ImportedScheduleCopyWith(_ImportedSchedule value, $Res Function(_ImportedSchedule) _then) = __$ImportedScheduleCopyWithImpl;
@override @useResult
$Res call({
 int? id,@JsonKey(name: 'document_number') String? documentNumber,@JsonKey(name: 'approval_type') String? approvalType, String title, String? drafter,@JsonKey(name: 'registration_date') String registrationDate, String? category,@JsonKey(name: 'sub_category') String? subCategory,@JsonKey(name: 'retention_period') String? retentionPeriod,@JsonKey(name: 'source_year') int? sourceYear,@JsonKey(name: 'imported_at') String? importedAt
});




}
/// @nodoc
class __$ImportedScheduleCopyWithImpl<$Res>
    implements _$ImportedScheduleCopyWith<$Res> {
  __$ImportedScheduleCopyWithImpl(this._self, this._then);

  final _ImportedSchedule _self;
  final $Res Function(_ImportedSchedule) _then;

/// Create a copy of ImportedSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? documentNumber = freezed,Object? approvalType = freezed,Object? title = null,Object? drafter = freezed,Object? registrationDate = null,Object? category = freezed,Object? subCategory = freezed,Object? retentionPeriod = freezed,Object? sourceYear = freezed,Object? importedAt = freezed,}) {
  return _then(_ImportedSchedule(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,documentNumber: freezed == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String?,approvalType: freezed == approvalType ? _self.approvalType : approvalType // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,drafter: freezed == drafter ? _self.drafter : drafter // ignore: cast_nullable_to_non_nullable
as String?,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,retentionPeriod: freezed == retentionPeriod ? _self.retentionPeriod : retentionPeriod // ignore: cast_nullable_to_non_nullable
as String?,sourceYear: freezed == sourceYear ? _self.sourceYear : sourceYear // ignore: cast_nullable_to_non_nullable
as int?,importedAt: freezed == importedAt ? _self.importedAt : importedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
