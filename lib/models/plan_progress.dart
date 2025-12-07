// lib/models/plan_progress.dart
// 🔥 計畫進度模型 v1.0
// ✅ 包含：整體進度、週進度、統計資訊

import 'package:flutter/material.dart';
import '../utils/workout_date_helper.dart';
import 'workout_model.dart';
import 'completion_status.dart';

/// 📊 計畫整體進度
class PlanProgress {
  final String planId;
  final int totalTrainingDays;      // 總訓練天數（-1 表示持續進行）
  final int completedDays;          // 已完成天數
  final int onTimeDays;             // 準時完成天數
  final int earlyDays;              // 提前完成天數
  final int makeupDays;             // 補做完成天數
  final int totalDuration;          // 總訓練時長（分鐘）
  final double totalCalories;       // 總消耗卡路里
  final WeeklyProgress currentWeek; // 本週進度
  final DateTime? planStartDate;
  final DateTime? planEndDate;

  PlanProgress({
    required this.planId,
    required this.totalTrainingDays,
    required this.completedDays,
    this.onTimeDays = 0,
    this.earlyDays = 0,
    this.makeupDays = 0,
    this.totalDuration = 0,
    this.totalCalories = 0,
    required this.currentWeek,
    this.planStartDate,
    this.planEndDate,
  });

  /// 整體完成率（0.0 - 1.0）
  double get completionRate {
    if (totalTrainingDays <= 0) return 0.0;
    return (completedDays / totalTrainingDays).clamp(0.0, 1.0);
  }

  /// 整體完成百分比（0 - 100）
  int get completionPercent => (completionRate * 100).round();

  /// 準時率（準時+提前 / 總完成）
  double get onTimeRate {
    if (completedDays == 0) return 0.0;
    return ((onTimeDays + earlyDays) / completedDays).clamp(0.0, 1.0);
  }

  /// 準時率百分比
  int get onTimePercent => (onTimeRate * 100).round();

  /// 是否為持續進行的計畫（無結束日期）
  bool get isOngoing => totalTrainingDays < 0;

  /// 剩餘天數
  int get remainingDays {
    if (isOngoing) return -1;
    return (totalTrainingDays - completedDays).clamp(0, totalTrainingDays);
  }

  /// 進度顯示文字
  String get progressText {
    if (isOngoing) {
      return '已完成 $completedDays 次';
    }
    return '$completedDays / $totalTrainingDays 次';
  }

  /// 平均每次訓練時長
  int get avgDuration {
    if (completedDays == 0) return 0;
    return (totalDuration / completedDays).round();
  }

  /// 空的進度
  factory PlanProgress.empty(String planId) {
    return PlanProgress(
      planId: planId,
      totalTrainingDays: 0,
      completedDays: 0,
      currentWeek: WeeklyProgress.empty(),
    );
  }
}

/// 📆 週進度
class WeeklyProgress {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int shouldComplete;         // 本週應完成次數
  final int completed;              // 本週已完成次數
  final int onTimeCount;            // 準時完成
  final int earlyCount;             // 提前完成
  final int makeupCount;            // 補做完成
  final int overdueCount;           // 逾期未完成
  final int pendingCount;           // 待完成（未來）
  final int dueTodayCount;          // 今日待做
  final List<PlanDayProgress> days;     // 每天的進度

  WeeklyProgress({
    required this.weekStart,
    required this.weekEnd,
    required this.shouldComplete,
    required this.completed,
    this.onTimeCount = 0,
    this.earlyCount = 0,
    this.makeupCount = 0,
    this.overdueCount = 0,
    this.pendingCount = 0,
    this.dueTodayCount = 0,
    this.days = const [],
  });

  /// 週完成率
  double get completionRate {
    if (shouldComplete == 0) return 0.0;
    return (completed / shouldComplete).clamp(0.0, 1.0);
  }

  /// 週完成百分比
  int get completionPercent => (completionRate * 100).round();

  /// 顯示文字
  String get displayText => '$completed / $shouldComplete 完成';

  /// 是否全部完成
  bool get isFullyCompleted => completed >= shouldComplete;

