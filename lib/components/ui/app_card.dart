// lib/components/ui/app_card.dart
// 🎴 統一的卡片組件 - 讓所有卡片風格一致

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 基礎卡片 - 所有卡片的基礎樣式
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final Gradient? gradient;
  
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.borderRadius,
    this.shadows,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppSizes.radiusXLarge;
    
    Widget cardContent = Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? AppSizes.cardPadding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        boxShadow: shadows ?? AppShadows.medium,
      ),
      child: child,
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        child: cardContent,
      );
    }
    
    return cardContent;
  }
}

/// 主要統計卡片 - 用於顯示重要數據（像「每日結果」）
class StatCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final Color? backgroundColor;
  final IconData? icon;
  final VoidCallback? onTap;
  
  const StatCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    this.backgroundColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: backgroundColor ?? AppColors.surface,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題區
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconMedium, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.gapSmall),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h4),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapLarge),
          // 內容區
          content,
        ],
      ),
    );
  }
}

/// 小型資訊卡片 - 用於顯示單一指標（像活躍天數、訓練次數）
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? backgroundColor;
  
  const InfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.primary,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizes.iconMedium, color: iconColor),
          ),
          const SizedBox(width: AppSizes.gapMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.h4.copyWith(color: iconColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表項目卡片 - 用於學員列表、聊天列表等
class ListItemCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  
  const ListItemCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSizes.gapMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSizes.gapSmall),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 行動卡片 - 用於快速操作按鈕（像「記錄飲食」「開始訓練」）
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: AppSizes.iconXLarge),
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}