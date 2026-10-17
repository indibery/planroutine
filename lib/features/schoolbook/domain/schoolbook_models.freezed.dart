// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schoolbook_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchoolInfo {

 String get code; String get name; int get periodCount;
/// Create a copy of SchoolInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchoolInfoCopyWith<SchoolInfo> get copyWith => _$SchoolInfoCopyWithImpl<SchoolInfo>(this as SchoolInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchoolInfo&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.periodCount, periodCount) || other.periodCount == periodCount));
}


@override
int get hashCode => Object.hash(runtimeType,code,name,periodCount);

@override
String toString() {
  return 'SchoolInfo(code: $code, name: $name, periodCount: $periodCount)';
}


}

/// @nodoc
abstract mixin class $SchoolInfoCopyWith<$Res>  {
  factory $SchoolInfoCopyWith(SchoolInfo value, $Res Function(SchoolInfo) _then) = _$SchoolInfoCopyWithImpl;
@useResult
$Res call({
 String code, String name, int periodCount
});




}
/// @nodoc
class _$SchoolInfoCopyWithImpl<$Res>
    implements $SchoolInfoCopyWith<$Res> {
  _$SchoolInfoCopyWithImpl(this._self, this._then);

  final SchoolInfo _self;
  final $Res Function(SchoolInfo) _then;

/// Create a copy of SchoolInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? name = null,Object? periodCount = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,periodCount: null == periodCount ? _self.periodCount : periodCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchoolInfo].
extension SchoolInfoPatterns on SchoolInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchoolInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchoolInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchoolInfo value)  $default,){
final _that = this;
switch (_that) {
case _SchoolInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchoolInfo value)?  $default,){
final _that = this;
switch (_that) {
case _SchoolInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String name,  int periodCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchoolInfo() when $default != null:
return $default(_that.code,_that.name,_that.periodCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String name,  int periodCount)  $default,) {final _that = this;
switch (_that) {
case _SchoolInfo():
return $default(_that.code,_that.name,_that.periodCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String name,  int periodCount)?  $default,) {final _that = this;
switch (_that) {
case _SchoolInfo() when $default != null:
return $default(_that.code,_that.name,_that.periodCount);case _:
  return null;

}
}

}

/// @nodoc


class _SchoolInfo implements SchoolInfo {
  const _SchoolInfo({required this.code, required this.name, required this.periodCount});
  

@override final  String code;
@override final  String name;
@override final  int periodCount;

/// Create a copy of SchoolInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchoolInfoCopyWith<_SchoolInfo> get copyWith => __$SchoolInfoCopyWithImpl<_SchoolInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchoolInfo&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.periodCount, periodCount) || other.periodCount == periodCount));
}


@override
int get hashCode => Object.hash(runtimeType,code,name,periodCount);

@override
String toString() {
  return 'SchoolInfo(code: $code, name: $name, periodCount: $periodCount)';
}


}

