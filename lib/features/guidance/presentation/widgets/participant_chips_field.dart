import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';

/// 관련인 칸 — 이름을 바로 쓴다. 쉼표(`,`·`，`)나 엔터에서 앞의 이름이 칩이 되고,
/// 치는 동안 명단(한 번 저장한 이름)에서 추천이 뜬다. 학생·보호자 구분은 묻지 않는다.
///
/// 아직 칩이 안 된 글은 [controller]에 남는다 — 저장할 때 편집 화면이 그것도 넣는다.
class ParticipantChipsField extends ConsumerWidget {
  const ParticipantChipsField({
    super.key,
    required this.participants,
    required this.controller,
    required this.onChanged,
  });

  final List<Participant> participants;
  final TextEditingController controller;
  final ValueChanged<List<Participant>> onChanged;

  static const inputKey = Key('guidance_participants_input');
  static Key suggestionKey(String name) => Key('guidance_suggestion_$name');

  /// 쉼표가 들어오면 그 앞의 이름들을 칩으로 만들고 칸에는 마지막 쉼표 뒤의 글만 남긴다.
  /// 한 번에 여러 글자가 들어온 것(붙여넣기)이면 마지막 조각도 다 쓴 이름으로 보고 칩으로 만든다 —
  /// `김하늘, 이도윤, 박서준`을 붙여 넣으면 셋 다 칩이 된다. 쳐서 넣는 쉼표는 한 글자씩 들어온다.
  TextEditingValue _split(TextEditingValue before, TextEditingValue after) {
    final text = after.text;
    final cut = text.lastIndexOf(nameSeparator);
    if (cut < 0) return after;
    final pasted = text.length - before.text.length > 1;
    final rest = pasted ? '' : text.substring(cut + 1).trimLeft();
    onChanged(addParticipantNames(participants, splitNames(pasted ? text : text.substring(0, cut))));
    return TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  void _submitted(String text) {
    onChanged(addParticipantNames(participants, splitNames(text)));
    controller.clear();
  }

  void _pick(GuidancePerson person) {
    onChanged([...participants, person.toParticipant()]);
    controller.clear();
  }

  /// 추천에서만 지운다(명단에서 보관) — 이미 쓴 기록의 이름은 판의 사본이라 그대로다.
  Future<void> _forget(
    BuildContext context,
    WidgetRef ref,
    GuidancePerson person,
  ) async {
    final id = person.id;
    if (id == null) return;
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.forgetSuggestionTitle,
      message: GuidanceStrings.forgetSuggestionMessage(person.name),
      confirmLabel: GuidanceStrings.delete,
      confirmColor: AppColors.error,
    );
    if (!ok) return;
    try {
      await ref.read(guidanceActionsProvider).archivePerson(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(GuidanceStrings.actionFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster =
        ref.watch(guidancePeopleProvider).valueOrNull ??
        const <GuidancePerson>[];
    final suggestions = suggestPeople(roster, controller.text, participants);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (participants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
            child: Wrap(
              spacing: AppSizes.spacing8,
              runSpacing: AppSizes.spacing8,
              children: [
                for (final p in participants)
                  InputChip(
                    label: Text(p.displayName),
                    onDeleted: () => onChanged([
                      for (final q in participants)
                        if (!identical(q, p)) q,
                    ]),
                  ),
              ],
            ),
          ),
        TextField(
          key: inputKey,
          controller: controller,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: GuidanceStrings.participantsInputHint,
          ),
          inputFormatters: [TextInputFormatter.withFunction(_split)],
          onSubmitted: _submitted,
        ),
        if (suggestions.isNotEmpty)
          // 추천을 누르는 것을 칸 밖 탭으로 보지 않게 — 키보드가 내려가지 않는다.
          TextFieldTapRegion(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final person in suggestions)
                        GestureDetector(
                          onLongPress: () => _forget(context, ref, person),
                          child: ActionChip(
                            key: suggestionKey(person.name),
                            avatar: const Icon(
                              Icons.add,
                              size: AppSizes.iconSmall,
                            ),
                            label: Text(person.name),
                            onPressed: () => _pick(person),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spacing4),
                  Text(
                    GuidanceStrings.suggestionHint,
                    style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
