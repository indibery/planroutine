import 'dart:io';

/// 소스 스캔 가드가 함께 쓰는 도구 — lib의 `.dart` 파일 모으기와 줄 주석 걷어내기.
///
/// 이 리포의 스캐너는 "언급"을 "사용"으로 오인한 적이 여러 번 있다(CLAUDE.md "스캐너는 언급과
/// 사용을 구별하지 못한다"). 그 규칙을 고칠 때 한 곳만 고치면 되도록 여기 둔다.

final _lineComment = RegExp(r'//.*$');

/// 줄 주석(`// …`)을 걷어낸 코드 부분.
String stripLineComment(String line) => line.replaceFirst(_lineComment, '');

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
