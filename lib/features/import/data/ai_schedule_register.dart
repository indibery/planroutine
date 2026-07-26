import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/entry_kind.dart';
import '../../schedule/domain/schedule.dart';
import 'ai_schedule_parser.dart';

/// AI가 사진에서 뽑은 행사를 검토 대기(pending)로 등록한다.
/// 중복(title+date 활성)은 insertConfirmedOrPending이 스킵(-1) — 재붙여넣기 안전.
/// 확정은 기존 검토 흐름(스와이프/일괄)에서, 캘린더 이벤트도 확정 시 생성된다.
Future<({int created, int skipped})> registerAiSchedules(
  ScheduleRepository repository,
  List<AiScheduleItem> items,
) async {
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
        // 사진(월간 일정표) 경로는 행사 — 오늘 탭에는 뜨지 않는다.
        kind: EntryKind.event,
        createdAt: now,
        updatedAt: now,
      ),
    );
    id < 0 ? skipped++ : created++;
  }
  return (created: created, skipped: skipped);
}
