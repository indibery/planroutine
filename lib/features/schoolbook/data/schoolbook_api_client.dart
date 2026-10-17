import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/date_utils.dart';
import '../domain/schoolbook_models.dart';
import 'sb_result.dart';
import 'schoolbook_parser.dart';

/// 스쿨북 API. 계약 원문은 SchoolBook 저장소 `BackEnd/docs/api.md`.
///
/// **이 앱이 부르는 것은 다섯뿐이다** — 로그인 · 교실 목록 · 하루 예약 · 예약 · 취소.
/// 학교 코드는 그 학교의 설정까지 바꿀 수 있는 권한이라 설정 API는 부르지 않는다
/// (`schoolbook_guard_test.dart`가 지킨다).
const schoolbookBaseUrl = 'https://schoolbook.zzolab.com/api';

const _timeout = Duration(seconds: 10);

class SchoolbookApiClient {
  SchoolbookApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 학교 코드 확인. 헤더 없이 부른다.
  Future<SbResult<SchoolInfo>> login(String code) => _run(
        () => _client.get(Uri.parse('$schoolbookBaseUrl/accounts/login/$code/')),
        (body) {
          final info = parseLogin(body);
          return info.periodCount == 0
              ? const SbResult(SbOutcome.noPeriods)
              : SbResult(SbOutcome.ok, value: info);
        },
      );

  Future<SbResult<List<SchoolbookRoom>>> rooms(String code) => _run(
        () => _client.get(Uri.parse('$schoolbookBaseUrl/rooms/'), headers: _auth(code)),
        (body) => SbResult(SbOutcome.ok, value: parseRooms(body)),
      );

  Future<SbResult<RoomDay>> roomDay(String code, int roomId, DateTime date) => _run(
        () => _client.get(
          Uri.parse('$schoolbookBaseUrl/rooms/$roomId/bookings/?date=${formatDate(date)}'),
          headers: _auth(code),
        ),
        (body) => SbResult(SbOutcome.ok, value: parseRoomDay(body)),
      );

  /// 예약. 하나라도 자리가 없으면 서버가 아무것도 만들지 않는다(`rejected`).
  /// **다시 보내지 않는다** — 중복 방지 키가 없어 시간 초과 뒤 재시도가 두 번 예약이 될 수 있다.
  Future<SbResult<void>> book(
    String code,
    int roomId, {
    required DateTime date,
    required List<int> periodIds,
    required String booker,
    required String password,
  }) =>
      _run(
        () => _client.post(
          Uri.parse('$schoolbookBaseUrl/rooms/$roomId/bookings/'),
          headers: _jsonAuth(code),
          body: jsonEncode({
            'date': formatDate(date),
            'period_ids': periodIds,
            'booker': booker,
            'password': password,
          }),
        ),
        (_) => const SbResult(SbOutcome.ok),
      );

  Future<SbResult<void>> cancel(
    String code,
    int roomId,
    int bookingId, {
    required String password,
  }) =>
      _run(
        () => _client.delete(
          Uri.parse('$schoolbookBaseUrl/rooms/$roomId/bookings/$bookingId/'),
          headers: _jsonAuth(code),
          body: jsonEncode({'password': password}),
        ),
        (_) => const SbResult(SbOutcome.ok),
      );

  Map<String, String> _auth(String code) => {'Authorization': code};

  Map<String, String> _jsonAuth(String code) =>
      {..._auth(code), 'Content-Type': 'application/json'};

  Future<SbResult<T>> _run<T>(
    Future<http.Response> Function() send,
    SbResult<T> Function(Object? body) onOk,
  ) async {
    try {
      final response = await send().timeout(_timeout);
      final text = utf8.decode(response.bodyBytes);
      final Object? body = text.isEmpty ? null : jsonDecode(text);
      switch (response.statusCode) {
        case >= 200 && < 300:
          return onOk(body);
        case 400:
          return SbResult(SbOutcome.rejected, detail: parseDetail(body));
        case 401:
          return const SbResult(SbOutcome.unauthorized);
        case 403:
          return const SbResult(SbOutcome.noPeriods);
        case 404:
          return const SbResult(SbOutcome.notFound);
        default:
          return const SbResult(SbOutcome.network);
      }
    } catch (_) {
      // 시간 초과 · 연결 실패 · JSON이 아닌 본문 · 형식이 다른 응답
      return const SbResult(SbOutcome.network);
    }
  }
}
