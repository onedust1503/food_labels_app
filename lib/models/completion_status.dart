// lib/models/completion_status.dart
// 🔥 訓練完成狀態定義 v3.0
// ✅ v3.0 重構：重命名 DayProgress → DayCompletionInfo
// ✅ v3.0 重構：重命名 WeeklyPlanProgress → WeeklyCompletionSummary
// ✅ 避免與 plan_progress.dart 中的類名衝突
// ✅ WorkoutCompletionRecord 為唯一定義位置
// ✅ 使用 WorkoutDateHelper 進行日期計算

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/workout_date_helper.dart';

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
        return const CompletionStatus(
          type: CompletionStatusType.onTime,
          label: '準時完成',
          shortLabel: '準時',
          color: Color(0xFF10B981), // 綠色
          backgroundColor: Color(0xFFD1FAE5),
          icon: Icons.check_circle,
          description: '太棒了！在計畫日當天完成訓練',
        );

      case CompletionStatusType.makeup:
        return const CompletionStatus(
          type: CompletionStatusType.makeup,
          label: '補做完成',
          shortLabel: '補做',
          color: Color(0xFFF59E0B), // 橘黃色
          backgroundColor: Color(0xFFFEF3C7),
          icon: Icons.replay_circle_filled,
          description: '已完成訓練，但晚於計畫日',
        );

      case CompletionStatusType.early:
        return const CompletionStatus(
          type: CompletionStatusType.early,
          label: '提前完成',
          shortLabel: '提前',
          color: Color(0xFF3B82F6), // 藍色
          backgroundColor: Color(0xFFDBEAFE),
          icon: Icons.fast_forward,
          description: '很積極！提前完成了訓練',
        );

      case CompletionStatusType.pending:
        return const CompletionStatus(
          type: CompletionStatusType.pending,
          label: '尚未開始',
          shortLabel: '未開始',
          color: Color(0xFF9CA3AF), // 灰色
          backgroundColor: Color(0xFFF3F4F6),
          icon: Icons.schedule,
          description: '計畫日還沒到，請按時完成',
        );

      case CompletionStatusType.overdue:
        return const CompletionStatus(
          type: CompletionStatusType.overdue,
          label: '逾期未完成',
          shortLabel: '逾期',
          color: Color(0xFFEF4444), // 紅色
          backgroundColor: Color(0xFFFEE2E2),
          icon: Icons.warning_amber,
          description: '計畫日已過，請盡快補做',
        );

      case CompletionStatusType.dueToday:
        return const CompletionStatus(
          type: CompletionStatusType.dueToday,
          label: '今日待做',
          shortLabel: '今日',
          color: Color(0xFF8B5CF6), // 紫色
          backgroundColor: Color(0xFFEDE9FE),
          icon: Icons.today,
          description: '今天是計畫日，加油完成訓練！',
        );
    }
  }

  /// 獲取狀態的優先級（用於排序）
  int get priority {
    switch (type) {
      case CompletionStatusType.dueToday:
        return 0; // 最高優先
      case CompletionStatusType.overdue:
        return 1;
      case CompletionStatusType.pending:
        return 2;
      case CompletionStatusType.onTime:
        return 3;
      case CompletionStatusType.early:
        return 4;
      case CompletionStatusType.makeup:
        return 5;
    }
  }

  /// 是否已完成
  bool get isCompleted =>
      type == CompletionStatusType.onTime ||
      type == CompletionStatusType.early ||
      type == CompletionStatusType.makeup;
}

