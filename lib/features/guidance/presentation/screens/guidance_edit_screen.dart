import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../widgets/occurred_input.dart';
import '../widgets/participant_picker_sheet.dart';

/// 새 기록·고치기 공용 전체 화면. 저장은 판을 하나 더한다(같은 내용이면 더하지 않는다).
class GuidanceEditScreen extends ConsumerStatefulWidget {
  const GuidanceEditScreen({super.key, this.recordId});

  final int? recordId;

  static const saveKey = Key('guidance_edit_save');
  static const cancelKey = Key('guidance_edit_cancel');
  static const titleKey = Key('guidance_edit_title');
  static const placeKey = Key('guidance_edit_place');
  static const factsKey = Key('guidance_edit_facts');
  static const quotesKey = Key('guidance_edit_quotes');
  static const actionsKey = Key('guidance_edit_actions');
  static const addPersonKey = Key('guidance_edit_add_person');
  static Key kindKey(GuidanceKind k) => Key('guidance_edit_kind_${k.dbValue}');
  static Key statusKey(GuidanceStatus s) => Key('guidance_edit_status_${s.dbValue}');

  @override
  ConsumerState<GuidanceEditScreen> createState() => _GuidanceEditScreenState();
}

class _GuidanceEditScreenState extends ConsumerState<GuidanceEditScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _facts = TextEditingController();
  final _quotes = TextEditingController();
  final _actions = TextEditingController();

  var _kind = GuidanceKind.guidance;
  var _status = GuidanceStatus.open;
  var _precision = OccurredPrecision.exact;
  DateTime? _occurredAt = DateTime.now();
  String? _occurredText;
  var _participants = <Participant>[];

  /// 고치는 중인 기록 id. 새 기록이면 null이었다가 처음 저장(또는 Task 8의 첨부)에서 정해진다.
  int? _recordId;

  /// 마지막으로 DB에 들어간 내용. 이것과 다르면 "고친 내용이 있다".
  GuidanceContent? _saved;
  String? _createdAt;
  var _loaded = false;
  var _titleError = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _recordId = widget.recordId;
    for (final c in [_title, _place, _facts, _quotes, _actions]) {
      c.addListener(_touch);
    }
    _load();
  }

  void _touch() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = widget.recordId;
    if (id == null) {
      _saved = _current();
      setState(() => _loaded = true);
      return;
    }
    final record = await ref.read(guidanceRepositoryProvider).getRecord(id);
    if (!mounted || record == null) return;
    final c = record.content;
    _title.text = c.title;
    _place.text = c.place ?? '';
    _facts.text = c.facts ?? '';
    _quotes.text = c.quotes ?? '';
    _actions.text = c.actions ?? '';
    setState(() {
      _kind = c.kind;
      _status = c.status;
      _precision = c.precision;
      _occurredAt = c.occurredAt;
      _occurredText = c.occurredText;
      _participants = [...c.participants];
      _createdAt = record.createdAt;
      _saved = c.normalized();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _place, _facts, _quotes, _actions]) {
      c.dispose();
    }
    super.dispose();
  }

  GuidanceContent _current() => GuidanceContent(
    kind: _kind,
    status: _status,
    precision: _precision,
    occurredAt: _occurredAt,
    occurredText: _occurredText,
    title: _title.text,
    place: _place.text,
    participants: _participants,
    facts: _facts.text,
    quotes: _quotes.text,
    actions: _actions.text,
  ).normalized();

  bool get _dirty {
    final saved = _saved;
    return _loaded && saved != null && !sameContent(saved, _current());
  }

  /// 아직 DB에 없는 새 기록을 지금 만든다 — 제목이 비었으면 `제목 없음`으로.
  /// Task 8(첨부)이 쓴다: 녹음·사진을 붙이는 순간 기록이 저장돼 있어야 한다.
  // ignore: unused_element — Task 8(첨부)이 쓴다
  Future<int> _ensureRecord() async {
    final existing = _recordId;
    if (existing != null) return existing;
    var content = _current();
    if (content.title.isEmpty) content = content.copyWith(title: GuidanceStrings.untitled);
    final id = await ref.read(guidanceActionsProvider).create(content);
    final record = await ref.read(guidanceRepositoryProvider).getRecord(id);
    if (mounted) {
      setState(() {
        _recordId = id;
        _saved = content;
        _createdAt = record?.createdAt;
      });
    }
    return id;
  }

  Future<void> _save() async {
    if (_busy) return;
    final content = _current();
    if (content.title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(guidanceActionsProvider);
    final id = _recordId;
    try {
      if (id == null) {
        _recordId = await actions.create(content);
      } else {
        await actions.save(id, content);
      }
      _saved = content;
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // 실패하면 글을 그대로 두고 다시 누를 수 있게 푼다. 성공해 pop한 뒤에는 풀지 않는다(닫히는 동안 두 번 눌림 방지).
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(GuidanceStrings.saveFailed)),
        );
      }
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.discardTitle,
      message: GuidanceStrings.discardMessage,
      confirmLabel: GuidanceStrings.discardConfirm,
    );
    if (leave && mounted) {
      _saved = _current();
      setState(() {});
      Navigator.of(context).pop();
    }
  }

  Future<void> _addPerson() async {
    final p = await showParticipantPicker(context, exclude: _participants);
    if (p == null || !mounted) return;
    setState(() => _participants = [..._participants, p]);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final created = _createdAt;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 72,
          leading: TextButton(
            key: GuidanceEditScreen.cancelKey,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(GuidanceStrings.cancel),
          ),
          title: Text(
            widget.recordId == null ? GuidanceStrings.editNewTitle : GuidanceStrings.editTitle,
            style: AppTextStyles.heading,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.spacing8),
              child: FilledButton(
                key: GuidanceEditScreen.saveKey,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.goldFill,
                  foregroundColor: AppColors.onGold,
                ),
                onPressed: _busy ? null : _save,
                child: const Text(GuidanceStrings.save),
              ),
            ),
          ],
        ),
        body: !_loaded
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spacing16,
                  AppSizes.spacing16,
                  AppSizes.spacing16,
                  AppSizes.spacing48,
                ),
                children: [
                  _label(GuidanceStrings.labelKind),
                  SegmentedButton<GuidanceKind>(
                    showSelectedIcon: false,
                    segments: [
                      for (final k in GuidanceKind.values)
                        ButtonSegment(
                          value: k,
                          label: Text(k.label, key: GuidanceEditScreen.kindKey(k)),
                        ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelStatus),
                  SegmentedButton<GuidanceStatus>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: GuidanceStatus.open,
                        label: Text(
                          GuidanceStrings.statusOpen,
                          key: GuidanceEditScreen.statusKey(GuidanceStatus.open),
                        ),
                      ),
                      ButtonSegment(
                        value: GuidanceStatus.closedAtSchool,
                        label: Text(
                          GuidanceStrings.statusClosedShort,
                          key: GuidanceEditScreen.statusKey(GuidanceStatus.closedAtSchool),
                        ),
                      ),
                      ButtonSegment(
                        value: GuidanceStatus.transferred,
                        label: Text(
                          GuidanceStrings.statusTransferredShort,
                          key: GuidanceEditScreen.statusKey(GuidanceStatus.transferred),
                        ),
                      ),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelOccurred),
                  OccurredInput(
                    precision: _precision,
                    at: _occurredAt,
                    text: _occurredText,
                    onChanged: (v) => setState(() {
                      _precision = v.precision;
                      _occurredAt = v.at;
                      _occurredText = v.text;
                    }),
                  ),
                  const SizedBox(height: AppSizes.spacing8),
                  Row(
                    children: [
                      Text(
                        '${GuidanceStrings.labelCreated} · ',
                        style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                      ),
                      Flexible(
                        child: Text(
                          created == null
                              ? GuidanceStrings.createdOnSave
                              : formatStamp(created, now: now),
                          style: AppTextStyles.bodyS.copyWith(color: AppColors.sub),
                        ),
                      ),
                    ],
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelTitle),
                  TextField(
                    key: GuidanceEditScreen.titleKey,
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      errorText: _titleError && _title.text.trim().isEmpty
                          ? GuidanceStrings.titleRequired
                          : null,
                    ),
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelPlace),
                  TextField(key: GuidanceEditScreen.placeKey, controller: _place),
                  _gap(),
                  _label(GuidanceStrings.labelParticipants),
                  Wrap(
                    spacing: AppSizes.spacing8,
                    runSpacing: AppSizes.spacing8,
                    children: [
                      for (final p in _participants)
                        InputChip(
                          label: Text(p.displayName),
                          onDeleted: () => setState(
                            () => _participants = [
                              for (final q in _participants)
                                if (!identical(q, p)) q,
                            ],
                          ),
                        ),
                      ActionChip(
                        key: GuidanceEditScreen.addPersonKey,
                        avatar: const Icon(Icons.add, size: AppSizes.iconSmall),
                        label: const Text(GuidanceStrings.addPerson),
                        onPressed: _addPerson,
                      ),
                    ],
                  ),
                  _hint(GuidanceStrings.participantsHint),
                  _gap(),
                  _label(GuidanceStrings.labelFacts),
                  TextField(
                    key: GuidanceEditScreen.factsKey,
                    controller: _facts,
                    minLines: 5,
                    maxLines: null,
                  ),
                  _gap(),
                  _label(GuidanceStrings.labelQuotes),
                  TextField(
                    key: GuidanceEditScreen.quotesKey,
                    controller: _quotes,
                    minLines: 3,
                    maxLines: null,
                  ),
                  _hint(GuidanceStrings.quotesHint),
                  _gap(),
                  _label(GuidanceStrings.labelActions),
                  TextField(
                    key: GuidanceEditScreen.actionsKey,
                    controller: _actions,
                    minLines: 3,
                    maxLines: null,
                  ),
                  _hint(GuidanceStrings.actionsHint),
                ],
              ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: AppSizes.spacing20);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.label.copyWith(color: AppColors.sub)),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSizes.spacing8),
    child: Text(text, style: AppTextStyles.bodyS.copyWith(color: AppColors.sub)),
  );
}
