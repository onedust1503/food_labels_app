// lib/theme/app_theme.dart
// 🎨 App 設計系統 - 統一的視覺風格定義

import 'package:flutter/material.dart';

/// 🎨 App 配色方案
class AppColors {
  // ===== 主色調 =====
  static const Color primary = Color(0xFF6C63FF);        // 紫藍色
  static const Color primaryLight = Color(0xFF9B95FF);
  static const Color primaryDark = Color(0xFF4D46CC);
  
  static const Color secondary = Color(0xFF22C55E);      // 綠色
  static const Color secondaryLight = Color(0xFF7FD957);
  static const Color secondaryDark = Color(0xFF16A34A);
  
  // ===== 輔助色（Pastel 柔色） =====
  static const Color accent1 = Color(0xFFFFB84D);        // 柔和橘
  static const Color accent2 = Color(0xFF7DCFB6);        // 柔和綠
  static const Color accent3 = Color(0xFFA996FF);        // 柔和紫
  static const Color accent4 = Color(0xFFFF8FA3);        // 柔和粉
  
  // ===== 背景色（淡色漸層背景） =====
  static const Color background = Color(0xFFF5F6FA);     // 淡灰紫
  static const Color backgroundAlt = Color(0xFFF8F9FC);  // 更淡的替代背景
  
  // ===== 卡片與表面 =====
  static const Color surface = Color(0xFFFFFFFF);        // 白色卡片
  static const Color surfaceLight = Color(0xFFFAFAFC);   // 淡色卡片
  
  // ===== 文字顏色 =====
  static const Color textPrimary = Color(0xFF1F2933);    // 深灰 - 主要文字
  static const Color textSecondary = Color(0xFF6B7280);  // 中灰 - 次要文字
  static const Color textTertiary = Color(0xFF9CA3AF);   // 淺灰 - 輔助文字
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // 白色 - 用在深色背景上
  
  // ===== 狀態色 =====
  static const Color success = Color(0xFF22C55E);        // 成功/活躍
  static const Color warning = Color(0xFFFFB84D);        // 警告/需關注
  static const Color error = Color(0xFFEF4444);          // 錯誤/危險
  static const Color info = Color(0xFF3B82F6);           // 資訊
  
  // ===== 語義化顏色（用於特定場景） =====
  static const Color coach = Color(0xFF22C55E);          // 教練色
  static const Color trainee = Color(0xFF3B82F6);        // 學員色
  
  // ===== 漸層定義 =====
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B95FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF7FD957)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFB84D), Color(0xFFFF8FA3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8F9FC), Color(0xFFF5F6FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// 📏 App 尺寸規範
class AppSizes {
  // ===== 圓角半徑 =====
  static const double radiusSmall = 12.0;       // 小元件（tag, chip）
  static const double radiusMedium = 16.0;      // 中等元件（button）
  static const double radiusLarge = 20.0;       // 大型元件（input field）
  static const double radiusXLarge = 24.0;      // 卡片
  static const double radiusXXLarge = 32.0;     // 特大卡片/modal
  
  // ===== 間距 =====
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 20.0;
  static const double paddingXLarge = 24.0;
  static const double paddingXXLarge = 32.0;
  
  // ===== 卡片內邊距 =====
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20.0);
  
  // ===== 元件間距 =====
  static const double gapSmall = 8.0;
  static const double gapMedium = 12.0;
  static const double gapLarge = 16.0;
  static const double gapXLarge = 20.0;
  static const double gapXXLarge = 24.0;
  
  // ===== Icon 尺寸 =====
  static const double iconSmall = 16.0;
  static const double iconMedium = 20.0;
  static const double iconLarge = 24.0;
  static const double iconXLarge = 32.0;
  static const double iconXXLarge = 48.0;
}

/// 🌟 App 陰影規範
class AppShadows {
  /// 小陰影 - 用於懸浮的小元件（chip, tag）
  static List<BoxShadow> get small => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// 中等陰影 - 用於卡片
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// 大陰影 - 用於重要卡片或彈窗
  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// 超大陰影 - 用於 modal 或底部彈窗
  static List<BoxShadow> get xLarge => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  /// 彩色陰影 - 用於主色按鈕或特殊卡片
  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

/// 📝 App 文字樣式
class AppTextStyles {
  static const String fontFamily = 'Inter'; // 或 'Poppins', 'Nunito'
  
  // ===== 標題樣式 =====
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  
  // ===== 內文樣式 =====
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );
  
  // ===== 輔助樣式 =====
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.4,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  
  // ===== 按鈕文字 =====
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    height: 1.2,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    height: 1.2,
  );
}

/// 🎯 完整的 ThemeData 配置
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // 顏色方案
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
      ),
      
      // Scaffold 背景
      scaffoldBackgroundColor: AppColors.background,
      
      // AppBar 樣式
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.h3,
      ),
      
      // 卡片樣式
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
      ),
      
      // 輸入框樣式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingLarge,
          vertical: AppSizes.paddingMedium,
        ),
      ),
      
      // 按鈕樣式
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingXLarge,
            vertical: AppSizes.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      
      // 文字按鈕樣式
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingMedium,
            vertical: AppSizes.paddingSmall,
          ),
          textStyle: AppTextStyles.label,
        ),
      ),
      
      // 修正：Chip 樣式
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.1),
        labelStyle: AppTextStyles.label,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: AppSizes.paddingSmall,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
      ),
      
      // 文字主題
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.label,
        labelSmall: AppTextStyles.caption,
      ),
    );
  }
}