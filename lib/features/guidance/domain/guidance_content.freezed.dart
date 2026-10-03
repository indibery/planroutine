// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guidance_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GuidanceContent {

 GuidanceKind get kind; GuidanceStatus get status; OccurredPrecision get precision; DateTime? get occurredAt; String? get occurredText; String get title; String? get place; List<Participant> get participants; String? get facts; String? get quotes; String? get actions;
/// Create a copy of GuidanceContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuidanceContentCopyWith<GuidanceContent> get copyWith => _$GuidanceContentCopyWithImpl<GuidanceContent>(this as GuidanceContent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuidanceContent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.status, status) || other.status == status)&&(identical(other.precision, precision) || other.precision == precision)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.occurredText, occurredText) || other.occurredText == occurredText)&&(identical(other.title, title) || other.title == title)&&(identical(other.place, place) || other.place == place)&&const DeepCollectionEquality().equals(other.participants, participants)&&(identical(other.facts, facts) || other.facts == facts)&&(identical(other.quotes, quotes) || other.quotes == quotes)&&(identical(other.actions, actions) || other.actions == actions));
}


@override
int get hashCode => Object.hash(runtimeType,kind,status,precision,occurredAt,occurredText,title,place,const DeepCollectionEquality().hash(participants),facts,quotes,actions);

@override
String toString() {
  return 'GuidanceContent(kind: $kind, status: $status, precision: $precision, occurredAt: $occurredAt, occurredText: $occurredText, title: $title, place: $place, participants: $participants, facts: $facts, quotes: $quotes, actions: $actions)';
}


}

/// @nodoc
abstract mixin class $GuidanceContentCopyWith<$Res>  {
  factory $GuidanceContentCopyWith(GuidanceContent value, $Res Function(GuidanceContent) _then) = _$GuidanceContentCopyWithImpl;
@useResult
$Res call({
 GuidanceKind kind, GuidanceStatus status, OccurredPrecision precision, DateTime? occurredAt, String? occurredText, String title, String? place, List<Participant> participants, String? facts, String? quotes, String? actions
});




}
/// @nodoc
class _$GuidanceContentCopyWithImpl<$Res>
    implements $GuidanceContentCopyWith<$Res> {
  _$GuidanceContentCopyWithImpl(this._self, this._then);

  final GuidanceContent _self;
  final $Res Function(GuidanceContent) _then;

/// Create a copy of GuidanceContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? status = null,Object? precision = null,Object? occurredAt = freezed,Object? occurredText = freezed,Object? title = null,Object? place = freezed,Object? participants = null,Object? facts = freezed,Object? quotes = freezed,Object? actions = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GuidanceKind,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GuidanceStatus,precision: null == precision ? _self.precision : precision // ignore: cast_nullable_to_non_nullable
as OccurredPrecision,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,occurredText: freezed == occurredText ? _self.occurredText : occurredText // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String?,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as List<Participant>,facts: freezed == facts ? _self.facts : facts // ignore: cast_nullable_to_non_nullable
as String?,quotes: freezed == quotes ? _self.quotes : quotes // ignore: cast_nullable_to_non_nullable
as String?,actions: freezed == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuidanceContent].
extension GuidanceContentPatterns on GuidanceContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuidanceContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuidanceContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuidanceContent value)  $default,){
final _that = this;
switch (_that) {
case _GuidanceContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuidanceContent value)?  $default,){
final _that = this;
switch (_that) {
case _GuidanceContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GuidanceKind kind,  GuidanceStatus status,  OccurredPrecision precision,  DateTime? occurredAt,  String? occurredText,  String title,  String? place,  List<Participant> participants,  String? facts,  String? quotes,  String? actions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuidanceContent() when $default != null:
return $default(_that.kind,_that.status,_that.precision,_that.occurredAt,_that.occurredText,_that.title,_that.place,_that.participants,_that.facts,_that.quotes,_that.actions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GuidanceKind kind,  GuidanceStatus status,  OccurredPrecision precision,  DateTime? occurredAt,  String? occurredText,  String title,  String? place,  List<Participant> participants,  String? facts,  String? quotes,  String? actions)  $default,) {final _that = this;
switch (_that) {
case _GuidanceContent():
return $default(_that.kind,_that.status,_that.precision,_that.occurredAt,_that.occurredText,_that.title,_that.place,_that.participants,_that.facts,_that.quotes,_that.actions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GuidanceKind kind,  GuidanceStatus status,  OccurredPrecision precision,  DateTime? occurredAt,  String? occurredText,  String title,  String? place,  List<Participant> participants,  String? facts,  String? quotes,  String? actions)?  $default,) {final _that = this;
switch (_that) {
case _GuidanceContent() when $default != null:
return $default(_that.kind,_that.status,_that.precision,_that.occurredAt,_that.occurredText,_that.title,_that.place,_that.participants,_that.facts,_that.quotes,_that.actions);case _:
  return null;

}
}

}

/// @nodoc


class _GuidanceContent extends GuidanceContent {
  const _GuidanceContent({this.kind = GuidanceKind.guidance, this.status = GuidanceStatus.open, this.precision = OccurredPrecision.exact, this.occurredAt, this.occurredText, this.title = '', this.place, final  List<Participant> participants = const <Participant>[], this.facts, this.quotes, this.actions}): _participants = participants,super._();
  

@override@JsonKey() final  GuidanceKind kind;
@override@JsonKey() final  GuidanceStatus status;
@override@JsonKey() final  OccurredPrecision precision;
@override final  DateTime? occurredAt;
@override final  String? occurredText;
@override@JsonKey() final  String title;
@override final  String? place;
 final  List<Participant> _participants;
@override@JsonKey() List<Participant> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

@override final  String? facts;
@override final  String? quotes;
@override final  String? actions;

/// Create a copy of GuidanceContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuidanceContentCopyWith<_GuidanceContent> get copyWith => __$GuidanceContentCopyWithImpl<_GuidanceContent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuidanceContent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.status, status) || other.status == status)&&(identical(other.precision, precision) || other.precision == precision)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.occurredText, occurredText) || other.occurredText == occurredText)&&(identical(other.title, title) || other.title == title)&&(identical(other.place, place) || other.place == place)&&const DeepCollectionEquality().equals(other._participants, _participants)&&(identical(other.facts, facts) || other.facts == facts)&&(identical(other.quotes, quotes) || other.quotes == quotes)&&(identical(other.actions, actions) || other.actions == actions));
}


@override
int get hashCode => Object.hash(runtimeType,kind,status,precision,occurredAt,occurredText,title,place,const DeepCollectionEquality().hash(_participants),facts,quotes,actions);

@override
String toString() {
  return 'GuidanceContent(kind: $kind, status: $status, precision: $precision, occurredAt: $occurredAt, occurredText: $occurredText, title: $title, place: $place, participants: $participants, facts: $facts, quotes: $quotes, actions: $actions)';
}


}

