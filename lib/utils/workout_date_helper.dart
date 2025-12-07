// lib/utils/workout_date_helper.dart
// 🔧 統一日期處理工具 v1.0
// 整合所有訓練相關的日期格式轉換和計算
// ✅ 支援：英文(monday)、中文完整(星期一)、中文簡短(週一)

import 'package:flutter/foundation.dart';

/// 訓練日期處理工具類
/// 提供統一的星期格式轉換、日期計算功能
class WorkoutDateHelper {
  // ============================================================
  // 🔥 星期格式對照表
  // ============================================================

  /// 星期幾對照表（weekday 1-7 對應多種格式）
  static const Map<int, List<String>> weekdayFormats = {
    1: ['星期一', '週一', 'monday', 'mon', '一'],
    2: ['星期二', '週二', 'tuesday', 'tue', '二'],
    3: ['星期三', '週三', 'wednesday', 'wed', '三'],
    4: ['星期四', '週四', 'thursday', 'thu', '四'],
    5: ['星期五', '週五', 'friday', 'fri', '五'],
    6: ['星期六', '週六', 'saturday', 'sat', '六'],
    7: ['星期日', '週日', 'sunday', 'sun', '日'],
  };

  /// 英文到中文完整格式映射
  static const Map<String, String> englishToFullChinese = {
    'monday': '星期一',
    'tuesday': '星期二',
    'wednesday': '星期三',
    'thursday': '星期四',
    'friday': '星期五',
    'saturday': '星期六',
    'sunday': '星期日',
    'mon': '星期一',
    'tue': '星期二',
    'wed': '星期三',
    'thu': '星期四',
    'fri': '星期五',
    'sat': '星期六',
    'sun': '星期日',
  };

  /// 中文簡短到完整格式映射
  static const Map<String, String> shortToFullChinese = {
    '週一': '星期一',
    '週二': '星期二',
    '週三': '星期三',
    '週四': '星期四',
    '週五': '星期五',
    '週六': '星期六',
    '週日': '星期日',
    '一': '星期一',
    '二': '星期二',
    '三': '星期三',
    '四': '星期四',
    '五': '星期五',
    '六': '星期六',
    '日': '星期日',
  };

  /// 完整中文到英文映射
  static const Map<String, String> fullChineseToEnglish = {
    '星期一': 'monday',
    '星期二': 'tuesday',
    '星期三': 'wednesday',
    '星期四': 'thursday',
    '星期五': 'friday',
    '星期六': 'saturday',
    '星期日': 'sunday',
  };

  // ============================================================
  // 🔥 格式轉換方法
  // ============================================================

