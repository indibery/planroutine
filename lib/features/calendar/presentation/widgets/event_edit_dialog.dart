import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/calendar_event.dart';

/// 이벤트 추가/수정 바텀시트
class EventEditDialog extends StatefulWidget {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius16),
        ),
      ),
      builder: (_) => EventEditDialog(
        initialDate: initialDate,
        event: event,
      ),
    );
  }

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
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
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppSizes.radius4),
          ),
        ),
        const Spacer(),
        Text(
          _isEditing ? AppStrings.calendarEditEvent : AppStrings.calendarAddEvent,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: AppStrings.calendarEventTitle,
        hintText: AppStrings.calendarEventTitleHint,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return AppStrings.calendarTitleRequired;
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: AppStrings.calendarEventDescription,
        hintText: AppStrings.calendarEventDescriptionHint,
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
          label: AppStrings.calendarEventDate,
          date: _eventDate,
          onTap: () => _pickDate(isStart: true),
        ),
        const SizedBox(height: AppSizes.spacing8),
        _buildDateTile(
          label: AppStrings.calendarEventEndDate,
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
          AppStrings.calendarEventAllDay,
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
          AppStrings.calendarEventColor,
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
                        ? Border.all(color: AppColors.textPrimary, width: 2.5)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
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
          child: ElevatedButton(
            onPressed: _onSave,
            child: const Text(AppStrings.save),
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

    final now = DateTime.now().toIso8601String();
    final dateStr = _formatDate(_eventDate);
    final endDateStr = _endDate != null ? _formatDate(_endDate!) : null;
    final colorHex = CalendarEvent.colorToHex(_selectedColor);

    final result = CalendarEvent(
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

    Navigator.pop(context, result);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
