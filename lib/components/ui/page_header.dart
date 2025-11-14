// lib/components/ui/page_header.dart
// 📱 統一的頁面頭部組件

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_tag.dart';

/// 簡單頁面標題 - 用於內頁
class SimplePageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  
  const SimplePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingLarge,
        vertical: AppSizes.paddingMedium,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new),
              color: AppColors.textPrimary,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// 主頁頭部 - 帶頭像和問候語
class HomePageHeader extends StatelessWidget {
  final String userName;
  final String greetingMessage;
  final String? avatarUrl;
  final bool isCoach;
  final int? notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onRefresh;
  
  const HomePageHeader({
    super.key,
    required this.userName,
    required this.greetingMessage,
    this.avatarUrl,
    required this.isCoach,
    this.notificationCount,
    this.onNotificationTap,
    this.onMenuTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingLarge),
      child: Row(
        children: [
          // 左側：頭像 + 名字
          Expanded(
            child: Row(
              children: [
                // 漢堡選單按鈕
                if (onMenuTap != null)
                  IconButton(
                    icon: const Icon(Icons.menu, size: 28),
                    onPressed: onMenuTap,
                    color: AppColors.textPrimary,
                  ),
                
                // 頭像
                Hero(
                  tag: 'user_avatar',
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCoach 
                          ? AppColors.secondaryGradient 
                          : AppColors.primaryGradient,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: AppSizes.gapMedium),
                
                // 問候語
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        greetingMessage,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 右側：操作按鈕
          Row(
            children: [
              // 刷新按鈕
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.textSecondary,
                  tooltip: '刷新',
                ),
              
              // 通知按鈕（帶徽章）
              if (onNotificationTap != null)
                Stack(
                  children: [
                    IconButton(
                      onPressed: onNotificationTap,
                      icon: const Icon(Icons.notifications_outlined),
                      color: AppColors.textSecondary,
                      tooltip: '通知',
                    ),
                    if (notificationCount != null && notificationCount! > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: AppBadge(count: notificationCount!),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 漸層頭部 - 用於特殊強調的頁面
class GradientPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Gradient gradient;
  final VoidCallback? onBack;
  
  const GradientPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.gradient,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingLarge,
        AppSizes.paddingXXLarge,
        AppSizes.paddingLarge,
        AppSizes.paddingLarge,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXXLarge),
          bottomRight: Radius.circular(AppSizes.radiusXXLarge),
        ),
        boxShadow: AppShadows.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部行：返回按鈕 + trailing
          if (onBack != null || trailing != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new),
                    color: AppColors.textOnPrimary,
                  )
                else
                  const SizedBox(width: 48),
                
                if (trailing != null) trailing!,
              ],
            ),
          
          const SizedBox(height: AppSizes.gapLarge),
          
          // 標題
          Text(
            title,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
          
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              subtitle!,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textOnPrimary.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 頁面區塊標題 - 用於分隔不同內容區塊
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? icon;
  
  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingLarge,
        vertical: AppSizes.paddingMedium,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconMedium, color: AppColors.textSecondary),
            const SizedBox(width: AppSizes.gapSmall),
          ],
          Expanded(
            child: Text(title, style: AppTextStyles.h3),
          ),
          if (actionText != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(actionText!),
            ),
        ],
      ),
    );
  }
}