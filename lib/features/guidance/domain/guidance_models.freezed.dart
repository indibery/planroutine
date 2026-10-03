// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guidance_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GuidanceRevision {

 int? get id; int get recordId; int get revisionNo; String get savedAt; GuidanceContent get content;
/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuidanceRevisionCopyWith<GuidanceRevision> get copyWith => _$GuidanceRevisionCopyWithImpl<GuidanceRevision>(this as GuidanceRevision, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuidanceRevision&&(identical(other.id, id) || other.id == id)&&(identical(other.recordId, recordId) || other.recordId == recordId)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&(identical(other.savedAt, savedAt) || other.savedAt == savedAt)&&(identical(other.content, content) || other.content == content));
}


@override
int get hashCode => Object.hash(runtimeType,id,recordId,revisionNo,savedAt,content);

@override
String toString() {
  return 'GuidanceRevision(id: $id, recordId: $recordId, revisionNo: $revisionNo, savedAt: $savedAt, content: $content)';
}


}

/// @nodoc
abstract mixin class $GuidanceRevisionCopyWith<$Res>  {
  factory $GuidanceRevisionCopyWith(GuidanceRevision value, $Res Function(GuidanceRevision) _then) = _$GuidanceRevisionCopyWithImpl;
@useResult
$Res call({
 int? id, int recordId, int revisionNo, String savedAt, GuidanceContent content
});


$GuidanceContentCopyWith<$Res> get content;

}
/// @nodoc
class _$GuidanceRevisionCopyWithImpl<$Res>
    implements $GuidanceRevisionCopyWith<$Res> {
  _$GuidanceRevisionCopyWithImpl(this._self, this._then);

  final GuidanceRevision _self;
  final $Res Function(GuidanceRevision) _then;

/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? recordId = null,Object? revisionNo = null,Object? savedAt = null,Object? content = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,recordId: null == recordId ? _self.recordId : recordId // ignore: cast_nullable_to_non_nullable
as int,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,savedAt: null == savedAt ? _self.savedAt : savedAt // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as GuidanceContent,
  ));
}
/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuidanceContentCopyWith<$Res> get content {
  
  return $GuidanceContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}


/// Adds pattern-matching-related methods to [GuidanceRevision].
extension GuidanceRevisionPatterns on GuidanceRevision {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuidanceRevision value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuidanceRevision() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuidanceRevision value)  $default,){
final _that = this;
switch (_that) {
case _GuidanceRevision():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuidanceRevision value)?  $default,){
final _that = this;
switch (_that) {
case _GuidanceRevision() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int recordId,  int revisionNo,  String savedAt,  GuidanceContent content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuidanceRevision() when $default != null:
return $default(_that.id,_that.recordId,_that.revisionNo,_that.savedAt,_that.content);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int recordId,  int revisionNo,  String savedAt,  GuidanceContent content)  $default,) {final _that = this;
switch (_that) {
case _GuidanceRevision():
return $default(_that.id,_that.recordId,_that.revisionNo,_that.savedAt,_that.content);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int recordId,  int revisionNo,  String savedAt,  GuidanceContent content)?  $default,) {final _that = this;
switch (_that) {
case _GuidanceRevision() when $default != null:
return $default(_that.id,_that.recordId,_that.revisionNo,_that.savedAt,_that.content);case _:
  return null;

}
}

}

/// @nodoc


class _GuidanceRevision extends GuidanceRevision {
  const _GuidanceRevision({this.id, required this.recordId, required this.revisionNo, required this.savedAt, required this.content}): super._();
  

@override final  int? id;
@override final  int recordId;
@override final  int revisionNo;
@override final  String savedAt;
@override final  GuidanceContent content;

/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuidanceRevisionCopyWith<_GuidanceRevision> get copyWith => __$GuidanceRevisionCopyWithImpl<_GuidanceRevision>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuidanceRevision&&(identical(other.id, id) || other.id == id)&&(identical(other.recordId, recordId) || other.recordId == recordId)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&(identical(other.savedAt, savedAt) || other.savedAt == savedAt)&&(identical(other.content, content) || other.content == content));
}


