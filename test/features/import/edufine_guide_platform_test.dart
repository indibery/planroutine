// 에듀파인 가이드는 **그 기기의 안내만** 보여준다.
//
// 2026-08-14에 안드로이드 공유·열기를 배선했는데(`MainActivity.kt`) 안내문은
// 갱신하지 않아, 2단계 제목이 문자 그대로 `② 아이폰으로 가져오기`였다
// (사용자 신고 2026-09-03). 안드로이드 사용자에게는 자기 안내가 아예 없었다.
//
// ⚠️ **분기는 `dart:io`의 `Platform.isAndroid`다.** `defaultTargetPlatform`은
// `flutter test`에서 **항상 `android`로 강제**되므로(`_platform_io.dart`의 assert
// 블록) 그걸로 분기하면 macOS에서 도는 위젯 테스트 전체에 안드로이드 UI가 나온다.
// `Platform.isAndroid`는 위젯 테스트로 직접 밟을 수 없어, 리포 규칙대로 위젯이
// `isAndroid` 주입점을 갖는다 — **이 가드가 성립하는 이유가 그 주입점이다.**
//
// ⚠️ 두 플랫폼의 **권장 방법이 뒤바뀐다**. 아이폰은 공유시트(A), 안드로이드는
// 열기(A)다. 매니페스트 필터 폭이 반대이기 때문이다 — 열기(`ACTION_VIEW`)는
// `text/plain`·`octet-stream`·와일드카드까지 받고 공유(`ACTION_SEND`)는 CSV mime
// 셋만 받는다. 그래서 안드로이드 안내는 **공유를 언급하지 않는다**: 적지 않은
// 경로는 변명할 것도 없고, 적은 경로는 항상 동작한다(사용자 결정 2026-09-04).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planroutine/core/constants/app_strings.dart';
import 'package:planroutine/features/import/presentation/widgets/edufine_guide_section.dart';

/// 접힘이 기본이라 펼쳐야 자식이 만들어진다.
///
/// ⚠️ **`key`가 필요하다.** 한 테스트에서 두 번 pump하면 `ExpansionTile`의 State가
/// 재사용돼 이미 펼쳐진 상태에서 다시 탭하고, 그래서 **접힌다**(실측). 플랫폼마다
/// 다른 키를 주면 State가 새로 만들어져 매번 접힘에서 시작한다.
Future<void> _pumpExpanded(
  WidgetTester tester, {
  required bool isAndroid,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EdufineGuideSection(
            key: ValueKey(isAndroid),
            isAndroid: isAndroid,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(ImportStrings.edufineGuideTitle));
  await tester.pumpAndSettle();
}

void main() {
  group('에듀파인 가이드 — 기기별 안내', () {
    testWidgets('안드로이드에서는 안드로이드 안내만 보인다', (tester) async {
      await _pumpExpanded(tester, isAndroid: true);

      expect(
        find.text(ImportStrings.edufineGuideSection2TitleAndroid),
        findsOneWidget,
      );
      expect(
        find.text(ImportStrings.edufineGuideSection2Title),
        findsNothing,
        reason: '아이폰 안내가 함께 뜨면 "그 기기의 안내만"이 깨진다',
      );
      // 아이폰 전용 문구가 새어나오지 않는지 — 제목만 봐서는 본문이 남는 것을 놓친다.
      expect(find.textContaining('아이폰'), findsNothing);
    });

    testWidgets('아이폰에서는 아이폰 안내만 보인다', (tester) async {
      await _pumpExpanded(tester, isAndroid: false);

      expect(
        find.text(ImportStrings.edufineGuideSection2Title),
        findsOneWidget,
      );
      expect(
        find.text(ImportStrings.edufineGuideSection2TitleAndroid),
        findsNothing,
      );
      expect(find.textContaining('안드로이드'), findsNothing);
    });

    testWidgets('안드로이드 안내는 공유를 언급하지 않는다', (tester) async {
      // 공유(`ACTION_SEND`) 필터가 CSV mime 셋만 받아 앱에 따라 목록에 안 뜬다.
      // 적지 않은 경로는 실패를 변명할 필요도 없다 — 열기만 적는다.
      await _pumpExpanded(tester, isAndroid: true);

      expect(
        find.textContaining('공유'),
        findsNothing,
        reason:
            '공유 경로는 보내는 앱이 CSV mime을 정확히 써야만 동작한다. '
            '안내에 넣으면 "안 뜨는 경우"를 함께 설명해야 하고, 그 경고가 '
            '안내문의 절반을 먹는다',
      );
    });

    testWidgets('① 단계는 두 기기에서 같고, PC에서 받는다는 것을 말한다', (tester) async {
      // 에듀파인은 업무용 PC 웹이라 ①은 플랫폼과 무관하다. 그 말이 없으면
      // "폰에서 에듀파인에 들어가야 하나"로 읽힌다.
      for (final android in [true, false]) {
        await _pumpExpanded(tester, isAndroid: android);
        expect(
          find.text(ImportStrings.edufineGuideSection1Title),
          findsOneWidget,
          reason: 'android=$android — ① 제목은 공통이다',
        );
        expect(
          find.text(ImportStrings.edufineGuideSection1Hint),
          findsOneWidget,
          reason: 'android=$android — PC에서 받는다는 안내가 있어야 한다',
        );
      }
    });

    testWidgets('두 안내의 뼈대가 같다 — 같은 자리에서 같은 것을 찾는다', (tester) async {
      // A = 앱 밖에서 보내기 / B = 앱에서 고르기. 플랫폼마다 방법 수나 순서가
      // 다르면 한쪽을 보고 다른 쪽을 설명할 수 없다.
      for (final android in [true, false]) {
        await _pumpExpanded(tester, isAndroid: android);
        expect(
          find.text(ImportStrings.edufineGuideSection2Hint),
          findsOneWidget,
          reason: 'android=$android — "둘 중 편한 방법" 안내가 공통이다',
        );
        expect(
          find.textContaining('파일 선택'),
          findsWidgets,
          reason: 'android=$android — B는 앱 안의 "파일 선택" 버튼으로 끝난다',
        );
      }
    });
  });
}
