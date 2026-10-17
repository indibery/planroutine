import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/sb_result.dart';
import '../../domain/booking_dates.dart';
import '../../domain/period_row.dart';
import '../../domain/schoolbook_models.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/book_sheet.dart';
import '../widgets/cancel_sheet.dart';
import '../widgets/period_row_tile.dart';
import '../widgets/room_chips.dart';
import '../widgets/week_strip.dart';

/// 학교를 연결한 뒤의 본문 — 교실 칩 · 이번 주 날짜 띠 · 교시 목록(시안 A).
/// 교시마다 줄 끝 버튼 하나: [예약] 또는 내 예약의 [취소].
/// 요청이 도는 교시. 교시 id는 날짜·교실과 무관하게 같으므로 셋을 함께 키로 쓴다.
typedef _PendingKey = ({int roomId, DateTime date, int periodId});

class SchoolbookDayBody extends ConsumerStatefulWidget {
  const SchoolbookDayBody({super.key, required this.clock});

  final DateTime Function() clock;

  @override
  ConsumerState<SchoolbookDayBody> createState() => _SchoolbookDayBodyState();
}

class _SchoolbookDayBodyState extends ConsumerState<SchoolbookDayBody>
    with WidgetsBindingObserver {
  late DateTime _day;
  int? _roomId;

  /// 하루 예약이 `404`로 온 교실 — 지워진 교실이라 목록을 다시 불러도 고르지 않는다.
  final _gone = <int>{};

  /// 바로 예약 요청이 도는 교시 — 그동안 버튼 대신 `예약 중…`(두 번 예약되지 않게).
  /// 비밀번호를 읽기 **전에** 잡고, 다시 불러온 목록이 도착한 **뒤에** 푼다 — 그 사이에
  /// 버튼이 다시 보이면 같은 교시를 또 보내게 되고 서버에는 중복 방지가 없다(최종 리뷰).
  final _pending = <_PendingKey>{};

  @override
  void initState() {
    super.initState();
    _day = initialDay(widget.clock());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 다른 선생님이 그사이 잡았을 수 있다 — 돌아오면 그날 목록을 다시 부른다
    final roomId = _roomId;
    if (state == AppLifecycleState.resumed && roomId != null) {
      ref.invalidate(roomDayProvider((roomId: roomId, date: _day)));
    }
  }

  void _setDay(DateTime day) => setState(() => _day = day);

  Future<void> _pickRoom(SchoolbookRoom room) async {
    setState(() => _roomId = room.id);
    await ref.read(schoolbookSettingsProvider.notifier).setLastRoom(room.id);
  }

  void _reloadDay(int roomId, DateTime day) =>
      ref.invalidate(roomDayProvider((roomId: roomId, date: day)));

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  /// 예약자와 비밀번호가 저장돼 있으면 **그 자리에서 바로** 예약한다(시트·확인 창 없음).
  /// 하나라도 없으면 입력 시트를 띄우고, 성공하면 저장해 다음부터 바로 잡힌다.
  Future<void> _book(SchoolbookRoom room, PeriodSlot slot) async {
    final settings = ref.read(schoolbookSettingsProvider).valueOrNull;
    final code = settings?.code;
    final day = _day;
    final pendingKey = (roomId: room.id, date: day, periodId: slot.id);
    if (code == null || _pending.contains(pendingKey)) return;
    setState(() => _pending.add(pendingKey));
    final dayKey = (roomId: room.id, date: day);
    final booker = settings?.booker;
    final password = await ref.read(schoolbookPasswordStoreProvider).read();
    if (!mounted) return;

    Future<SbResult<void>> send(String booker, String password) =>
        ref.read(schoolbookApiClientProvider).book(
              code,
              room.id,
              date: day,
              periodIds: [slot.id],
              booker: booker,
              password: password,
            );

    if (booker != null && password != null) {
      final r = await send(booker, password);
      // 다시 불러온 목록이 오기 전에는 옛 목록(그 교시의 [예약])이 그대로 보인다 — 다 받고 푼다
      ref.invalidate(roomDayProvider(dayKey));
      await ref.read(roomDayProvider(dayKey).future);
      if (!mounted) return;
      setState(() => _pending.remove(pendingKey));
      _snack(switch (r.outcome) {
        SbOutcome.ok => SchoolbookStrings.booked(room.name, day, [slot.name]),
        SbOutcome.network => SchoolbookStrings.resultUnknown,
        SbOutcome.rejected => r.detail ?? SchoolbookStrings.bookFailed,
        _ => SchoolbookStrings.bookFailed,
      });
      return;
    }
    // 시트로 간다 — 시트가 스스로 요청 중 잠금을 한다
    setState(() => _pending.remove(pendingKey));

    // 직전 알림이 시트 위에 떠서 시트 안 오류 문구를 가리지 않게 닫는다
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final result = await showBookSheet(
      context,
      title: SchoolbookStrings.bookSheetTitle(
        room.name,
        SchoolbookStrings.dayLabel(day),
        [slot.name],
      ),
      initialBooker: booker,
      initialPassword: password,
      submit: (booker, password) async {
        final r = await send(booker, password);
        if (r.outcome == SbOutcome.ok) {
          // 성공했을 때만 기억한다 — 다음부터 바로 예약된다
          await ref.read(schoolbookSettingsProvider.notifier).setBooker(booker);
          await ref.read(schoolbookPasswordStoreProvider).write(password);
        } else if (r.outcome == SbOutcome.rejected) {
          // 그사이 남이 먼저 잡았을 수 있다
          _reloadDay(room.id, day);
        }
        return r;
      },
    );
    if (!mounted || result == null) return;
    _reloadDay(room.id, day);
    _snack(switch (result) {
      BookSheetResult.booked => SchoolbookStrings.booked(room.name, day, [slot.name]),
      BookSheetResult.unknown => SchoolbookStrings.resultUnknown,
    });
  }

  /// 내 예약 취소 — 비밀번호를 매번 묻는다(사용자 결정).
  Future<void> _cancel(SchoolbookRoom room, PeriodSlot slot, PersonChip mine) async {
    final code = ref.read(schoolbookSettingsProvider).valueOrNull?.code;
    final bookingId = mine.bookingId;
    if (code == null || bookingId == null || !mine.cancellable) return;
    final day = _day;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final result = await showCancelSheet(
      context,
      booker: mine.label,
      periodName: slot.name,
      submit: (password) async {
        final r = await ref
            .read(schoolbookApiClientProvider)
            .cancel(code, room.id, bookingId, password: password);
        if (r.outcome == SbOutcome.notFound) _reloadDay(room.id, day);
        return r;
      },
    );
    if (!mounted || result == null) return;
    _reloadDay(room.id, day);
    _snack(switch (result) {
      CancelSheetResult.canceled => SchoolbookStrings.canceled,
      CancelSheetResult.unknown => SchoolbookStrings.resultUnknown,
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(schoolbookRoomsProvider);
    return rooms.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _failed(() => ref.invalidate(schoolbookRoomsProvider)),
      data: (result) => switch (result.outcome) {
        SbOutcome.ok => _withRooms(result.value ?? const []),
        SbOutcome.unauthorized => _disconnected(),
        SbOutcome.noPeriods => const _Message(SchoolbookStrings.noPeriods),
        _ => _failed(() => ref.invalidate(schoolbookRoomsProvider)),
      },
    );
  }

  Widget _withRooms(List<SchoolbookRoom> all) {
    final rooms = [for (final r in all) if (!_gone.contains(r.id)) r];
    if (rooms.isEmpty) return const _Message(SchoolbookStrings.noRooms);
    final settings = ref.watch(schoolbookSettingsProvider).valueOrNull;
    final wanted = _roomId ?? settings?.lastRoomId;
    final room = rooms.firstWhere((r) => r.id == wanted, orElse: () => rooms.first);
    _roomId = room.id;

    final key = (roomId: room.id, date: _day);
    final day = ref.watch(roomDayProvider(key));
    final today = widget.clock();
    final next = nextWeek(_day, today);

    return Column(
      children: [
        const SizedBox(height: AppSizes.spacing8),
        RoomChips(rooms: rooms, selectedId: room.id, onSelect: _pickRoom),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing8),
          child: WeekStrip(
            day: _day,
            today: today,
            onSelect: _setDay,
            onPreviousWeek: () => _setDay(previousWeek(_day)),
            onNextWeek: next == null ? null : () => _setDay(next),
          ),
        ),
        Expanded(
          child: day.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _failed(() => ref.invalidate(roomDayProvider(key))),
            data: (result) => _dayResult(result, room, today, settings?.booker),
          ),
        ),
      ],
    );
  }

  Widget _dayResult(
    SbResult<RoomDay> result,
    SchoolbookRoom room,
    DateTime today,
    String? myBooker,
  ) {
    switch (result.outcome) {
      case SbOutcome.ok:
        break;
      case SbOutcome.notFound:
        // 보던 교실이 지워졌다 — 목록을 다시 불러 첫 교실로
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _gone.add(room.id);
            _roomId = null;
          });
          ref.invalidate(schoolbookRoomsProvider);
        });
        return const Center(child: CircularProgressIndicator());
      case SbOutcome.unauthorized:
        return _disconnected();
      case SbOutcome.noPeriods:
        return const _Message(SchoolbookStrings.noPeriods);
      case SbOutcome.rejected || SbOutcome.network:
        return _failed(
          () => ref.invalidate(roomDayProvider((roomId: room.id, date: _day))),
        );
    }
    final periods = result.value?.periods ?? const <PeriodSlot>[];
    if (periods.isEmpty) return const _Message(SchoolbookStrings.noSlots);

    final todayOnly = DateTime(today.year, today.month, today.day);
    final bookable = isBookableDate(_day, today);
    final past = _day.isBefore(todayOnly);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing16,
      ),
      children: [
        for (final p in periods)
          Builder(builder: (context) {
            final view = buildPeriodRow(
              p,
              capacity: room.capacity,
              bookableDay: bookable,
              pastDay: past,
              myBooker: myBooker,
            );
            final mine = view.myBooking;
            return PeriodRowTile(
              view: view,
              pending: _pending.contains((roomId: room.id, date: _day, periodId: p.id)),
              onBook: () => _book(room, p),
              onCancel: () {
                if (mine != null) _cancel(room, p, mine);
              },
            );
          }),
      ],
    );
  }

  Widget _failed(VoidCallback retry) => _Message(
        SchoolbookStrings.loadFailed,
        action: SchoolbookStrings.retry,
        onAction: retry,
      );

  Widget _disconnected() => _Message(
        SchoolbookStrings.disconnectedTitle,
        action: SchoolbookStrings.reconnect,
        onAction: () => ref.read(schoolbookSettingsProvider.notifier).disconnect(),
      );
}

/// 빈 상태 한 줄(+ 할 일 버튼).
class _Message extends StatelessWidget {
  const _Message(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(icon: Icons.meeting_room_outlined, title: title),
            if (action != null) ...[
              const SizedBox(height: AppSizes.spacing16),
              TextButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}
