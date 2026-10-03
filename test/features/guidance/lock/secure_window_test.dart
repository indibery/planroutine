import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/presentation/lock/secure_window.dart';

void main() {
  late List<bool> calls;
  PlatformSecureWindow make({bool android = true, bool ios = false}) =>
      PlatformSecureWindow(isAndroid: android, isIOS: ios, invoke: (on) async => calls.add(on));

  setUp(() => calls = []);

  test('테마 재생성처럼 true,true,false로 겹치면 플래그를 끄지 않고, 마지막 false에서 끈다', () async {
    final w = make();
    await w.setSecure(true); // 옛 게이트
    await w.setSecure(true); // 새 게이트 initState
    await w.setSecure(false); // 옛 게이트 dispose
    expect(calls, [true], reason: '새 게이트가 화면에 있으니 꺼지면 안 된다');
    await w.setSecure(false); // 새 게이트 dispose
    expect(calls, [true, false]);
  });

  test('0 아래로 내려가지 않는다', () async {
    final w = make();
    await w.setSecure(false);
    expect(calls, isEmpty);
    await w.setSecure(true);
    expect(calls, [true]);
  });

  // 의도를 넓혔다(2026-10-03): iOS도 같은 채널을 부른다(앱 전환기 가림막). 이 테스트는 이제
  // "안드로이드·iOS 어느 쪽도 아니면"을 본다.
  test('안드로이드가 아니면 아무 호출도 없다', () async {
    final w = make(android: false, ios: false);
    await w.setSecure(true);
    await w.setSecure(false);
    expect(calls, isEmpty);
  });

  test('iOS에서도 같은 참조 카운트로 채널을 부른다(앱 전환기 가림막)', () async {
    final w = make(android: false, ios: true);
    await w.setSecure(true);
    await w.setSecure(true);
    await w.setSecure(false);
    expect(calls, [true]);
    await w.setSecure(false);
    expect(calls, [true, false]);
  });
}
