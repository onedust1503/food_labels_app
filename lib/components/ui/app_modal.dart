// lib/components/ui/app_modal.dart
// 🎨 統一的 Modal 彈窗組件 - 莫蘭迪風格

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Modal 彈窗工具類
class AppModal {
  /// 🎯 顯示底部彈窗 - 統一樣式和動畫
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeight,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      // 🎯 優化動畫
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 300),
      ),
      builder: (context) => Container(
        constraints: maxHeight != null 
            ? BoxConstraints(maxHeight: maxHeight)
            : null,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎯 拖動把手
            const _DragHandle(),
            // 內容
            Flexible(child: child),
          ],
        ),
      ),
    );
  }

  /// 🎯 顯示確認對話框
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '確定',
    String cancelText = '取消',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(title, style: AppTextStyles.h3),
        content: Text(message, style: AppTextStyles.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: AppTextStyles.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? AppColors.error : AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 🎯 顯示 Loading 對話框
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.large,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                if (message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: AppTextStyles.bodyLarge,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎯 顯示成功提示
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 🎯 顯示錯誤提示
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 🎯 顯示資訊提示
  static void showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// 拖動把手組件
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// 🎯 標準底部彈窗容器
class ModalContainer extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  
  const ModalContainer({
    super.key,
    this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

/// 🎯 快速操作底部彈窗
class QuickActionSheet extends StatelessWidget {
  final String title;
  final List<QuickActionItem> actions;
  
  const QuickActionSheet({
    super.key,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ModalContainer(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((action) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 24,
              ),
            ),
            title: Text(
              action.title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: action.subtitle != null
                ? Text(
                    action.subtitle!,
                    style: AppTextStyles.bodySmall,
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              action.onTap();
            },
          );
        }).toList(),
      ),
    );
  }
}

/// 快速操作項目
class QuickActionItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  QuickActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
  });
}