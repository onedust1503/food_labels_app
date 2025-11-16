// lib/widgets/nutrition/soft_card.dart
// Soft UI 風格的卡片組件 - 帶有柔和陰影和圓角

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool enabled;

  const SoftCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 24.0,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // 主陰影 - 下方
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          // 次陰影 - 增加深度
          BoxShadow(
            color: AppColors.shadowLight.withOpacity(0.5),
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null && enabled) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 淺色背景的軟卡片 - 用於次要內容
class SoftCardLight extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;

  const SoftCardLight({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        // 非常輕微的陰影,幾乎看不見
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 餐別選擇按鈕 - Soft UI 風格
class MealTypeChip extends StatelessWidget {
  final String mealType;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const MealTypeChip({
    super.key,
    required this.mealType,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.getMealColor(mealType)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.getMealColor(mealType)
                : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.getMealColor(mealType).withOpacity(0.25),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppColors.getMealEmoji(mealType),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.textWhite : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圓形控制按鈕 - 用於份量增減
class SoftCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const SoftCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled
              ? (color ?? AppColors.primary)
              : AppColors.divider,
          shape: BoxShape.circle,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: (color ?? AppColors.primary).withOpacity(0.25),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isEnabled ? AppColors.textWhite : AppColors.textTertiary,
          size: size * 0.5,
        ),
      ),
    );
  }
}