import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/pill_chip.dart';
import '../../domain/schoolbook_models.dart';

/// 맨 위 교실 칩 한 줄(시안 A). 교실이 많으면 옆으로 민다.
class RoomChips extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacing16),
      child: Row(
        children: [
          for (final room in rooms) ...[
            PillChip(
              key: chipKey(room.id),
              label: room.name,
              selected: room.id == selectedId,
              onTap: () => onSelect(room),
            ),
            const SizedBox(width: AppSizes.spacing8),
          ],
        ],
      ),
    );
  }
}
