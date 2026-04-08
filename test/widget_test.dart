import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:planroutine/app.dart';

void main() {
  testWidgets('앱 기본 렌더링 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PlanRoutineApp()),
    );
    await tester.pumpAndSettle();

    // 캘린더 탭이 기본 화면
    expect(find.text('캘린더'), findsWidgets);
  });
}
