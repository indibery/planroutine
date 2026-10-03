import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `guidance_revisions`는 추가만 한다 — 판을 고치면 "처음에 뭐라고 썼는지"가 사라진다.
/// 저장소 소스를 훑어 UPDATE가 없고 DELETE가 영구 삭제 한 곳뿐인지 본다.
void main() {
  final src = File('lib/features/guidance/data/guidance_repository.dart').readAsStringSync();

  test('판 테이블에 update를 쓰지 않는다', () {
    expect(RegExp(r'update\(\s*DatabaseHelper\.tableGuidanceRevisions').hasMatch(src), isFalse);
    expect(RegExp(r'UPDATE\s+guidance_revisions', caseSensitive: false).hasMatch(src), isFalse);
    expect(src.contains('rawUpdate'), isFalse);
  });

  test('판 테이블 delete는 permanentDelete 안의 한 곳뿐이다', () {
    final hits = RegExp(r'delete\(\s*DatabaseHelper\.tableGuidanceRevisions').allMatches(src).toList();
    expect(hits, hasLength(1));
    final start = src.indexOf('Future<List<String>> permanentDelete(');
    final end = src.indexOf('\n  }\n', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(hits.single.start > start && hits.single.start < end, isTrue);
    expect(src.contains('rawDelete'), isFalse);
  });
}
