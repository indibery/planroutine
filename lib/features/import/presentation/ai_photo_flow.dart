import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/bulk_bar_snack.dart';
import '../../../core/constants/app_strings.dart';
import '../../schedule/presentation/providers/schedule_providers.dart';
import '../data/ai_schedule_parser.dart';
import '../data/ai_schedule_register.dart';
import '../../schedule/domain/entry_kind.dart';

/// 사진 → AI → 붙여넣기 왕복 흐름의 두 동작.
///
/// 입력 탭 히어로([PhotoInputHero])가 이 둘을 한 상태에서 읽어 쓴다.

/// ① 변환 프롬프트를 클립보드에 싣는다.
///
/// [kind]는 히어로에서 고른 소스 종류다. **②의 [pasteAiSchedulesAndRegister]에 같은
/// 값을 넘겨야 한다** — 갈리면 쪽지 프롬프트로 뽑은 마감 기한이 행사로 저장돼 오늘
/// 탭에 뜨지 않는다. 호출부(히어로)가 하나의 상태에서 둘 다 읽는다.
Future<void> copyAiPhotoPrompt(
  BuildContext context, {
  EntryKind kind = EntryKind.event,
}) async {
  await Clipboard.setData(
    ClipboardData(text: buildAiPhotoPrompt(DateTime.now(), kind: kind)),
  );
  if (!context.mounted) return;
  showBulkBarSnack(context, ImportStrings.aiPromptCopiedFor(kind));
}

/// ② 클립보드의 AI 응답을 파싱해 **곧바로 검토 대기로 등록한다.**
///
/// 확인 시트를 거치지 않는다. 예전에는 미리보기 시트에서 `등록`을 한 번 누르고
/// 검토 목록에서 또 확정해야 해서, 한 흐름에 같은 것을 묻는 관문이 둘이었다
/// (사용자 요청 2026-08-14). 시트가 하던 말(인식 건수 · 중복 제외 · 형식 오류)은
/// [ImportStrings.aiRegisterSummary]가 한 줄로 진다.
///
/// **취소 자리가 없어졌다** — 잘못 붙여넣으면 되돌릴 기회 없이 목록에 들어온다.
/// 대신 검토 목록에서 ← 스와이프나 `대기 N건 삭제`로 걷어낼 수 있고 둘 다
/// soft-delete라, 잃는 것이 휴지통을 거치는 한 걸음뿐이다.
Future<void> pasteAiSchedulesAndRegister(
  BuildContext context,
  WidgetRef ref, {
  EntryKind kind = EntryKind.event,
}) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final parsed = parseAiScheduleJson(data?.text ?? '');
  if (!context.mounted) return;
  if (parsed.items.isEmpty) {
    // **못 뽑은 것과 못 읽은 것을 구분한다.** 형식 오류만 있었다면 AI는 답을
    // 줬는데 우리가 못 받은 것이고, 사용자가 할 일이 다르다 — 다시 복사할
    // 게 아니라 AI에 다시 요청해야 한다.
    showBulkBarSnack(
      context,
      parsed.invalidCount > 0
          ? ImportStrings.aiParseAllInvalid(parsed.invalidCount)
          : ImportStrings.aiParseEmptyFor(kind),
    );
    return;
  }

  // 기존 활성 일정(title+date)과 대조해 중복은 넣지 않는다.
  final repository = ref.read(scheduleRepositoryProvider);
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

  final result = await registerAiSchedules(
    repository,
    fresh,
    // ①에서 복사한 프롬프트와 **같은 종류**로 저장한다.
    kind: kind,
  );
  ref.invalidate(schedulesProvider);
  if (!context.mounted) return;
  showBulkBarSnack(
    context,
    ImportStrings.aiRegisterSummary(
      kind,
      created: result.created,
      // `insertConfirmedOrPending`이 한 번 더 걸러낸 건수(`skipped`)를 합친다.
      // 빼면 우리 키 검사를 통과한 중복이 조용히 사라진다.
      dup: dupCount + result.skipped,
      skipped: parsed.invalidCount,
    ),
  );
}

