import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';
import 'calendar_grid.dart';
import 'page_index_mapping.dart';

/// 월 단위 가로 슬라이딩 페이저. 기존 GestureDetector(onHorizontalDragEnd)를 대체.
///
/// - 페이지 인덱스 ↔ (year, month) 매핑은 [pageIndexToMonth] / [monthToPageIndex] 사용
/// - 외부에서 [selectedDateProvider]가 바뀌면 [PageController.animateToPage]로 따라감
/// - 페이지가 슬라이드 완료되면 [selectedDateProvider]를 새 월로 갱신
class CalendarMonthPager extends ConsumerStatefulWidget {
  const CalendarMonthPager({
    super.key,
    required this.onDateSelected,
  });

  /// 그리드 내 날짜 셀 탭 콜백 (calendar_screen에서 selectedDate 갱신용).
  final void Function(DateTime date) onDateSelected;

  @override
  ConsumerState<CalendarMonthPager> createState() =>
      _CalendarMonthPagerState();
}

class _CalendarMonthPagerState extends ConsumerState<CalendarMonthPager> {
  late final int _anchorYear;
  late final int _anchorMonth;
  late final PageController _controller;
  ProviderSubscription<DateTime>? _selectedDateSub;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(selectedDateProvider);
    _anchorYear = initial.year;
    _anchorMonth = initial.month;
    _controller = PageController(initialPage: kPagerBaseline);

    // 외부에서 selectedDate가 바뀌면 (chevron / "오늘로 점프" / 일정 확정 등)
    // PageView를 그 페이지로 animateToPage. 무한 루프 방지를 위해
    // 현재 페이지와 다를 때만 명령.
    _selectedDateSub = ref.listenManual<DateTime>(
      selectedDateProvider,
      (prev, next) {
        final targetIndex = monthToPageIndex(
          year: next.year,
          month: next.month,
          anchorYear: _anchorYear,
          anchorMonth: _anchorMonth,
        );
        final currentIndex = _controller.page?.round() ?? targetIndex;
        if (targetIndex != currentIndex) {
          _controller.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _selectedDateSub?.close();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final newMonth = pageIndexToMonth(
      index: index,
      anchorYear: _anchorYear,
      anchorMonth: _anchorMonth,
    );
    final current = ref.read(selectedDateProvider);
    if (current.year != newMonth.year || current.month != newMonth.month) {
      ref.read(selectedDateProvider.notifier).state = newMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 그리드 영역 고정 높이. 기존 calendar_screen.dart의 280을 따름 (loading
      // placeholder와 동일).
      height: 320,
      child: PageView.builder(
        controller: _controller,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final m = pageIndexToMonth(
            index: index,
            anchorYear: _anchorYear,
            anchorMonth: _anchorMonth,
          );
          return _CalendarPage(
            year: m.year,
            month: m.month,
            onDateSelected: widget.onDateSelected,
          );
        },
      ),
    );
  }
}

/// 단일 월 페이지 — 자기 (year, month)로 family를 watch해 그리드 그림.
class _CalendarPage extends ConsumerWidget {
  const _CalendarPage({
    required this.year,
    required this.month,
    required this.onDateSelected,
  });

  final int year;
  final int month;
  final void Function(DateTime date) onDateSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      monthEventsByYearMonthProvider((year: year, month: month)),
    );
    final selectedDate = ref.watch(selectedDateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
      child: eventsAsync.when(
        data: (events) {
          final eventsMap = <String, List<CalendarEvent>>{};
          for (final e in events) {
            eventsMap.putIfAbsent(e.eventDate, () => <CalendarEvent>[]).add(e);
          }
          return CalendarGrid(
            year: year,
            month: month,
            selectedDate: selectedDate,
            eventsMap: eventsMap,
            onDateSelected: onDateSelected,
          );
        },
        loading: () => const SizedBox(
          height: 280,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const SizedBox(
          height: 280,
          child: Center(
            child: Text(
              AppStrings.error,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}
