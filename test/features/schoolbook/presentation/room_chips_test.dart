import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/shared/widgets/pill_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planroutine/features/schoolbook/presentation/widgets/room_chips.dart';

import '../fake_server.dart';
import 'schoolbook_screen_harness.dart';

/// 장소가 8곳 이상인 학교 — 한 줄에서 옆으로 민다(사용자 결정).
Routes _manyRooms() {
  final rooms = [
    for (var i = 1; i <= 10; i++) {'id': 2000 + i, 'name': '특별실 $i호', 'capacity': 1},
  ];
  return defaultRoutes()
    ..['GET /api/rooms/'] = ((_) => jsonResponse(rooms))
    ..['GET /api/rooms/2010/bookings/'] = ((_) => fixtureResponse('day_gym'))
    ..['GET /api/rooms/2001/bookings/'] = ((_) => fixtureResponse('day_gym'));
}

void main() {
  testWidgets('기억한 교실이 줄 끝에 있어도 열었을 때 보인다', (tester) async {
    await pumpSchoolbook(tester, routes: _manyRooms(), lastRoomId: 2010);
    expect(find.byKey(RoomChips.chipKey(2010)).hitTestable(), findsOneWidget);
  });

  testWidgets('오른쪽에 칩이 더 있으면 끝을 흐리게 알린다', (tester) async {
    await pumpSchoolbook(tester, routes: _manyRooms(), lastRoomId: 2001);
    expect(find.byKey(RoomChips.moreRightKey), findsOneWidget);
    expect(find.byKey(RoomChips.moreLeftKey), findsNothing);
  });

  testWidgets('끝까지 밀면 오른쪽 흐림이 사라지고 왼쪽에 생긴다', (tester) async {
    await pumpSchoolbook(tester, routes: _manyRooms(), lastRoomId: 2001);
    await tester.drag(find.byType(RoomChips), const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(RoomChips.moreRightKey), findsNothing);
    expect(find.byKey(RoomChips.moreLeftKey), findsOneWidget);
  });

  testWidgets('최근에 들어간 장소가 앞에 온다', (tester) async {
    await pumpSchoolbook(tester, recentRoomIds: [1512, 1511]);
    final chips = tester.widgetList<PillChip>(find.byType(PillChip)).map((c) => c.label).toList();
    expect(chips, ['과학실', '체육관', '3층 다목적실 겸 방과후 돌봄교실']);
  });

  testWidgets('칩을 눌러도 지금 화면의 순서는 그대로, 다음에 열 때 앞으로 온다', (tester) async {
    await pumpSchoolbook(tester, recentRoomIds: [1512, 1511]);
    await tester.tap(find.byKey(RoomChips.chipKey(1513)));
    await settle(tester);
    List<String> labels() =>
        tester.widgetList<PillChip>(find.byType(PillChip)).map((c) => c.label).toList();
    expect(labels().first, '과학실');
    final raw = (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);
    expect((jsonDecode(raw ?? '{}') as Map)['recentRoomIds'], [1513, 1512, 1511]);
  });

  testWidgets('교실이 적어 한 줄에 다 들어가면 흐림이 없다', (tester) async {
    final routes = defaultRoutes()
      ..['GET /api/rooms/'] = ((_) => jsonResponse([
            {'id': 1511, 'name': '체육관', 'capacity': 1},
          ]));
    await pumpSchoolbook(tester, routes: routes, lastRoomId: 1511);
    expect(find.byKey(RoomChips.moreRightKey), findsNothing);
    expect(find.byKey(RoomChips.moreLeftKey), findsNothing);
  });
}
