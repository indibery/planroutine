import 'dart:io';

/// 소스 스캔 가드가 함께 쓰는 도구 — lib의 `.dart` 파일 모으기와 줄 주석 걷어내기.
///
/// 이 리포의 스캐너는 "언급"을 "사용"으로 오인한 적이 여러 번 있다(CLAUDE.md "스캐너는 언급과
/// 사용을 구별하지 못한다"). 그 규칙을 고칠 때 한 곳만 고치면 되도록 여기 둔다.

final _lineComment = RegExp(r'//.*$');

/// 줄 주석(`// …`)을 걷어낸 코드 부분.
String stripLineComment(String line) => line.replaceFirst(_lineComment, '');

/// [path] 파일의 코드에서 줄 주석을 걷어낸 전문.
String strippedCode(String path) =>
    File(path).readAsLinesSync().map(stripLineComment).join('\n');

/// lib 아래 모든 `.dart` 파일.
///
/// 경로가 틀려 아무것도 읽지 않으면 가드가 헛통과하므로, 너무 적으면 여기서 바로 실패한다.
List<File> libDartFiles() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  if (files.length < 100) {
    throw StateError('lib에서 .dart 파일을 ${files.length}개만 찾았다 — 실행 경로를 확인하라');
  }
  return files;
}

/// [code]의 [index] 위치를 **바로 감싸는** 호출 이름 — 그 위치가 그 호출의 `child:` 인자일 때만.
///
/// 뒤로 훑으며 아직 닫히지 않은 가장 안쪽 괄호를 찾는다. 그 괄호가 `(`이고 바로 앞이 식별자이며
/// 그 사이 마지막 인자가 `child:`이면 그 식별자(`ButtonSemantics`, `ButtonSemantics.gesture` 등)를
/// 돌려준다. 목록(`[`)·맵(`{`) 안이거나 `child:`가 아닌 인자 안이면 null.
///
/// 문자열 안의 괄호는 고려하지 않는다 — 위젯 트리 소스에서 그런 경우가 드물고, 생기면 가드가
/// 오히려 실패(=사람이 보게 됨) 쪽으로 기운다. 주석은 [stripLineComment]로 미리 걷어낸 코드를 넘긴다.
String? enclosingChildOf(String code, int index) {
  var depth = 0;
  for (var j = index - 1; j >= 0; j--) {
    final c = code[j];
    if (c == ')' || c == ']' || c == '}') {
      depth++;
    } else if (c == '(' || c == '[' || c == '{') {
      if (depth > 0) {
        depth--;
        continue;
      }
      if (c != '(') return null;
      final between = code.substring(j + 1, index);
      if (!_childArgAtEnd.hasMatch(_topLevel(between))) return null;
      return _callName.firstMatch(code.substring(0, j))?.group(1);
    }
  }
  return null;
}

final _childArgAtEnd = RegExp(r'(^|,)\s*child:\s*$');
final _callName = RegExp(r'([A-Za-z_][\w.]*)\s*$');

/// 괄호 안쪽(중첩된 호출 인자)을 걷어낸, 한 호출의 최상위 인자 글자만.
String _topLevel(String args) {
  final out = StringBuffer();
  var depth = 0;
  for (final c in args.split('')) {
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 0) {
      out.write(c);
    }
  }
  return out.toString();
}
