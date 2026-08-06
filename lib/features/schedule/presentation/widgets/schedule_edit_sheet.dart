import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/schedule.dart';
import '../providers/schedule_providers.dart';

/// 일정 편집 바텀시트.
///
/// 제목·설명·날짜를 수정하고 저장 시 [schedulesProvider]를 통해 업데이트한다.
class ScheduleEditSheet extends ConsumerStatefulWidget {
  const ScheduleEditSheet({super.key, required this.schedule});

  final Schedule schedule;

  /// 바텀시트 표시용 헬퍼.
  static Future<void> show(BuildContext context, Schedule schedule) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radius16),
        ),
      ),
      builder: (_) => ScheduleEditSheet(schedule: schedule),
    );
  }

  @override
  ConsumerState<ScheduleEditSheet> createState() => _ScheduleEditSheetState();
}

class _ScheduleEditSheetState extends ConsumerState<ScheduleEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule.title);
    _descController = TextEditingController(
      text: widget.schedule.description ?? '',
    );
    _selectedDate =
        DateTime.tryParse(widget.schedule.scheduledDate) ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (widget.schedule.id case final id?) {
      ref
          .read(schedulesProvider.notifier)
          .updateSchedule(
            id,
            title: _titleController.text,
            date: _selectedDate,
            description: _descController.text.isEmpty
                ? null
                : _descController.text,
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 아래를 가리는 것 중 **큰 쪽**만큼 여백을 준다 — 키보드(viewInsets)와
    // 시스템 내비게이션 바(viewPadding)는 서로 다른 값이다. 자세한 근거는
    // `event_edit_dialog.dart`의 같은 자리에 적어 뒀다(두 시트가 같은 규칙).
    //
    // **음수는 걸러낸다** — 3.41.6에서 플랫폼이 음수를 보고한 적이 있다.
    //
    // 가드: `schedule_edit_sheet_negative_inset_test.dart`(음수) ·
    //      `edit_sheet_system_inset_test.dart`(시스템 바).
    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(
          0,
          math.max(
            MediaQuery.viewInsetsOf(context).bottom,
            MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ScheduleStrings.editTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.spacing16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: ScheduleStrings.titleLabel,
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: ScheduleStrings.descriptionHint,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSizes.spacing12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: ScheduleStrings.dateLabel,
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('yyyy.MM.dd (E)', 'ko_KR').format(_selectedDate),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text(AppStrings.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
