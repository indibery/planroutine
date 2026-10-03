import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/guidance_content.dart';
import '../../domain/guidance_logic.dart';
import '../../domain/guidance_models.dart';
import '../../domain/guidance_types.dart';
import '../../domain/participant.dart';
import '../providers/guidance_providers.dart';
import '../recording/attachment_importer.dart';
import '../recording/recording_screen.dart';
import '../widgets/attachment_tile.dart';
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
  static const recordKey = Key('guidance_edit_record');
  static const importAudioKey = Key('guidance_edit_import_audio');
  static const importImageKey = Key('guidance_edit_import_image');
  static const retryAttachKey = Key('guidance_edit_retry_attach');
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

  /// 녹음 화면이 열려 있는 동안 — 빠르게 두 번 눌러도 화면이 쌓이지 않게.
  var _recording = false;

  /// 녹음은 끝났는데 기록 저장·첨부가 실패해 아직 붙지 못한 것. 파일은 첨부 폴더에 있다.
  final _unattached = <RecordingResult>[];
  var _retrying = false;

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
  /// 첨부가 쓴다: 녹음·사진을 붙이는 순간 기록이 저장돼 있어야 한다.
  Future<int> _ensureRecord() async {
    final existing = _recordId;
    if (existing != null) return existing;
    var content = _current();
    if (content.title.isEmpty) content = content.copyWith(title: GuidanceStrings.untitled);
    final repo = ref.read(guidanceRepositoryProvider);
    final id = await ref.read(guidanceActionsProvider).create(content);
    // 만든 id를 **먼저** 붙든다 — 아래 조회가 실패해도 다음 첨부가 기록을 또 만들지 않게.
    _recordId = id;
    _saved = content;
    if (mounted) setState(() {});
    final record = await repo.getRecord(id);
    if (mounted) setState(() => _createdAt = record?.createdAt);
    return id;
  }

  void _saveFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.saveFailed)));
  }

  Future<void> _attachRecording(RecordingResult r) async {
    // 기다리는 사이 화면이 사라져도 붙일 수 있게 먼저 읽어 둔다(dispose 뒤에는 ref를 못 쓴다).
    final actions = ref.read(guidanceActionsProvider);
    final id = await _ensureRecord();
    await actions.attachRecording(recordId: id, path: r.path, durationMs: r.durationMs, startedAt: r.startedAt);
  }

  Future<void> _record() async {
    if (_recording) return;
    _recording = true;
    final RecordingResult? result;
    try {
      // 녹음 **전에** 기록을 만든다 — 녹음 중 탭을 옮겨 이 화면들이 사라져도 녹음 화면이
      // 이 기록에 직접 붙일 수 있게(RecordingScreen 참고).
      final int id;
      try {
        id = await _ensureRecord();
      } catch (_) {
        _saveFailed();
        return;
      }
      if (!mounted) return;
      final title = _title.text.trim();
      result = await Navigator.of(context).push<RecordingResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecordingScreen(recordId: id, title: title.isEmpty ? GuidanceStrings.untitled : title),
        ),
      );
    } finally {
      _recording = false;
    }
    if (result == null || !mounted) return;
    try {
      await _attachRecording(result);
    } catch (_) {
      // 파일은 첨부 폴더에 남아 있다 — 잃지 않게 화면에 붙들어 두고 다시 붙이게 한다.
      if (!mounted) return;
      setState(() => _unattached.add(result!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.attachFailedKept)));
    }
  }

  /// 붙이지 못한 녹음을 모두 다시 붙여 본다. 성공한 것만 목록에서 빼고, 하나라도 남으면 false.
  Future<bool> _attachPending() async {
    for (final r in List.of(_unattached)) {
      try {
        await _attachRecording(r);
        _unattached.remove(r);
      } catch (_) {}
    }
    return _unattached.isEmpty;
  }

  Future<void> _retryAttach() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final ok = await _attachPending();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(GuidanceStrings.attachFailedKept)));
    }
  }

  Future<void> _import(AttachmentType type) async {
    final importer = ref.read(attachmentImporterProvider);
    final picked = type == AttachmentType.audio ? await importer.pickAudio() : await importer.pickImage();
    if (picked == null) return;
    try {
      if (!mounted) return;
      final id = await _ensureRecord();
      await ref
          .read(guidanceActionsProvider)
          .attachImported(recordId: id, sourcePath: picked.path, type: type, originalName: picked.name);
    } catch (_) {
      _saveFailed();
    } finally {
      // 고르기 창이 넘긴 사본은 첨부 폴더로 복사가 끝났으면(성공·실패 모두) 남길 이유가 없다.
      await importer.discard(picked);
    }
  }

  Future<void> _removeAttachment(GuidanceAttachment a) async {
    final id = a.id;
    if (id == null) return;
    final ok = await ConfirmDialog.show(
      context: context,
      useRootNavigator: false,
      title: GuidanceStrings.removeAttachmentTitle,
      message: GuidanceStrings.removeAttachmentMessage,
      confirmLabel: GuidanceStrings.removeAttachmentConfirm,
    );
    if (!ok) return;
    try {
      await ref.read(guidanceActionsProvider).removeAttachment(id);
    } catch (_) {
      _saveFailed();
    }
  }

  List<Widget> _attachmentsSection(DateTime now) {
    final id = _recordId;
    final attachments = id == null
        ? const <GuidanceAttachment>[]
        : [
            for (final a in ref.watch(guidanceAttachmentsProvider(id)).valueOrNull ?? const <GuidanceAttachment>[])
              if (!a.isRemoved) a,
          ];
    return [
      _gap(),
      _label(GuidanceStrings.labelAttachments),
      if (_unattached.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: AppSizes.spacing8),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12, vertical: AppSizes.spacing8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.error),
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: AppSizes.spacing8),
              Expanded(
                child: Text(
                  GuidanceStrings.unattachedRecording(_unattached.length),
                  style: AppTextStyles.bodyM.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton(
                key: GuidanceEditScreen.retryAttachKey,
                onPressed: _retrying ? null : _retryAttach,
                child: const Text(GuidanceStrings.retryAttach),
              ),
            ],
          ),
        ),
      for (final a in attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spacing8),
          child: AttachmentTile(key: ValueKey(a.id), attachment: a, now: now, onRemove: () => _removeAttachment(a)),
        ),
      Wrap(
        spacing: AppSizes.spacing8,
        runSpacing: AppSizes.spacing8,
        children: [
          OutlinedButton.icon(
            key: GuidanceEditScreen.recordKey,
            onPressed: _record,
            icon: Icon(Icons.fiber_manual_record, color: AppColors.error),
            label: const Text(GuidanceStrings.record),
          ),
          OutlinedButton.icon(
            key: GuidanceEditScreen.importAudioKey,
            onPressed: () => _import(AttachmentType.audio),
            icon: const Icon(Icons.audio_file_outlined),
            label: const Text(GuidanceStrings.importAudio),
          ),
          OutlinedButton.icon(
            key: GuidanceEditScreen.importImageKey,
            onPressed: () => _import(AttachmentType.image),
            icon: const Icon(Icons.image_outlined),
            label: const Text(GuidanceStrings.importImage),
          ),
        ],
      ),
      _hint(GuidanceStrings.importHintSchoolPhone),
      _hint(GuidanceStrings.importHintCallRecording),
    ];
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
      // 붙이지 못한 녹음이 남아 있으면 닫기 전에 먼저 붙여 본다 — 하나라도 못 붙이면 화면을 지킨다.
      if (_unattached.isNotEmpty && !await _attachPending()) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(GuidanceStrings.attachFailedKept)));
        }
        return;
      }
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
      // 붙이지 못한 녹음은 나가면 이 화면에서 다시 붙일 길이 없다 — 그 사실을 먼저 말한다.
      message: _unattached.isEmpty
          ? GuidanceStrings.discardMessage
          : GuidanceStrings.discardUnattachedMessage(_unattached.length),
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
      canPop: !_dirty && _unattached.isEmpty,
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
                  ..._attachmentsSection(now),
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
