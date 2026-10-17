import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/button_semantics.dart';

/// 맨 위 교실 이름 한 줄(시안 B). 누르면 교실 고르기 시트.
class RoomBar extends StatelessWidget {
  const RoomBar({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius12)),
      child: ButtonSemantics(
        label: '$name ${SchoolbookStrings.changeRoom}',
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacing16,
              vertical: AppSizes.spacing12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spacing8),
                Text(
                  SchoolbookStrings.changeRoom,
                  style: TextStyle(fontSize: 14, color: AppColors.sub),
                ),
                Icon(Icons.expand_more, size: 20, color: AppColors.sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
