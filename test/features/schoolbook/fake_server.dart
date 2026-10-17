import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_api_client.dart';

import 'fixture.dart';

/// 화면 테스트용 가짜 스쿨북. `'GET /api/rooms/'`처럼 `메서드 경로`(쿼리 포함)로 응답을 고른다.
/// 없는 요청은 404. 받은 요청은 [requests]에 쌓인다.
class FakeSchoolbook {
  FakeSchoolbook(this.routes);

  final Map<String, FutureOr<http.Response> Function(http.Request)> routes;
  final requests = <http.Request>[];

  SchoolbookApiClient client() => SchoolbookApiClient(
        client: MockClient((req) async {
          requests.add(req);
          final query = req.url.hasQuery ? '?${req.url.query}' : '';
          final handler = routes['${req.method} ${req.url.path}$query'];
          if (handler == null) return http.Response('{"detail":"not found"}', 404);
          return handler(req);
        }),
      );

  int count(String method, String pathPrefix) => requests
      .where((r) => r.method == method && r.url.path.startsWith(pathPrefix))
      .length;
}

/// 픽스처 응답(한글이라 content-type을 준다).
http.Response fixtureResponse(String name) {
  final f = loadSchoolbookFixture(name);
  return jsonResponse(f.body, f.status);
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
