import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/schoolbook_models.dart';

/// 맨 위 교실 칩 한 줄(시안 A). 장소가 많으면 옆으로 민다(사용자 결정 — 여러 줄로 감싸지 않는다).
///
/// 한 줄이라 생기는 두 문제를 막는다: 고른 교실이 화면 밖이면 열 때 그 칩까지 스크롤하고,
/// 칩이 더 있는 쪽 끝을 흐리게 해 밀 수 있다는 것을 알린다.
class RoomChips extends StatefulWidget {
  const RoomChips({
    super.key,
    required this.rooms,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SchoolbookRoom> rooms;
  final int selectedId;
  final ValueChanged<SchoolbookRoom> onSelect;

  static Key chipKey(int roomId) => Key('schoolbook_room_$roomId');
  static const moreLeftKey = Key('schoolbook_rooms_more_left');
  static const moreRightKey = Key('schoolbook_rooms_more_right');

  @override
  State<RoomChips> createState() => _RoomChipsState();
}

class _RoomChipsState extends State<RoomChips> {
  final _scroll = ScrollController();
  final _selectedChip = GlobalKey();
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(RoomChips old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId || old.rooms.length != widget.rooms.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelected() {
    if (!mounted) return;
    final chip = _selectedChip.currentContext;
    if (chip != null) {
      Scrollable.ensureVisible(chip, alignment: 0.5, duration: Duration.zero);
    }
    _updateEdges();
  }

  void _updateEdges() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final left = p.extentBefore > 0.5;
    final right = p.extentAfter > 0.5;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      // 칩 폭이 정해진 뒤(첫 배치 · 글자 크기 변경)에도 끝 표시를 맞춘다
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
            child: Row(
              children: [
                for (final room in widget.rooms) ...[
                  KeyedSubtree(
                    key: room.id == widget.selectedId ? _selectedChip : null,
                    child: PillChip(
                      key: RoomChips.chipKey(room.id),
                      label: room.name,
                      selected: room.id == widget.selectedId,
                      onTap: () => widget.onSelect(room),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacing8),
                ],
              ],
            ),
          ),
          if (_moreLeft) const _EdgeFade(key: RoomChips.moreLeftKey, left: true),
          if (_moreRight) const _EdgeFade(key: RoomChips.moreRightKey, left: false),
        ],
      ),
    );
  }
}

/// 칩이 더 있는 쪽 끝을 배경색으로 흐린다. 누르는 것은 아래 칩으로 그대로 간다.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({super.key, required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: 40,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [bg, bg.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
