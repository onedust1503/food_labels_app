// lib/models/completion_status.dart
// 🔥 訓練完成狀態定義 v1.0
// 用於統一管理計畫訓練的完成狀態顯示

import 'package:flutter/material.dart';

/// 訓練完成狀態類型
enum CompletionStatusType {
  /// ✅ 準時完成 - 在計畫日當天完成
  onTime,
  
  /// 🟡 補做完成 - 過了計畫日才完成（遲到）
  makeup,
  
  /// 🔵 提前完成 - 在計畫日之前完成
  early,
  
  /// ⏳ 待完成 - 還沒到計畫日，尚未完成
  pending,
  
  /// ❌ 逾期未完成 - 過了計畫日，尚未完成
  overdue,
  
  /// 🏃 今日待做 - 今天是計畫日，尚未完成
  dueToday,
}

/// 完成狀態的詳細資訊
class CompletionStatus {
  final CompletionStatusType type;
  final String label;
  final String shortLabel;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final String description;
  
  const CompletionStatus({
    required this.type,
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.description,
  });
  
  /// 根據類型獲取對應的狀態資訊
  factory CompletionStatus.fromType(CompletionStatusType type) {
    switch (type) {
      case CompletionStatusType.onTime:
        return CompletionStatus(
          type: type,
          label: '準時完成',
          shortLabel: '準時',
          color: const Color(0xFF10B981),      // 綠色
          backgroundColor: const Color(0xFFD1FAE5),
          icon: Icons.check_circle,
          description: '太棒了！在計畫日當天完成訓練',
        );
        
      case CompletionStatusType.makeup:
        return CompletionStatus(
          type: type,
          label: '補做完成',
          shortLabel: '補做',
          color: const Color(0xFFF59E0B),      // 橘黃色
          backgroundColor: const Color(0xFFFEF3C7),
          icon: Icons.replay_circle_filled,
          description: '已完成訓練，但晚於計畫日',
        );
        
      case CompletionStatusType.early:
        return CompletionStatus(
          type: type,
          label: '提前完成',
          shortLabel: '提前',
          color: const Color(0xFF3B82F6),      // 藍色
          backgroundColor: const Color(0xFFDBEAFE),
          icon: Icons.fast_forward,
          description: '很積極！提前完成了訓練',
        );
        
      case CompletionStatusType.pending:
        return CompletionStatus(
          type: type,
          label: '尚未開始',
          shortLabel: '未開始',
          color: const Color(0xFF9CA3AF),      // 灰色
          backgroundColor: const Color(0xFFF3F4F6),
          icon: Icons.schedule,
          description: '計畫日還沒到，請按時完成',
        );
        
      case CompletionStatusType.overdue:
        return CompletionStatus(
          type: type,
          label: '逾期未完成',
          shortLabel: '逾期',
          color: const Color(0xFFEF4444),      // 紅色
          backgroundColor: const Color(0xFFFEE2E2),
          icon: Icons.warning_amber_rounded,
          description: '已過計畫日，建議儘快補做',
        );
        
      case CompletionStatusType.dueToday:
        return CompletionStatus(
          type: type,
          label: '今日待做',
          shortLabel: '今日',
          color: const Color(0xFF8B5CF6),      // 紫色
          backgroundColor: const Color(0xFFEDE9FE),
          icon: Icons.today,
          description: '今天是訓練日，加油完成吧！',
        );
    }
  }
}

/// 訓練完成記錄的詳細資訊
class WorkoutCompletionRecord {
  final String id;
  final String planId;
  final String planName;
  final String planDayOfWeek;      // 計畫的星期幾（例：星期一）
  final DateTime? plannedDate;     // 計畫的具體日期（本週）
  final DateTime? actualDate;      // 實際完成日期
  final String? actualDayOfWeek;   // 實際完成的星期幾
  final CompletionStatusType statusType;
  final int duration;              // 訓練時長（分鐘）
  final double calories;           // 消耗卡路里
  final int exerciseCount;         // 動作數量
  final int setCount;              // 完成組數
  final String? sessionId;
  
