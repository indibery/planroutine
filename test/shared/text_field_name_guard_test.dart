import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

/// 입력칸은 이름이 있어야 한다 — `InputDecoration`의 `labelText`·`hintText`·`label`, 또는
/// 바로 위의 `Semantics(label:)`.
///
/// 지도 기록 작성 화면은 칸 위에 `제목` 같은 글자를 따로 두고 칸 자체에는 이름을 주지 않아,
/// 시뮬레이터 자동화가 다섯 칸을 이름 없는 텍스트 필드로 읽고 위치로만 가렸다(2026-10-04).
/// 겉모양을 바꾸지 않으려고 `Semantics(label:)`로 감싼다 — Flutter 트리에서 그 이름이 입력칸
/// 노드 자체에 붙는 것을 확인했다(`textField` 플래그·값·편집 동작이 그대로다).
List<String> findUnnamedTextFields(String source) {
  final lines = source.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = stripLineComment(lines[i]);
    final m = RegExp(r'\b(TextField|TextFormField)\(').firstMatch(line);
    if (m == null) continue;
    final block = lines.skip(i).take(15).map(stripLineComment).join('\n');
    final named = RegExp(r'\b(labelText|hintText|label):').hasMatch(block);
    final before = [
      line.substring(0, m.start),
      ...lines
          .skip(i < 3 ? 0 : i - 3)
          .take(i < 3 ? i : 3)
          .map(stripLineComment),
    ];
    final wrapped = before.any((l) => l.contains('Semantics('));
    if (!named && !wrapped) out.add('${i + 1}: ${lines[i].trim()}');
  }
  return out;
}

void main() {
  test('스캐너: 이름 없는 칸을 잡고, 이름 있거나 감싼 칸은 통과시킨다', () {
    expect(
      findUnnamedTextFields('''
    TextField(controller: _place),'''),
      hasLength(1),
    );
    expect(
      findUnnamedTextFields('''
    TextField(
      decoration: InputDecoration(hintText: '메모'),
    ),'''),
      isEmpty,
    );
    expect(
      findUnnamedTextFields('''
    Semantics(
      label: '장소',
      child: TextField(controller: _place),
    ),'''),
      isEmpty,
    );
  });

  test('lib의 입력칸은 전부 이름이 있다', () {
    final offenders = <String>[
      for (final f in libDartFiles())
        for (final hit in findUnnamedTextFields(f.readAsStringSync()))
          '${f.path}:$hit',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
