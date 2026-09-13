// 채널 배선과 준비 신호.
//
// ⚠️ **준비 신호가 이 기능의 급소다.** 앱이 꺼진 상태에서 단축어를 누르면
// 시스템이 앱을 백그라운드로 띄우는데, Dart `main()`과 인텐트 `perform()`의
// 도달 순서가 **보장되지 않는다**(실측에서는 Dart가 1초 빨랐지만 1회 관측이다).
// 신호가 빠지면 Swift가 영원히 기다리거나 빈 결과를 돌려준다.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/core/app_intents/app_intents_bridge.dart';
import 'package:planroutine/core/app_intents/app_intents_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(AppIntentsContract.channelName);

  late ProviderContainer container;
  late List<MethodCall> toSwift;

  setUp(() {
    container = ProviderContainer();
    toSwift = [];
    // Dart → Swift 방향을 가로채 `ready`가 실제로 나가는지 본다.
    messenger.setMockMethodCallHandler(channel, (call) async {
      toSwift.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    container.dispose();
  });

  test('배선하면 준비 신호를 보낸다', () async {
    await AppIntentsBridge.attach(container);

    expect(
      toSwift.map((c) => c.method),
      contains(AppIntentsContract.methodReady),
      reason: '이 신호가 없으면 Swift가 인텐트를 처리하지 못한다',
    );
  });

  test('배선 뒤에는 Swift에서 온 호출을 받는다', () async {
    await AppIntentsBridge.attach(container);

    final reply = await messenger.handlePlatformMessage(
      AppIntentsContract.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall(AppIntentsContract.methodQuery, {
          AppIntentsContract.argRange: 'today',
        }),
      ),
      (_) {},
    );

    expect(reply, isNotNull, reason: '핸들러가 붙지 않아 응답이 없다');
  });
}
