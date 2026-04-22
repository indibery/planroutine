import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/gold_gradient_button.dart';
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
  late bool _isAllDay;
  late Color _selectedColor;
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
    _isAllDay = event?.isAllDay ?? true;
    _selectedColor = event?.eventColor ?? AppColors.eventPresets[0];
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
                const SizedBox(height: AppSizes.spacing16),
                _buildDescriptionField(),
                const SizedBox(height: AppSizes.spacing16),
                _buildDateRow(),
                const SizedBox(height: AppSizes.spacing16),
                _buildAllDayToggle(),
                const SizedBox(height: AppSizes.spacing16),
                _buildColorPicker(),
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
          style: const TextStyle(
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
                  icon: const Icon(
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
              style: const TextStyle(
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
            const Icon(
              Icons.calendar_today,
              size: AppSizes.iconSmall,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDayToggle() {
    return Row(
      children: [
        const Text(
          CalendarStrings.eventAllDay,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Switch(
          value: _isAllDay,
          onChanged: (value) => setState(() => _isAllDay = value),
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          CalendarStrings.eventColor,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spacing8),
        Row(
          children: AppColors.eventPresets.map((color) {
            final isSelected = _selectedColor.toARGB32() == color.toARGB32();
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  height: 32,
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSizes.spacing4 / 2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppColors.gold, width: 2.5)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: AppColors.navy, size: 16)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
    final colorHex = CalendarEvent.colorToHex(_selectedColor);
    return CalendarEvent(
      id: widget.event?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      eventDate: dateStr,
      endDate: endDateStr,
      isAllDay: _isAllDay,
      color: colorHex,
      scheduleId: widget.event?.scheduleId,
      createdAt: widget.event?.createdAt ?? now,
      updatedAt: now,
    );
  }

}