  /// 空的週進度
  factory WeeklyProgress.empty() {
    final now = DateTime.now();
    return WeeklyProgress(
      weekStart: WorkoutDateHelper.getWeekStart(now),
      weekEnd: WorkoutDateHelper.getWeekEnd(now),
      shouldComplete: 0,
      completed: 0,
    );
  }
}

/// 📅 單日進度（重命名避免與 completion_status.dart 衝突）
class PlanDayProgress {
  final String dayKey;              // 英文 key (monday)
  final String dayName;             // 中文名稱 (星期一)
  final String shortName;           // 簡短名稱 (週一)
  final DateTime date;              // 實際日期
  final bool isTrainingDay;         // 是否為訓練日
  final bool isToday;               // 是否為今天
  final bool isAfterPlanStart;      // 是否在計畫開始後
  final CompletionStatusType status; // 完成狀態
  final DateTime? completedAt;      // 完成時間
  final int duration;               // 訓練時長
  final double calories;            // 消耗卡路里

  PlanDayProgress({
    required this.dayKey,
    required this.dayName,
    required this.shortName,
    required this.date,
    required this.isTrainingDay,
    required this.isToday,
    required this.isAfterPlanStart,
    required this.status,
    this.completedAt,
    this.duration = 0,
    this.calories = 0,
  });

  /// 是否已完成
  bool get isCompleted => 
      status == CompletionStatusType.onTime ||
      status == CompletionStatusType.early ||
      status == CompletionStatusType.makeup;

  /// 獲取狀態資訊
  CompletionStatus get statusInfo => CompletionStatus.fromType(status);

  /// 從 weekday 數字創建
  factory PlanDayProgress.fromWeekday({
    required int weekday,
    required DateTime date,
    required bool isTrainingDay,
    required bool isAfterPlanStart,
    required CompletionStatusType status,
    DateTime? completedAt,
    int duration = 0,
    double calories = 0,
  }) {
    final dayKey = WorkoutDateHelper.getEnglish(weekday);
    final dayName = WorkoutDateHelper.getFullChinese(weekday);
    final shortName = WorkoutDateHelper.getShortChinese(weekday);
    final today = DateTime.now();
    final isToday = date.year == today.year && 
                    date.month == today.month && 
                    date.day == today.day;

    return PlanDayProgress(
      dayKey: dayKey,
      dayName: dayName,
      shortName: shortName,
      date: date,
      isTrainingDay: isTrainingDay,
      isToday: isToday,
      isAfterPlanStart: isAfterPlanStart,
      status: status,
      completedAt: completedAt,
      duration: duration,
      calories: calories,
    );
  }
}

/// 🔧 計畫進度計算工具
class PlanProgressCalculator {
  
