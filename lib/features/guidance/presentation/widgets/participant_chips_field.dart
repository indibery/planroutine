import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';

/// 관련인 칸 — 이름을 바로 쓴다. 쉼표(`,`·`，`)나 엔터에서 앞의 이름이 칩이 되고,
/// 치는 동안 명단(한 번 저장한 이름)에서 추천이 뜬다. 학생·보호자 구분은 묻지 않는다.
///
/// 칩은 입력칸 **안**에 같은 줄로 선다 — 칸 위에 칩 줄을 따로 두면 첫 칩이 생기는 순간
/// 화면이 한 줄 밀렸다(실기기 피드백 2026-10-04).
///
/// 아직 칩이 안 된 글은 [controller]에 남는다 — 저장할 때 편집 화면이 그것도 넣는다.
class ParticipantChipsField extends ConsumerStatefulWidget {
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
  static const boxKey = Key('guidance_participants_box');
  static Key suggestionKey(String name) => Key('guidance_suggestion_$name');

  /// 칩이 있을 때 입력칸이 칩과 같은 줄에서 차지하는 폭. 이름은 대개 3~6글자다.
  static const inputWidthWithChips = 120.0;

  @override
  ConsumerState<ParticipantChipsField> createState() =>
      _ParticipantChipsFieldState();
}

class _ParticipantChipsFieldState extends ConsumerState<ParticipantChipsField>
    with WidgetsBindingObserver {
  final _focus = FocusNode();
  final _blockKey = GlobalKey();

  List<Participant> get _participants => widget.participants;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() {});

  /// 키보드가 오르내릴 때마다 온다. 입력칸이 보이는 것만으로는 그 아래 추천이 키보드에
  /// 가리므로(입력칸은 [EditableText]가 스스로 보이게 한다) 추천까지 보이게 다시 맞춘다.
  @override
  void didChangeMetrics() => _scheduleReveal();

  bool get _showingSuggestions =>
      suggestPeople(_roster, widget.controller.text, _participants).isNotEmpty;

  List<GuidancePerson> get _roster =>
      ref.read(guidancePeopleProvider).valueOrNull ?? const <GuidancePerson>[];

  void _scheduleReveal() {
    if (!_focus.hasFocus || !_showingSuggestions) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _blockKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  /// 쉼표가 들어오면 그 앞의 이름들을 칩으로 만들고 칸에는 마지막 쉼표 뒤의 글만 남긴다.
  /// 한 번에 여러 글자가 들어온 것(붙여넣기)이면 마지막 조각도 다 쓴 이름으로 보고 칩으로 만든다 —
  /// `김하늘, 이도윤, 박서준`을 붙여 넣으면 셋 다 칩이 된다. 쳐서 넣는 쉼표는 한 글자씩 들어온다.
  /// 키보드가 조합 중인 글을 한꺼번에 바꿔 넣는 것(composing 있음)은 붙여넣기로 보지 않는다.
  TextEditingValue _split(TextEditingValue before, TextEditingValue after) {
    final text = after.text;
    final cut = text.lastIndexOf(nameSeparator);
    if (cut < 0) return after;
    // 한글 조합 중(composing이 있다)에는 한 번에 여러 글자가 바뀌어도 붙여넣기가 아니다.
    final composing = after.composing;
    final composingNow = composing.isValid && !composing.isCollapsed;
    final pasted = !composingNow && text.length - before.text.length > 1;
    final rest = pasted ? '' : text.substring(cut + 1).trimLeft();
    widget.onChanged(addParticipantNames(_participants, splitNames(pasted ? text : text.substring(0, cut))));
    return TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  void _submitted(String text) {
    widget.onChanged(addParticipantNames(_participants, splitNames(text)));
    widget.controller.clear();
  }

  void _pick(GuidancePerson person) {
    widget.onChanged([..._participants, person.toParticipant()]);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final roster =
        ref.watch(guidancePeopleProvider).valueOrNull ??
        const <GuidancePerson>[];
    final suggestions = suggestPeople(roster, widget.controller.text, _participants);
    _scheduleReveal();
    // 추천·칩을 누르는 것을 칸 밖 탭으로 보지 않게 — 키보드가 내려가지 않는다.
    return TextFieldTapRegion(
      child: Column(
        key: _blockKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            child: InputDecorator(
              key: ParticipantChipsField.boxKey,
              isFocused: _focus.hasFocus,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSizes.spacing12,
                  vertical: AppSizes.spacing8,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: AppSizes.spacing8,
                  runSpacing: AppSizes.spacing8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final p in _participants)
                      InputChip(
                        label: Text(p.displayName),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onDeleted: () => widget.onChanged([
                          for (final q in _participants)
                            if (!identical(q, p)) q,
                        ]),
                      ),
                    SizedBox(
                      width: _participants.isEmpty
                          ? constraints.maxWidth
                          : ParticipantChipsField.inputWidthWithChips.clamp(
                              0.0,
                              constraints.maxWidth,
                            ),
                      child: TextField(
                        key: ParticipantChipsField.inputKey,
                        controller: widget.controller,
                        focusNode: _focus,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: _participants.isEmpty
                              ? GuidanceStrings.participantsInputHint
                              : null,
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacing4,
                            vertical: AppSizes.spacing8,
                          ),
                        ),
                        inputFormatters: [TextInputFormatter.withFunction(_split)],
                        onSubmitted: _submitted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final person in suggestions)
                        ActionChip(
                          key: ParticipantChipsField.suggestionKey(person.name),
                          avatar: const Icon(
                            Icons.add,
                            size: AppSizes.iconSmall,
                          ),
                          label: Text(person.name),
                          onPressed: () => _pick(person),
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
        ],
      ),
    );
  }
}
