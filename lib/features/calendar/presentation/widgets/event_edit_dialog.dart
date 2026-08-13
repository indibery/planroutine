import 'dart:math' as math;

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

  /// 종류(업무/행사) 선택 행을 노출할지.
  ///
  /// 오늘 탭은 업무만 담는 화면이라 `false`로 잠근다 — 거기서 행사를 만들면
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
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
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
    // 고급 기능: AI 자동화 공유 토글이 ON이고 기존 이벤트 편집일 때만 노출(기본 OFF).
    final aiEnabled =
        ref.watch(aiTaskShareEnabledProvider).valueOrNull ?? false;

    // 아래를 가리는 것 중 **큰 쪽**만큼 여백을 준다 — 키보드(viewInsets)와
    // 시스템 내비게이션 바(viewPadding)는 서로 다른 값이다. 키보드가 올라오면
    // 그 인셋이 내비게이션 바 높이까지 포함하므로 더하지 않고 max로 고른다.
    //
    // **키보드만 보면 안 된다** — 키보드가 없을 때 `viewInsets.bottom`이 0이 되어
    // 여백이 통째로 사라지고, `useSafeArea`가 기본 false라 시트가 시스템 바 아래로
    // 뻗어 저장·취소 버튼이 깔린다(Android 실기기 신고, 24pt = 48dp 바의 절반).
    //
    // **음수는 걸러낸다** — 플랫폼이 음수 인셋을 보고한 순간이 실제로 있었고
    // (3.41.6, 1회), 그 값이 그대로 들어가면 `RenderPadding`의 `isNonNegative`
    // assert로 앱이 죽는다. 바깥 `max(0, ...)`이 두 값 모두를 막는다.
    //
    // 가드: `event_edit_dialog_negative_inset_test.dart`(음수) ·
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
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
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
                  icon: Icon(Icons.delete_outline, color: AppColors.inkRed),
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
              avatar: Icon(Icons.event_repeat, size: 18, color: AppColors.gold),
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
                  selection: TextSelection.collapsed(
                    offset: result.title.length,
                  ),
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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              formatter.format(date),
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
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
  /// 종류(업무/행사) + 중요 표시. [EventEditDialog.allowKindChange]가 false면
  /// 종류 행과 구분선을 함께 뺀다 — 구분선만 남으면 뭔가 잘린 것처럼 읽힌다.
  Widget _buildAttributesCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radius12),
      ),
      child: widget.allowKindChange
          ? _buildKindAndImportantRow()
          : _buildImportantTile(),
    );
  }

  /// 종류와 중요 표시를 **한 줄**에 넣는다(캘린더 경로).
  ///
  /// 나뉘어 있던 두 행을 합쳐 약 56dp를 회수한다 — 키보드가 올라오면 시트가 화면을
  /// 다 쓰고 그 뒤로는 저장·취소가 스크롤 밖으로 밀리는데, 그 임계값을 올린다
  /// (실측: 키보드 380dp에서 35dp 가렸다).
  ///
  /// ⚠️ **구조적 해결은 아니다.** 버튼이 여전히 `SingleChildScrollView` 안에 있어,
  /// 더 큰 키보드·큰 글꼴·필드 추가로 같은 자리가 다시 깨질 수 있다. 그때는 버튼을
  /// 스크롤 밖 고정 푸터로 빼는 것이 다음 수순이다.
  ///
  /// `종류` 글자를 뺐다 — 세그먼트가 `업무`/`행사`라 스스로 설명하고, 320pt 폭에서
  /// 글자까지 넣으면 넘친다(가드가 320·390·430을 훑는다).
  Widget _buildKindAndImportantRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacing16,
        vertical: AppSizes.spacing8,
      ),
      child: Row(
        children: [
          Icon(Icons.label_outline, color: AppColors.primary),
          const SizedBox(width: AppSizes.spacing12),
          Flexible(
            child: SegmentedButton<EntryKind>(
              key: const Key('kind_selector'),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // 채움은 goldFill + onGold — 라이트에서 gold(딥골드) 채움은 대비가 낮다.
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.onGold
                      : AppColors.sub,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.goldFill
                      : Colors.transparent,
                ),
                side: WidgetStatePropertyAll(
                  BorderSide(color: AppColors.lineStrong, width: 0.5),
                ),
              ),
              segments: EntryKind.values
                  .map(
                    (k) => ButtonSegment<EntryKind>(
                      value: k,
                      label: Text(k.label),
                    ),
                  )
                  .toList(),
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
          const SizedBox(width: AppSizes.spacing8),
          _buildImportantChip(),
        ],
      ),
    );
  }

  /// 중요 표시 — **이름을 컨트롤 안에 담은 토글 칩.**
  ///
  /// 종류와 한 줄로 합치던 시절에는 `★ + Switch`였는데, 글자 라벨이 없어 처음 보는
  /// 사람이 무슨 스위치인지 알 수 없었다(사용자 신고 2026-08-07). 게다가 별이 상태와
  /// 무관하게 늘 골드라 **꺼져 있어도 켜진 것처럼** 보였다.
  ///
  /// 스위치를 버리고 칩으로 바꾸면 이름이 들어가면서 오히려 **좁아진다**
  /// (실측 84 → 72dp). 라벨을 뺐던 이유가 폭이었으므로 그 제약이 풀린다.
  ///
  /// 상태는 **채움과 별 모양 두 겹**으로 말한다 — 색만으로 두지 않는 것은 도장
  /// 시트가 선택 표시에 체크 아이콘을 함께 넣은 것과 같은 이유다.
  /// 채움은 `goldFill` + `onGold`로 바로 옆 세그먼트와 같은 규칙을 쓴다.
  Widget _buildImportantChip() {
    final on = _isImportant;
    return Semantics(
      label: CalendarStrings.importantLabel,
      button: true,
      toggled: on,
      // **자식 시맨틱을 제외한다.** 칩 안의 `중요` 텍스트가 자기 노드를 만들어
      // 부모 라벨을 덮으면, 스크린리더가 `중요 표시` 대신 `중요`만 읽는다
      // (가드가 `bySemanticsLabel`로 0건을 잡았다).
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('important_toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isImportant = !on),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing12),
          decoration: BoxDecoration(
            color: on ? AppColors.goldFill : Colors.transparent,
            border: Border.all(
              color: on ? AppColors.goldFill : AppColors.lineStrong,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.star_rounded : Icons.star_border_rounded,
                size: AppSizes.iconSmall,
                color: on ? AppColors.onGold : AppColors.sub,
              ),
              const SizedBox(width: AppSizes.spacing4),
              Text(
                CalendarStrings.importantBadge,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.onGold : AppColors.sub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 오늘 탭 경로 — 종류를 못 바꾸므로 중요 표시만 한 줄로 둔다(기존 그대로).
  Widget _buildImportantTile() {
    return Column(
      children: [
        SwitchListTile(
          key: const Key('important_toggle'),
          value: _isImportant,
          onChanged: (v) => setState(() => _isImportant = v),
          // **썸 색을 지정하지 않는다.** `app_theme`의 `switchTheme`이 ON 썸을
          // navy, 트랙을 gold로 잡아 대비를 맞춰 뒀다. 여기서 `activeThumbColor`를
          // gold로 주면 트랙과 같은 색이 돼 **ON이 썸 없는 단색 골드 알약**이
          // 된다(두 팔레트 모두 트랙=`gold`라 다크·라이트 둘 다 재현). 같은 결함을
          // 버스 표시 스위치(I12)에서 고친 것과 같은 이유로 지운다.
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
          child: GoldGradientButton(label: AppStrings.save, onPressed: _onSave),
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
  /// (kind → 행사가 업무로, googleEventId → Google 중복 이벤트).
  /// `CalendarEvent`에 필드가 추가돼도 여기를 고칠 필요가 없어야 한다.
  CalendarEvent _buildEvent() {
    final now = DateTime.now().toIso8601String();
    final existing = widget.event;

    if (existing != null) {
      // 종료 날짜 입력 UI는 없지만 endDate는 copyWith가 보존한다. 시작일을
      // 옛 종료일보다 뒤로 옮기면 기간이 거꾸로(end < start) 남아 Google/기기
      // 캘린더 저장이 실패한다 — UI로 고칠 방법도 없으니 모순되면 버린다.
      final staleEnd =
          existing.endDate != null && existing.endDateTime.isBefore(_eventDate);
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
