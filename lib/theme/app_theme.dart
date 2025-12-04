// lib/theme/app_theme.dart
// 🎨 App 設計系統 - 明亮版莫蘭迪風格
// ✨ 保留優雅感,提升活力和清晰度

import 'package:flutter/material.dart';

/// 🎨 App 配色方案 - 明亮版莫蘭迪色系
class AppColors {
  // ===== 主色調（明亮莫蘭迪藍） =====
  static const Color primary = Color(0xFF7FB3D5);        // 明亮霧藍 (提亮15%)
  static const Color primaryLight = Color(0xFFB3D4E8);   // 淺天藍
  static const Color primaryDark = Color(0xFF6A9FB5);    // 深藍灰
  
  static const Color secondary = Color(0xFFA8D5BA);      // 明亮薄荷綠 (提亮15%)
  static const Color secondaryLight = Color(0xFFC8E6D4);
  static const Color secondaryDark = Color(0xFF88B9A1);
  
  // ===== 輔助色（明亮柔色系） =====
  static const Color accent1 = Color(0xFFFFB74D);        // 活力橘 (更溫暖)
  static const Color accent2 = Color(0xFF81C784);        // 活力綠
  static const Color accent3 = Color(0xFFBA68C8);        // 柔和紫
  static const Color accent4 = Color(0xFFE57373);        // 溫柔粉
  
  // ===== 背景色（明亮淡雅） =====
  static const Color background = Color(0xFFF8FAFB);     // 極淡藍底
  static const Color backgroundAlt = Color(0xFFFFFFFF);  // 純白
  
  // ===== 卡片與表面 =====
  static const Color surface = Color(0xFFFFFFFF);        // 純白卡片
  static const Color surfaceLight = Color(0xFFF8FAFB);   // 極淡藍卡片
  
  // ===== 文字顏色 =====
  static const Color textPrimary = Color(0xFF2C3E50);    // 深藍灰 (提高對比)
  static const Color textSecondary = Color(0xFF5A6C7D);  // 中藍灰
  static const Color textTertiary = Color(0xFF95A5A6);   // 淺灰
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // 純白
  
  // ===== 分隔線 =====
  static const Color divider = Color(0xFFE2E8F0);        // 柔和分隔線
  
  // ===== 狀態色（明亮版本） =====
  static const Color success = Color(0xFF81C784);        // 清新綠
  static const Color warning = Color(0xFFFFB74D);        // 溫暖橘
  static const Color error = Color(0xFFE57373);          // 柔和紅
  static const Color info = Color(0xFF64B5F6);           // 清澈藍
  
  // ===== 語義化顏色 =====
  static const Color coach = Color(0xFF81C784);          // 教練色（清新綠）
  static const Color trainee = Color(0xFF64B5F6);        // 學員色（清澈藍）
  
  // ===== 漸層定義（明亮莫蘭迪漸層） =====
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7FB3D5), Color(0xFF6A9FB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFA8D5BA), Color(0xFF88B9A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient warmGradient = LinearGradient(
    colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient energyGradient = LinearGradient(
    colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFE8F4F8), Color(0xFFF8FAFB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ===== 🔥 新增：動態漸層（根據狀態） =====
  static const Gradient successGradient = LinearGradient(
    colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB74D), Color(0xFFFFA726)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient neutralGradient = LinearGradient(
    colors: [Color(0xFFB0BEC5), Color(0xFF90A4AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ===== 🔥 新增：動態配色函數 =====
  /// 根據達成率返回對應顏色
  static Color getProgressColor(double percentage) {
    if (percentage >= 0.8) {
      return success; // 達標：亮綠色
    } else if (percentage >= 0.5) {
      return warning; // 進行中：亮橘色
    } else {
      return const Color(0xFF90A4AE); // 未開始：莫蘭迪灰
    }
  }
  
  /// 根據達成率返回對應漸層
  static Gradient getProgressGradient(double percentage) {
    if (percentage >= 0.8) {
      return successGradient;
    } else if (percentage >= 0.5) {
      return warningGradient;
    } else {
      return neutralGradient;
    }
  }
}

/// 📏 App 尺寸規範
class AppSizes {
  // ===== 圓角半徑 =====
  static const double radiusSmall = 12.0;       // 小元件（tag, chip）
  static const double radiusMedium = 16.0;      // 中等元件（button）
  static const double radiusLarge = 20.0;       // 大型元件（input field）
  static const double radiusXLarge = 24.0;      // 卡片
  static const double radiusXXLarge = 28.0;     // 特大卡片（統一為28）
  
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

/// 🌟 App 陰影規範（明亮版 - 更明顯的層次）
class AppShadows {
  /// 小陰影 - 淡雅
  static List<BoxShadow> get small => [
    BoxShadow(
      color: const Color(0xFF2C3E50).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// 中等陰影 - 柔和
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: const Color(0xFF2C3E50).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// 大陰影 - 明顯
  static List<BoxShadow> get large => [
    BoxShadow(
      color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// 超大陰影
  static List<BoxShadow> get xLarge => [
    BoxShadow(
      color: const Color(0xFF2C3E50).withValues(alpha: 0.10),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  /// 彩色陰影 - 明亮版（更有活力）
  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// 🔥 新增：文字陰影（用於百分比數字等）
  static List<Shadow> get textShadow => [
    Shadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// 🔥 新增：強調陰影（用於重要卡片）
  static List<BoxShadow> get emphasized => [
    BoxShadow(
      color: const Color(0xFF7FB3D5).withValues(alpha: 0.15),
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
    letterSpacing: -0.5,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: -0.2,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: -0.1,
  );
  
  // ===== 內文樣式 =====
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.6,
    letterSpacing: 0.1,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.6,
    letterSpacing: 0.1,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
    letterSpacing: 0.2,
  );
  
  // ===== 輔助樣式 =====
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.4,
    letterSpacing: 0.3,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.2,
  );
  
  // ===== 按鈕文字 =====
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    height: 1.2,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    height: 1.2,
    letterSpacing: 0.3,
  );
  
  // ===== 🔥 新增：高亮文字樣式 =====
  static const TextStyle highlight = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: AppColors.textOnPrimary,
    height: 1.0,
    letterSpacing: -1.0,
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
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
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
          borderRadius: BorderRadius.circular(AppSizes.radiusXXLarge),
        ),
        shadowColor: const Color(0xFF2C3E50).withValues(alpha: 0.06),
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
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
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
      
      // Chip 樣式
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
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
      
      // Divider 樣式
      dividerTheme: DividerThemeData(
        color: AppColors.divider,  // ✅ 使用新增的 divider 顏色
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 🎨 動畫配置
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
}