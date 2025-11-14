// lib/components/ui/app_tag.dart
// 🏷️ 統一的標籤與徽章組件

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 基礎標籤 - 用於顯示角色、狀態等
class AppTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final bool outlined;
  
  const AppTag({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.icon,
    this.outlined = false,
  });
  
  // 預設樣式 - 教練
  factory AppTag.coach({String? label}) {
    return AppTag(
      label: label ?? '教練',
      color: AppColors.coach,
      icon: Icons.verified_user,
    );
  }
  
  // 預設樣式 - 學員
  factory AppTag.trainee({String? label}) {
    return AppTag(
      label: label ?? '學員',
      color: AppColors.trainee,
      icon: Icons.person,
    );
  }
  
  // 預設樣式 - 成功/已接受
  factory AppTag.success({required String label}) {
    return AppTag(
      label: label,
      color: AppColors.success,
      icon: Icons.check_circle,
    );
  }
  
  // 預設樣式 - 警告/需關注
  factory AppTag.warning({required String label}) {
    return AppTag(
      label: label,
      color: AppColors.warning,
      icon: Icons.warning_rounded,
    );
  }
  
  // 預設樣式 - 資訊
  factory AppTag.info({required String label}) {
    return AppTag(
      label: label,
      color: AppColors.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? 
        (outlined ? color : AppColors.textOnPrimary);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        border: outlined ? Border.all(color: color, width: 1.5) : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: effectiveTextColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: effectiveTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 數字徽章 - 用於顯示未讀數量、通知數等
class AppBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final bool showZero;
  
  const AppBadge({
    super.key,
    required this.count,
    this.color,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0 && !showZero) {
      return const SizedBox.shrink();
    }
    
    final displayCount = count > 99 ? '99+' : count.toString();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: color ?? AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          displayCount,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

/// 狀態點 - 用於顯示在線狀態等
class StatusDot extends StatelessWidget {
  final bool isActive;
  final Color? activeColor;
  final double size;
  
  const StatusDot({
    super.key,
    required this.isActive,
    this.activeColor,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive 
            ? (activeColor ?? AppColors.success) 
            : AppColors.textTertiary,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surface,
          width: 2,
        ),
      ),
    );
  }
}

/// 百分比標籤 - 用於顯示進度百分比
class PercentageTag extends StatelessWidget {
  final int percentage;
  final bool showIcon;
  
  const PercentageTag({
    super.key,
    required this.percentage,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    Color tagColor;
    IconData? icon;
    
    if (percentage >= 80) {
      tagColor = AppColors.success;
      icon = Icons.trending_up;
    } else if (percentage >= 50) {
      tagColor = AppColors.warning;
      icon = Icons.trending_flat;
    } else {
      tagColor = AppColors.error;
      icon = Icons.trending_down;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(icon, size: 14, color: tagColor),
            const SizedBox(width: 4),
          ],
          Text(
            '$percentage%',
            style: AppTextStyles.caption.copyWith(
              color: tagColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}