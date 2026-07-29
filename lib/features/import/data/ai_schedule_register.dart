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
Future<({int created, int skipped})> registerAiSchedules(
  ScheduleRepository repository,
  List<AiScheduleItem> items, {
  EntryKind kind = EntryKind.event,
}) async {
  final now = DateTime.now().toIso8601String();
  var created = 0;
  var skipped = 0;
  for (final item in items) {
    final id = await repository.insertConfirmedOrPending(
      Schedule(
        title: item.title,
        description: item.description,
        scheduledDate: item.date,
        status: ScheduleStatus.pending,
        // 일정표는 행사(캘린더만), 쪽지의 마감 기한은 업무(오늘 탭에 뜬다).
        kind: kind,
        createdAt: now,
        updatedAt: now,
      ),
    );
    id < 0 ? skipped++ : created++;
  }
  return (created: created, skipped: skipped);
}
