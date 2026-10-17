import 'dart:convert';
import 'dart:io';

/// `test/fixtures/schoolbook/<name>.json` — 테스트 학교에서 뜬 실측 응답.
/// 파일은 `{"status": 상태 코드, "body": 응답 본문}` 모양이다.
({int status, Object? body}) loadSchoolbookFixture(String name) {
  final json = jsonDecode(
    File('test/fixtures/schoolbook/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (status: json['status'] as int, body: json['body']);
}
