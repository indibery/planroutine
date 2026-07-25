import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../calendar/domain/calendar_event.dart';
import '../../domain/stamp_settings.dart';
import 'completion_seal.dart';

/// 오늘 탭의 이벤트 한 줄 — 체크 원 + 제목 + 완료 도장 슬롯.
///
/// 체크 원을 누르면 행이 살짝 눌렸다 올라오고(340ms) 우측에 도장이 떨어진다(460ms).
/// 완료해도 목록에서 빠지지 않고 자리에 남는다 — 재정렬하면 도장이 화면 밖에서 재생된다.
class TodayEventRow extends StatefulWidget {
  const TodayEventRow({
    super.key,
    required this.event,
    required this.onToggle,
    required this.onTap,
    this.stampSettings = StampSettings.defaults,
    this.showOverdueDate = false,
  });

  final CalendarEvent event;

  /// 도장 모양 + "이미 찍은 도장 흐리게" 설정.
  final StampSettings stampSettings;

  /// 체크 원 탭.
  final VoidCallback onToggle;

  /// 본문 탭 — 편집 시트로.
  final VoidCallback onTap;

  /// 기한이 지난 행이면 날짜를 붉게 표시한다.
  final bool showOverdueDate;

  /// 체크 원의 최소 탭 영역 (iOS HIG). 원은 24로 보이지만 손가락은 44를 겨냥한다.
  static const _tapTarget = 44.0;

  /// 우측 도장 슬롯 폭 — 제목이 도장 밑으로 들어가지 않게 자리를 비워둔다.
  static const _sealSlot = 56.0;

  /// build마다 새로 만들면 행 수만큼 낭비된다(생성 2.5µs vs 재사용 0.16µs).
  static final _overdueFormatter = DateFormat('M월 d일', 'ko_KR');

  @override
  State<TodayEventRow> createState() => _TodayEventRowState();
}

class _TodayEventRowState extends State<TodayEventRow>
    with TickerProviderStateMixin {
  late final AnimationController _seal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 200),
    value: widget.event.isCompleted ? 1 : 0,
  );

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  static final Animatable<double> _pressScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.975), weight: 22),
    TweenSequenceItem(
      tween: Tween(begin: 0.975, end: 1.0).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 78,
    ),
  ]);

  /// 이 행이 처음 그려질 때 이미 완료돼 있었는지.
  ///
  /// "이미 찍은 도장 흐리게" 설정은 **지난 도장**에만 적용해야 한다. 화면에서 방금
  /// 누른 도장은 진하게 남아야 누르는 재미가 산다.
  ///
  /// initState에서 즉시 채운다 — 필드 초기화식으로 두면 첫 읽기 시점까지 지연돼
  /// 그때의 완료 상태를 "진입 시 상태"로 오인할 수 있다.
  late bool _stampedOnEntry;

  @override
  void initState() {
    super.initState();
    _stampedOnEntry = widget.event.isCompleted;
  }

  @override
  void didUpdateWidget(TodayEventRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.event.isCompleted;
    final now = widget.event.isCompleted;
    if (now && !was) {
      // 화면에서 방금 찍은 도장 — 흐리게 대상이 아니다.
      _stampedOnEntry = false;
      _seal.forward(from: 0);
    } else if (!now && was) {
      _seal.reverse();
    }
  }

  @override
  void dispose() {
    _seal.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onCheckTap() {
    HapticFeedback.mediumImpact();
    _press.forward(from: 0);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (context, child) => Transform.scale(
        scale: _pressScale.evaluate(_press),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.line, width: 0.5),
            ),
          ),
          child: Padding(
            // 우측 여백 — 도장이 화면 경계에 붙지 않게. 앱 전체 페이지 여백(20)에 맞춘다.
            padding: const EdgeInsets.only(
              left: AppSizes.spacing8,
              right: AppSizes.spacing12,
            ),
            child: Row(
              children: [
                _checkCircle(),
                Expanded(child: _titleBlock()),
                _sealSlot(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkCircle() {
    final isDone = widget.event.isCompleted;
    return GestureDetector(
      key: Key('today_check_${widget.event.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: _onCheckTap,
      child: SizedBox(
        width: TodayEventRow._tapTarget,
        height: TodayEventRow._tapTarget,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: AppSizes.iconMedium,
            height: AppSizes.iconMedium,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.goldFill : Colors.transparent,
              border: Border.all(
                color: isDone ? AppColors.goldFill : AppColors.border,
                width: 1.6,
              ),
            ),
            child: AnimatedScale(
              scale: isDone ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.check_rounded,
                size: 15,
                color: AppColors.onGold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final event = widget.event;
    final isDone = event.isCompleted;
    final showImportant = event.showsImportant;
    final meta = _metaLabel();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showImportant)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2,
                    right: AppSizes.spacing4,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppColors.goldFill,
                  ),
                ),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: isDone ? AppColors.faint : AppColors.ink,
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.faint,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: isDone
                      ? AppColors.faint
                      : (widget.showOverdueDate
                          ? AppColors.inkRed
                          : AppColors.sub),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 지난 행은 기한 날짜를, 오늘 행은 설명을 메타로 쓴다.
  String? _metaLabel() {
    if (widget.showOverdueDate) {
      return TodayEventRow._overdueFormatter.format(widget.event.eventDateTime);
    }
    final description = widget.event.description;
    if (description == null || description.isEmpty) return null;
    return description;
  }

  Widget _sealSlot() {
    return AnimatedBuilder(
      animation: _seal,
      builder: (context, _) {
        // 완료 취소 중(reverse)에도 페이드아웃이 끝날 때까지 남아 있어야 한다.
        final visible = widget.event.isCompleted || _seal.value > 0;
        return SizedBox(
          width: TodayEventRow._sealSlot,
          child: visible
              ? Center(
                  child: CompletionSeal(
                    key: Key('today_seal_${widget.event.id}'),
                    animation: _seal,
                    style: widget.stampSettings.style,
                    dimmed: widget.stampSettings.dimPreviousStamps &&
                        _stampedOnEntry,
                  ),
                )
              : null,
        );
      },
    );
  }
}
