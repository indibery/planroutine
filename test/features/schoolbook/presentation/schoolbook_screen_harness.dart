import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:planroutine/features/schoolbook/presentation/screens/schoolbook_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_server.dart';

const testCode = 'abcdefghijk12';

/// 픽스처의 날(화요일). 이날 아침을 '지금'으로 두면 처음 화면이 이날이다.
final fixtureDay = DateTime(2026, 10, 20);

typedef Routes = Map<String, FutureOr<http.Response> Function(http.Request)>;

/// 테스트 학교 픽스처로 채운 기본 경로. 다목적실(1513)은 체육관 응답을 빌려 쓴다.
Routes defaultRoutes() => {
      'GET /api/rooms/': (_) => fixtureResponse('rooms'),
      'GET /api/rooms/1511/bookings/': (_) => fixtureResponse('day_gym'),
      'GET /api/rooms/1512/bookings/': (_) => fixtureResponse('day_science'),
      'GET /api/rooms/1513/bookings/': (_) => fixtureResponse('day_gym'),
    };

/// 연결된 상태로 장소 예약 탭을 띄운다.
Future<FakeSchoolbook> pumpSchoolbook(
  WidgetTester tester, {
  Routes? routes,
  int? lastRoomId,
  String? booker,
  DateTime? now,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({
    schoolbookSettingsPrefsKey: jsonEncode({
      'code': testCode,
      'schoolName': '플랜테스트',
      'lastRoomId': lastRoomId,
      'booker': booker,
    }),
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final server = FakeSchoolbook(routes ?? defaultRoutes());
  final clock = now ?? DateTime(2026, 10, 20, 8);
  await tester.pumpWidget(ProviderScope(
    overrides: [schoolbookApiClientProvider.overrideWithValue(server.client())],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: SchoolbookScreen(clock: () => clock),
    ),
  ));
  await settle(tester);
  return server;
}

/// 가짜 요청과 저장이 끝날 때까지 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}
