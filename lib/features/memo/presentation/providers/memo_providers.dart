import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/modules/app_module.dart';
import '../../../../core/modules/installed_modules_provider.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../schedule/domain/entry_kind.dart';
import '../../data/memo_repository.dart';
import '../../domain/memo.dart';
import '../../domain/memo_order.dart';

final memoRepositoryProvider = Provider<MemoRepository>(
  (ref) => MemoRepository(),
);

/// 쪽지가 바뀌었다는 신호. 캘린더·휴지통이 watch해 다시 읽는다 — 서로를 직접
/// invalidate하지 않으려고(`eventsRevisionProvider`와 같은 이유).
final memoRevisionProvider = StateProvider<int>((ref) => 0);

final memosProvider = AsyncNotifierProvider<MemosNotifier, List<Memo>>(
  MemosNotifier.new,
);

class MemosNotifier extends AsyncNotifier<List<Memo>> {
  MemoRepository get _repo => ref.read(memoRepositoryProvider);

  @override
  Future<List<Memo>> build() {
    ref.watch(memoRevisionProvider);
    return ref.watch(memoRepositoryProvider).getActive();
  }

  void _changed() => ref.read(memoRevisionProvider.notifier).state++;

  /// 직전 변경으로 무효화된 build가 다시 돌 때까지 기다린다. 안 기다리면 연달아
  /// 부를 때 `ref`가 "의존성이 바뀌었는데 아직 재빌드 전" assert에 걸린다.
  Future<void> _settled() => future;

  Future<void> add(String text) async {
    await _settled();
    final t = text.trim();
    if (t.isEmpty) return;
    await _repo.add(t);
    _changed();
  }

  Future<void> save(Memo memo) async {
    await _settled();
    await _repo.update(memo);
    _changed();
  }

  Future<void> remove(int id) async {
    await _settled();
    await _repo.softDelete(id);
    _changed();
  }

  /// 보드에서 끌어 놓은 순서를 저장한다. 화면만 바꾸고 끝내면 다시 켰을 때 돌아간다.
  Future<void> move(int id, int toIndex) async {
    final current = await future;
    final ids = [for (final m in current) ?m.id];
    await _repo.saveOrder(moveId(ids, id, toIndex));
    _changed();
  }

  /// **일정을 먼저 만들고, 성공하면 쪽지를 뗀다.** 거꾸로 하면 일정 생성이 실패했을 때
  /// 쪽지만 사라진다. 일정은 손으로 넣은 일정과 같은 경로(`addEvent`) — 알림 동기화·
  /// 리비전이 함께 따라온다.
  Future<void> convertToEvent(
    Memo memo, {
    required EntryKind kind,
    required DateTime date,
  }) async {
    final id = memo.id;
    if (id == null) return;
    await _settled();
    await ref
        .read(selectedMonthEventsProvider.notifier)
        .addEvent(
          CalendarEvent(
            title: memo.text.trim(),
            eventDate: formatDate(date),
            kind: kind,
          ),
        );
    await _repo.softDelete(id);
    _changed();
  }
}

/// 캘린더용 — 그 달의 날짜 붙은 쪽지를 `YYYY-MM-DD`별로. **기능이 꺼져 있으면 빈 맵**.
final monthMemosByDateProvider =
    FutureProvider.family<Map<String, List<Memo>>, ({int year, int month})>((
      ref,
      key,
    ) async {
      if (!ref.watch(moduleInstalledProvider(ModuleIds.memo))) return const {};
      ref.watch(memoRevisionProvider);
      final memos = await ref
          .watch(memoRepositoryProvider)
          .getByDateRange(
            DateTime(key.year, key.month, 1),
            DateTime(key.year, key.month + 1, 0),
          );
      final map = <String, List<Memo>>{};
      for (final m in memos) {
        final d = m.memoDate;
        if (d == null) continue;
        map.putIfAbsent(formatDate(d), () => <Memo>[]).add(m);
      }
      return map;
    });
