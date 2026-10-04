import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

/// 직접 만든 터치 영역은 `ButtonSemantics`로 감싼다(`lib/shared/widgets/button_semantics.dart`).
///
/// `GestureDetector`·`InkWell`·`InkResponse`에 탭 콜백만 달면 시뮬레이터 자동화 두 도구가
/// 그 자리를 글자로 읽어 누를 대상으로 보지 않는다(2026-10-04, 21곳을 한꺼번에 고쳤다).
///
/// 버튼이 아닌 터치 영역(빈 곳을 눌러 입력칸에 커서를 주는 것, 안에 버튼을 따로 둔 행)은
/// 바로 위 줄에 `// 시맨틱스 예외: <이유>`를 적는다.
///
/// `FloatingActionButton`도 본다 — Flutter 트리에는 이름이 있어도 mobile MCP가 합쳐진 노드의
/// 이름을 놓쳤다(지도 기록 `+`). 새 FAB을 추가할 때 같은 회귀를 막는다.
///
/// 주석은 걷어내고 본다 — 이 리포의 스캐너는 언급을 사용으로 오인한 적이 여러 번 있다.
List<String> findUnwrapped(String source) {
  final lines = source.split('\n');
  final code = lines.map(stripLineComment).join('\n');
  final detector = RegExp(
    r'\b(GestureDetector|InkWell|InkResponse|FloatingActionButton)\(',
  );
  final tapArg = RegExp(r'\bon(Tap|LongPress|DoubleTap|Pressed)\s*:');
  final out = <String>[];
  for (final m in detector.allMatches(code)) {
    final line = '\n'.allMatches(code.substring(0, m.start)).length;
    final after = lines.skip(line).take(10).map(stripLineComment).join('\n');
    if (!tapArg.hasMatch(after)) continue;
    // 바로 감싸는 호출이 ButtonSemantics이고, 이 감지기가 그 `child:`여야 한다.
    final wrapper = enclosingChildOf(code, m.start);
    final wrapped = wrapper != null && wrapper.startsWith('ButtonSemantics');
    final excused = lines
        .skip(line < 3 ? 0 : line - 3)
        .take(line < 3 ? line : 3)
        .any((l) => l.contains('시맨틱스 예외:'));
    if (!wrapped && !excused) out.add('${line + 1}: ${lines[line].trim()}');
  }
  return out;
}

final _iconButton = RegExp(r'\bIconButton(\.\w+)?\(');

/// 아이콘만 있는 `IconButton`은 아이콘에 이름을 준다(`Icon(semanticLabel:)`). 말풍선은 쓰지 않는다
/// (`no_tooltip_guard_test.dart`). 정류장 검색의 돋보기가 이름 없는 버튼으로 남아 있었다.
List<String> findUnnamedIconButtons(String source) {
  final lines = source.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!_iconButton.hasMatch(stripLineComment(lines[i]))) continue;
    final block = lines.skip(i).take(12).map(stripLineComment).join('\n');
    if (!block.contains('semanticLabel')) {
      out.add('${i + 1}: ${lines[i].trim()}');
    }
  }
  return out;
}

void main() {
  group('스캐너 자체', () {
    test('감싸지 않은 탭 영역을 잡는다', () {
      expect(
        findUnwrapped('''
    return GestureDetector(
      onTap: onTap,
      child: Text('x'),
    );'''),
        hasLength(1),
      );
    });

    test('ButtonSemantics로 감싸면 통과한다', () {
      expect(
        findUnwrapped('''
    return ButtonSemantics(
      label: '정류장 선택',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Text('x'),
      ),
    );'''),
        isEmpty,
      );
    });

    test('바로 위에 다른 것을 감싼 ButtonSemantics가 있어도 맨 감지기는 잡는다', () {
      // 예전 판정은 "앞 10줄 안에 ButtonSemantics라는 글자가 있는가"라 이 경우를 놓쳤다
      // (verifier가 짚었다, 2026-10-04). 지금은 바로 감싸는 호출이 ButtonSemantics인지 본다.
      expect(
        findUnwrapped('''
    Column(children: [
      ButtonSemantics(label: '저장', onTap: save, child: const Text('저장')),
      GestureDetector(
        onTap: delete,
        child: const Text('삭제'),
      ),
    ]);'''),
        hasLength(1),
      );
    });

    test('ButtonSemantics의 child가 아니라 다른 인자 안에 있으면 잡는다', () {
      expect(
        findUnwrapped('''
    ButtonSemantics(
      label: '정류장',
      onTap: pick,
      child: Row(children: [
        GestureDetector(onTap: other, child: const Text('x')),
      ]),
    );'''),
        hasLength(1),
      );
    });

    test('한 줄에 감싼 것도 통과한다', () {
      expect(
        findUnwrapped('''
        : ButtonSemantics(label: x, onTap: open, child: InkWell(
            onTap: open,
            child: Text('x'),
          )),'''),
        isEmpty,
      );
    });

    test('FloatingActionButton도 감싸야 한다', () {
      const fab = '''
      floatingActionButton: FloatingActionButton(
        onPressed: add,
        child: const Icon(Icons.add),
      ),''';
      expect(findUnwrapped(fab), hasLength(1));
      expect(
        findUnwrapped('''
      floatingActionButton: ButtonSemantics(
        label: '새 기록',
        onTap: add,
        child: FloatingActionButton(
          onPressed: add,
          child: const Icon(Icons.add),
        ),
      ),'''),
        isEmpty,
      );
    });

    test('주석 속 언급과 탭 없는 감지기는 무시한다', () {
      expect(
        findUnwrapped('''
    // `GestureDetector(`는 onTap: 만 주면 버튼이 아니다
    return GestureDetector(
      onVerticalDragStart: (_) {},
      child: Text('x'),
    );'''),
        isEmpty,
      );
    });

    test('예외 표시가 있으면 통과한다', () {
      expect(
        findUnwrapped('''
    // 시맨틱스 예외: 빈 곳을 눌러 입력칸에 커서를 줄 뿐이다
    GestureDetector(
      onTap: focus.requestFocus,
      child: Text('x'),
    ),'''),
        isEmpty,
      );
    });
  });

  test('스캐너: 이름 없는 IconButton을 잡고 이름 있는 것은 통과시킨다', () {
    expect(
      findUnnamedIconButtons('''
    IconButton(
      icon: const Icon(Icons.search),
      onPressed: search,
    ),'''),
      hasLength(1),
    );
    expect(
      findUnnamedIconButtons('''
    IconButton(
      icon: const Icon(Icons.search, semanticLabel: '검색'),
      onPressed: search,
    ),'''),
      isEmpty,
    );
  });

  test('lib의 IconButton은 전부 아이콘에 이름이 있다', () {
    final offenders = <String>[
      for (final f in libDartFiles())
        for (final hit in findUnnamedIconButtons(f.readAsStringSync()))
          '${f.path}:$hit',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('lib의 직접 만든 터치 영역은 전부 ButtonSemantics로 감쌌다', () {
    final offenders = <String>[
      for (final f in libDartFiles())
        for (final hit in findUnwrapped(f.readAsStringSync())) '${f.path}:$hit',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
