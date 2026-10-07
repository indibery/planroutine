// 최적화된 리소스 축소(Play 권고 "R8 최적화로 메모리 및 성능 개선", 2026-10-07).
//
// `android.r8.optimizedResourceShrinking`은 AGP 8.12·8.13에서만 뜻이 있다 — 그보다 낮으면 조용히
// 무시되고, AGP 9부터는 기본값이라 필요 없다. 그래서 설정 한 줄과 AGP 버전을 **짝으로** 지킨다.
// 실제로 축소가 맞게 도는지(알림 아이콘·Gson 모델)는 release 스모크의 몫이다 — 이 가드는 설정만 본다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final props = File('android/gradle.properties').readAsStringSync();
  final settings = File('android/settings.gradle.kts').readAsStringSync();

  (int, int) agp() {
    final m = RegExp(
      r'id\("com\.android\.application"\) version "(\d+)\.(\d+)',
    ).firstMatch(settings);
    expect(m, isNotNull, reason: 'settings.gradle.kts에서 AGP 버전을 찾지 못했다');
    return (int.parse(m?.group(1) ?? '0'), int.parse(m?.group(2) ?? '0'));
  }

  test('AGP 8.12~8.x에서는 최적화된 리소스 축소를 켠다', () {
    final (major, minor) = agp();
    if (major >= 9) return; // AGP 9부터는 기본값이다.
    expect(
      major == 8 && minor >= 12,
      isTrue,
      reason: '이 설정은 AGP 8.12부터 동작한다 — 지금은 $major.$minor',
    );
    expect(
      RegExp(
        r'^android\.r8\.optimizedResourceShrinking=true\s*$',
        multiLine: true,
      ).hasMatch(props),
      isTrue,
    );
  });

  test('알림 아이콘을 지키는 keep 규칙이 남아 있다 — 축소기가 바뀌어도 지운다', () {
    final keep = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    expect(keep, contains('@drawable/ic_notification'));
  });
}