/// @nodoc
abstract mixin class _$SchoolInfoCopyWith<$Res> implements $SchoolInfoCopyWith<$Res> {
  factory _$SchoolInfoCopyWith(_SchoolInfo value, $Res Function(_SchoolInfo) _then) = __$SchoolInfoCopyWithImpl;
@override @useResult
$Res call({
 String code, String name, int periodCount
});




}
/// @nodoc
class __$SchoolInfoCopyWithImpl<$Res>
    implements _$SchoolInfoCopyWith<$Res> {
  __$SchoolInfoCopyWithImpl(this._self, this._then);

  final _SchoolInfo _self;
  final $Res Function(_SchoolInfo) _then;

/// Create a copy of SchoolInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? name = null,Object? periodCount = null,}) {
  return _then(_SchoolInfo(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,periodCount: null == periodCount ? _self.periodCount : periodCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SchoolbookRoom {

 int get id; String get name; int get capacity;
/// Create a copy of SchoolbookRoom
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchoolbookRoomCopyWith<SchoolbookRoom> get copyWith => _$SchoolbookRoomCopyWithImpl<SchoolbookRoom>(this as SchoolbookRoom, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchoolbookRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,capacity);

@override
String toString() {
  return 'SchoolbookRoom(id: $id, name: $name, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class $SchoolbookRoomCopyWith<$Res>  {
  factory $SchoolbookRoomCopyWith(SchoolbookRoom value, $Res Function(SchoolbookRoom) _then) = _$SchoolbookRoomCopyWithImpl;
@useResult
$Res call({
 int id, String name, int capacity
});




}
/// @nodoc
class _$SchoolbookRoomCopyWithImpl<$Res>
    implements $SchoolbookRoomCopyWith<$Res> {
  _$SchoolbookRoomCopyWithImpl(this._self, this._then);

  final SchoolbookRoom _self;
  final $Res Function(SchoolbookRoom) _then;

/// Create a copy of SchoolbookRoom
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? capacity = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchoolbookRoom].
extension SchoolbookRoomPatterns on SchoolbookRoom {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchoolbookRoom value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchoolbookRoom() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchoolbookRoom value)  $default,){
final _that = this;
switch (_that) {
case _SchoolbookRoom():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchoolbookRoom value)?  $default,){
final _that = this;
switch (_that) {
case _SchoolbookRoom() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int capacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchoolbookRoom() when $default != null:
return $default(_that.id,_that.name,_that.capacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int capacity)  $default,) {final _that = this;
switch (_that) {
case _SchoolbookRoom():
return $default(_that.id,_that.name,_that.capacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int capacity)?  $default,) {final _that = this;
switch (_that) {
case _SchoolbookRoom() when $default != null:
return $default(_that.id,_that.name,_that.capacity);case _:
  return null;

}
}

}

/// @nodoc


class _SchoolbookRoom implements SchoolbookRoom {
  const _SchoolbookRoom({required this.id, required this.name, required this.capacity});
  

@override final  int id;
@override final  String name;
@override final  int capacity;

/// Create a copy of SchoolbookRoom
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchoolbookRoomCopyWith<_SchoolbookRoom> get copyWith => __$SchoolbookRoomCopyWithImpl<_SchoolbookRoom>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchoolbookRoom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.capacity, capacity) || other.capacity == capacity));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,capacity);

@override
String toString() {
  return 'SchoolbookRoom(id: $id, name: $name, capacity: $capacity)';
}


}

/// @nodoc
abstract mixin class _$SchoolbookRoomCopyWith<$Res> implements $SchoolbookRoomCopyWith<$Res> {
  factory _$SchoolbookRoomCopyWith(_SchoolbookRoom value, $Res Function(_SchoolbookRoom) _then) = __$SchoolbookRoomCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int capacity
});




}
/// @nodoc
class __$SchoolbookRoomCopyWithImpl<$Res>
    implements _$SchoolbookRoomCopyWith<$Res> {
  __$SchoolbookRoomCopyWithImpl(this._self, this._then);

  final _SchoolbookRoom _self;
  final $Res Function(_SchoolbookRoom) _then;

/// Create a copy of SchoolbookRoom
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? capacity = null,}) {
  return _then(_SchoolbookRoom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SlotBooking {

 int get id; String get booker; bool get canceled;
/// Create a copy of SlotBooking
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlotBookingCopyWith<SlotBooking> get copyWith => _$SlotBookingCopyWithImpl<SlotBooking>(this as SlotBooking, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlotBooking&&(identical(other.id, id) || other.id == id)&&(identical(other.booker, booker) || other.booker == booker)&&(identical(other.canceled, canceled) || other.canceled == canceled));
}


@override
int get hashCode => Object.hash(runtimeType,id,booker,canceled);

@override
String toString() {
  return 'SlotBooking(id: $id, booker: $booker, canceled: $canceled)';
}


}

/// @nodoc
abstract mixin class $SlotBookingCopyWith<$Res>  {
  factory $SlotBookingCopyWith(SlotBooking value, $Res Function(SlotBooking) _then) = _$SlotBookingCopyWithImpl;
@useResult
$Res call({
 int id, String booker, bool canceled
});




}
/// @nodoc
class _$SlotBookingCopyWithImpl<$Res>
    implements $SlotBookingCopyWith<$Res> {
  _$SlotBookingCopyWithImpl(this._self, this._then);

  final SlotBooking _self;
  final $Res Function(SlotBooking) _then;

/// Create a copy of SlotBooking
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? booker = null,Object? canceled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,booker: null == booker ? _self.booker : booker // ignore: cast_nullable_to_non_nullable
as String,canceled: null == canceled ? _self.canceled : canceled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SlotBooking].
extension SlotBookingPatterns on SlotBooking {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlotBooking value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlotBooking() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlotBooking value)  $default,){
final _that = this;
switch (_that) {
case _SlotBooking():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlotBooking value)?  $default,){
final _that = this;
switch (_that) {
case _SlotBooking() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String booker,  bool canceled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlotBooking() when $default != null:
return $default(_that.id,_that.booker,_that.canceled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String booker,  bool canceled)  $default,) {final _that = this;
switch (_that) {
case _SlotBooking():
return $default(_that.id,_that.booker,_that.canceled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String booker,  bool canceled)?  $default,) {final _that = this;
switch (_that) {
case _SlotBooking() when $default != null:
return $default(_that.id,_that.booker,_that.canceled);case _:
  return null;

}
}

}

/// @nodoc


class _SlotBooking implements SlotBooking {
  const _SlotBooking({required this.id, required this.booker, required this.canceled});
  

@override final  int id;
@override final  String booker;
@override final  bool canceled;

/// Create a copy of SlotBooking
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlotBookingCopyWith<_SlotBooking> get copyWith => __$SlotBookingCopyWithImpl<_SlotBooking>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlotBooking&&(identical(other.id, id) || other.id == id)&&(identical(other.booker, booker) || other.booker == booker)&&(identical(other.canceled, canceled) || other.canceled == canceled));
}


