import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/tab_header_title.dart';
import '../../../../shared/widgets/gold_fab.dart';
import '../../../device_calendar/data/device_calendar_service.dart';
import '../../../device_calendar/presentation/providers/device_calendar_providers.dart';
import '../../../google/data/google_calendar_service.dart';
import '../../../google/presentation/providers/google_providers.dart';
import '../../../settings/presentation/providers/calendar_target_provider.dart';
import '../../../memo/domain/memo.dart';
import '../../../memo/presentation/providers/memo_providers.dart';
import '../../../memo/presentation/widgets/memo_sheet.dart';
import '../../domain/calendar_event.dart';
import '../../domain/extra_date_keys.dart';
import '../providers/calendar_providers.dart';
import '../widgets/calendar_month_pager.dart';
import '../widgets/calendar_slide_hint_bar.dart';
import '../widgets/event_edit_dialog.dart';
import '../widgets/month_event_list.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 캘린더 화면
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  static final _monthFormatter = DateFormat('yyyy년 M월', 'ko_KR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final monthEventsGrouped = ref.watch(monthEventsGroupedProvider);
    final ym = ref.watch(selectedDateProvider.select((d) => (d.year, d.month)));
    // 기능이 꺼져 있으면 provider가 빈 맵을 준다 — 캘린더에 쪽지가 안 보인다.
    final memosByDate =
        ref
            .watch(monthMemosByDateProvider((year: ym.$1, month: ym.$2)))
            .valueOrNull ??
        const <String, List<Memo>>{};

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: AppSizes.spacing12),
          child: Center(child: BrandLogo(size: 28)),
        ),
        title: const TabHeaderTitle(
          eyebrow: CalendarStrings.eyebrow,
          title: CalendarStrings.title,
        ),
      ),
      body: Column(
        children: [
          _buildMonthHeader(context, ref, selectedDate),
          CalendarMonthPager(
            onDateSelected: (date) {
              ref.read(selectedDateProvider.notifier).state = date;
            },
          ),
          const Divider(height: 1),
          const CalendarSlideHintBar(),
          Expanded(
            child: monthEventsGrouped.when(
              data: (events) {
                // 일정 없이 쪽지만 있는 날도 섹션이 생겨야 쪽지를 그릴 자리가 있다.
                final groupedEntries = mergeExtraDateKeys(
                  events,
                  memosByDate.keys,
                );
                return groupedEntries.isEmpty
                    ? Center(
                        child: Text(
                          CalendarStrings.noEvents,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                        ),
                      )
                    : MonthEventList(
                        groupedEntries: groupedEntries,
                        selectedDate: selectedDate,
                        onEventTap: (event) =>
                            _onEditEvent(context, ref, event),
                        onEventSaveToGoogle: _resolveSaveCallback(context, ref),
                        onEventToggleCompleted: (event) =>
                            _onToggleCompleted(context, ref, event),
                        memosByDate: memosByDate,
                        onMemoTap: (m) => MemoSheet.show(context, m),
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text(AppStrings.error)),
            ),
          ),
        ],
      ),
      floatingActionButton: GoldFab(
        onTap: () => _onAddEvent(context, ref, selectedDate),
        semanticLabel: CalendarStrings.addEvent,
      ),
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final monthText = _monthFormatter.format(selectedDate);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: AppColors.sub,
              semanticLabel: CalendarStrings.prevMonth,
            ),
            onPressed: () {
              final prev = DateTime(
                selectedDate.year,
                selectedDate.month - 1,
                1,
              );
              ref.read(selectedDateProvider.notifier).state = prev;
            },
          ),
          ButtonSemantics.gesture(
            label: '$monthText, ${CalendarStrings.goToday}',
            onTap: () => _goToday(ref),
            child: Text(
              monthText,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: AppColors.sub,
              semanticLabel: CalendarStrings.nextMonth,
            ),
            onPressed: () {
              final next = DateTime(
                selectedDate.year,
                selectedDate.month + 1,
                1,
              );
              ref.read(selectedDateProvider.notifier).state = next;
            },
          ),
        ],
      ),
    );
  }

  /// 월 제목을 누르면 오늘이 있는 달로 돌아간다.
  void _goToday(WidgetRef ref) =>
      ref.read(selectedDateProvider.notifier).state = DateTime.now();

  Future<void> _onAddEvent(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final result = await EventEditDialog.show(context, initialDate: date);
    if (result != null) {
      await ref.read(selectedMonthEventsProvider.notifier).addEvent(result);
    }
  }

  Future<void> _onEditEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final result = await EventEditDialog.show(
      context,
      initialDate: event.eventDateTime,
      event: event,
    );
    if (result != null) {
      await ref.read(selectedMonthEventsProvider.notifier).updateEvent(result);
    }
  }

  /// 오른쪽 스와이프 — 구글 캘린더에 이벤트 저장.
  /// 우측 스와이프 콜백 결정 — target에 따라 활성/비활성.
  /// AppFeatures.googleCalendarEnabled 꺼져 있거나 target=none이면 null 반환
  /// → EventListSection이 우측 스와이프 자체를 비활성화.
  ValueChanged<CalendarEvent>? _resolveSaveCallback(
    BuildContext context,
    WidgetRef ref,
  ) {
    if (!AppFeatures.googleCalendarEnabled) return null;
    final target = ref.watch(
      calendarTargetProvider.select(
        (a) => a.valueOrNull ?? CalendarTarget.none,
      ),
    );
    if (target == CalendarTarget.none) return null;
    return (event) => _onSaveToCalendar(context, ref, event);
  }

  /// 우측 스와이프 — target에 따라 Google/기기 분기.
  Future<void> _onSaveToCalendar(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final target =
        ref.read(calendarTargetProvider).valueOrNull ?? CalendarTarget.none;
    switch (target) {
      case CalendarTarget.none:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(CalendarIntegrationStrings.setupNeeded)),
        );
      case CalendarTarget.google:
        await _onSaveToGoogle(context, ref, event);
      case CalendarTarget.device:
        await _onSaveToDevice(context, ref, event);
    }
  }

  /// 기기 캘린더 저장 — 권한 확인 → save → device_event_id 보관.
  Future<void> _onSaveToDevice(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final service = ref.read(deviceCalendarServiceProvider);

    final hadPermission = await service.hasPermissions();
    var granted = hadPermission;
    if (!granted) granted = await service.requestPermissions();
    // 권한 상태가 변했으면 설정 화면의 row가 즉시 갱신되도록 두 provider 모두 invalidate
    if (granted != hadPermission) {
      ref.invalidate(calendarPermissionStatusProvider);
    }
    if (!granted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(CalendarIntegrationStrings.permissionDenied),
          action: SnackBarAction(
            label: CalendarIntegrationStrings.openSettings,
            onPressed: () async {
              await openAppSettings();
              ref.invalidate(calendarPermissionStatusProvider);
            },
          ),
        ),
      );
      return;
    }

    final wasAlreadySaved = event.deviceEventId != null;
    try {
      final saved = await service.saveEvent(
        existingId: event.deviceEventId,
        title: event.title,
        description: event.description,
        startDate: event.eventDateTime,
        endDate: event.endDate != null ? event.endDateTime : null,
      );

      final eventId = event.id;
      if (eventId != null) {
        final repository = ref.read(calendarRepositoryProvider);
        await repository.updateDeviceEventId(eventId, saved.eventId);
        ref.invalidate(monthEventsByYearMonthProvider);
        ref.invalidate(selectedMonthEventsProvider);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAlreadySaved
                ? CalendarIntegrationStrings.alreadySaved
                : CalendarIntegrationStrings.savedDeviceTo(saved.calendarName),
          ),
        ),
      );
    } on DeviceCalendarException catch (e) {
      // **사유를 버리지 않는다.** 예전에는 `catch (_)`라 화면에도 로그에도
      // `저장 실패` 넉 자만 남았고, 실기기에서 실패했을 때 (a) 쓸 수 있는 캘린더가
      // 없는 것인지 (b) 플랫폼이 거부한 것인지 구분할 방법이 아무 데도 없었다
      // (릴리스 빌드라 logcat에도 안 남는다 — 2026-08-06 실측).
      debugPrint('[device-calendar] 저장 실패: ${e.message}');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(CalendarIntegrationStrings.saveFailed)),
      );
    }
  }

  /// 로그인 안 돼있으면 먼저 로그인 유도, 실패는 스낵바로 안내.
  ///
  /// 중복 방지: `event.googleEventId`가 이미 있으면 update API 호출.
  /// 구글쪽에서 지워져 404면 insert로 재시도(사용자가 의도적으로 재생성).
  Future<void> _onSaveToGoogle(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final service = ref.read(googleCalendarServiceProvider);
    final repository = ref.read(calendarRepositoryProvider);
    try {
      if (service.currentUser == null) {
        final account = await service.signIn();
        if (account == null) return; // 사용자 취소
      }

      final start = event.eventDateTime;
      final end = event.endDate != null ? event.endDateTime : start;

      String? resultId;
      var wasNewSave = true; // insert 경로일 때만 true, update 성공 시 false
      final existingId = event.googleEventId;
      if (existingId != null && existingId.isNotEmpty) {
        try {
          final updated = await service.updateEvent(
            eventId: existingId,
            title: event.title,
            description: event.description,
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
          );
          resultId = updated.id;
          wasNewSave = false;
        } on GoogleEventNotFoundException {
          // 구글쪽에서 삭제됨 → 새로 생성 (local id는 새 id로 덮어씀)
          final created = await service.createEvent(
            title: event.title,
            description: event.description,
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
          );
          resultId = created.id;
        }
      } else {
        final created = await service.createEvent(
          title: event.title,
          description: event.description,
          startDate: start,
          endDate: end,
          isAllDay: event.isAllDay,
        );
        resultId = created.id;
      }

      // 받은 id를 로컬에 기록 (다음 저장을 update로 처리하기 위해)
      final eventId = event.id;
      if (eventId != null && resultId != null && resultId.isNotEmpty) {
        await repository.updateGoogleEventId(eventId, resultId);
        ref.invalidate(monthEventsByYearMonthProvider);
        ref.invalidate(selectedMonthEventsProvider);
      }

      if (context.mounted) {
        final msg = wasNewSave
            ? CalendarStrings.saveToGoogleDone
            : CalendarStrings.saveToGoogleAlready;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('${CalendarStrings.saveToGoogleFailed}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }
  }

  /// 왼쪽 스와이프 — 이벤트 완료/완료 취소 토글.
  Future<void> _onToggleCompleted(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    await ref.read(selectedMonthEventsProvider.notifier).toggleCompleted(event);
  }
}
