// lib/theme/workout_colors.dart
// 🎨 運動模組專用 Soft UI 主題色彩
// 與飲食模組的藍色系區分，使用活力橘色系

import 'package:flutter/material.dart';

class WorkoutColors {
  // ========== 主色調 ==========
  // 活力橘 - 運動模組主色
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8A5C);
  static const Color primaryDark = Color(0xFFE55A2B);
  static const Color primarySoft = Color(0xFFFFF0EB);
  
  // 薄荷綠 - 完成/成功狀態
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successSoft = Color(0xFFE8F5E9);
  
  // 天藍色 - 休息狀態
  static const Color rest = Color(0xFF42A5F5);
  static const Color restLight = Color(0xFF64B5F6);
  static const Color restSoft = Color(0xFFE3F2FD);
  
  // 灰色 - 待做狀態
  static const Color pending = Color(0xFFBDBDBD);
  static const Color pendingLight = Color(0xFFE0E0E0);
  static const Color pendingSoft = Color(0xFFF5F5F5);
  
  // 進行中 - 亮橘色
  static const Color active = Color(0xFFFFB74D);
  static const Color activeSoft = Color(0xFFFFF8E1);
  
  // ========== 背景色 ==========
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  static const Color surfaceLight = Color(0xFFFAFAFA);
  
  // ========== 文字色 ==========
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;
  
  // ========== 運動類型顏色 ==========
  static const Color chest = Color(0xFFE57373);      // 胸部 - 紅
  static const Color back = Color(0xFF64B5F6);       // 背部 - 藍
  static const Color legs = Color(0xFF81C784);       // 腿部 - 綠
  static const Color shoulders = Color(0xFFFFB74D);  // 肩膀 - 橘
  static const Color arms = Color(0xFFBA68C8);       // 手臂 - 紫
  static const Color core = Color(0xFF4DD0E1);       // 核心 - 青
  static const Color cardio = Color(0xFFFF8A65);     // 有氧 - 橘紅
  
  // ========== 漸層 ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient restGradient = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ========== Soft UI 陰影 ==========
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> softShadowSmall = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ];
  
  // ========== 根據運動類型獲取顏色 ==========
  static Color getExerciseTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'chest':
      case '胸部':
        return chest;
      case 'back':
      case '背部':
        return back;
      case 'legs':
      case '腿部':
        return legs;
      case 'shoulders':
      case '肩膀':
        return shoulders;
      case 'arms':
      case '手臂':
        return arms;
      case 'core':
      case '核心':
        return core;
      case 'cardio':
      case '有氧':
        return cardio;
      default:
        return primary;
    }
  }
}