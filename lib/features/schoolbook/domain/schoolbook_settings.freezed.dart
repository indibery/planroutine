// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schoolbook_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchoolbookSettings {

 String? get code; String? get schoolName; int? get lastRoomId;/// 최근에 들어간 교실, 앞이 가장 최근(최대 20곳). 교실 칩이 이 순서로 앞에 선다(사용자 결정).
 List<int> get recentRoomIds; String? get booker;
/// Create a copy of SchoolbookSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchoolbookSettingsCopyWith<SchoolbookSettings> get copyWith => _$SchoolbookSettingsCopyWithImpl<SchoolbookSettings>(this as SchoolbookSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchoolbookSettings&&(identical(other.code, code) || other.code == code)&&(identical(other.schoolName, schoolName) || other.schoolName == schoolName)&&(identical(other.lastRoomId, lastRoomId) || other.lastRoomId == lastRoomId)&&const DeepCollectionEquality().equals(other.recentRoomIds, recentRoomIds)&&(identical(other.booker, booker) || other.booker == booker));
}


@override
int get hashCode => Object.hash(runtimeType,code,schoolName,lastRoomId,const DeepCollectionEquality().hash(recentRoomIds),booker);

@override
String toString() {
  return 'SchoolbookSettings(code: $code, schoolName: $schoolName, lastRoomId: $lastRoomId, recentRoomIds: $recentRoomIds, booker: $booker)';
}


}

/// @nodoc
abstract mixin class $SchoolbookSettingsCopyWith<$Res>  {
  factory $SchoolbookSettingsCopyWith(SchoolbookSettings value, $Res Function(SchoolbookSettings) _then) = _$SchoolbookSettingsCopyWithImpl;
@useResult
$Res call({
 String? code, String? schoolName, int? lastRoomId, List<int> recentRoomIds, String? booker
});




}
/// @nodoc
class _$SchoolbookSettingsCopyWithImpl<$Res>
    implements $SchoolbookSettingsCopyWith<$Res> {
  _$SchoolbookSettingsCopyWithImpl(this._self, this._then);

  final SchoolbookSettings _self;
  final $Res Function(SchoolbookSettings) _then;

/// Create a copy of SchoolbookSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = freezed,Object? schoolName = freezed,Object? lastRoomId = freezed,Object? recentRoomIds = null,Object? booker = freezed,}) {
  return _then(_self.copyWith(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,schoolName: freezed == schoolName ? _self.schoolName : schoolName // ignore: cast_nullable_to_non_nullable
as String?,lastRoomId: freezed == lastRoomId ? _self.lastRoomId : lastRoomId // ignore: cast_nullable_to_non_nullable
as int?,recentRoomIds: null == recentRoomIds ? _self.recentRoomIds : recentRoomIds // ignore: cast_nullable_to_non_nullable
as List<int>,booker: freezed == booker ? _self.booker : booker // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SchoolbookSettings].
extension SchoolbookSettingsPatterns on SchoolbookSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchoolbookSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchoolbookSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchoolbookSettings value)  $default,){
final _that = this;
switch (_that) {
case _SchoolbookSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchoolbookSettings value)?  $default,){
final _that = this;
switch (_that) {
case _SchoolbookSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? code,  String? schoolName,  int? lastRoomId,  List<int> recentRoomIds,  String? booker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchoolbookSettings() when $default != null:
return $default(_that.code,_that.schoolName,_that.lastRoomId,_that.recentRoomIds,_that.booker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? code,  String? schoolName,  int? lastRoomId,  List<int> recentRoomIds,  String? booker)  $default,) {final _that = this;
switch (_that) {
case _SchoolbookSettings():
return $default(_that.code,_that.schoolName,_that.lastRoomId,_that.recentRoomIds,_that.booker);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? code,  String? schoolName,  int? lastRoomId,  List<int> recentRoomIds,  String? booker)?  $default,) {final _that = this;
switch (_that) {
case _SchoolbookSettings() when $default != null:
return $default(_that.code,_that.schoolName,_that.lastRoomId,_that.recentRoomIds,_that.booker);case _:
  return null;

}
}

}

/// @nodoc


class _SchoolbookSettings extends SchoolbookSettings {
  const _SchoolbookSettings({this.code, this.schoolName, this.lastRoomId, final  List<int> recentRoomIds = const <int>[], this.booker}): _recentRoomIds = recentRoomIds,super._();
  

@override final  String? code;
@override final  String? schoolName;
@override final  int? lastRoomId;
/// 최근에 들어간 교실, 앞이 가장 최근(최대 20곳). 교실 칩이 이 순서로 앞에 선다(사용자 결정).
 final  List<int> _recentRoomIds;
/// 최근에 들어간 교실, 앞이 가장 최근(최대 20곳). 교실 칩이 이 순서로 앞에 선다(사용자 결정).
@override@JsonKey() List<int> get recentRoomIds {
  if (_recentRoomIds is EqualUnmodifiableListView) return _recentRoomIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentRoomIds);
}

@override final  String? booker;

/// Create a copy of SchoolbookSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchoolbookSettingsCopyWith<_SchoolbookSettings> get copyWith => __$SchoolbookSettingsCopyWithImpl<_SchoolbookSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchoolbookSettings&&(identical(other.code, code) || other.code == code)&&(identical(other.schoolName, schoolName) || other.schoolName == schoolName)&&(identical(other.lastRoomId, lastRoomId) || other.lastRoomId == lastRoomId)&&const DeepCollectionEquality().equals(other._recentRoomIds, _recentRoomIds)&&(identical(other.booker, booker) || other.booker == booker));
}


@override
int get hashCode => Object.hash(runtimeType,code,schoolName,lastRoomId,const DeepCollectionEquality().hash(_recentRoomIds),booker);

@override
String toString() {
  return 'SchoolbookSettings(code: $code, schoolName: $schoolName, lastRoomId: $lastRoomId, recentRoomIds: $recentRoomIds, booker: $booker)';
}


}

/// @nodoc
abstract mixin class _$SchoolbookSettingsCopyWith<$Res> implements $SchoolbookSettingsCopyWith<$Res> {
  factory _$SchoolbookSettingsCopyWith(_SchoolbookSettings value, $Res Function(_SchoolbookSettings) _then) = __$SchoolbookSettingsCopyWithImpl;
@override @useResult
$Res call({
 String? code, String? schoolName, int? lastRoomId, List<int> recentRoomIds, String? booker
});




}
/// @nodoc
class __$SchoolbookSettingsCopyWithImpl<$Res>
    implements _$SchoolbookSettingsCopyWith<$Res> {
  __$SchoolbookSettingsCopyWithImpl(this._self, this._then);

  final _SchoolbookSettings _self;
  final $Res Function(_SchoolbookSettings) _then;

/// Create a copy of SchoolbookSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = freezed,Object? schoolName = freezed,Object? lastRoomId = freezed,Object? recentRoomIds = null,Object? booker = freezed,}) {
  return _then(_SchoolbookSettings(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,schoolName: freezed == schoolName ? _self.schoolName : schoolName // ignore: cast_nullable_to_non_nullable
as String?,lastRoomId: freezed == lastRoomId ? _self.lastRoomId : lastRoomId // ignore: cast_nullable_to_non_nullable
as int?,recentRoomIds: null == recentRoomIds ? _self._recentRoomIds : recentRoomIds // ignore: cast_nullable_to_non_nullable
as List<int>,booker: freezed == booker ? _self.booker : booker // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
