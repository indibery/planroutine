import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/title_year_utils.dart';
import '../../../../features/settings/presentation/providers/ai_task_share_provider.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
import '../../../../shared/widgets/segmented_setting_row.dart';
import '../../../schedule/domain/entry_kind.dart';
import '../../data/ai_task_exporter.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';

/// 이벤트 추가/수정 바텀시트
class EventEditDialog extends ConsumerStatefulWidget {
  const EventEditDialog({
    super.key,
    required this.initialDate,
    this.event,
    this.allowKindChange = true,
  });

  final DateTime initialDate;
  final CalendarEvent? event;

  /// 종류(업무/학교일정) 선택 행을 노출할지.
  ///
  /// 오늘 탭은 업무만 담는 화면이라 `false`로 잠근다 — 거기서 학교일정을 만들면
  /// 저장 직후 목록에서 사라져 저장 실패로 읽힌다. 잠가도 `_kind` 상태는 살아 있어
  /// 기존 이벤트를 편집할 때 원래 종류가 보존된다.
  final bool allowKindChange;

  /// 바텀시트 표시
  static Future<CalendarEvent?> show(
    BuildContext context, {
    required DateTime initialDate,
    CalendarEvent? event,
    bool allowKindChange = true,
  }) {
    return showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.navyMid,
      barrierColor: AppColors.navy.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius28),
        ),
      ),
      builder: (_) => EventEditDialog(
        initialDate: initialDate,
        event: event,
        allowKindChange: allowKindChange,
      ),
    );
  }

  @override
  ConsumerState<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends ConsumerState<EventEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _eventDate;
  late bool _isImportant;
  late EntryKind _kind;

  /// 이 시트에서 연도 칩을 이미 눌렀는지. 저장하지 않으므로 취소하면 사라진다 —
  /// 다시 열면 칩이 돌아온다. 시트 안에서 두 번 눌러 연도가 계속 올라가는 것을 막는다.
  bool _yearShifted = false;
  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController =
        TextEditingController(text: event?.description ?? '');
    _eventDate = event?.eventDateTime ?? widget.initialDate;
    _isImportant = event?.isImportant ?? false;
    _kind = event?.kind ?? EntryKind.task;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // 고급 기능: AI 자동화 공유 토글이 ON이고 기존 이벤트 편집일 때만 노출(기본 OFF).
    final aiEnabled =
        ref.watch(aiTaskShareEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacing16),
                _buildHeader(),
                const SizedBox(height: AppSizes.spacing20),
                _buildTitleField(),
                _buildYearShiftChip(),
                const SizedBox(height: AppSizes.spacing16),
                _buildDescriptionField(),
                const SizedBox(height: AppSizes.spacing16),
                _buildDateRow(),
                const SizedBox(height: AppSizes.spacing8),
                _buildAttributesCard(),
                if (_isEditing && aiEnabled) ...[
                  const SizedBox(height: AppSizes.spacing16),
                  _buildAiShareAction(),
                ],
                const SizedBox(height: AppSizes.spacing24),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // 좌측은 빈 공간 — 가운데 정렬용 (우측 아이콘 너비만큼)
        const SizedBox(width: 40),
        const Spacer(),
        Text(
          _isEditing ? CalendarStrings.editEvent : CalendarStrings.addEvent,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        // 편집 시에만 우측에 휴지통 노출 (새 이벤트엔 삭제할 게 없음)
        SizedBox(
          width: 40,
          child: _isEditing
              ? IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.inkRed,
                  ),
                  tooltip: AppStrings.delete,
                  onPressed: _onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: CalendarStrings.eventTitle,
        hintText: CalendarStrings.eventTitleHint,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return CalendarStrings.titleRequired;
        }
        return null;
      },
    );
  }

  /// 제목에 연도가 있으면 나타나는 "연도 한 해 밀기" 원탭 칩.
  ///
  /// 컨트롤러를 구독해 입력 중에도 실시간으로 노출/숨김된다. 탭하면 제목의 **모든**
  /// 연도를 +1년 하고 커서를 끝으로 옮긴 뒤 **칩을 감춘다**(저장은 사용자가 직접).
  ///
  /// 꺼지는 이유가 셋이고 수명이 다르다:
  ///   - `!_isEditing` — 신규 생성은 방금 본인이 타이핑한 연도라 밀라고 권할 이유가 없다.
  ///   - `reviewedAt != null` — 이미 저장해 정리한 항목. **영구**(DB 컬럼).
  ///   - `_yearShifted` — 이 시트에서 이미 눌렀다. **세션 한정**이라 취소하면 돌아온다.
  Widget _buildYearShiftChip() {
    if (!_isEditing || _yearShifted) return const SizedBox.shrink();
    if (widget.event?.reviewedAt != null) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final result = shiftTitleYears(value.text);
        if (result.from.isEmpty) return const SizedBox.shrink();
        final label = result.from.length == 1
            ? '${result.from.first} → ${result.from.first + 1}'
            : CalendarStrings.yearShiftAll;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing8),
            child: ActionChip(
              key: const Key('year_shift_chip'),
              avatar: Icon(
                Icons.event_repeat,
                size: 18,
                color: AppColors.gold,
              ),
              label: Text(label),
              labelStyle: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surfaceVariant,
              side: BorderSide(color: AppColors.gold),
              onPressed: () {
                _titleController.value = TextEditingValue(
                  text: result.title,
                  selection:
                      TextSelection.collapsed(offset: result.title.length),
                );
                setState(() => _yearShifted = true);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: CalendarStrings.eventDescription,
        hintText: CalendarStrings.eventDescriptionHint,
      ),
      minLines: 4,
      maxLines: 6,
    );
  }

  Widget _buildDateRow() {
    return _buildDateTile(
      label: CalendarStrings.eventDate,
      date: _eventDate,
      onTap: _pickDate,
    );
  }

  Widget _buildDateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final formatter = DateFormat('yyyy년 M월 d일', 'ko_KR');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacing16,
          vertical: AppSizes.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radius12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              formatter.format(date),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSizes.spacing8),
            Icon(
              Icons.calendar_today,
              size: AppSizes.iconSmall,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }


  /// 성격 카드 — "이 항목이 어떤 성격인가"를 정하는 값들을 한 테두리에 묶는다.
  ///
  /// 종류(업무/학교일정) + 중요 표시. [EventEditDialog.allowKindChange]가 false면
  /// 종류 행과 구분선을 함께 뺀다 — 구분선만 남으면 뭔가 잘린 것처럼 읽힌다.
  Widget _buildAttributesCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: Column(
        children: [
          if (widget.allowKindChange) ...[
            SegmentedSettingRow<EntryKind>(
              key: const Key('kind_selector'),
              icon: Icons.label_outline,
              label: CalendarStrings.kindLabel,
              segments: EntryKind.values
                  .map((k) => ButtonSegment<EntryKind>(
                        value: k,
                        label: Text(k.label),
                      ))
                  .toList(),
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            Divider(height: 1, color: AppColors.border),
          ],
          SwitchListTile(
            key: const Key('important_toggle'),
            value: _isImportant,
            onChanged: (v) => setState(() => _isImportant = v),
            activeThumbColor: AppColors.gold,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
            ),
            secondary: Icon(Icons.star_rounded, color: AppColors.gold),
            title: Text(
              CalendarStrings.importantLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS/iPad 공유시트 팝오버 앵커 Rect. 미지정 시 iPad에서 PlatformException으로
  /// 시트가 안 뜬다(내보내기 타일과 동일 대응).
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  /// 고급 기능: 이 이벤트를 외부 AI로 보내 자동화(하이브리드 지시문+JSON 공유시트).
  Widget _buildAiShareAction() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          final event = widget.event;
          if (event == null) return;
          Share.share(
            buildAiTaskExport(event),
            sharePositionOrigin: _shareOrigin(),
          );
        },
        icon: Icon(Icons.auto_awesome, size: 18, color: AppColors.gold),
        label: const Text('AI로 보내기'),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
        ),
        const SizedBox(width: AppSizes.spacing12),
        Expanded(
          child: GoldGradientButton(
            label: AppStrings.save,
            onPressed: _onSave,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _buildEvent());
  }

  /// 휴지통으로 soft-delete. 다이얼로그 닫고 notifier에 위임.
  Future<void> _onDelete() async {
    final event = widget.event;
    final id = event?.id;
    if (id == null) return;
    await ref.read(selectedMonthEventsProvider.notifier).deleteEvent(id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// 저장할 이벤트를 만든다.
  ///
  /// 편집일 때는 **반드시 copyWith**를 쓴다. 생성자로 새로 만들면 시트가 모르는 필드가
  /// `@Default`/null로 되돌아가고, `updateEvent`의 `toMap()`이 그 값으로 DB를 덮는다
  /// (kind → 학교일정이 업무로, googleEventId → Google 중복 이벤트).
  /// `CalendarEvent`에 필드가 추가돼도 여기를 고칠 필요가 없어야 한다.
  CalendarEvent _buildEvent() {
    final now = DateTime.now().toIso8601String();
    final existing = widget.event;

    if (existing != null) {
      // 종료 날짜 입력 UI는 없지만 endDate는 copyWith가 보존한다. 시작일을
      // 옛 종료일보다 뒤로 옮기면 기간이 거꾸로(end < start) 남아 Google/기기
      // 캘린더 저장이 실패한다 — UI로 고칠 방법도 없으니 모순되면 버린다.
      final staleEnd = existing.endDate != null &&
          existing.endDateTime.isBefore(_eventDate);
      return existing.copyWith(
        title: _titleController.text.trim(),
        description: _trimmedDescription(),
        eventDate: formatDate(_eventDate),
        endDate: staleEnd ? null : existing.endDate,
        isImportant: _isImportant,
        kind: _kind,
        // 저장했다는 것 자체가 검토의 증거다. 이 값이 `작년` 배지와 연도 칩을 함께 끈다.
        reviewedAt: now,
        updatedAt: now,
      );
    }

    return CalendarEvent(
      title: _titleController.text.trim(),
      description: _trimmedDescription(),
      eventDate: formatDate(_eventDate),
      isAllDay: true,
      isImportant: _isImportant,
      kind: _kind,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 설명은 비어 있으면 null로 저장한다(빈 문자열을 남기지 않는다).
  String? _trimmedDescription() {
    final text = _descriptionController.text.trim();
    return text.isEmpty ? null : text;
  }
}