@override
int get hashCode => Object.hash(runtimeType,id,booker,canceled);

@override
String toString() {
  return 'SlotBooking(id: $id, booker: $booker, canceled: $canceled)';
}


}

/// @nodoc
abstract mixin class _$SlotBookingCopyWith<$Res> implements $SlotBookingCopyWith<$Res> {
  factory _$SlotBookingCopyWith(_SlotBooking value, $Res Function(_SlotBooking) _then) = __$SlotBookingCopyWithImpl;
@override @useResult
$Res call({
 int id, String booker, bool canceled
});




}
/// @nodoc
class __$SlotBookingCopyWithImpl<$Res>
    implements _$SlotBookingCopyWith<$Res> {
  __$SlotBookingCopyWithImpl(this._self, this._then);

  final _SlotBooking _self;
  final $Res Function(_SlotBooking) _then;

/// Create a copy of SlotBooking
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? booker = null,Object? canceled = null,}) {
  return _then(_SlotBooking(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,booker: null == booker ? _self.booker : booker // ignore: cast_nullable_to_non_nullable
as String,canceled: null == canceled ? _self.canceled : canceled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$PeriodSlot {

 int get id; String get name; String? get startTime; String? get endTime; bool get archived; int get remaining; List<String> get fixed; List<SlotBooking> get bookings;
/// Create a copy of PeriodSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PeriodSlotCopyWith<PeriodSlot> get copyWith => _$PeriodSlotCopyWithImpl<PeriodSlot>(this as PeriodSlot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PeriodSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&const DeepCollectionEquality().equals(other.fixed, fixed)&&const DeepCollectionEquality().equals(other.bookings, bookings));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,startTime,endTime,archived,remaining,const DeepCollectionEquality().hash(fixed),const DeepCollectionEquality().hash(bookings));

@override
String toString() {
  return 'PeriodSlot(id: $id, name: $name, startTime: $startTime, endTime: $endTime, archived: $archived, remaining: $remaining, fixed: $fixed, bookings: $bookings)';
}


}

/// @nodoc
abstract mixin class $PeriodSlotCopyWith<$Res>  {
  factory $PeriodSlotCopyWith(PeriodSlot value, $Res Function(PeriodSlot) _then) = _$PeriodSlotCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? startTime, String? endTime, bool archived, int remaining, List<String> fixed, List<SlotBooking> bookings
});




}
/// @nodoc
class _$PeriodSlotCopyWithImpl<$Res>
    implements $PeriodSlotCopyWith<$Res> {
  _$PeriodSlotCopyWithImpl(this._self, this._then);

  final PeriodSlot _self;
  final $Res Function(PeriodSlot) _then;

/// Create a copy of PeriodSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? startTime = freezed,Object? endTime = freezed,Object? archived = null,Object? remaining = null,Object? fixed = null,Object? bookings = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,fixed: null == fixed ? _self.fixed : fixed // ignore: cast_nullable_to_non_nullable
as List<String>,bookings: null == bookings ? _self.bookings : bookings // ignore: cast_nullable_to_non_nullable
as List<SlotBooking>,
  ));
}

}


