// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TranscriptSegment {

 int get startMs; int get endMs; String get text;
/// Create a copy of TranscriptSegment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscriptSegmentCopyWith<TranscriptSegment> get copyWith => _$TranscriptSegmentCopyWithImpl<TranscriptSegment>(this as TranscriptSegment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscriptSegment&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,startMs,endMs,text);

@override
String toString() {
  return 'TranscriptSegment(startMs: $startMs, endMs: $endMs, text: $text)';
}


}

/// @nodoc
abstract mixin class $TranscriptSegmentCopyWith<$Res>  {
  factory $TranscriptSegmentCopyWith(TranscriptSegment value, $Res Function(TranscriptSegment) _then) = _$TranscriptSegmentCopyWithImpl;
@useResult
$Res call({
 int startMs, int endMs, String text
});




}
/// @nodoc
class _$TranscriptSegmentCopyWithImpl<$Res>
    implements $TranscriptSegmentCopyWith<$Res> {
  _$TranscriptSegmentCopyWithImpl(this._self, this._then);

  final TranscriptSegment _self;
  final $Res Function(TranscriptSegment) _then;

/// Create a copy of TranscriptSegment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startMs = null,Object? endMs = null,Object? text = null,}) {
  return _then(_self.copyWith(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TranscriptSegment].
extension TranscriptSegmentPatterns on TranscriptSegment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TranscriptSegment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TranscriptSegment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TranscriptSegment value)  $default,){
final _that = this;
switch (_that) {
case _TranscriptSegment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TranscriptSegment value)?  $default,){
final _that = this;
switch (_that) {
case _TranscriptSegment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startMs,  int endMs,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TranscriptSegment() when $default != null:
return $default(_that.startMs,_that.endMs,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startMs,  int endMs,  String text)  $default,) {final _that = this;
switch (_that) {
case _TranscriptSegment():
return $default(_that.startMs,_that.endMs,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startMs,  int endMs,  String text)?  $default,) {final _that = this;
switch (_that) {
case _TranscriptSegment() when $default != null:
return $default(_that.startMs,_that.endMs,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class _TranscriptSegment implements TranscriptSegment {
  const _TranscriptSegment({required this.startMs, required this.endMs, required this.text});
  

@override final  int startMs;
@override final  int endMs;
@override final  String text;

/// Create a copy of TranscriptSegment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TranscriptSegmentCopyWith<_TranscriptSegment> get copyWith => __$TranscriptSegmentCopyWithImpl<_TranscriptSegment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TranscriptSegment&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,startMs,endMs,text);

@override
String toString() {
  return 'TranscriptSegment(startMs: $startMs, endMs: $endMs, text: $text)';
}


}

/// @nodoc
abstract mixin class _$TranscriptSegmentCopyWith<$Res> implements $TranscriptSegmentCopyWith<$Res> {
  factory _$TranscriptSegmentCopyWith(_TranscriptSegment value, $Res Function(_TranscriptSegment) _then) = __$TranscriptSegmentCopyWithImpl;
@override @useResult
$Res call({
 int startMs, int endMs, String text
});




}
/// @nodoc
class __$TranscriptSegmentCopyWithImpl<$Res>
    implements _$TranscriptSegmentCopyWith<$Res> {
  __$TranscriptSegmentCopyWithImpl(this._self, this._then);

  final _TranscriptSegment _self;
  final $Res Function(_TranscriptSegment) _then;

/// Create a copy of TranscriptSegment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startMs = null,Object? endMs = null,Object? text = null,}) {
  return _then(_TranscriptSegment(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
