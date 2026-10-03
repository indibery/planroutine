import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 지도 기록 화면의 대화상자·시간 고르기는 탭의 중첩 내비게이터에 떠야 한다. 루트에 뜨면
/// 앱이 잠겨도 덮개 **위**에 남아 내용(제목·이름)이 보인다.
void main() {
  const calls = ['showDialog(', 'showDialog<', 'ConfirmDialog.show(', 'showDatePicker(', 'showTimePicker('];

  test('지도 기록 화면의 대화상자는 모두 useRootNavigator: false다', () {
    final files = Directory('lib/features/guidance/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final call in calls) {
        var i = src.indexOf(call);
        while (i >= 0) {
          final window = src.substring(i, (i + 700).clamp(0, src.length));
          expect(window.contains('useRootNavigator: false'), isTrue, reason: '${f.path} @$i $call');
          i = src.indexOf(call, i + call.length);
        }
      }
    }
  });
}