/// Adds pattern-matching-related methods to [PeriodSlot].
extension PeriodSlotPatterns on PeriodSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PeriodSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PeriodSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PeriodSlot value)  $default,){
final _that = this;
switch (_that) {
case _PeriodSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PeriodSlot value)?  $default,){
final _that = this;
switch (_that) {
case _PeriodSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? startTime,  String? endTime,  bool archived,  int remaining,  List<String> fixed,  List<SlotBooking> bookings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PeriodSlot() when $default != null:
return $default(_that.id,_that.name,_that.startTime,_that.endTime,_that.archived,_that.remaining,_that.fixed,_that.bookings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? startTime,  String? endTime,  bool archived,  int remaining,  List<String> fixed,  List<SlotBooking> bookings)  $default,) {final _that = this;
switch (_that) {
case _PeriodSlot():
return $default(_that.id,_that.name,_that.startTime,_that.endTime,_that.archived,_that.remaining,_that.fixed,_that.bookings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? startTime,  String? endTime,  bool archived,  int remaining,  List<String> fixed,  List<SlotBooking> bookings)?  $default,) {final _that = this;
switch (_that) {
case _PeriodSlot() when $default != null:
return $default(_that.id,_that.name,_that.startTime,_that.endTime,_that.archived,_that.remaining,_that.fixed,_that.bookings);case _:
  return null;

}
}

}

/// @nodoc


class _PeriodSlot implements PeriodSlot {
  const _PeriodSlot({required this.id, required this.name, this.startTime, this.endTime, required this.archived, required this.remaining, required final  List<String> fixed, required final  List<SlotBooking> bookings}): _fixed = fixed,_bookings = bookings;
  

@override final  int id;
@override final  String name;
@override final  String? startTime;
@override final  String? endTime;
@override final  bool archived;
@override final  int remaining;
 final  List<String> _fixed;
@override List<String> get fixed {
  if (_fixed is EqualUnmodifiableListView) return _fixed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fixed);
}

 final  List<SlotBooking> _bookings;
@override List<SlotBooking> get bookings {
  if (_bookings is EqualUnmodifiableListView) return _bookings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bookings);
}


/// Create a copy of PeriodSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PeriodSlotCopyWith<_PeriodSlot> get copyWith => __$PeriodSlotCopyWithImpl<_PeriodSlot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PeriodSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&const DeepCollectionEquality().equals(other._fixed, _fixed)&&const DeepCollectionEquality().equals(other._bookings, _bookings));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,startTime,endTime,archived,remaining,const DeepCollectionEquality().hash(_fixed),const DeepCollectionEquality().hash(_bookings));

@override
String toString() {
  return 'PeriodSlot(id: $id, name: $name, startTime: $startTime, endTime: $endTime, archived: $archived, remaining: $remaining, fixed: $fixed, bookings: $bookings)';
}


}

