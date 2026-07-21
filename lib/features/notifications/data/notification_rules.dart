import '../../../core/constants/strings/notification_strings.dart';
import '../../calendar/domain/calendar_event.dart';
import '../domain/notification_settings.dart';
import '../domain/pending_notification.dart';

/// iOS는 앱당 64개 예약 알림 상한. 안전 버퍼 포함 60개까지만 생성.
/// 발송 날짜당 알림 1개로 통합하므로 실제로는 이 상한에 거의 닿지 않는다.
const int kMaxPendingNotifications = 60;

/// 한 섹션(오늘/1주 후/이달)에서 제목을 최대 몇 개까지 노출할지. 초과분은 "외 N건".
const int _maxTitlesPerSection = 2;

/// 통합 알림 ID: 발송 날짜(YYYYMMDD) 기준 유일.
/// 같은 날 발송분은 같은 id로 병합되어 하나의 알림이 된다.
int _dailyDigestId(DateTime date) =>
    300000000 + date.year * 10000 + date.month * 100 + date.day;

/// 주어진 [events]/[settings]/[now] 기준으로 예약할 알림을 계산.
///
/// 순수 함수 — DB/플랫폼/IO 없음, 유닛 테스트 용이.
///
/// 규칙:
///   - masterEnabled가 false면 빈 리스트
///   - completed/deleted 이벤트는 대상 제외
///   - 발송 시각이 [now] 이후인 것만 포함 (과거 시각은 iOS가 즉시 발송하므로 배제)
///   - **발송 날짜(항상 hour:minute)마다 알림 1개** — 같은 아침에 겹치는
///     월초·1주 전·당일 아침 알림을 하나로 통합한다.
///   - 각 알림 본문은 `오늘 → 1주 후 → 이달` 섹션 순서, 섹션당 제목 최대
///     [_maxTitlesPerSection]개 + "외 N건"
///   - 생성 수가 [kMaxPendingNotifications]를 초과하면 가까운 시각 우선 정렬 후 절단
List<PendingNotification> computeNotifications({
  required List<CalendarEvent> events,
  required NotificationSettings settings,
  required DateTime now,
}) {
  if (!settings.masterEnabled) return [];

  final activeEvents = events
      .where((e) => e.deletedAt == null && e.completedAt == null)
      .toList();

  // 발송 시각 → 그 시각에 합쳐질 섹션별 제목 모음
  final byFireTime = <DateTime, _Digest>{};
  _Digest digestAt(DateTime at) =>
      byFireTime.putIfAbsent(at, () => _Digest());

  // 월초 알림: 활성 이벤트가 있는 달마다 1일 발송.
  // 이달 섹션은 그 달 전체 건수 + 중요표시된 이벤트 제목만 담는다.
  if (settings.monthStartEnabled) {
    final byMonth = <String, List<CalendarEvent>>{};
    for (final event in activeEvents) {
      final date = DateTime.tryParse(event.eventDate);
      if (date == null) continue;
      byMonth.putIfAbsent('${date.year}-${date.month}', () => []).add(event);
    }
    byMonth.forEach((key, monthEvents) {
      final parts = key.split('-');
      final at = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        1,
        settings.hour,
        settings.minute,
      );
      if (at.isAfter(now)) {
        final digest = digestAt(at);
        digest.monthTotal += monthEvents.length;
        for (final e in monthEvents) {
          if (!e.isImportant) continue;
          final date = DateTime.tryParse(e.eventDate);
          if (date == null) continue;
          digest.monthImportant.add(_Entry(date, e.title));
        }
      }
    });
  }

  // 이벤트 1주 전 / 당일 아침
  for (final event in activeEvents) {
    final eventDate = DateTime.tryParse(event.eventDate);
    if (eventDate == null) continue;
    final eventStart = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      settings.hour,
      settings.minute,
    );

    if (settings.weekBeforeEnabled) {
      final at = eventStart.subtract(const Duration(days: 7));
      if (at.isAfter(now)) digestAt(at).week.add(_Entry(eventStart, event.title));
    }
    if (settings.dayOfEnabled) {
      // 이벤트 당일 아침 발송 ('오늘 X 있어요').
      if (eventStart.isAfter(now)) {
        digestAt(eventStart).today.add(_Entry(eventStart, event.title));
      }
    }
  }

  // 통합된 발송 시각마다 알림 1개 생성
  final pendings = <PendingNotification>[];
  byFireTime.forEach((at, digest) {
    final body = digest.buildBody();
    if (body.isEmpty) return;
    pendings.add(PendingNotification(
      id: _dailyDigestId(at),
      title: NotificationStrings.digestTitle,
      body: body,
      scheduledAt: at,
    ));
  });

  // 시각 오름차순 정렬 후 iOS 상한에 맞춰 절단
  pendings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (pendings.length > kMaxPendingNotifications) {
    return pendings.sublist(0, kMaxPendingNotifications);
  }
  return pendings;
}

/// 발송 시각에 얹히는 개별 항목 — 제목과 임박순 정렬용 이벤트 날짜.
class _Entry {
  const _Entry(this.date, this.title);
  final DateTime date;
  final String title;
}

/// 한 발송 시각에 통합될 알림 본문의 누적 버퍼.
class _Digest {
  final List<_Entry> today = [];
  final List<_Entry> week = [];

  /// 이달 섹션: 그 달 전체 건수 + 중요표시된 항목만.
  final List<_Entry> monthImportant = [];
  int monthTotal = 0;

  /// 섹션 순서: 오늘 → 1주 후 → 이달. 비어 있는 섹션은 생략.
  String buildBody() {
    final lines = <String>[];
    _appendTitleSection(NotificationStrings.digestToday, today, lines);
    _appendTitleSection(NotificationStrings.digestWeek, week, lines);
    _appendMonthSection(lines);
    return lines.join('\n');
  }

  void _appendTitleSection(String label, List<_Entry> entries, List<String> out) {
    if (entries.isEmpty) return;
    out.add('$label: ${_formatTitles(_titlesByImminence(entries))}');
  }

  void _appendMonthSection(List<String> out) {
    if (monthTotal == 0) return;
    final buffer = StringBuffer(
      '${NotificationStrings.digestMonth}: '
      '${NotificationStrings.digestMonthTotal(monthTotal)}',
    );
    if (monthImportant.isNotEmpty) {
      buffer.write(
        ' · ${NotificationStrings.digestImportant} '
        '${_formatTitles(_titlesByImminence(monthImportant))}',
      );
    }
    out.add(buffer.toString());
  }

  /// 이벤트 날짜 오름차순(가장 임박한 순), 같은 날은 제목순으로 제목 리스트 반환.
  List<String> _titlesByImminence(List<_Entry> entries) {
    final sorted = [...entries]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.title.compareTo(b.title);
    });
    return sorted.map((e) => e.title).toList();
  }

  String _formatTitles(List<String> titles) {
    if (titles.length <= _maxTitlesPerSection) return titles.join(', ');
    final shown = titles.take(_maxTitlesPerSection).join(', ');
    final rest = titles.length - _maxTitlesPerSection;
    return '$shown ${NotificationStrings.digestOverflow(rest)}';
  }
}
