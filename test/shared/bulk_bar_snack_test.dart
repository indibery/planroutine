// 입력 탭에서 뜨는 스낵바는 **하단 일괄 확정 바를 가리지 않는다.**
//
// 기본값(`SnackBarBehavior.fixed`)이 앉는 자리가 정확히 그 pill이라, 4초 동안
// 확정을 누를 수 없다(사용자 신고 2026-08-14, **2026-09-03 재신고**).
//
// ⚠️ **재신고의 정체는 회귀가 아니었다.** 2026-08-14 수정은 헬퍼를
// `ai_photo_flow.dart`의 **private 함수**로 가뒀고, AI 붙여넣기 경로만 그것을 썼다.
// 다른 두 호출부는 여전히 맨 `SnackBar`를 만들고 있었다:
//
//   ① AI 붙여넣기            — 고쳐짐
//   ② CSV 등록 완료          — 안 고쳐짐 ← 사용자가 만난 것
//   ③ ← 스와이프 삭제 되돌리기 — 안 고쳐짐 ← 더 나쁘다(`되돌리기` 버튼을 못 누른다)
//
// 가드도 `photo_input_hero_test.dart` 하나뿐이라 ①만 봤다. 그래서 헬퍼를
// `shared/`로 올리고 **이 파일이 세 경로를 함께** 지킨다.
//
// 검사 대상은 소스 문자열이 아니라 **실제로 만들어진 `SnackBar` 위젯**이다 —
// 다른 방식으로 같은 결함을 만들어도(`margin`을 직접 주는 등) 값이 어긋나면 잡힌다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_sizes.dart';
import 'package:planroutine/shared/bulk_bar_snack.dart';

/// 스낵바가 일괄 확정 바를 비켜 있는지.
void expectClearsBulkBar(WidgetTester tester, String which) {
  final snack = tester.widget<SnackBar>(find.byType(SnackBar));
  expect(
    snack.behavior,
    SnackBarBehavior.floating,
    reason: '$which — fixed는 화면 맨 아래에 앉고 그 자리가 일괄 확정 pill이다',
  );
  final bottom = snack.margin?.resolve(TextDirection.ltr).bottom;
  expect(bottom, isNotNull, reason: '$which — floating이어도 여백이 없으면 pill 위에 겹친다');
  expect(
    bottom,
    greaterThanOrEqualTo(AppSizes.bulkRegisterBarHeight),
    reason:
        '$which — 아래 여백 $bottom 이 바 높이 '
        '${AppSizes.bulkRegisterBarHeight}보다 작다',
  );
}

Future<void> _pumpAndShow(
  WidgetTester tester,
  void Function(BuildContext) show,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => show(context),
            child: const Text('띄우기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('띄우기'));
  await tester.pump();
}

void main() {
  group('showBulkBarSnack', () {
    testWidgets('일괄 확정 바 위로 띄운다', (tester) async {
      await _pumpAndShow(tester, (c) => showBulkBarSnack(c, '등록했어요'));
      expectClearsBulkBar(tester, 'showBulkBarSnack');
      expect(find.text('등록했어요'), findsOneWidget);
    });

    testWidgets('액션을 달아도 자리를 지키고, 그 액션이 눌린다', (tester) async {
      // ⚠️ **지금 이 헬퍼에 액션을 넘기는 제품 호출부는 없다.** ③의 실행취소는
      // 2026-09-04에 걷어냈다 — 다른 삭제 경로에 없어 입력 탭만 예외였기 때문이다
      // (`schedule_screen_review_test.dart`의 부재 가드가 그 결정을 지킨다).
      //
      // 그래도 파라미터와 이 가드는 남긴다. 헬퍼는 범용 API이고, 액션 있는
      // 스낵바를 입력 탭에 다시 두게 되면 **가려지는 순간 그 액션은 못 누르는
      // 버튼**이 된다 — 그때 이 가드가 이미 서 있다.
      var undone = false;
      await _pumpAndShow(
        tester,
        (c) => showBulkBarSnack(
          c,
          '삭제했어요',
          action: SnackBarAction(label: '되돌리기', onPressed: () => undone = true),
        ),
      );
      expectClearsBulkBar(tester, '되돌리기 스낵바');

      // 등장 애니메이션이 끝나야 탭이 먹는다(중간에는 IgnorePointer다).
      await tester.pumpAndSettle();
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      expect(undone, isTrue, reason: '눌릴 수 있어야 액션이 의미가 있다');
    });

    testWidgets('앞선 스낵바를 지우고 띄운다 — 두 줄이 쌓이면 pill을 덮는다', (tester) async {
      await _pumpAndShow(tester, (c) => showBulkBarSnack(c, '첫 번째'));
      final ctx = tester.element(find.text('띄우기'));
      showBulkBarSnack(ctx, '두 번째');
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('첫 번째'), findsNothing);
    });
  });

  testWidgets('messenger 변종도 같은 자리를 지킨다 — /import가 pop 전에 쓴다', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showBulkBarSnackWith(messenger, '가져왔어요');
    await tester.pump();

    expectClearsBulkBar(tester, 'showBulkBarSnackWith');
    expect(find.text('가져왔어요'), findsOneWidget);
  });

  group('호출부가 이 헬퍼를 쓴다', () {
    // 위 세 건은 헬퍼가 옳게 동작하는지만 본다. **호출부가 그것을 쓰는지**는
    // 각 경로의 위젯 테스트가 지킨다:
    //   ① photo_input_hero_test.dart
    //   ② import_returns_after_register_test.dart
    //   ③ schedule_screen_review_test.dart
    // 여기서는 맨 `SnackBar`를 만드는 호출부가 다시 생기지 않는지 훑는다 —
    // 헬퍼를 공용으로 올린 이유가 그것이기 때문이다.
    test('입력 탭 경로에 맨 SnackBar 생성이 남아 있지 않다', () {
      const paths = [
        'lib/features/import/presentation/ai_photo_flow.dart',
        'lib/features/import/presentation/screens/import_screen.dart',
        'lib/features/schedule/presentation/screens/schedule_screen.dart',
      ];
      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('showSnackBar'),
          isFalse,
          reason:
              '$path 가 스낵바를 직접 띄운다 — `showBulkBarSnack`을 쓸 것. '
              '직접 띄우면 behavior/margin을 빠뜨려 일괄 확정 pill을 가린다',
        );
      }
    });
  });
}