/// @nodoc
abstract mixin class _$PeriodSlotCopyWith<$Res> implements $PeriodSlotCopyWith<$Res> {
  factory _$PeriodSlotCopyWith(_PeriodSlot value, $Res Function(_PeriodSlot) _then) = __$PeriodSlotCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? startTime, String? endTime, bool archived, int remaining, List<String> fixed, List<SlotBooking> bookings
});




}
/// @nodoc
class __$PeriodSlotCopyWithImpl<$Res>
    implements _$PeriodSlotCopyWith<$Res> {
  __$PeriodSlotCopyWithImpl(this._self, this._then);

  final _PeriodSlot _self;
  final $Res Function(_PeriodSlot) _then;

/// Create a copy of PeriodSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? startTime = freezed,Object? endTime = freezed,Object? archived = null,Object? remaining = null,Object? fixed = null,Object? bookings = null,}) {
  return _then(_PeriodSlot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,fixed: null == fixed ? _self._fixed : fixed // ignore: cast_nullable_to_non_nullable
as List<String>,bookings: null == bookings ? _self._bookings : bookings // ignore: cast_nullable_to_non_nullable
as List<SlotBooking>,
  ));
}


}

/// @nodoc
mixin _$RoomDay {

 DateTime get date; List<PeriodSlot> get periods;
/// Create a copy of RoomDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomDayCopyWith<RoomDay> get copyWith => _$RoomDayCopyWithImpl<RoomDay>(this as RoomDay, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomDay&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.periods, periods));
}


@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(periods));

@override
String toString() {
  return 'RoomDay(date: $date, periods: $periods)';
}


}

/// @nodoc
abstract mixin class $RoomDayCopyWith<$Res>  {
  factory $RoomDayCopyWith(RoomDay value, $Res Function(RoomDay) _then) = _$RoomDayCopyWithImpl;
@useResult
$Res call({
 DateTime date, List<PeriodSlot> periods
});




}
/// @nodoc
class _$RoomDayCopyWithImpl<$Res>
    implements $RoomDayCopyWith<$Res> {
  _$RoomDayCopyWithImpl(this._self, this._then);

  final RoomDay _self;
  final $Res Function(RoomDay) _then;

/// Create a copy of RoomDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? periods = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,periods: null == periods ? _self.periods : periods // ignore: cast_nullable_to_non_nullable
as List<PeriodSlot>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomDay].
extension RoomDayPatterns on RoomDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomDay value)  $default,){
final _that = this;
switch (_that) {
case _RoomDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomDay value)?  $default,){
final _that = this;
switch (_that) {
case _RoomDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime date,  List<PeriodSlot> periods)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomDay() when $default != null:
return $default(_that.date,_that.periods);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime date,  List<PeriodSlot> periods)  $default,) {final _that = this;
switch (_that) {
case _RoomDay():
return $default(_that.date,_that.periods);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime date,  List<PeriodSlot> periods)?  $default,) {final _that = this;
switch (_that) {
case _RoomDay() when $default != null:
return $default(_that.date,_that.periods);case _:
  return null;

}
}

}

/// @nodoc


class _RoomDay implements RoomDay {
  const _RoomDay({required this.date, required final  List<PeriodSlot> periods}): _periods = periods;
  

@override final  DateTime date;
 final  List<PeriodSlot> _periods;
@override List<PeriodSlot> get periods {
  if (_periods is EqualUnmodifiableListView) return _periods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_periods);
}


/// Create a copy of RoomDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomDayCopyWith<_RoomDay> get copyWith => __$RoomDayCopyWithImpl<_RoomDay>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomDay&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._periods, _periods));
}


@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(_periods));

@override
String toString() {
  return 'RoomDay(date: $date, periods: $periods)';
}


}

/// @nodoc
abstract mixin class _$RoomDayCopyWith<$Res> implements $RoomDayCopyWith<$Res> {
  factory _$RoomDayCopyWith(_RoomDay value, $Res Function(_RoomDay) _then) = __$RoomDayCopyWithImpl;
@override @useResult
$Res call({
 DateTime date, List<PeriodSlot> periods
});




}
/// @nodoc
class __$RoomDayCopyWithImpl<$Res>
    implements _$RoomDayCopyWith<$Res> {
  __$RoomDayCopyWithImpl(this._self, this._then);

  final _RoomDay _self;
  final $Res Function(_RoomDay) _then;

/// Create a copy of RoomDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? periods = null,}) {
  return _then(_RoomDay(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,periods: null == periods ? _self._periods : periods // ignore: cast_nullable_to_non_nullable
as List<PeriodSlot>,
  ));
}


}

// dart format on
