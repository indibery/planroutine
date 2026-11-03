// 잠긴 동안(새 기록은 인증 없이 열린다) 관련인 칸은 명단을 읽지 않고 추천을 띄우지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planroutine/features/guidance/domain/guidance_models.dart';
import 'package:planroutine/features/guidance/domain/participant.dart';
import 'package:planroutine/features/guidance/presentation/lock/guidance_unlock.dart';
import 'package:planroutine/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:planroutine/features/guidance/presentation/widgets/participant_chips_field.dart';

void main() {
  var rosterReads = 0;
  setUp(() => rosterReads = 0);

  Future<List<Participant>> pump(WidgetTester tester, {required bool unlocked}) async {
    var chips = <Participant>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidancePeopleProvider.overrideWith((ref) {
            rosterReads++;
            return [const GuidancePerson(id: 1, name: '박서준')];
          }),
          if (unlocked) guidanceUnlockProvider.overrideWithValue(GuidanceUnlock()..markUnlocked()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ParticipantChipsField(
                participants: chips,
                controller: controller,
                onChanged: (v) => setState(() => chips = v),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return chips;
  }

  final input = find.byKey(ParticipantChipsField.inputKey);

  testWidgets('잠기면 명단을 읽지 않고 추천이 없다', (tester) async {
    await pump(tester, unlocked: false);
    await tester.enterText(input, '박');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(ParticipantChipsField.suggestionKey('박서준')), findsNothing);
    expect(rosterReads, 0);
  });

  testWidgets('잠겨도 쉼표로 칩은 만들어진다', (tester) async {
    await pump(tester, unlocked: false);
    await tester.enterText(input, '박서');
    await tester.enterText(input, '박서,');
    await tester.pump();
    expect(find.widgetWithText(InputChip, '박서'), findsOneWidget);
  });

  testWidgets('풀리면 추천이 보인다', (tester) async {
    await pump(tester, unlocked: true);
    await tester.enterText(input, '박');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(ParticipantChipsField.suggestionKey('박서준')), findsOneWidget);
  });
}
