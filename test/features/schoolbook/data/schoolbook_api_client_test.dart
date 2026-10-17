import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/schoolbook/data/sb_result.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_api_client.dart';

import '../fixture.dart';

const _code = 'abcdefghijk12';
final _day = DateTime(2026, 10, 20);

/// 한글 픽스처라 content-type을 꼭 준다(버스 테스트와 같은 이유).
http.Response _fixture(String name) {
  final f = loadSchoolbookFixture(name);
  return http.Response(jsonEncode(f.body), f.status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  late List<http.Request> requests;

  SchoolbookApiClient clientWith(FutureOr<http.Response> Function(http.Request) handler) {
    requests = [];
    return SchoolbookApiClient(
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
    );
  }

  group('결과 갈래', () {
    test('login 성공 — 헤더 없이 부른다', () async {
      final r = await clientWith((_) => _fixture('login')).login(_code);
      expect(r.outcome, SbOutcome.ok);
      expect(r.value?.name, '플랜테스트');
      expect(requests.single.url.toString(),
          'https://schoolbook.zzolab.com/api/accounts/login/$_code/');
      expect(requests.single.headers.containsKey('authorization'), isFalse);
    });

    test('없는 코드는 unauthorized', () async {
      final r = await clientWith((_) => _fixture('login_unknown')).login(_code);
      expect(r.outcome, SbOutcome.unauthorized);
    });

    test('교시가 하나도 없는 학교는 noPeriods', () async {
      final r = await clientWith((_) => http.Response(
            jsonEncode({'name': '새학교', 'code': _code, 'periods': [], 'notices': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )).login(_code);
      expect(r.outcome, SbOutcome.noPeriods);
    });

    test('403은 noPeriods', () async {
      final r = await clientWith((_) => http.Response('{"detail":"x"}', 403)).rooms(_code);
      expect(r.outcome, SbOutcome.noPeriods);
    });

    test('자리가 없으면 rejected + 서버 문구', () async {
      final r = await clientWith((_) => _fixture('book_full'))
          .book(_code, 1511, date: _day, periodIds: [1604], booker: '체육전담', password: '1234');
      expect(r.outcome, SbOutcome.rejected);
      expect(r.detail, '3교시의 남은 자리가 없습니다.');
    });

    test('비밀번호가 틀리면 rejected', () async {
      final r = await clientWith((_) => _fixture('cancel_wrong_password'))
          .cancel(_code, 1511, 9, password: '0000');
      expect(r.outcome, SbOutcome.rejected);
      expect(r.detail, '비밀번호가 맞지 않습니다.');
    });

    test('없는 예약 취소는 notFound', () async {
      final r = await clientWith((_) => _fixture('cancel_not_found'))
          .cancel(_code, 1511, 9, password: '1234');
      expect(r.outcome, SbOutcome.notFound);
    });

    test('예약 성공은 ok', () async {
      final r = await clientWith((_) => _fixture('book_ok'))
          .book(_code, 1511, date: _day, periodIds: [1603, 1605], booker: '체육전담', password: '1234');
      expect(r.outcome, SbOutcome.ok);
    });
  });

  group('요청 모양', () {
    test('교실 목록은 Authorization에 학교 코드', () async {
      final r = await clientWith((_) => _fixture('rooms')).rooms(_code);
      expect(r.outcome, SbOutcome.ok);
      expect(requests.single.headers['authorization'], _code);
      expect(requests.single.url.path, '/api/rooms/');
    });

    test('하루 예약은 ?date=', () async {
      final r = await clientWith((_) => _fixture('day_gym')).roomDay(_code, 1511, _day);
      expect(r.outcome, SbOutcome.ok);
      expect(requests.single.url.toString(),
          'https://schoolbook.zzolab.com/api/rooms/1511/bookings/?date=2026-10-20');
    });

    test('예약 본문 키는 넷', () async {
      await clientWith((_) => _fixture('book_ok'))
          .book(_code, 1511, date: _day, periodIds: [1603, 1605], booker: '체육전담', password: '1234');
      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/rooms/1511/bookings/');
      expect(jsonDecode(req.body), {
        'date': '2026-10-20',
        'period_ids': [1603, 1605],
        'booker': '체육전담',
        'password': '1234',
      });
    });

    test('취소는 DELETE + 비밀번호 본문', () async {
      await clientWith((_) => http.Response('', 204)).cancel(_code, 1511, 9, password: '1234');
      final req = requests.single;
      expect(req.method, 'DELETE');
      expect(req.url.path, '/api/rooms/1511/bookings/9/');
      expect(jsonDecode(req.body), {'password': '1234'});
    });
  });

  group('네트워크 갈래 — 던지지 않는다', () {
    for (final entry in <String, FutureOr<http.Response> Function(http.Request)>{
      '429': (_) => http.Response('{"detail":"Request was throttled."}', 429),
      '500': (_) => http.Response('oops', 500),
      'HTML 본문': (_) => http.Response('<html></html>', 200),
      '시간 초과': (_) => throw TimeoutException('t'),
      '연결 실패': (_) => throw const SocketException('down'),
    }.entries) {
      test('${entry.key} → network', () async {
        final r = await clientWith(entry.value).rooms(_code);
        expect(r.outcome, SbOutcome.network);
      });
    }

    test('예약이 network로 끝나도 다시 보내지 않는다', () async {
      final client = clientWith((_) => throw TimeoutException('t'));
      final r = await client.book(_code, 1511,
          date: _day, periodIds: [1603], booker: '체육전담', password: '1234');
      expect(r.outcome, SbOutcome.network);
      expect(requests, hasLength(1));
    });
  });
}
