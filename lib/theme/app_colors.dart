// lib/theme/app_colors.dart
// Soft UI 色彩系統 - 柔和且現代的配色方案

import 'package:flutter/material.dart';

class AppColors {
  // ========== 基礎背景色 ==========
  // 主背景 - 非常淡的灰藍色,營造輕鬆氛圍
  static const Color background = Color(0xFFF0F4F8);
  
  // 卡片背景 - 純白,用於主要內容區塊
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // 次要背景 - 用於區塊分隔
  static const Color secondaryBackground = Color(0xFFF8FAFB);

  // ========== 主色調 ==========
  // 主要品牌色 - 柔和的藍色
  static const Color primary = Color(0xFF5B8DEE);
  static const Color primaryLight = Color(0xFF8FB4F7);
  static const Color primaryDark = Color(0xFF3B69CC);
  
  // 主色調的淡版本 - 用於背景高亮
  static const Color primaryPale = Color(0xFFE8F0FE);

  // ========== 功能色 ==========
  // 成功 - 柔和的綠色
  static const Color success = Color(0xFF6BCF8F);
  static const Color successLight = Color(0xFFE8F8ED);
  
  // 警告 - 柔和的橙色
  static const Color warning = Color(0xFFFAB76A);
  static const Color warningLight = Color(0xFFFFF4E5);
  
  // 錯誤 - 柔和的紅色
  static const Color error = Color(0xFFEF7B7B);
  static const Color errorLight = Color(0xFFFEE8E8);
  
  // 資訊 - 柔和的青色
  static const Color info = Color(0xFF62C9E8);
  static const Color infoLight = Color(0xFFE5F7FC);

  // ========== 營養素顏色 ==========
  // 熱量 - 溫暖的橘紅色
  static const Color calories = Color(0xFFFF9066);
  
  // 蛋白質 - 活力的粉紅色
  static const Color protein = Color(0xFFFF6B9D);
  
  // 碳水化合物 - 陽光黃色
  static const Color carbs = Color(0xFFFFC94D);
  
  // 脂肪 - 清新的紫色
  static const Color fat = Color(0xFF9B8AFF);

  // ========== 文字顏色 ==========
  // 主要文字 - 深灰色,不使用純黑避免過於刺眼
  static const Color textPrimary = Color(0xFF2D3748);
  
  // 次要文字 - 中等灰色
  static const Color textSecondary = Color(0xFF718096);
  
  // 輔助文字 - 淺灰色
  static const Color textTertiary = Color(0xFFA0AEC0);
  
  // 白色文字 - 用於深色背景
  static const Color textWhite = Color(0xFFFFFFFF);

  // ========== 陰影顏色 ==========
  // 柔和陰影 - 用於卡片浮起效果
  static Color shadowLight = const Color(0xFF2D3748).withOpacity(0.04);
  static Color shadowMedium = const Color(0xFF2D3748).withOpacity(0.08);
  static Color shadowDark = const Color(0xFF2D3748).withOpacity(0.12);

  // ========== 餐別顏色 ==========
  // 早餐 - 清晨的金黃色
  static const Color breakfast = Color(0xFFFFC94D);
  static const Color breakfastLight = Color(0xFFFFF8E1);
  
  // 午餐 - 正午的橙色
  static const Color lunch = Color(0xFFFF9066);
  static const Color lunchLight = Color(0xFFFFE8DC);
  
  // 晚餐 - 黃昏的紫色
  static const Color dinner = Color(0xFF9B8AFF);
  static const Color dinnerLight = Color(0xFFF0EDFF);
  
  // 點心 - 甜美的粉紅色
  static const Color snack = Color(0xFFFF6B9D);
  static const Color snackLight = Color(0xFFFFE0EC);

  // 🌙 宵夜 - 深夜的藍紫色
  static const Color lateNight = Color(0xFF6B9DFF);
  static const Color lateNightLight = Color(0xFFE0ECFF);

  // ========== 分隔線 ==========
  static const Color divider = Color(0xFFE2E8F0);

  // ========== 輔助方法 ==========
  
  /// 根據餐別返回對應顏色
  static Color getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfast;
      case 'lunch':
        return lunch;
      case 'dinner':
        return dinner;
      case 'snack':
        return snack;
      case 'latenight':
      case 'late_night':
        return lateNight;
      default:
        return primary;
    }
  }

  /// 根據餐別返回對應淡色背景
  static Color getMealLightColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfastLight;
      case 'lunch':
        return lunchLight;
      case 'dinner':
        return dinnerLight;
      case 'snack':
        return snackLight;
      case 'latenight':
      case 'late_night':
        return lateNightLight;
      default:
        return primaryPale;
    }
  }

  /// 根據餐別返回中文名稱
  static String getMealName(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '點心';
      case 'latenight':
      case 'late_night':
        return '宵夜';
      default:
        return '其他';
    }
  }

  /// 根據餐別返回emoji圖示
  static String getMealEmoji(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      case 'snack':
        return '🍪';
      case 'latenight':
      case 'late_night':
        return '🌃';
      default:
        return '🍽️';
    }
  }
}