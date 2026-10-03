import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/date_utils.dart';
import 'memo_color.dart';

part 'memo.freezed.dart';

/// 포스트잇 한 장. 날짜가 있으면 그날 캘린더에 보인다.
@freezed
abstract class Memo with _$Memo {
  const Memo._();

  const factory Memo({
    int? id,
    required String text,
    @Default(MemoColor.yellow) MemoColor color,
    DateTime? memoDate,
    @Default(0) int sortOrder,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
  }) = _Memo;

  factory Memo.fromMap(Map<String, dynamic> map) {
    final date = map['memo_date'] as String?;
    return Memo(
      id: map['id'] as int?,
      text: map['text'] as String,
      color: MemoColor.fromValue(map['color'] as String?),
      memoDate: date == null ? null : DateTime.tryParse(date),
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      deletedAt: map['deleted_at'] as String?,
    );
  }

  /// `deleted_at`은 넣지 않는다 — soft-delete는 전용 메서드만 만진다(`CalendarEvent.toMap`과 같다).
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    final date = memoDate;
    return {
      if (id != null) 'id': id,
      'text': text,
      'color': color.dbValue,
      'memo_date': date == null ? null : formatDate(date),
      'sort_order': sortOrder,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }
}