  /// 將任意格式的星期字串轉換為 weekday 數字 (1-7)
  /// 返回 null 表示無法識別
  static int? parseWeekday(String dayStr) {
    final normalized = dayStr.toLowerCase().trim();

    for (final entry in weekdayFormats.entries) {
      for (final format in entry.value) {
        if (normalized == format.toLowerCase() ||
            normalized.contains(format.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 從 weekday 數字獲取標準格式的星期字串（完整格式：星期一）
  static String getFullChinese(int weekday) {
    return weekdayFormats[weekday.clamp(1, 7)]?[0] ?? '未知';
  }

  /// 從 weekday 數字獲取短格式的星期字串（週一）
  static String getShortChinese(int weekday) {
    return weekdayFormats[weekday.clamp(1, 7)]?[1] ?? '未知';
  }

  /// 從 weekday 數字獲取英文格式（monday）
  static String getEnglish(int weekday) {
    return weekdayFormats[weekday.clamp(1, 7)]?[2] ?? 'unknown';
  }

  /// 🔥 正規化任何格式的星期為統一格式（中文完整：星期一）
  static String normalizeToChinese(String day) {
    final lower = day.toLowerCase().trim();

    // 1. 英文格式 -> 中文完整
    if (englishToFullChinese.containsKey(lower)) {
      return englishToFullChinese[lower]!;
    }

    // 2. 中文短格式 -> 中文完整
    if (shortToFullChinese.containsKey(day)) {
      return shortToFullChinese[day]!;
    }

    // 3. 已經是中文完整格式
    if (fullChineseToEnglish.containsKey(day)) {
      return day;
    }

    // 4. 嘗試解析後轉換
    final weekday = parseWeekday(day);
    if (weekday != null) {
      return getFullChinese(weekday);
    }

    // 5. 無法識別，返回原值
    return day;
  }

  /// 🔥 正規化任何格式的星期為英文格式（monday）
  static String normalizeToEnglish(String day) {
    final lower = day.toLowerCase().trim();

    // 1. 已經是英文格式
    if (englishToFullChinese.containsKey(lower)) {
      // 統一為完整英文（monday 而非 mon）
      final weekday = parseWeekday(lower);
      return weekday != null ? getEnglish(weekday) : lower;
    }

    // 2. 中文格式 -> 英文
    final normalized = normalizeToChinese(day);
    if (fullChineseToEnglish.containsKey(normalized)) {
      return fullChineseToEnglish[normalized]!;
    }

    // 3. 無法識別，返回原值小寫
    return lower;
  }

  /// 🔥 判斷兩個星期字串是否相同（格式無關）
  static bool isSameWeekday(String day1, String day2) {
    if (day1 == day2) return true;

    final weekday1 = parseWeekday(day1);
    final weekday2 = parseWeekday(day2);

    if (weekday1 == null || weekday2 == null) {
      if (kDebugMode) {
        debugPrint('⚠️ isSameWeekday: 無法解析 "$day1" 或 "$day2"');
      }
      return false;
    }

    final result = weekday1 == weekday2;

    if (kDebugMode) {
      debugPrint('🔍 isSameWeekday: "$day1"($weekday1) vs "$day2"($weekday2) = $result');
    }

    return result;
  }

  // ============================================================
  // 🔥 日期計算方法
  // ============================================================

  /// 獲取本週的開始日期（週一 00:00:00）
  static DateTime getWeekStart([DateTime? date]) {
    final d = date ?? DateTime.now();
    final weekday = d.weekday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
  }

  /// 獲取本週的結束日期（週日 23:59:59）
  static DateTime getWeekEnd([DateTime? date]) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  /// 獲取指定 weekday 在本週的具體日期
  static DateTime getDateForWeekday(int weekday, [DateTime? referenceDate]) {
    final weekStart = getWeekStart(referenceDate);
    return weekStart.add(Duration(days: weekday - 1));
  }

  /// 獲取指定星期字串在本週的具體日期
  static DateTime? getDateForWeekdayString(String dayOfWeek, [DateTime? referenceDate]) {
    final weekday = parseWeekday(dayOfWeek);
    if (weekday == null) return null;
    return getDateForWeekday(weekday, referenceDate);
  }

  /// 獲取 ISO 週數
  static int getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - 1;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    final difference = date.difference(firstMonday).inDays;
    return (difference / 7).ceil();
  }

  /// 獲取今天的 weekday (1-7)
  static int getTodayWeekday() {
    return DateTime.now().weekday;
  }

  /// 獲取今天的中文完整星期（星期一）
  static String getTodayFullChinese() {
    return getFullChinese(getTodayWeekday());
  }

  /// 獲取今天的英文星期（monday）
  static String getTodayEnglish() {
    return getEnglish(getTodayWeekday());
  }

  // ============================================================
  // 🔥 日期比較方法
  // ============================================================

  /// 判斷日期是否為今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 判斷日期是否已過（不含今天）
  static bool isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(today);
  }

  /// 判斷日期是否為未來（不含今天）
  static bool isFuture(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAfter(today);
  }

  /// 判斷日期是否在本週內
  static bool isThisWeek(DateTime date) {
    final weekStart = getWeekStart();
    final weekEnd = getWeekEnd();
    return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
  }

  /// 獲取兩個日期之間的天數差
  static int daysBetween(DateTime from, DateTime to) {
    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    return toDate.difference(fromDate).inDays;
  }

  // ============================================================
  // 🔥 格式化方法
  // ============================================================

  /// 格式化日期為 yyyy-MM-dd
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 格式化日期為中文格式（x月x日）
  static String formatDateChinese(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  /// 格式化日期為完整中文格式（x月x日 星期x）
  static String formatDateWithWeekday(DateTime date) {
    return '${date.month}月${date.day}日 ${getFullChinese(date.weekday)}';
  }
}