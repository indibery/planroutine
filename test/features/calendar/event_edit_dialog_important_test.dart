import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/core/theme/app_theme.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  const importantToggle = Key('important_toggle');

  /// 팔레트와 전역 `switchTheme`을 실제로 적용한 채 다이얼로그를 띄운다 — 색 검증 전용.
  ///
  /// 아래 `openAndReturn`은 기본 `ThemeData`라 앱이 정해둔 스위치 색이 걸리지 않는다.
  Future<void> openThemed(WidgetTester tester, Brightness brightness) async {
    AppColors.applyBrightness(brightness);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.of(brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => EventEditDialog.show(
                  context,
                  initialDate: DateTime(2026, 3, 2),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // show()로 다이얼로그를 띄우고, 저장 시 반환되는 이벤트를 캡처한다.
  Future<CalendarEvent?> openAndReturn(
    WidgetTester tester, {
    CalendarEvent? event,
  }) async {
    CalendarEvent? captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await EventEditDialog.show(
                    context,
                    initialDate: DateTime(2026, 3, 2),
                    event: event,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return captured;
  }

  group('캘린더 이벤트 편집 — 중요 표시 토글', () {
    testWidgets('토글이 보이고 기존 이벤트의 isImportant를 반영한다', (tester) async {
      await openAndReturn(
        tester,
        event: const CalendarEvent(
          id: 1,
          title: '입학식',
          eventDate: '2026-03-02',
          isImportant: true,
        ),
      );

      final sw = tester.widget<SwitchListTile>(find.byKey(importantToggle));
      expect(sw.value, true);
    });

    testWidgets('토글을 켜고 저장하면 isImportant=true인 이벤트 반환', (tester) async {
      CalendarEvent? result;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await EventEditDialog.show(
                      context,
                      initialDate: DateTime(2026, 3, 2),
                      event: const CalendarEvent(
                        id: 1,
                        title: '입학식',
                        eventDate: '2026-03-02',
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(importantToggle));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isImportant, true);
    });
  });

  group('중요 표시 스위치 — 전역 switchTheme을 따른다 (최종 리뷰 신규 발견)', () {
    // 팔레트는 전역이다 — 라이트로 바꾼 채 끝내면 뒤따르는 테스트가 오염된다.
    tearDown(() => AppColors.applyBrightness(Brightness.dark));

    for (final brightness in Brightness.values) {
      testWidgets('$brightness 에서 켠 썸이 트랙과 다른 색이다', (tester) async {
        await openThemed(tester, brightness);
        await tester.tap(find.byKey(importantToggle));
        await tester.pumpAndSettle();

        final finder = find.byKey(importantToggle);
        final tile = tester.widget<SwitchListTile>(finder);
        final theme = Theme.of(tester.element(finder));
        const selected = {WidgetState.selected};

        // Flutter의 해상 순서를 그대로 재현한다: 위젯의 `activeThumbColor`가
        // `switchTheme.thumbColor`를 밀어낸다(`switch.dart`의 `_widgetThumbColor`).
        final thumb = tile.activeThumbColor ??
            theme.switchTheme.thumbColor?.resolve(selected);
        final track = tile.activeTrackColor ??
            theme.switchTheme.trackColor?.resolve(selected);

        expect(thumb, isNotNull);
        expect(track, isNotNull);
        expect(thumb, isNot(track),
            reason: '썸과 트랙이 같은 색이면 켠 상태가 썸 없는 단색 알약이 된다 — '
                'M3 스위치는 selected 그림자·외곽선이 없어 형태 단서도 없다');
      });
    }
  });
}
