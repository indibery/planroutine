import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:planroutine/features/calendar/domain/calendar_event.dart';
import 'package:planroutine/features/calendar/presentation/widgets/event_edit_dialog.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  Future<void> pumpEditDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EventEditDialog(
              initialDate: DateTime(2026, 1, 3),
              event: CalendarEvent(
                id: 1,
                title: '겨울방학 운영 계획',
                eventDate: '2026-01-03',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('EventEditDialog — AI로 보내기 게이팅 (고급 기능)', () {
    testWidgets('AI 자동화 공유가 OFF(기본)면 액션이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpEditDialog(tester);
      expect(find.text('AI로 보내기'), findsNothing);
    });

    testWidgets('AI 자동화 공유가 ON이면 액션이 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_task_share_enabled': true});
      await pumpEditDialog(tester);
      expect(find.text('AI로 보내기'), findsOneWidget);
    });

    testWidgets('탭하면 sharePositionOrigin과 함께 공유 호출(iPad 팝오버 앵커 필수)',
        (tester) async {
      SharedPreferences.setMockInitialValues({'ai_task_share_enabled': true});
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      MethodCall? shareCall;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          shareCall = call;
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      await pumpEditDialog(tester);
      await tester.tap(find.text('AI로 보내기'));
      await tester.pump();

      expect(shareCall?.method, 'share');
      final args = shareCall!.arguments as Map;
      expect(args['text'], contains('```json'));
      expect(args['originWidth'], isNotNull,
          reason: 'sharePositionOrigin 없으면 iPad에서 공유시트가 안 뜸');
    });
  });
}
