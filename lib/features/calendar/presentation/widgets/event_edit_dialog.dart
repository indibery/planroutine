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
import '../../data/ai_task_exporter.dart';
import '../../domain/calendar_event.dart';
import '../providers/calendar_providers.dart';

/// 이벤트 추가/수정 바텀시트
class EventEditDialog extends ConsumerStatefulWidget {
  const EventEditDialog({
    super.key,
    required this.initialDate,
    this.event,
  });

  final DateTime initialDate;
  final CalendarEvent? event;

  /// 바텀시트 표시
  static Future<CalendarEvent?> show(
    BuildContext context, {
    required DateTime initialDate,
    CalendarEvent? event,
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
  DateTime? _endDate;
  late bool _isImportant;
  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController =
        TextEditingController(text: event?.description ?? '');
    _eventDate = event?.eventDateTime ?? widget.initialDate;
    _endDate = event?.endDate != null ? event?.endDateTime : null;
    _isImportant = event?.isImportant ?? false;
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
                _buildYearBumpChip(),
                const SizedBox(height: AppSizes.spacing16),
                _buildDescriptionField(),
                const SizedBox(height: AppSizes.spacing16),
                _buildDateRow(),
                const SizedBox(height: AppSizes.spacing8),
                _buildImportantToggle(),
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

  /// 제목에 올해 이전 연도가 있을 때만 나타나는 "연도 올해로" 원탭 칩.
  ///
  /// 컨트롤러를 구독해 입력 중에도 실시간으로 노출/숨김된다. 탭하면 제목의 이전
  /// 연도만 올해로 치환하고 커서를 끝으로 옮긴다. (저장은 사용자가 직접)
  Widget _buildYearBumpChip() {
    final currentYear = DateTime.now().year;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final result = bumpTitleYear(value.text, currentYear);
        if (result.from == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing8),
            child: ActionChip(
              avatar: Icon(
                Icons.event_repeat,
                size: 18,
                color: AppColors.gold,
              ),
              label: Text('${result.from} → $currentYear'),
              labelStyle: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.navy,
              side: BorderSide(color: AppColors.gold),
              onPressed: () {
                _titleController.value = TextEditingValue(
                  text: result.title,
                  selection:
                      TextSelection.collapsed(offset: result.title.length),
                );
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
      maxLines: 2,
    );
  }

  Widget _buildDateRow() {
    final formatter = DateFormat('yyyy년 M월 d일', 'ko_KR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateTile(
          label: CalendarStrings.eventDate,
          date: _eventDate,
          onTap: () => _pickDate(isStart: true),
        ),
        const SizedBox(height: AppSizes.spacing8),
        _buildDateTile(
          label: CalendarStrings.eventEndDate,
          date: _endDate,
          hint: formatter.format(_eventDate),
          onTap: () => _pickDate(isStart: false),
        ),
      ],
    );
  }

  Widget _buildDateTile({
    required String label,
    DateTime? date,
    String? hint,
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
              date != null ? formatter.format(date) : (hint ?? ''),
              style: TextStyle(
                fontSize: 14,
                color: date != null ? AppColors.textPrimary : AppColors.textHint,
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


  /// 중요 표시 토글. 켜면 캘린더 격자·목록에서 ★(골드)로 강조된다.
  Widget _buildImportantToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: SwitchListTile(
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

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _eventDate : (_endDate ?? _eventDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _eventDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked.isBefore(_eventDate) ? _eventDate : picked;
        }
      });
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

  CalendarEvent _buildEvent() {
    final now = DateTime.now().toIso8601String();
    final dateStr = formatDate(_eventDate);
    final endDateStr = _endDate != null ? formatDate(_endDate!) : null;
    return CalendarEvent(
      id: widget.event?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      eventDate: dateStr,
      endDate: endDateStr,
      isAllDay: true,
      // 색상 피커 제거 — 기존 색은 보존, 신규는 미지정(eventColor가 기본색으로 폴백)
      color: widget.event?.color,
      scheduleId: widget.event?.scheduleId,
      createdAt: widget.event?.createdAt ?? now,
      updatedAt: now,
      isImportant: _isImportant,
    );
  }

}
