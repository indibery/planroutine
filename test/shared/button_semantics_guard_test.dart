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
  final detector = RegExp(
    r'\b(GestureDetector|InkWell|InkResponse|FloatingActionButton)\(',
  );
  final tapArg = RegExp(r'\bon(Tap|LongPress|DoubleTap|Pressed)\s*:');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!detector.hasMatch(stripLineComment(lines[i]))) continue;
    final after = lines.skip(i).take(10).map(stripLineComment).join('\n');
    if (!tapArg.hasMatch(after)) continue;
    final before = lines.skip(i < 10 ? 0 : i - 10).take(i < 10 ? i : 10);
    // 포맷하지 않은 파일은 `ButtonSemantics(label: …, child: InkWell(`처럼 한 줄에 쓴다.
    final sameLine = stripLineComment(
      lines[i],
    ).substring(0, detector.firstMatch(stripLineComment(lines[i]))?.start ?? 0);
    final wrapped =
        sameLine.contains('ButtonSemantics') ||
        before.map(stripLineComment).any((l) => l.contains('ButtonSemantics'));
    final excused = lines
        .skip(i < 3 ? 0 : i - 3)
        .take(i < 3 ? i : 3)
        .any((l) => l.contains('시맨틱스 예외:'));
    if (!wrapped && !excused) out.add('${i + 1}: ${lines[i].trim()}');
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
