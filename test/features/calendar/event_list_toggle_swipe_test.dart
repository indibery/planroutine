import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> swipeLeft(WidgetTester tester, Finder f) async {
    final g = await tester.startGesture(tester.getCenter(f));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-45, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('완료된 이벤트를 endToStart 스와이프하면 토글 콜백이 호출된다',
      (tester) async {
    final toggled = <int>[];
    // 완료된 상태의 이벤트로 렌더 → 스와이프 → 콜백 확인
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventListSection(
              selectedDate: DateTime(2026, 3, 2),
              events: const [
                CalendarEvent(
                  id: 7,
                  title: '완료된 이벤트',
                  eventDate: '2026-03-02',
                  completedAt: '2026-03-02T10:00:00.000',
                ),
              ],
              onEventTap: (_) {},
              onEventSaveToGoogle: null,
              onEventToggleCompleted: (e) => toggled.add(e.id!),
              onEventBumpYear: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await swipeLeft(tester, find.text('완료된 이벤트'));
    expect(toggled, [7]);
  });

  testWidgets('같은 이벤트를 연속 두 번 스와이프하면 콜백이 두 번 호출된다',
      (tester) async {
    // 통합 테스트 재현: 첫 스와이프로 완료 → 리렌더 → 두 번째 스와이프로 완료 취소.
    final calls = <bool>[]; // 각 스와이프 시점의 isCompleted
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: _RebuildOnToggle(
              builder: (isCompleted, onToggle) => EventListSection(
                selectedDate: DateTime(2026, 3, 2),
                events: [
                  CalendarEvent(
                    id: 7,
                    title: '토글 이벤트',
                    eventDate: '2026-03-02',
                    completedAt:
                        isCompleted ? '2026-03-02T10:00:00.000' : null,
                  ),
                ],
                onEventTap: (_) {},
                onEventSaveToGoogle: null,
                onEventToggleCompleted: (e) {
                  calls.add(e.isCompleted);
                  onToggle();
                },
                onEventBumpYear: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await swipeLeft(tester, find.text('토글 이벤트'));
    await swipeLeft(tester, find.text('토글 이벤트'));

    // 첫 스와이프: 미완료 상태에서 호출 / 두 번째: 완료 상태에서 호출
    expect(calls, [false, true]);
  });
}

/// isCompleted를 내부 상태로 들고 토글 시 리빌드하는 테스트 하네스.
class _RebuildOnToggle extends StatefulWidget {
  const _RebuildOnToggle({required this.builder});
  final Widget Function(bool isCompleted, VoidCallback onToggle) builder;

  @override
  State<_RebuildOnToggle> createState() => _RebuildOnToggleState();
}

class _RebuildOnToggleState extends State<_RebuildOnToggle> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _completed,
      () => setState(() => _completed = !_completed),
    );
  }
}
