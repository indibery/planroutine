import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/domain/schedule_digest.dart';
import '../../features/calendar/presentation/providers/calendar_providers.dart';
import '../../features/import/data/ai_schedule_intake.dart';
import '../../features/schedule/domain/entry_kind.dart';
import '../../features/schedule/presentation/providers/schedule_providers.dart';
import '../constants/app_strings.dart';
import 'app_intents_contract.dart';

/// 단축어에서 들어온 호출을 기존 Dart 경로로 넘긴다.
///
/// **여기에 업무 규칙을 쓰지 않는다.** 파싱·중복 판정은 [intakeAiScheduleText],
/// 요약은 [buildScheduleDigest]가 진다. 이 클래스가 하는 일은 인자를 풀고
/// 결과를 문자열로 돌려주는 것뿐이다 — 규칙이 여기로 새면 화면 경로와
/// 단축어 경로가 서로 다르게 동작하기 시작한다.
class AppIntentsHandler {
  const AppIntentsHandler(this._container);

  final ProviderContainer _container;

  Future<Object?> handle(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};

    switch (call.method) {
      case AppIntentsContract.methodRegister:
        return _register(args);
      case AppIntentsContract.methodQuery:
        return _query(args);
      default:
        throw MissingPluginException('알 수 없는 App Intents 메서드: ${call.method}');
    }
  }

  Future<String> _register(Map<String, Object?> args) async {
    final text = args[AppIntentsContract.argText] as String? ?? '';
    // 기본값은 행사다 — 사진 AI 경로의 히어로 세그먼트와 같은 기본값이고,
    // 단축어로 넘어오는 것도 대개 AI가 일정표에서 뽑은 행사다.
    final kind = args.containsKey(AppIntentsContract.argKind)
        ? EntryKind.fromValue(args[AppIntentsContract.argKind] as String?)
        : EntryKind.event;

    final result = await intakeAiScheduleText(
      _container.read(scheduleRepositoryProvider),
      text,
      kind: kind,
    );

    // 앱이 떠 있는 상태에서 단축어를 쓰면 **같은 프로세스의 상태를 만지는 것**이라,
    // 이것을 빼면 검토 목록이 그대로여서 사용자에게는 실패로 보인다.
    _container.invalidate(schedulesProvider);

    if (result.created == 0 && result.dup == 0 && result.invalid > 0) {
      return ImportStrings.aiParseAllInvalid(result.invalid);
    }
    return ImportStrings.aiRegisterSummary(
      kind,
      created: result.created,
      dup: result.dup,
      skipped: result.invalid,
    );
  }

  Future<String> _query(Map<String, Object?> args) async {
    final range = DigestRange.fromValue(
      args[AppIntentsContract.argRange] as String?,
    );
    final now = DateTime.now();
    final bounds = digestBounds(now, range);
    final events = await _container
        .read(calendarRepositoryProvider)
        .getEventsByDateRange(bounds.start, bounds.end);

    return buildScheduleDigest(events: events, now: now, range: range);
  }
}
