import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/entry_kind.dart';
import 'ai_schedule_parser.dart';
import 'ai_schedule_register.dart';

/// AI 응답 텍스트를 검토 대기로 들인다. **UI에 의존하지 않는다.**
///
/// 입력 탭 히어로(클립보드)와 단축어 인텐트(App Intents)가 **둘 다 이 함수를**
/// 쓴다. 중복 판정이 예전에는 `pasteAiSchedulesAndRegister` 안에 인라인으로
/// 있어서 두 번째 호출부가 생기는 순간 규칙이 갈라질 자리였다 — 여기로 모은다.
///
/// 반환값 셋은 성격이 다르다:
///   - `created` 실제로 들어간 건수
///   - `dup` 이미 있는 것(활성 `title + scheduled_date`)이라 건너뛴 건수.
///     같은 텍스트 안의 중복도 여기 포함한다.
///   - `invalid` 파서가 형식 오류로 버린 건수. **AI에 다시 요청해야 하는 경우**라
///     `dup`과 섞으면 사용자가 할 일을 알 수 없다.
Future<({int created, int dup, int invalid})> intakeAiScheduleText(
  ScheduleRepository repository,
  String text, {
  EntryKind kind = EntryKind.event,
}) async {
  final parsed = parseAiScheduleJson(text);
  if (parsed.items.isEmpty) {
    return (created: 0, dup: 0, invalid: parsed.invalidCount);
  }

  // 기존 활성 일정(title+date)과 대조해 중복은 넣지 않는다.
  final existing = await repository.getSchedules();
  final existingKeys = existing
      .map((s) => '${s.title}|${s.scheduledDate}')
      .toSet();
  final seen = <String>{};
  final fresh = <AiScheduleItem>[];
  var dupCount = 0;
  for (final item in parsed.items) {
    final key = '${item.title}|${item.date}';
    if (existingKeys.contains(key) || !seen.add(key)) {
      dupCount++;
    } else {
      fresh.add(item);
    }
  }

  final result = await registerAiSchedules(repository, fresh, kind: kind);

  return (
    created: result.created,
    // `insertConfirmedOrPending`이 한 번 더 걸러낸 건수(`skipped`)를 합친다.
    // 빼면 우리 키 검사를 통과한 중복이 조용히 사라진다.
    dup: dupCount + result.skipped,
    invalid: parsed.invalidCount,
  );
}
