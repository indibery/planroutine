import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/title_year_utils.dart';
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
    _descController =
        TextEditingController(text: widget.schedule.description ?? '');
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
      ref.read(schedulesProvider.notifier).updateSchedule(
            id,
            title: _titleController.text,
            date: _selectedDate,
            description:
                _descController.text.isEmpty ? null : _descController.text,
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.spacing24,
        AppSizes.spacing24,
        AppSizes.spacing24,
        MediaQuery.of(context).viewInsets.bottom + AppSizes.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
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
          _YearBumpChip(controller: _titleController),
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
    );
  }
}

/// 제목에 올해 이전 연도가 있을 때만 나타나는 "연도 올해로" 원탭 칩.
///
/// 컨트롤러 변경을 구독해 입력 중에도 실시간으로 노출/숨김된다. 탭하면 제목의
/// 이전 연도만 올해로 치환하고 커서를 끝으로 옮긴다. (저장은 사용자가 직접)
class _YearBumpChip extends StatelessWidget {
  const _YearBumpChip({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final result = bumpTitleYear(value.text, currentYear);
        if (result.from == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacing8),
            child: ActionChip(
              avatar: const Icon(Icons.event_repeat, size: 18),
              label: Text('${result.from} → $currentYear'),
              onPressed: () {
                controller.value = TextEditingValue(
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
}