  /// 🔥 精確計算計畫期間內的訓練日數量
  static int calculateTotalTrainingDays(WorkoutPlanModel plan) {
    if (plan.endDate == null) return -1; // 持續進行
    
    // 取得計畫的訓練日（weekday 1-7）
    final trainingWeekdays = plan.days
        .map((d) => WorkoutDateHelper.parseWeekday(d.dayOfWeek))
        .whereType<int>()
        .toSet();
    
    if (trainingWeekdays.isEmpty) return 0;
    
    int count = 0;
    DateTime current = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    final endDate = DateTime(
      plan.endDate!.year,
      plan.endDate!.month,
      plan.endDate!.day,
    );
    
    while (!current.isAfter(endDate)) {
      if (trainingWeekdays.contains(current.weekday)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return count;
  }

  /// 🔥 計算本週應完成的訓練日數量（考慮計畫開始日期）
  static int calculateWeeklyTargetDays(
    WorkoutPlanModel plan, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final weekStart = WorkoutDateHelper.getWeekStart(ref);
    final weekEnd = WorkoutDateHelper.getWeekEnd(ref);
    
    final planStartDate = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    
    // 計畫結束日期（如果有）
    final planEndDate = plan.endDate != null
        ? DateTime(plan.endDate!.year, plan.endDate!.month, plan.endDate!.day)
        : null;
    
    // 取得計畫的訓練日
    final trainingWeekdays = plan.days
        .map((d) => WorkoutDateHelper.parseWeekday(d.dayOfWeek))
        .whereType<int>()
        .toSet();
    
    if (trainingWeekdays.isEmpty) return 0;
    
    int count = 0;
    DateTime current = weekStart;
    
    while (!current.isAfter(weekEnd)) {
      // 檢查是否在計畫期間內
      final isAfterPlanStart = !current.isBefore(planStartDate);
      final isBeforePlanEnd = planEndDate == null || !current.isAfter(planEndDate);
      
      if (isAfterPlanStart && isBeforePlanEnd && 
          trainingWeekdays.contains(current.weekday)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return count;
  }

  /// 🔥 生成本週每天的進度列表
  static List<PlanDayProgress> generateWeekDays({
    required WorkoutPlanModel plan,
    required Map<String, Map<String, dynamic>> completions,
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final weekStart = WorkoutDateHelper.getWeekStart(ref);
    final today = DateTime(ref.year, ref.month, ref.day);
    
    final planStartDate = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    
    // 取得計畫的訓練日
    final trainingWeekdays = plan.days
        .map((d) => WorkoutDateHelper.parseWeekday(d.dayOfWeek))
        .whereType<int>()
        .toSet();
    
    final List<PlanDayProgress> days = [];
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final weekday = date.weekday;
      final isTrainingDay = trainingWeekdays.contains(weekday);
      final isAfterPlanStart = !date.isBefore(planStartDate);
      final isToday = date.isAtSameMomentAs(today);
      final isPast = date.isBefore(today);
      
      // 查找完成記錄
      final dayKey = WorkoutDateHelper.getEnglish(weekday);
      Map<String, dynamic>? completionData;
      
      for (final entry in completions.entries) {
        final completedDay = entry.value['planDayOfWeek'] ?? entry.key;
        if (WorkoutDateHelper.isSameWeekday(completedDay, dayKey) &&
            entry.value['completed'] == true) {
          completionData = entry.value;
          break;
        }
      }
      
      // 判定狀態
      CompletionStatusType status;
      if (completionData != null) {
        // 已完成 - 使用記錄中的狀態或計算
        status = completionData['statusType'] as CompletionStatusType? ??
            (completionData['isOnSchedule'] == true
                ? CompletionStatusType.onTime
                : CompletionStatusType.makeup);
      } else if (!isTrainingDay) {
        status = CompletionStatusType.pending;
      } else if (!isAfterPlanStart) {
        status = CompletionStatusType.pending; // 計畫未開始
      } else if (isToday) {
        status = CompletionStatusType.dueToday;
      } else if (isPast) {
        status = CompletionStatusType.overdue;
      } else {
        status = CompletionStatusType.pending;
      }
      
      days.add(PlanDayProgress.fromWeekday(
        weekday: weekday,
        date: date,
        isTrainingDay: isTrainingDay,
        isAfterPlanStart: isAfterPlanStart,
        status: status,
        completedAt: completionData?['actualDate'] as DateTime?,
        duration: completionData?['duration'] as int? ?? 0,
        calories: (completionData?['calories'] as num?)?.toDouble() ?? 0,
      ));
    }
    
    return days;
  }
}

/// 🎨 進度顯示 Widget 輔助
class ProgressDisplayHelper {
  
  /// 獲取進度條顏色
  static Color getProgressColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981); // 綠色
    if (rate >= 0.5) return const Color(0xFFF59E0B); // 橘色
    return const Color(0xFFEF4444); // 紅色
  }

  /// 獲取進度描述
  static String getProgressDescription(double rate) {
    if (rate >= 1.0) return '完美達成！';
    if (rate >= 0.8) return '表現優秀';
    if (rate >= 0.5) return '繼續加油';
    if (rate > 0) return '需要努力';
    return '尚未開始';
  }

  /// 獲取週進度圖示
  static List<Widget> buildWeekDots(WeeklyProgress weekly) {
    return weekly.days.map((day) {
      if (!day.isTrainingDay) {
        return const SizedBox(width: 8);
      }
      
      final status = day.statusInfo;
      return Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: day.isCompleted ? status.color : status.backgroundColor,
          shape: BoxShape.circle,
          border: !day.isCompleted
              ? Border.all(color: status.color, width: 2)
              : null,
        ),
        child: day.isCompleted
            ? Icon(Icons.check, size: 8, color: Colors.white)
            : null,
      );
    }).toList();
  }
}