import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planroutine/features/schoolbook/data/sb_result.dart';
import 'package:planroutine/features/schoolbook/data/schoolbook_api_client.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_models.dart';
import 'package:planroutine/features/schoolbook/domain/schoolbook_settings.dart';
import 'package:planroutine/features/schoolbook/presentation/providers/schoolbook_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _info = SchoolInfo(code: 'abcdefghijk12', name: '플랜테스트', periodCount: 7);

void main() {
  late int calls;

  ProviderContainer containerWith() {
    calls = 0;
    final client = SchoolbookApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    final c = ProviderContainer(overrides: [
      schoolbookApiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> saved() async =>
      (await SharedPreferences.getInstance()).getString(schoolbookSettingsPrefsKey);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('설정이 없는데 비밀번호만 남아 있으면(iOS에서 앱을 지웠다 다시 설치) 지운다', () async {
    // iOS Keychain은 앱을 지워도 남는다 — 비밀번호는 연결 뒤에만 생기므로 설정 없이 남은 것은 옛 설치의 것이다
    FlutterSecureStorage.setMockInitialValues({'schoolbook_password_v1': '1234'});
    final c = containerWith();
    await c.read(schoolbookSettingsProvider.future);
    expect(await c.read(schoolbookPasswordStoreProvider).read(), isNull);
  });

  test('연결된 설정이 있으면 비밀번호를 그대로 둔다', () async {
    SharedPreferences.setMockInitialValues({
      schoolbookSettingsPrefsKey: '{"code":"abcdefghijk12","schoolName":"플랜테스트"}',
    });
    FlutterSecureStorage.setMockInitialValues({'schoolbook_password_v1': '1234'});
    final c = containerWith();
    await c.read(schoolbookSettingsProvider.future);
    expect(await c.read(schoolbookPasswordStoreProvider).read(), '1234');
  });

  test('disconnect는 예약 비밀번호도 지운다', () async {
    final c = containerWith();
    await c.read(schoolbookSettingsProvider.future);
    await c.read(schoolbookPasswordStoreProvider).write('1234');
    await c.read(schoolbookSettingsProvider.notifier).disconnect();
    expect(await c.read(schoolbookPasswordStoreProvider).read(), isNull);
  });

  test('connect는 코드와 학교 이름을 저장하고 마지막 교실을 비운다', () async {
    final c = containerWith();
    final n = c.read(schoolbookSettingsProvider.notifier);
    await c.read(schoolbookSettingsProvider.future);
    await n.setLastRoom(12);
    await n.connect(_info);
    final json = jsonDecode((await saved())!) as Map<String, dynamic>;
    expect(json['code'], 'abcdefghijk12');
    expect(json['schoolName'], '플랜테스트');
    expect(json['lastRoomId'], isNull);
  });

  test('예약자 이름은 앞뒤 공백을 정리하고, 비우면 null', () async {
    final c = containerWith();
    final n = c.read(schoolbookSettingsProvider.notifier);
    await c.read(schoolbookSettingsProvider.future);
    await n.setBooker(' 체육전담 ');
    expect(c.read(schoolbookSettingsProvider).value?.booker, '체육전담');
    await n.setBooker('  ');
    expect(c.read(schoolbookSettingsProvider).value?.booker, isNull);
  });

  test('disconnect는 저장 키를 지운다', () async {
    final c = containerWith();
    final n = c.read(schoolbookSettingsProvider.notifier);
    await c.read(schoolbookSettingsProvider.future);
    await n.connect(_info);
    await n.disconnect();
    expect(await saved(), isNull);
    expect(c.read(schoolbookSettingsProvider).value, SchoolbookSettings.empty);
  });

  test('손상된 저장값은 빈 설정', () async {
    SharedPreferences.setMockInitialValues({schoolbookSettingsPrefsKey: '{'});
    final c = containerWith();
    expect(await c.read(schoolbookSettingsProvider.future), SchoolbookSettings.empty);
  });

  test('예약을 거쳐도 저장값에 비밀번호가 없다', () async {
    final c = containerWith();
    final n = c.read(schoolbookSettingsProvider.notifier);
    await c.read(schoolbookSettingsProvider.future);
    await n.connect(_info);
    await c.read(schoolbookApiClientProvider).book('abcdefghijk12', 1,
        date: DateTime(2026, 10, 20), periodIds: [1], booker: '체육전담', password: '1234');
    await n.setBooker('체육전담');
    final raw = (await saved())!;
    expect(raw, isNot(contains('password')));
    expect(raw, isNot(contains('1234')));
  });

  test('연결 전에는 교실 목록을 부르지 않는다', () async {
    final c = containerWith();
    final r = await c.read(schoolbookRoomsProvider.future);
    expect(r.outcome, SbOutcome.unauthorized);
    expect(calls, 0);
  });

  test('연결 뒤 교실 목록과 하루 예약을 부른다', () async {
    final c = containerWith();
    await c.read(schoolbookSettingsProvider.future);
    await c.read(schoolbookSettingsProvider.notifier).connect(_info);
    final sub = c.listen(schoolbookRoomsProvider, (_, _) {});
    addTearDown(sub.close);
    final r = await c.read(schoolbookRoomsProvider.future);
    expect(r.outcome, SbOutcome.ok);
    expect(calls, 1);
  });
}
