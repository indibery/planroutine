// Play 권고 "일부 사용자에게는 더 넓은 화면이 표시되지 않을 수 있습니다"(edge-to-edge, 2026-10-09).
//
// Android 15+는 OS가 강제로 확장하지만 14 이하는 앱이 켜야 한다. Flutter 엔진은 3.47.x까지도
// `EdgeToEdge.enable()`을 부르지 않아(flutter/flutter#192921) 경고가 남는다 — 그래서 앱이 직접 부른다.
// 이 가드는 소스만 본다(Kotlin은 위젯 테스트로 못 밟는다). 실제 화면은 API 34·36 에뮬레이터로 확인했다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 주석을 걷어낸 코드 — 스캐너는 낱말의 언급과 사용을 구별하지 못한다(리포 함정).
String _codeOnly(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  final src = _codeOnly(
    File(
      'android/app/src/main/kotlin/com/planroutine/app/MainActivity.kt',
    ).readAsStringSync(),
  );

  test('MainActivity가 onCreate에서 enableEdgeToEdge()를 부른다', () {
    expect(src, contains('import androidx.activity.enableEdgeToEdge'));
    expect(src, contains('enableEdgeToEdge()'));
  });

  test('super.onCreate보다 먼저 부른다 — 창이 만들어지기 전에 켜야 한다(공식 문서 순서)', () {
    final enable = src.indexOf('enableEdgeToEdge()');
    final superCreate = src.indexOf('super.onCreate(');
    expect(superCreate, greaterThan(0));
    expect(enable, lessThan(superCreate));
  });
}