@override
int get hashCode => Object.hash(runtimeType,id,recordId,revisionNo,savedAt,content);

@override
String toString() {
  return 'GuidanceRevision(id: $id, recordId: $recordId, revisionNo: $revisionNo, savedAt: $savedAt, content: $content)';
}


}

/// @nodoc
abstract mixin class _$GuidanceRevisionCopyWith<$Res> implements $GuidanceRevisionCopyWith<$Res> {
  factory _$GuidanceRevisionCopyWith(_GuidanceRevision value, $Res Function(_GuidanceRevision) _then) = __$GuidanceRevisionCopyWithImpl;
@override @useResult
$Res call({
 int? id, int recordId, int revisionNo, String savedAt, GuidanceContent content
});


@override $GuidanceContentCopyWith<$Res> get content;

}
/// @nodoc
class __$GuidanceRevisionCopyWithImpl<$Res>
    implements _$GuidanceRevisionCopyWith<$Res> {
  __$GuidanceRevisionCopyWithImpl(this._self, this._then);

  final _GuidanceRevision _self;
  final $Res Function(_GuidanceRevision) _then;

/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? recordId = null,Object? revisionNo = null,Object? savedAt = null,Object? content = null,}) {
  return _then(_GuidanceRevision(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,recordId: null == recordId ? _self.recordId : recordId // ignore: cast_nullable_to_non_nullable
as int,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,savedAt: null == savedAt ? _self.savedAt : savedAt // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as GuidanceContent,
  ));
}

/// Create a copy of GuidanceRevision
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuidanceContentCopyWith<$Res> get content {
  
  return $GuidanceContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}

/// @nodoc
mixin _$GuidanceRecord {

 int get id; String get createdAt; String? get deletedAt; GuidanceRevision get latest; int get revisionCount; int get attachmentCount;
/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuidanceRecordCopyWith<GuidanceRecord> get copyWith => _$GuidanceRecordCopyWithImpl<GuidanceRecord>(this as GuidanceRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuidanceRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.latest, latest) || other.latest == latest)&&(identical(other.revisionCount, revisionCount) || other.revisionCount == revisionCount)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,createdAt,deletedAt,latest,revisionCount,attachmentCount);

@override
String toString() {
  return 'GuidanceRecord(id: $id, createdAt: $createdAt, deletedAt: $deletedAt, latest: $latest, revisionCount: $revisionCount, attachmentCount: $attachmentCount)';
}


}

/// @nodoc
abstract mixin class $GuidanceRecordCopyWith<$Res>  {
  factory $GuidanceRecordCopyWith(GuidanceRecord value, $Res Function(GuidanceRecord) _then) = _$GuidanceRecordCopyWithImpl;
@useResult
$Res call({
 int id, String createdAt, String? deletedAt, GuidanceRevision latest, int revisionCount, int attachmentCount
});


$GuidanceRevisionCopyWith<$Res> get latest;

}
/// @nodoc
class _$GuidanceRecordCopyWithImpl<$Res>
    implements $GuidanceRecordCopyWith<$Res> {
  _$GuidanceRecordCopyWithImpl(this._self, this._then);

  final GuidanceRecord _self;
  final $Res Function(GuidanceRecord) _then;

/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? deletedAt = freezed,Object? latest = null,Object? revisionCount = null,Object? attachmentCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,latest: null == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as GuidanceRevision,revisionCount: null == revisionCount ? _self.revisionCount : revisionCount // ignore: cast_nullable_to_non_nullable
as int,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuidanceRevisionCopyWith<$Res> get latest {
  
  return $GuidanceRevisionCopyWith<$Res>(_self.latest, (value) {
    return _then(_self.copyWith(latest: value));
  });
}
}


