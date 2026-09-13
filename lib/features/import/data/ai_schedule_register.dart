import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/entry_kind.dart';
import '../../schedule/domain/schedule.dart';
import 'ai_schedule_parser.dart';

/// AI가 사진에서 뽑은 행사를 검토 대기(pending)로 등록한다.
/// 중복(title+date 활성)은 insertConfirmedOrPending이 스킵(-1) — 재붙여넣기 안전.
/// 확정은 기존 검토 흐름(스와이프/일괄)에서, 캘린더 이벤트도 확정 시 생성된다.
/// 사진 AI 결과를 검토 대기로 넣는다.
///
/// [kind]는 히어로에서 고른 소스 종류다 — `buildAiPhotoPrompt`에 넘긴 값과 **같아야
/// 한다**. 갈리면 쪽지 프롬프트로 뽑은 마감 기한이 행사로 저장돼 오늘 탭에 뜨지 않고,
/// 사용자는 사진을 찍은 이유(그날 할 일을 잊지 않는 것)를 잃는다.
/// [status]는 기본이 검토 대기다. **단축어 경로만 [ScheduleStatus.confirmed]를 준다** —
/// 앱 밖에서 넣는데 확정하러 앱을 열어야 하면 "앱을 열지 않는다"는 전제가 무너지고,
/// `일정 조회` 인텐트가 `calendar_events`를 보므로 넣은 것을 조회할 수도 없다.
///
/// 반환의 `ids`는 **실제로 삽입된 것만** 담는다(중복으로 스킵된 것은 없다).
/// 확정으로 넣은 호출부가 이 id로 캘린더 이벤트를 만든다.
Future<({int created, int skipped, List<int> ids})> registerAiSchedules(
  ScheduleRepository repository,
  List<AiScheduleItem> items, {
  EntryKind kind = EntryKind.event,
  ScheduleStatus status = ScheduleStatus.pending,
}) async {
  final now = DateTime.now().toIso8601String();
  var created = 0;
  var skipped = 0;
  final ids = <int>[];
  for (final item in items) {
    final id = await repository.insertConfirmedOrPending(
      Schedule(
        title: item.title,
        description: item.description,
        scheduledDate: item.date,
        status: status,
        // 일정표는 행사(캘린더만), 쪽지의 마감 기한은 업무(오늘 탭에 뜬다).
        kind: kind,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (id < 0) {
      skipped++;
    } else {
      created++;
      ids.add(id);
    }
  }
  return (created: created, skipped: skipped, ids: ids);
}
