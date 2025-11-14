// lib/components/ui/app_card.dart
// 🎴 統一的卡片組件 - 讓所有卡片風格一致（莫蘭迪風格優化版）

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
    // 🎯 重點改動：預設圓角改為 24（更圓潤）
    final effectiveBorderRadius = borderRadius ?? 24.0;
    
    Widget cardContent = Container(
      // 🎯 重點改動：增加垂直間距到 12
      margin: margin ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      // 🎯 重點改動：增加內邊距到 20
      padding: padding ?? const EdgeInsets.all(20),
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
                Icon(icon, size: 22, color: AppColors.textSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h4),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // 🎯 重點改動：增加內容區間距
          const SizedBox(height: 20),
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
      // 🎯 重點改動：增加內邊距
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? iconColor.withValues(alpha: 0.1),
        // 🎯 重點改動：圓角改為 20
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // 🎯 簡化層級：移除多餘的 Container 包覆
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
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
      // 🎯 重點改動：增加內邊距
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 16),
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
                  const SizedBox(height: 6),
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
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 行動卡片 - 用於快速操作按鈕（像「記錄飲食」「開始訓練」）
/// 🎯 重點改動：這個組件最需要改進 - 參考圖片的圓潤卡片
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
      // 🎯 圓角改為 24（超圓潤）
      borderRadius: BorderRadius.circular(24),
      child: Container(
        // 🎯 增加垂直內邊距
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          // 🎯 簡化邊框 - 更淡
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎯 簡化 icon - 移除多餘包覆
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🆕 學習卡片 - 像參考圖片中的 Geography、Geometry 卡片
class SubjectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  
  const SubjectCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon 容器
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            // 標題
            Text(
              title,
              style: AppTextStyles.h4.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            // 副標題
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}