/// Adds pattern-matching-related methods to [GuidanceRecord].
extension GuidanceRecordPatterns on GuidanceRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuidanceRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuidanceRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuidanceRecord value)  $default,){
final _that = this;
switch (_that) {
case _GuidanceRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuidanceRecord value)?  $default,){
final _that = this;
switch (_that) {
case _GuidanceRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String createdAt,  String? deletedAt,  GuidanceRevision latest,  int revisionCount,  int attachmentCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuidanceRecord() when $default != null:
return $default(_that.id,_that.createdAt,_that.deletedAt,_that.latest,_that.revisionCount,_that.attachmentCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String createdAt,  String? deletedAt,  GuidanceRevision latest,  int revisionCount,  int attachmentCount)  $default,) {final _that = this;
switch (_that) {
case _GuidanceRecord():
return $default(_that.id,_that.createdAt,_that.deletedAt,_that.latest,_that.revisionCount,_that.attachmentCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String createdAt,  String? deletedAt,  GuidanceRevision latest,  int revisionCount,  int attachmentCount)?  $default,) {final _that = this;
switch (_that) {
case _GuidanceRecord() when $default != null:
return $default(_that.id,_that.createdAt,_that.deletedAt,_that.latest,_that.revisionCount,_that.attachmentCount);case _:
  return null;

}
}

}

/// @nodoc


class _GuidanceRecord extends GuidanceRecord {
  const _GuidanceRecord({required this.id, required this.createdAt, this.deletedAt, required this.latest, this.revisionCount = 1, this.attachmentCount = 0}): super._();
  

@override final  int id;
@override final  String createdAt;
@override final  String? deletedAt;
@override final  GuidanceRevision latest;
@override@JsonKey() final  int revisionCount;
@override@JsonKey() final  int attachmentCount;

/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuidanceRecordCopyWith<_GuidanceRecord> get copyWith => __$GuidanceRecordCopyWithImpl<_GuidanceRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuidanceRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.latest, latest) || other.latest == latest)&&(identical(other.revisionCount, revisionCount) || other.revisionCount == revisionCount)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,createdAt,deletedAt,latest,revisionCount,attachmentCount);

@override
String toString() {
  return 'GuidanceRecord(id: $id, createdAt: $createdAt, deletedAt: $deletedAt, latest: $latest, revisionCount: $revisionCount, attachmentCount: $attachmentCount)';
}


}

