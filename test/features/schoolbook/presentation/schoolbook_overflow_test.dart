import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

/// 긴 교실 이름 + 한 칸에 예약자 넷 — 체육 수업 전 휴대폰으로 보는 화면이라 좁은 폭과 큰 글자에서 넘치면 안 된다.
Map<String, Object?> _crowdedDay() => {
      'date': '2026-10-20',
      'periods': [
        {
          'id': 1,
          'name': '3교시',
          'start_time': '10:40',
          'end_time': '11:20',
          'archived': false,
          'remaining': 1,
          'fixed': [
            {'booker': '체육전담'},
          ],
          'bookings': [
            for (final (i, b) in ['5-1', '6-2', '방과후 돌봄 1반', '4-3'].indexed)
              {'id': i + 1, 'booker': b, 'cancel_reason': null, 'canceled_at': null},
          ],
        },
      ],
    };

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('폭 $width · 글자 $scale배에서 넘치지 않는다', (tester) async {
        final routes = defaultRoutes()
          ..['GET /api/rooms/'] = ((_) => jsonResponse([
                {'id': 1513, 'name': '3층 다목적실 겸 방과후 돌봄교실', 'capacity': 6},
              ]))
          ..['GET /api/rooms/1513/bookings/'] = ((_) => jsonResponse(_crowdedDay()));
        await pumpSchoolbook(tester,
            routes: routes, size: Size(width, 844), textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('방과후 돌봄 1반'), findsOneWidget);
      });
    }
  }
}
