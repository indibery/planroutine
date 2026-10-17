import '../domain/schoolbook_models.dart';

// 스쿨북 응답(계약: SchoolBook `BackEnd/docs/api.md`) → 모델.
// 형이 틀리면 FormatException — 클라이언트가 잡아 `network`로 바꾼다.

T _as<T>(Object? value, String what) {
  if (value is T) return value;
  throw FormatException('스쿨북 응답 형식이 다릅니다: $what');
}

Map<String, dynamic> _map(Object? v, String what) =>
    _as<Map<String, dynamic>>(v, what);

List<dynamic> _list(Object? v, String what) => _as<List<dynamic>>(v, what);

SchoolInfo parseLogin(Object? body) {
  final m = _map(body, 'login');
  return SchoolInfo(
    code: _as<String>(m['code'], 'code'),
    name: _as<String>(m['name'], 'name'),
    periodCount: _list(m['periods'], 'periods').length,
  );
}

List<SchoolbookRoom> parseRooms(Object? body) => [
      for (final r in _list(body, 'rooms'))
        SchoolbookRoom(
          id: _as<int>(_map(r, 'room')['id'], 'room.id'),
          name: _as<String>(r['name'], 'room.name'),
          capacity: _as<int>(r['capacity'], 'room.capacity'),
        ),
    ];

RoomDay parseRoomDay(Object? body) {
  final m = _map(body, 'day');
  final date = DateTime.tryParse(_as<String>(m['date'], 'date'));
  if (date == null) throw const FormatException('date');
  return RoomDay(
    date: date,
    periods: [
      for (final p in _list(m['periods'], 'periods')) _parsePeriod(_map(p, 'period')),
    ],
  );
}

PeriodSlot _parsePeriod(Map<String, dynamic> p) => PeriodSlot(
      id: _as<int>(p['id'], 'period.id'),
      name: _as<String>(p['name'], 'period.name'),
      startTime: _as<String?>(p['start_time'], 'start_time'),
      endTime: _as<String?>(p['end_time'], 'end_time'),
      archived: _as<bool>(p['archived'], 'archived'),
      remaining: _as<int>(p['remaining'], 'remaining'),
      fixed: [
        for (final f in _list(p['fixed'] ?? const [], 'fixed'))
          _as<String>(_map(f, 'fixed')['booker'], 'fixed.booker'),
      ],
      bookings: [
        for (final b in _list(p['bookings'], 'bookings'))
          SlotBooking(
            id: _as<int>(_map(b, 'booking')['id'], 'booking.id'),
            booker: _as<String>(b['booker'], 'booking.booker'),
            canceled: b['cancel_reason'] != null,
          ),
      ],
    );

/// 오류 응답의 `detail`(화면에 그대로 보여 줄 문구). 없으면 null.
String? parseDetail(Object? body) {
  if (body is Map<String, dynamic>) {
    final d = body['detail'];
    if (d is String) return d;
  }
  return null;
}
