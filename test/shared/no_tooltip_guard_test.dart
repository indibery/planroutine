import 'package:flutter_test/flutter_test.dart';

import '../helpers/source_scan.dart';

/// 버튼 이름은 `tooltip`이 아니라 `label`(`Icon(semanticLabel:)` 등)로 준다.
///
/// - **말풍선은 이 앱에서 볼 일이 없다.** 터치 화면에서는 길게 눌러야 뜨고, 마우스·트랙패드를
///   붙이는 iPad는 지원하지 않는다(`TARGETED_DEVICE_FAMILY = "1"`).
/// - **mobile MCP는 `tooltip` 속성을 읽지 않는다.** 이름이 tooltip에만 있으면 그 버튼이 이름
///   없는 `Button`으로 나와, 휴지통의 `복구`와 `영구 삭제`를 위치로만 골라야 했다
///   (2026-10-04). label과 tooltip을 둘 다 주면 `snapshot_ui`에 `이전 달 이전 달`처럼
///   두 번 붙는다.
///
/// 주석은 걷어내고 검사한다 — 이 리포의 스캐너는 "언급"을 "사용"으로 오인한 적이 여러 번 있다.
final _tooltip = RegExp(r'\btooltip:|\bTooltip\(');

/// `tooltip:`·`Tooltip(`을 쓴 줄(주석 속 언급은 빼고).
List<String> findTooltips(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_tooltip.hasMatch(stripLineComment(lines[i])))
        '${i + 1}: ${lines[i].trim()}',
  ];
}

void main() {
  test('lib 코드에 tooltip이 없다', () {
    final offenders = <String>[
      for (final f in libDartFiles())
        for (final hit in findTooltips(f.readAsStringSync())) '${f.path}:$hit',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          '버튼 이름은 tooltip 대신 label로 준다(IconButton이면 '
          'Icon(semanticLabel:)). 이유는 이 파일 주석 참고.\n${offenders.join('\n')}',
    );
  });

  test('스캐너: 실제 사용은 잡고 주석 속 언급은 무시한다', () {
    expect(
      findTooltips("  IconButton(tooltip: '검색', onPressed: f),"),
      hasLength(1),
    );
    expect(findTooltips('  Tooltip(message: x, child: y),'), hasLength(1));
    expect(findTooltips('  // tooltip: 은 쓰지 않는다 — Tooltip( 도'), isEmpty);
  });
}