  WorkoutCompletionRecord({
    required this.id,
    required this.planId,
    required this.planName,
    required this.planDayOfWeek,
    this.plannedDate,
    this.actualDate,
    this.actualDayOfWeek,
    required this.statusType,
    this.duration = 0,
    this.calories = 0,
    this.exerciseCount = 0,
    this.setCount = 0,
    this.sessionId,
  });
  
  CompletionStatus get status => CompletionStatus.fromType(statusType);
  
  /// 從 Firebase 資料轉換
  factory WorkoutCompletionRecord.fromFirestore(Map<String, dynamic> data, String docId) {
    // 判斷狀態類型
    CompletionStatusType type;
    
    final isCompleted = data['actualDate'] != null;
    final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
    
    if (isCompleted) {
      if (isOnSchedule) {
        type = CompletionStatusType.onTime;
      } else {
        // 需要進一步判斷是提前還是補做
        // 這裡暫時用 isOnSchedule 來判斷，實際應該比較日期
        type = CompletionStatusType.makeup;
      }
    } else {
      type = CompletionStatusType.pending;
    }
    
    return WorkoutCompletionRecord(
      id: docId,
      planId: data['planId'] ?? '',
      planName: data['planName'] ?? '',
      planDayOfWeek: data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '',
      actualDate: data['actualDate'] != null 
          ? (data['actualDate'] as dynamic).toDate() 
          : null,
      actualDayOfWeek: data['actualDayOfWeek'],
      statusType: type,
      duration: data['totalDuration'] ?? data['duration'] ?? 0,
      calories: (data['caloriesBurned'] ?? 0).toDouble(),
      exerciseCount: data['exercisesCompleted'] ?? data['totalExercises'] ?? 0,
      setCount: data['setsCompleted'] ?? data['totalSets'] ?? 0,
      sessionId: data['sessionId'],
    );
  }
}

/// 週計畫進度總覽
class WeeklyPlanProgress {
  final String planId;
  final String planName;
  final int totalDays;             // 計畫總訓練天數
  final int completedOnTime;       // 準時完成數
  final int completedMakeup;       // 補做完成數
  final int completedEarly;        // 提前完成數
  final int overdue;               // 逾期未完成數
  final int pending;               // 待完成數
  final int dueToday;              // 今日待做數
  final List<DayProgress> dayProgress;  // 每日進度
  
  WeeklyPlanProgress({
    required this.planId,
    required this.planName,
    required this.totalDays,
    this.completedOnTime = 0,
    this.completedMakeup = 0,
    this.completedEarly = 0,
    this.overdue = 0,
    this.pending = 0,
    this.dueToday = 0,
    this.dayProgress = const [],
  });
  
  /// 總完成數
  int get totalCompleted => completedOnTime + completedMakeup + completedEarly;
  
  /// 完成率
  double get completionRate => totalDays > 0 ? totalCompleted / totalDays : 0;
  
  /// 準時率（準時 + 提前 / 總完成）
  double get onTimeRate => totalCompleted > 0 
      ? (completedOnTime + completedEarly) / totalCompleted 
      : 0;
  
  /// 本週狀態摘要文字
  String get summaryText {
    if (totalCompleted == 0) {
      if (dueToday > 0) return '今日有 $dueToday 項訓練待完成';
      if (overdue > 0) return '有 $overdue 項訓練已逾期';
      return '本週尚未開始訓練';
    }
    
    final onTimePercent = (onTimeRate * 100).round();
    return '完成 $totalCompleted/$totalDays 項（$onTimePercent% 準時）';
  }
}

/// 單日進度
class DayProgress {
  final String dayOfWeek;          // 星期幾
  final DateTime date;             // 具體日期
  final bool hasPlannedWorkout;    // 是否有計畫訓練
  final CompletionStatusType? status;
  final WorkoutCompletionRecord? completionRecord;
  
  DayProgress({
    required this.dayOfWeek,
    required this.date,
    required this.hasPlannedWorkout,
    this.status,
    this.completionRecord,
  });
  
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }
  
  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isAfter(today);
  }
}