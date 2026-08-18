// 공휴일 행 미리보기 — 실제 위젯으로 렌더해 PNG로 뽑는다.
//   flutter test test/tools/holiday_row_preview.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:planroutine/core/constants/app_colors.dart';
import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_list_section.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko_KR', null));

  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.light ? 'light' : 'dark';
    testWidgets('공휴일 행 — $name', (tester) async {
      final bytes = File(
        'assets/fonts/PretendardVariable.ttf',
      ).readAsBytesSync();
      await (FontLoader('Pretendard')
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();

      AppColors.applyBrightness(brightness);
      tester.view.physicalSize = const Size(390 * 3, 560 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Material(
              color: AppColors.background,
              child: RepaintBoundary(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 연휴 첫날 + 일정 하나
                      EventListSection(
                        selectedDate: DateTime(2026, 9, 24),
                        events: [
                          CalendarEvent(
                            id: 1,
                            title: '생활기록부 창체 입력 마감',
                            eventDate: '2026-09-24',
                          ),
                        ],
                        onEventTap: (_) {},
                        onEventSaveToGoogle: (_) {},
                        onEventToggleCompleted: (_) {},
                      ),
                      // 하루짜리 공휴일 + 일정 없음
                      EventListSection(
                        selectedDate: DateTime(2026, 10, 3),
                        events: const [],
                        onEventTap: (_) {},
                        onEventSaveToGoogle: (_) {},
                        onEventToggleCompleted: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'build/holiday_row_$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