/// 訓練完成記錄
/// 🔥 這是 WorkoutCompletionRecord 的唯一定義位置
class WorkoutCompletionRecord {
  final String id;
  final String planId;
  final String planName;
  final String planDayOfWeek; // 計畫的星期幾
  final DateTime? plannedDate; // 計畫日期
  final DateTime? actualDate; // 實際完成日期
  final String? actualDayOfWeek; // 實際完成的星期幾
  final CompletionStatusType statusType;
  final int duration; // 訓練時長（分鐘）
  final double calories; // 消耗卡路里
  final int exerciseCount; // 動作數量
  final int setCount; // 完成組數
  final String? sessionId;
  final String? notes;

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
    this.notes,
  });

  CompletionStatus get status => CompletionStatus.fromType(statusType);

  /// 🔥 從 Firebase 資料轉換（智能判斷狀態）
  factory WorkoutCompletionRecord.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
    final actualDate = data['actualDate'] != null
        ? (data['actualDate'] as Timestamp).toDate()
        : null;

    // 🔥 使用統一的日期工具計算狀態
    CompletionStatusType statusType;

    if (actualDate != null) {
      // 已完成 - 判斷是準時、提前還是補做
      final plannedDate = WorkoutDateHelper.getDateForWeekdayString(
        planDayOfWeek,
        actualDate, // 以實際完成日期所在週為參考
      );

      if (plannedDate != null) {
        final plannedDateOnly = DateTime(
          plannedDate.year,
          plannedDate.month,
          plannedDate.day,
        );
        final actualDateOnly = DateTime(
          actualDate.year,
          actualDate.month,
          actualDate.day,
        );

        if (actualDateOnly.isAtSameMomentAs(plannedDateOnly)) {
          statusType = CompletionStatusType.onTime;
        } else if (actualDateOnly.isBefore(plannedDateOnly)) {
          statusType = CompletionStatusType.early;
        } else {
          statusType = CompletionStatusType.makeup;
        }
      } else {
        // 無法解析計畫日，使用 isOnSchedule 欄位判斷
        final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
        statusType = isOnSchedule
            ? CompletionStatusType.onTime
            : CompletionStatusType.makeup;
      }
    } else {
      // 未完成 - 判斷是待完成、今日待做還是逾期
      final plannedDate = WorkoutDateHelper.getDateForWeekdayString(planDayOfWeek);

      if (plannedDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final plannedDateOnly = DateTime(
          plannedDate.year,
          plannedDate.month,
          plannedDate.day,
        );

        if (today.isAtSameMomentAs(plannedDateOnly)) {
          statusType = CompletionStatusType.dueToday;
        } else if (today.isAfter(plannedDateOnly)) {
          statusType = CompletionStatusType.overdue;
        } else {
          statusType = CompletionStatusType.pending;
        }
      } else {
        statusType = CompletionStatusType.pending;
      }
    }

    return WorkoutCompletionRecord(
      id: docId,
      planId: data['planId'] ?? '',
      planName: data['planName'] ?? '',
      planDayOfWeek: planDayOfWeek,
      plannedDate: data['plannedDate'] != null
          ? (data['plannedDate'] as Timestamp).toDate()
          : null,
      actualDate: actualDate,
      actualDayOfWeek: data['actualDayOfWeek'],
      statusType: statusType,
      duration: data['totalDuration'] ?? data['duration'] ?? 0,
      calories: (data['caloriesBurned'] ?? data['calories'] ?? 0).toDouble(),
      exerciseCount: data['exerciseCount'] ?? 0,
      setCount: data['setCount'] ?? 0,
      sessionId: data['sessionId'],
      notes: data['notes'],
    );
  }

  /// 轉換為 Firebase 資料
  Map<String, dynamic> toFirestore() {
    return {
      'planId': planId,
      'planName': planName,
      'planDayOfWeek': planDayOfWeek,
      if (plannedDate != null) 'plannedDate': Timestamp.fromDate(plannedDate!),
      if (actualDate != null) 'actualDate': Timestamp.fromDate(actualDate!),
      if (actualDayOfWeek != null) 'actualDayOfWeek': actualDayOfWeek,
      'isOnSchedule': statusType == CompletionStatusType.onTime ||
          statusType == CompletionStatusType.early,
      'totalDuration': duration,
      'caloriesBurned': calories,
      'exerciseCount': exerciseCount,
      'setCount': setCount,
      if (sessionId != null) 'sessionId': sessionId,
      if (notes != null) 'notes': notes,
    };
  }
}

// ============================================================
// 🔥 v3.0：重命名以避免與 plan_progress.dart 衝突
// ============================================================

/// 週計畫完成摘要（重命名：WeeklyPlanProgress → WeeklyCompletionSummary）
class WeeklyCompletionSummary {
  final String planId;
  final String planName;
  final int totalDays; // 計畫總訓練天數
  final int completedOnTime; // 準時完成數
  final int completedMakeup; // 補做完成數
  final int completedEarly; // 提前完成數
  final int overdue; // 逾期未完成數
  final int pending; // 待完成數
  final int dueToday; // 今日待做數
  final List<DayCompletionInfo> dayProgress; // 每日進度

  WeeklyCompletionSummary({
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
  double get onTimeRate =>
      totalCompleted > 0 ? (completedOnTime + completedEarly) / totalCompleted : 0;

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

/// 單日完成資訊（重命名：DayProgress → DayCompletionInfo）
class DayCompletionInfo {
  final String dayOfWeek; // 星期幾
  final DateTime date; // 具體日期
  final bool hasPlannedWorkout; // 是否有計畫訓練
  final CompletionStatusType? status;
  final WorkoutCompletionRecord? completionRecord;

  DayCompletionInfo({
    required this.dayOfWeek,
    required this.date,
    required this.hasPlannedWorkout,
    this.status,
    this.completionRecord,
  });

  bool get isToday => WorkoutDateHelper.isToday(date);

  bool get isPast => WorkoutDateHelper.isPast(date);

  bool get isFuture => WorkoutDateHelper.isFuture(date);
}

// ============================================================
// 🔥 v3.0：重命名完成，不再有類名衝突
// ============================================================
// 舊名稱對照：
// - WeeklyPlanProgress → WeeklyCompletionSummary
// - DayProgress → DayCompletionInfo
// 如果其他地方使用舊名稱，請更新為新名稱