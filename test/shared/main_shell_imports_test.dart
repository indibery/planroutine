// MainShell(shared/widgets)은 기능(features/)에 닿지 않는다 — 등록부(module_catalog)는
// 버스·포스트잇 같은 기능 화면을 들고 있으므로 고정 탭 상수만 따로 가져온다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main_shell.dart는 module_catalog를 import하지 않는다', () {
    final src = File('lib/shared/widgets/main_shell.dart').readAsStringSync();
    expect(src.contains('module_catalog.dart'), isFalse);
    expect(src.contains('fixed_tabs.dart'), isTrue);
  });

  test('fixed_tabs.dart는 features를 import하지 않는다', () {
    final src = File('lib/core/modules/fixed_tabs.dart').readAsStringSync();
    expect(src.contains('features/'), isFalse);
  });
}
