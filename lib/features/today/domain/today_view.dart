import '../../../core/utils/date_utils.dart';
import '../../calendar/domain/calendar_event.dart';

/// 지난 항목을 거슬러 보는 기본 범위 (롤링 7일).
///
/// 작년 CSV를 임포트하는 앱이라 DB에는 이미 날짜가 지난 미완료 이벤트가 수십~수백 건
/// 쌓여 있다. 컷오프가 없으면 오늘 탭을 여는 순간 지난 목록에 파묻혀 "오늘"이 화면 밖으로
/// 밀려난다.
const todayOverdueLookbackDays = 7;

/// 오늘 탭이 그릴 화면 상태 — [buildTodayView]의 출력.
///
/// `PendingNotification`과 같이 계산 결과 뷰이므로 freezed 없이 순수 클래스로 둔다
/// (직렬화·DB 저장 대상이 아니다).
class TodayView {
  const TodayView({required this.overdue, required this.today});

  /// 기한이 지난 항목 — 조회 시점에 미완료였던 것. 날짜 오름차순.
  ///
  /// 화면에서 완료해도 이 목록에서 빠지지 않는다(자리 고정). 다음 진입 때 사라진다.
  final List<CalendarEvent> overdue;

  /// 오늘 항목 — 완료 포함. 중요 미완료 → 일반 미완료 → 완료 순.
  final List<CalendarEvent> today;

  /// 오늘 완료 건수. 지난 항목은 세지 않는다.
  int get doneCount => today.where((e) => e.isCompleted).length;

  /// 오늘 전체 건수.
  int get totalCount => today.length;

  /// 오늘 남은 건수.
  int get remainingCount => totalCount - doneCount;

  bool get hasToday => totalCount > 0;

  /// 오늘 항목을 모두 닫았는지. 오늘 일정이 없는 날은 false(달성이 아니라 빈 상태).
  bool get isAllDone => hasToday && doneCount == totalCount;

  /// [id] 항목의 완료 상태만 바꾼 새 뷰. **목록 순서와 위치는 그대로 둔다.**
  ///
  /// 완료 즉시 재정렬하면 탭한 행이 아래로 이동해 도장 애니메이션이 화면 밖에서
  /// 재생된다. 정렬은 화면 재진입 시([buildTodayView] 재실행) 적용된다.
  TodayView withToggled(int id, String? completedAt) {
    return TodayView(
      overdue: _replace(overdue, id, completedAt),
      today: _replace(today, id, completedAt),
    );
  }

  static List<CalendarEvent> _replace(
    List<CalendarEvent> events,
    int id,
    String? completedAt,
  ) {
    return events
        .map((e) => e.id == id ? e.copyWith(completedAt: completedAt) : e)
        .toList();
  }
}

/// 조회한 이벤트를 오늘 탭 화면 상태로 가른다 — DB·플랫폼 무관 순수 함수.
///
/// [events]는 `getEventsByDateRange(오늘−[lookbackDays], 오늘)` 결과를 넘긴다.
/// 범위 밖(미래) 이벤트가 섞여 들어와도 양쪽 목록 어디에도 넣지 않는다.
TodayView buildTodayView({
  required List<CalendarEvent> events,
  required DateTime today,
  int lookbackDays = todayOverdueLookbackDays,
}) {
  final todayStr = formatDate(today);
  final cutoffStr = formatDate(
    DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: lookbackDays)),
  );

  // 오늘 탭은 **업무**만 다룬다 — 행사(운동회 등)에는 완료 개념이 없어
  // 도장·진행 링의 의미가 깨진다. 캘린더 탭에서는 둘 다 보인다.
  final tasks = events.where((e) => e.kind.showsInToday);

  // 'YYYY-MM-DD'는 사전순 비교가 곧 날짜순 비교다.
  final overdue =
      tasks
          .where(
            (e) =>
                e.deletedAt == null &&
                !e.isCompleted &&
                e.eventDate.compareTo(todayStr) < 0 &&
                e.eventDate.compareTo(cutoffStr) >= 0,
          )
          .toList()
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

  final todayEvents = tasks
      .where((e) => e.deletedAt == null && e.eventDate == todayStr)
      .toList();

  // sort 대신 그룹별 분할 — Dart의 List.sort는 안정 정렬이 보장되지 않아
  // 같은 그룹 안의 입력 순서(created_at 순)가 흐트러질 수 있다.
  return TodayView(
    overdue: overdue,
    today: [
      ...todayEvents.where((e) => !e.isCompleted && e.isImportant),
      ...todayEvents.where((e) => !e.isCompleted && !e.isImportant),
      ...todayEvents.where((e) => e.isCompleted),
    ],
  );
}
