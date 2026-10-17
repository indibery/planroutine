import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../data/sb_result.dart';
import '../../domain/booking_dates.dart';
import '../../domain/period_row.dart';
import '../../domain/schoolbook_models.dart';
import '../providers/schoolbook_providers.dart';
import '../widgets/book_sheet.dart';
import '../widgets/cancel_sheet.dart';
import '../widgets/day_nav.dart';
import '../widgets/period_row_tile.dart';
import '../widgets/room_bar.dart';
import '../widgets/room_picker_sheet.dart';

/// 학교를 연결한 뒤의 본문 — 교실 이름 한 줄 · ◀ 날짜 ▶ · 교시 목록 · 예약 버튼(시안 B).
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
  final _selected = <int>{};

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

  void _setDay(DateTime day) => setState(() {
        _day = day;
        _selected.clear();
      });

  Future<void> _pickRoom(List<SchoolbookRoom> rooms, int selectedId) async {
    final picked = await showRoomPicker(context, rooms: rooms, selectedId: selectedId);
    if (picked == null || !mounted) return;
    setState(() {
      _roomId = picked.id;
      _selected.clear();
    });
    await ref.read(schoolbookSettingsProvider.notifier).setLastRoom(picked.id);
  }

  void _reloadDay(int roomId, DateTime day) =>
      ref.invalidate(roomDayProvider((roomId: roomId, date: day)));

  /// 알림은 아래 예약 버튼 위에 띄운다 — 바닥에 붙이면 4초 동안 버튼을 덮어
  /// 이어서 다른 교시를 예약할 수 없었다(시뮬레이터 실측 2026-10-17).
  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            AppSizes.spacing16,
            0,
            AppSizes.spacing16,
            AppSizes.buttonHeight + AppSizes.spacing12 + AppSizes.spacing8,
          ),
        ),
      );

  Future<void> _book(SchoolbookRoom room, List<PeriodSlot> chosen) async {
    final settings = ref.read(schoolbookSettingsProvider).valueOrNull;
    final code = settings?.code;
    if (code == null) return;
    final day = _day;
    final names = [for (final p in chosen) p.name];
    final password = await ref.read(schoolbookPasswordStoreProvider).read();
    if (!mounted) return;
    final result = await showBookSheet(
      context,
      title: SchoolbookStrings.bookSheetTitle(room.name, dayLabel(day), names),
      initialBooker: settings?.booker,
      initialPassword: password,
      submit: (booker, password) async {
        final r = await ref.read(schoolbookApiClientProvider).book(
              code,
              room.id,
              date: day,
              periodIds: [for (final p in chosen) p.id],
              booker: booker,
              password: password,
            );
        if (r.outcome == SbOutcome.ok) {
          // 성공했을 때만 기억한다 — 다음 예약 시트에 미리 채운다
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
    setState(_selected.clear);
    _reloadDay(room.id, day);
    _snack(switch (result) {
      BookSheetResult.booked => SchoolbookStrings.booked(names),
      BookSheetResult.unknown => SchoolbookStrings.resultUnknown,
    });
  }

  Future<void> _cancel(SchoolbookRoom room, PeriodSlot slot, PersonChip person) async {
    final code = ref.read(schoolbookSettingsProvider).valueOrNull?.code;
    final bookingId = person.bookingId;
    if (code == null || bookingId == null || !person.cancellable) return;
    final day = _day;
    final result = await showCancelSheet(
      context,
      booker: person.label,
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
    final wanted = _roomId ?? ref.watch(schoolbookSettingsProvider).valueOrNull?.lastRoomId;
    final room = rooms.firstWhere((r) => r.id == wanted, orElse: () => rooms.first);
    _roomId = room.id;

    final key = (roomId: room.id, date: _day);
    final day = ref.watch(roomDayProvider(key));
    final today = widget.clock();
    final previous = previousWeekday(_day);
    final next = nextWeekday(_day, today);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spacing16, AppSizes.spacing8, AppSizes.spacing16, 0,
          ),
          child: RoomBar(name: room.name, onTap: () => _pickRoom(rooms, room.id)),
        ),
        DayNav(
          day: _day,
          onPrevious: () => _setDay(previous),
          onNext: next == null ? null : () => _setDay(next),
        ),
        Expanded(
          child: day.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _failed(() => ref.invalidate(roomDayProvider(key))),
            data: (result) => _dayResult(result, room, today),
          ),
        ),
      ],
    );
  }

  Widget _dayResult(SbResult<RoomDay> result, SchoolbookRoom room, DateTime today) {
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
            _selected.clear();
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
    final views = [
      for (final p in periods)
        buildPeriodRow(p, capacity: room.capacity, bookableDay: bookable, pastDay: past),
    ];
    // 다시 불러온 목록에서 더는 고를 수 없는 교시는 체크를 푼다
    final selectable = {for (final v in views) if (v.selectable) v.slot.id};
    _selected.retainAll(selectable);
    final chosen = [for (final p in periods) if (_selected.contains(p.id)) p];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacing16, 0, AppSizes.spacing16, AppSizes.spacing16,
            ),
            children: [
              for (final v in views)
                PeriodRowTile(
                  view: v,
                  checked: _selected.contains(v.slot.id),
                  onChecked: (on) => setState(() {
                    on ? _selected.add(v.slot.id) : _selected.remove(v.slot.id);
                  }),
                  onPersonTap: (person) => _cancel(room, v.slot, person),
                ),
            ],
          ),
        ),
        if (chosen.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacing12),
              child: Center(
                child: GoldGradientButton(
                  label: SchoolbookStrings.bookButton([for (final p in chosen) p.name]),
                  onPressed: () => _book(room, chosen),
                ),
              ),
            ),
          ),
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
