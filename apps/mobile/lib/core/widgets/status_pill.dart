import 'package:flutter/material.dart';

import '../../models/family_activity.dart';
import '../theme/app_colors.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.dot = false,
    this.compact = false,
  });

  factory StatusPill.request(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const StatusPill(
          label: '待审核',
          foreground: AppColors.gold,
          background: AppColors.goldSoft,
          dot: true,
        );
      case RequestStatus.approved:
        return const StatusPill(
          label: '已通过',
          foreground: AppColors.jade,
          background: AppColors.jadeSoft,
          dot: true,
        );
      case RequestStatus.rejected:
        return const StatusPill(
          label: '已拒绝',
          foreground: AppColors.cinnabar,
          background: AppColors.cinnabarSoft,
          dot: true,
        );
      case RequestStatus.cancelled:
        return const StatusPill(
          label: '已取消',
          foreground: AppColors.inkMuted,
          background: AppColors.slateSoft,
          dot: true,
        );
    }
  }

  final String label;
  final Color foreground;
  final Color background;
  final bool dot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              height: 1.1,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.color = AppColors.inkMuted,
    this.background = AppColors.slateSoft,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1.15,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
