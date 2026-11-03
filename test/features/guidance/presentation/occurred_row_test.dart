import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/guidance/domain/guidance_content.dart';
import 'package:planroutine/features/guidance/domain/guidance_logic.dart';
import 'package:planroutine/features/guidance/domain/guidance_types.dart';
import 'package:planroutine/features/guidance/presentation/widgets/occurred_input.dart';
import 'package:planroutine/features/guidance/presentation/widgets/occurred_row.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('ko', null));

  final now = DateTime(2026, 11, 3, 10, 0);
  final at = DateTime(2026, 11, 2, 14, 30);

  Future<void> pump(
    WidgetTester tester, {
    OccurredPrecision precision = OccurredPrecision.exact,
    String? text,
    List<OccurredPrecision>? precisions,
    List<String>? texts,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OccurredRow(
          current: GuidanceContent(precision: precision, occurredAt: at, occurredText: text),
          now: now,
          createdLine: '기록 시각 · 저장할 때 자동으로 남아요',
          precision: precision,
          occurredAt: at,
          occurredText: text,
          onPrecision: (p) => precisions?.add(p),
          onAt: (_) {},
          onText: (t) => texts?.add(t),
        ),
      ),
    ));
  }

  testWidgets('요약은 formatOccurred 값, 오른쪽에 정밀도', (tester) async {
    await pump(tester);
    final c = GuidanceContent(occurredAt: at);
    expect(find.text(formatOccurred(c, now: now)), findsOneWidget);
    expect(find.text('정확히'), findsOneWidget);
    expect(find.text(GuidanceStrings.labelWhen), findsOneWidget);
  });

  testWidgets('행을 누르면 시트에 세그먼트와 기록 시각 줄', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(OccurredRow.rowKey));
    await tester.pumpAndSettle();
    expect(find.text('날짜만'), findsOneWidget);
    expect(find.text('기록 시각 · 저장할 때 자동으로 남아요'), findsOneWidget);
  });

  testWidgets('날짜만을 누르면 콜백 1회, 시트 안이 즉시 바뀐다', (tester) async {
    final precisions = <OccurredPrecision>[];
    await pump(tester, precisions: precisions);
    await tester.tap(find.byKey(OccurredRow.rowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(OccurredInput.timeKey), findsOneWidget);
    await tester.tap(find.text('날짜만'));
    await tester.pumpAndSettle();
    expect(precisions, [OccurredPrecision.date]);
    expect(find.byKey(OccurredInput.timeKey), findsNothing);
  });

  testWidgets('대략 글을 쓰고 끌어 닫아도 마지막 글이 올라갔다', (tester) async {
    final texts = <String>[];
    await pump(tester, texts: texts);
    await tester.tap(find.byKey(OccurredRow.rowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대략'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3월 초');
    await tester.pump();
    await tester.drag(find.text(GuidanceStrings.labelOccurred), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(texts.last, '3월 초');
  });

  testWidgets('대략 + 빈 글 요약은 시각 모름', (tester) async {
    await pump(tester, precision: OccurredPrecision.approx);
    expect(find.text(GuidanceStrings.occurredUnknown), findsOneWidget);
  });

  testWidgets('320pt에서 넘침 없음(행·시트)', (tester) async {
    await pump(tester, width: 320);
    await tester.tap(find.byKey(OccurredRow.rowKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
