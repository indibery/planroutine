import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/sheet_title.dart';
import '../../domain/schoolbook_models.dart';

/// 교실 고르기 시트 — 이름과 정원. 고른 교실을 돌려준다(닫으면 null).
Future<SchoolbookRoom?> showRoomPicker(
  BuildContext context, {
  required List<SchoolbookRoom> rooms,
  required int? selectedId,
}) {
  return showModalBottomSheet<SchoolbookRoom>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.spacing16),
              child: SheetTitle(SchoolbookStrings.roomPickerTitle),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final room in rooms)
                    ListTile(
                      title: Text(room.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(SchoolbookStrings.capacity(room.capacity)),
                      trailing: room.id == selectedId
                          ? Icon(Icons.check, color: AppColors.gold, semanticLabel: room.name)
                          : null,
                      onTap: () => Navigator.of(context).pop(room),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