/// @nodoc
abstract mixin class _$GuidanceContentCopyWith<$Res> implements $GuidanceContentCopyWith<$Res> {
  factory _$GuidanceContentCopyWith(_GuidanceContent value, $Res Function(_GuidanceContent) _then) = __$GuidanceContentCopyWithImpl;
@override @useResult
$Res call({
 GuidanceKind kind, GuidanceStatus status, OccurredPrecision precision, DateTime? occurredAt, String? occurredText, String title, String? place, List<Participant> participants, String? facts, String? quotes, String? actions
});




}
/// @nodoc
class __$GuidanceContentCopyWithImpl<$Res>
    implements _$GuidanceContentCopyWith<$Res> {
  __$GuidanceContentCopyWithImpl(this._self, this._then);

  final _GuidanceContent _self;
  final $Res Function(_GuidanceContent) _then;

/// Create a copy of GuidanceContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? status = null,Object? precision = null,Object? occurredAt = freezed,Object? occurredText = freezed,Object? title = null,Object? place = freezed,Object? participants = null,Object? facts = freezed,Object? quotes = freezed,Object? actions = freezed,}) {
  return _then(_GuidanceContent(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GuidanceKind,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GuidanceStatus,precision: null == precision ? _self.precision : precision // ignore: cast_nullable_to_non_nullable
as OccurredPrecision,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,occurredText: freezed == occurredText ? _self.occurredText : occurredText // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String?,participants: null == participants ? _self._participants : participants // ignore: cast_nullable_to_non_nullable
as List<Participant>,facts: freezed == facts ? _self.facts : facts // ignore: cast_nullable_to_non_nullable
as String?,quotes: freezed == quotes ? _self.quotes : quotes // ignore: cast_nullable_to_non_nullable
as String?,actions: freezed == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
