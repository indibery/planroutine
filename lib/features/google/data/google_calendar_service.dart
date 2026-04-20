import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

/// Google Calendar API 래퍼 — 로그인/로그아웃/이벤트 생성.
///
/// 단방향 동기화: 플랜루틴에서 만든 이벤트를 사용자의 primary 구글 캘린더로
/// **생성**만 한다. 이후 수정/삭제는 동기화하지 않는다 (개인정보 최소 노출).
class GoogleCalendarService {
  GoogleCalendarService() : _signIn = _buildSignIn();

  final GoogleSignIn _signIn;

  static GoogleSignIn _buildSignIn() {
    return GoogleSignIn(
      scopes: const [gcal.CalendarApi.calendarEventsScope],
    );
  }

  /// 현재 로그인된 계정 (없으면 null) 변화를 방출하는 스트림.
  Stream<GoogleSignInAccount?> get accountStream =>
      _signIn.onCurrentUserChanged;

  /// 조용한 로그인 시도 (사용자 interaction 없이 저장된 토큰 복구).
  /// 이미 로그인된 적 있는 계정이 있으면 복귀, 없으면 null.
  Future<GoogleSignInAccount?> signInSilently() async {
    return _signIn.signInSilently();
  }

  /// 사용자 로그인 (Google 동의 화면 표시).
  Future<GoogleSignInAccount?> signIn() async {
    return _signIn.signIn();
  }

  /// 로그아웃 — 앱이 저장한 토큰 폐기. 구글 계정 자체는 영향 없음.
  Future<void> signOut() async {
    await _signIn.signOut();
  }

  /// 현재 로그인된 계정 (즉시 조회).
  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  /// primary 캘린더에 이벤트 생성.
  ///
  /// [startDate] ~ [endDate]는 종일 이벤트면 같은 날짜, 기간 이벤트면 다르게.
  /// 종일 이벤트의 end 날짜는 **다음 날**로 들어간다 (Google Calendar API 규칙).
  Future<gcal.Event> createEvent({
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required bool isAllDay,
  }) async {
    final account = _signIn.currentUser;
    if (account == null) {
      throw StateError('Google 로그인이 필요합니다');
    }
    final headers = await account.authHeaders;
    final client = _AuthenticatedClient(headers);
    try {
      final api = gcal.CalendarApi(client);
      final event = _buildEvent(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
      );
      return await api.events.insert(event, 'primary');
    } finally {
      client.close();
    }
  }

  /// 이미 저장된 이벤트 [eventId]를 primary 캘린더에서 업데이트.
  ///
  /// 구글쪽에서 사용자가 이미 삭제했으면 404가 반환되므로 [NotFoundException]으로
  /// 감싸서 호출측에서 "insert로 재시도" 전략을 쓸 수 있게 한다.
  Future<gcal.Event> updateEvent({
    required String eventId,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required bool isAllDay,
  }) async {
    final account = _signIn.currentUser;
    if (account == null) {
      throw StateError('Google 로그인이 필요합니다');
    }
    final headers = await account.authHeaders;
    final client = _AuthenticatedClient(headers);
    try {
      final api = gcal.CalendarApi(client);
      final event = _buildEvent(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
      );
      try {
        return await api.events.update(event, 'primary', eventId);
      } on gcal.DetailedApiRequestError catch (e) {
        if (e.status == 404 || e.status == 410) {
          throw const GoogleEventNotFoundException();
        }
        rethrow;
      }
    } finally {
      client.close();
    }
  }

  gcal.Event _buildEvent({
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required bool isAllDay,
  }) {
    final event = gcal.Event()
      ..summary = title
      ..description = description;
    if (isAllDay) {
      // 종일 이벤트: date만, end는 exclusive(다음 날)
      final end = endDate ?? startDate;
      event.start = gcal.EventDateTime()..date = _dateOnly(startDate);
      event.end = gcal.EventDateTime()
        ..date = _dateOnly(end.add(const Duration(days: 1)));
    } else {
      final end = endDate ?? startDate.add(const Duration(hours: 1));
      event.start = gcal.EventDateTime()..dateTime = startDate.toUtc();
      event.end = gcal.EventDateTime()..dateTime = end.toUtc();
    }
    return event;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// 구글쪽에서 이미 삭제/만료된 이벤트 id로 update를 시도한 경우.
/// 호출측은 이를 잡아 insert로 재시도할지 결정한다.
class GoogleEventNotFoundException implements Exception {
  const GoogleEventNotFoundException();
  @override
  String toString() => 'GoogleEventNotFoundException';
}

/// google_sign_in이 반환한 auth header를 모든 요청에 붙이는 http 클라이언트.
class _AuthenticatedClient extends http.BaseClient {
  _AuthenticatedClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

