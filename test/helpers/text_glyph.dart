import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [text] 안의 `RichText`가 실제로 쓰는 글자 스타일(테마·DefaultTextStyle까지 합친 값).
TextStyle? textStyleOf(WidgetTester tester, Finder text) => tester
    .widget<RichText>(
      find.descendant(of: text, matching: find.byType(RichText)),
    )
    .text
    .style;

/// 글자가 실제로 그려진 가로 범위(전역 좌표의 왼쪽·오른쪽 끝).
///
/// `tester.getCenter(find.text(...))`는 **위젯 상자**의 가운데다. 가로로 늘어난 칸
/// (`CrossAxisAlignment.stretch`) 안의 `Text`는 상자가 칸 전체라, 글자가 왼쪽에 붙어 있어도
/// 상자 가운데는 화면 가운데가 된다 — 버스 확인 시트 제목 가드가 그렇게 헛통과했다.
(double, double) _glyphSpan(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  final left = boxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);
  final right = boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b);
  return (
    paragraph.localToGlobal(Offset(left, 0)).dx,
    paragraph.localToGlobal(Offset(right, 0)).dx,
  );
}

/// 글자가 실제로 그려진 범위의 가로 가운데. 시트 제목 가운데 정렬을 잴 때 쓴다.
double glyphCenterX(WidgetTester tester, Finder text) {
  final (left, right) = _glyphSpan(tester, text);
  return (left + right) / 2;
}

/// 글자가 실제로 시작하는 가로 위치. 행끼리 제목 시작선이 맞는지 볼 때 쓴다.
double glyphLeftX(WidgetTester tester, Finder text) =>
    _glyphSpan(tester, text).$1;