/// @nodoc
abstract mixin class _$GuidanceRecordCopyWith<$Res> implements $GuidanceRecordCopyWith<$Res> {
  factory _$GuidanceRecordCopyWith(_GuidanceRecord value, $Res Function(_GuidanceRecord) _then) = __$GuidanceRecordCopyWithImpl;
@override @useResult
$Res call({
 int id, String createdAt, String? deletedAt, GuidanceRevision latest, int revisionCount, int attachmentCount
});


@override $GuidanceRevisionCopyWith<$Res> get latest;

}
/// @nodoc
class __$GuidanceRecordCopyWithImpl<$Res>
    implements _$GuidanceRecordCopyWith<$Res> {
  __$GuidanceRecordCopyWithImpl(this._self, this._then);

  final _GuidanceRecord _self;
  final $Res Function(_GuidanceRecord) _then;

/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? deletedAt = freezed,Object? latest = null,Object? revisionCount = null,Object? attachmentCount = null,}) {
  return _then(_GuidanceRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as String?,latest: null == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as GuidanceRevision,revisionCount: null == revisionCount ? _self.revisionCount : revisionCount // ignore: cast_nullable_to_non_nullable
as int,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of GuidanceRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GuidanceRevisionCopyWith<$Res> get latest {
  
  return $GuidanceRevisionCopyWith<$Res>(_self.latest, (value) {
    return _then(_self.copyWith(latest: value));
  });
}
}

/// @nodoc
mixin _$GuidanceAttachment {

 int? get id; int get recordId; AttachmentType get type; AttachmentSource get source; String get fileName; String? get originalName; String get sha256; int get byteSize; int? get durationMs; String? get capturedAt; String get attachedAt; String? get removedAt;
/// Create a copy of GuidanceAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuidanceAttachmentCopyWith<GuidanceAttachment> get copyWith => _$GuidanceAttachmentCopyWithImpl<GuidanceAttachment>(this as GuidanceAttachment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuidanceAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.recordId, recordId) || other.recordId == recordId)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.originalName, originalName) || other.originalName == originalName)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.byteSize, byteSize) || other.byteSize == byteSize)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.attachedAt, attachedAt) || other.attachedAt == attachedAt)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,recordId,type,source,fileName,originalName,sha256,byteSize,durationMs,capturedAt,attachedAt,removedAt);

@override
String toString() {
  return 'GuidanceAttachment(id: $id, recordId: $recordId, type: $type, source: $source, fileName: $fileName, originalName: $originalName, sha256: $sha256, byteSize: $byteSize, durationMs: $durationMs, capturedAt: $capturedAt, attachedAt: $attachedAt, removedAt: $removedAt)';
}


}

/// @nodoc
abstract mixin class $GuidanceAttachmentCopyWith<$Res>  {
  factory $GuidanceAttachmentCopyWith(GuidanceAttachment value, $Res Function(GuidanceAttachment) _then) = _$GuidanceAttachmentCopyWithImpl;
@useResult
$Res call({
 int? id, int recordId, AttachmentType type, AttachmentSource source, String fileName, String? originalName, String sha256, int byteSize, int? durationMs, String? capturedAt, String attachedAt, String? removedAt
});




}
/// @nodoc
class _$GuidanceAttachmentCopyWithImpl<$Res>
    implements $GuidanceAttachmentCopyWith<$Res> {
  _$GuidanceAttachmentCopyWithImpl(this._self, this._then);

  final GuidanceAttachment _self;
  final $Res Function(GuidanceAttachment) _then;

/// Create a copy of GuidanceAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? recordId = null,Object? type = null,Object? source = null,Object? fileName = null,Object? originalName = freezed,Object? sha256 = null,Object? byteSize = null,Object? durationMs = freezed,Object? capturedAt = freezed,Object? attachedAt = null,Object? removedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,recordId: null == recordId ? _self.recordId : recordId // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AttachmentType,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as AttachmentSource,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,originalName: freezed == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String?,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,capturedAt: freezed == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as String?,attachedAt: null == attachedAt ? _self.attachedAt : attachedAt // ignore: cast_nullable_to_non_nullable
as String,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuidanceAttachment].
extension GuidanceAttachmentPatterns on GuidanceAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuidanceAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuidanceAttachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuidanceAttachment value)  $default,){
final _that = this;
switch (_that) {
case _GuidanceAttachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuidanceAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _GuidanceAttachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int recordId,  AttachmentType type,  AttachmentSource source,  String fileName,  String? originalName,  String sha256,  int byteSize,  int? durationMs,  String? capturedAt,  String attachedAt,  String? removedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuidanceAttachment() when $default != null:
return $default(_that.id,_that.recordId,_that.type,_that.source,_that.fileName,_that.originalName,_that.sha256,_that.byteSize,_that.durationMs,_that.capturedAt,_that.attachedAt,_that.removedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int recordId,  AttachmentType type,  AttachmentSource source,  String fileName,  String? originalName,  String sha256,  int byteSize,  int? durationMs,  String? capturedAt,  String attachedAt,  String? removedAt)  $default,) {final _that = this;
switch (_that) {
case _GuidanceAttachment():
return $default(_that.id,_that.recordId,_that.type,_that.source,_that.fileName,_that.originalName,_that.sha256,_that.byteSize,_that.durationMs,_that.capturedAt,_that.attachedAt,_that.removedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int recordId,  AttachmentType type,  AttachmentSource source,  String fileName,  String? originalName,  String sha256,  int byteSize,  int? durationMs,  String? capturedAt,  String attachedAt,  String? removedAt)?  $default,) {final _that = this;
switch (_that) {
case _GuidanceAttachment() when $default != null:
return $default(_that.id,_that.recordId,_that.type,_that.source,_that.fileName,_that.originalName,_that.sha256,_that.byteSize,_that.durationMs,_that.capturedAt,_that.attachedAt,_that.removedAt);case _:
  return null;

}
}

}

/// @nodoc


class _GuidanceAttachment extends GuidanceAttachment {
  const _GuidanceAttachment({this.id, required this.recordId, required this.type, required this.source, required this.fileName, this.originalName, required this.sha256, required this.byteSize, this.durationMs, this.capturedAt, required this.attachedAt, this.removedAt}): super._();
  

@override final  int? id;
@override final  int recordId;
@override final  AttachmentType type;
@override final  AttachmentSource source;
@override final  String fileName;
@override final  String? originalName;
@override final  String sha256;
@override final  int byteSize;
@override final  int? durationMs;
@override final  String? capturedAt;
@override final  String attachedAt;
@override final  String? removedAt;

/// Create a copy of GuidanceAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuidanceAttachmentCopyWith<_GuidanceAttachment> get copyWith => __$GuidanceAttachmentCopyWithImpl<_GuidanceAttachment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuidanceAttachment&&(identical(other.id, id) || other.id == id)&&(identical(other.recordId, recordId) || other.recordId == recordId)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.originalName, originalName) || other.originalName == originalName)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.byteSize, byteSize) || other.byteSize == byteSize)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.attachedAt, attachedAt) || other.attachedAt == attachedAt)&&(identical(other.removedAt, removedAt) || other.removedAt == removedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,recordId,type,source,fileName,originalName,sha256,byteSize,durationMs,capturedAt,attachedAt,removedAt);

@override
String toString() {
  return 'GuidanceAttachment(id: $id, recordId: $recordId, type: $type, source: $source, fileName: $fileName, originalName: $originalName, sha256: $sha256, byteSize: $byteSize, durationMs: $durationMs, capturedAt: $capturedAt, attachedAt: $attachedAt, removedAt: $removedAt)';
}


}

/// @nodoc
abstract mixin class _$GuidanceAttachmentCopyWith<$Res> implements $GuidanceAttachmentCopyWith<$Res> {
  factory _$GuidanceAttachmentCopyWith(_GuidanceAttachment value, $Res Function(_GuidanceAttachment) _then) = __$GuidanceAttachmentCopyWithImpl;
@override @useResult
$Res call({
 int? id, int recordId, AttachmentType type, AttachmentSource source, String fileName, String? originalName, String sha256, int byteSize, int? durationMs, String? capturedAt, String attachedAt, String? removedAt
});




}
/// @nodoc
class __$GuidanceAttachmentCopyWithImpl<$Res>
    implements _$GuidanceAttachmentCopyWith<$Res> {
  __$GuidanceAttachmentCopyWithImpl(this._self, this._then);

  final _GuidanceAttachment _self;
  final $Res Function(_GuidanceAttachment) _then;

/// Create a copy of GuidanceAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? recordId = null,Object? type = null,Object? source = null,Object? fileName = null,Object? originalName = freezed,Object? sha256 = null,Object? byteSize = null,Object? durationMs = freezed,Object? capturedAt = freezed,Object? attachedAt = null,Object? removedAt = freezed,}) {
  return _then(_GuidanceAttachment(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,recordId: null == recordId ? _self.recordId : recordId // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AttachmentType,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as AttachmentSource,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,originalName: freezed == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String?,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,byteSize: null == byteSize ? _self.byteSize : byteSize // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,capturedAt: freezed == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as String?,attachedAt: null == attachedAt ? _self.attachedAt : attachedAt // ignore: cast_nullable_to_non_nullable
as String,removedAt: freezed == removedAt ? _self.removedAt : removedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$GuidancePerson {

 int? get id; String get name; PersonRole get role; String? get memo; String? get archivedAt; String? get createdAt; String? get updatedAt;
/// Create a copy of GuidancePerson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuidancePersonCopyWith<GuidancePerson> get copyWith => _$GuidancePersonCopyWithImpl<GuidancePerson>(this as GuidancePerson, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuidancePerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.memo, memo) || other.memo == memo)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,role,memo,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'GuidancePerson(id: $id, name: $name, role: $role, memo: $memo, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $GuidancePersonCopyWith<$Res>  {
  factory $GuidancePersonCopyWith(GuidancePerson value, $Res Function(GuidancePerson) _then) = _$GuidancePersonCopyWithImpl;
@useResult
$Res call({
 int? id, String name, PersonRole role, String? memo, String? archivedAt, String? createdAt, String? updatedAt
});




}
/// @nodoc
class _$GuidancePersonCopyWithImpl<$Res>
    implements $GuidancePersonCopyWith<$Res> {
  _$GuidancePersonCopyWithImpl(this._self, this._then);

  final GuidancePerson _self;
  final $Res Function(GuidancePerson) _then;

/// Create a copy of GuidancePerson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = null,Object? role = null,Object? memo = freezed,Object? archivedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as PersonRole,memo: freezed == memo ? _self.memo : memo // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuidancePerson].
extension GuidancePersonPatterns on GuidancePerson {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuidancePerson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuidancePerson() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuidancePerson value)  $default,){
final _that = this;
switch (_that) {
case _GuidancePerson():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuidancePerson value)?  $default,){
final _that = this;
switch (_that) {
case _GuidancePerson() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String name,  PersonRole role,  String? memo,  String? archivedAt,  String? createdAt,  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuidancePerson() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.memo,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String name,  PersonRole role,  String? memo,  String? archivedAt,  String? createdAt,  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _GuidancePerson():
return $default(_that.id,_that.name,_that.role,_that.memo,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String name,  PersonRole role,  String? memo,  String? archivedAt,  String? createdAt,  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _GuidancePerson() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.memo,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _GuidancePerson extends GuidancePerson {
  const _GuidancePerson({this.id, required this.name, this.role = PersonRole.student, this.memo, this.archivedAt, this.createdAt, this.updatedAt}): super._();
  

@override final  int? id;
@override final  String name;
@override@JsonKey() final  PersonRole role;
@override final  String? memo;
@override final  String? archivedAt;
@override final  String? createdAt;
@override final  String? updatedAt;

/// Create a copy of GuidancePerson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuidancePersonCopyWith<_GuidancePerson> get copyWith => __$GuidancePersonCopyWithImpl<_GuidancePerson>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuidancePerson&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&(identical(other.memo, memo) || other.memo == memo)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,role,memo,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'GuidancePerson(id: $id, name: $name, role: $role, memo: $memo, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$GuidancePersonCopyWith<$Res> implements $GuidancePersonCopyWith<$Res> {
  factory _$GuidancePersonCopyWith(_GuidancePerson value, $Res Function(_GuidancePerson) _then) = __$GuidancePersonCopyWithImpl;
@override @useResult
$Res call({
 int? id, String name, PersonRole role, String? memo, String? archivedAt, String? createdAt, String? updatedAt
});




}
/// @nodoc
class __$GuidancePersonCopyWithImpl<$Res>
    implements _$GuidancePersonCopyWith<$Res> {
  __$GuidancePersonCopyWithImpl(this._self, this._then);

  final _GuidancePerson _self;
  final $Res Function(_GuidancePerson) _then;

/// Create a copy of GuidancePerson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = null,Object? role = null,Object? memo = freezed,Object? archivedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_GuidancePerson(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as PersonRole,memo: freezed == memo ? _self.memo : memo // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
