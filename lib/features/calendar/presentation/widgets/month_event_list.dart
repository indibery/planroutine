import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/calendar_event.dart';
import '../date_jump.dart';
import 'event_list_section.dart';

/// 한 달치 이벤트를 날짜별 섹션으로 쌓는 스크롤 목록.
///
/// [selectedDate]가 바뀌면 그 날짜 섹션(없으면 다음 가까운 날짜)으로 스크롤하고
/// 도착 지점을 잠깐 골드로 플래시한다. 모든 섹션을 즉시 레이아웃해야
/// `ensureVisible`가 화면 밖 섹션도 찾아 스크롤할 수 있으므로,
/// (지연 레이아웃되는) ListView 대신 SingleChildScrollView + Column을 쓴다.
class MonthEventList extends StatefulWidget {
  const MonthEventList({
    super.key,
    required this.groupedEntries,
    required this.selectedDate,
    required this.onEventTap,
    required this.onEventSaveToGoogle,
    required this.onEventToggleCompleted,
    required this.onEventBumpYear,
  });

  final List<MapEntry<String, List<CalendarEvent>>> groupedEntries;
  final DateTime selectedDate;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<CalendarEvent>? onEventSaveToGoogle;
  final ValueChanged<CalendarEvent> onEventToggleCompleted;
  final ValueChanged<CalendarEvent> onEventBumpYear;

  @override
  State<MonthEventList> createState() => _MonthEventListState();
}

class _MonthEventListState extends State<MonthEventList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _flashKey;

  @override
  void didUpdateWidget(covariant MonthEventList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _jumpToDate(widget.selectedDate);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 선택된 날짜의 섹션(또는 그 이후 가장 가까운 섹션)으로 스크롤 + 플래시.
  void _jumpToDate(DateTime date) {
    final entries = widget.groupedEntries;
    if (entries.isEmpty) return;
    final keys = entries.map((e) => e.key).toList();
    final index = nextGroupIndexFor(keys, formatDate(date));
    if (index < 0) return;
    final targetKey = keys[index];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[targetKey]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      // 플래시: 잠깐 켰다가 꺼서 골드 배경이 서서히 사라지게 한다.
      setState(() => _flashKey = targetKey);
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _flashKey = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 지연 레이아웃되는 ListView 대신 Column으로 모든 섹션을 즉시 레이아웃해야
    // ensureVisible가 화면 밖 섹션의 context를 찾아 스크롤할 수 있다.
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        top: AppSizes.spacing16,
        bottom: AppSizes.fabSize + AppSizes.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in widget.groupedEntries)
            KeyedSubtree(
              key: _sectionKeys.putIfAbsent(entry.key, () => GlobalKey()),
              child: EventListSection(
                selectedDate: DateTime.parse(entry.key),
                events: entry.value,
                highlight: _flashKey == entry.key,
                onEventTap: widget.onEventTap,
                onEventSaveToGoogle: widget.onEventSaveToGoogle,
                onEventToggleCompleted: widget.onEventToggleCompleted,
                onEventBumpYear: widget.onEventBumpYear,
              ),
            ),
        ],
      ),
    );
  }
}
