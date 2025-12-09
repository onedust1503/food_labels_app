// lib/services/workout_completion_service.dart
// 🔥 訓練完成狀態計算服務 v4.2
// ✅ v4.2 更新：同時查詢計畫訓練和自由訓練
// ✅ v4.1 修正：移除 WorkoutCompletionRecord 重複定義，改用 TraineeWorkoutLog
// ✅ v4.0 更新：加入 feedback 支援
// ✅ v3.0 更新：使用新類名避免衝突

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/completion_status.dart';
import '../utils/workout_date_helper.dart';

class WorkoutCompletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 狀態計算核心邏輯
  // ============================================================

  CompletionStatusType calculateStatus({
    required String planDayOfWeek,
    DateTime? actualDate,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final plannedDate = WorkoutDateHelper.getDateForWeekdayString(planDayOfWeek, referenceDate);
    if (plannedDate == null) {
      if (kDebugMode) {
        debugPrint('⚠️ 無法解析星期格式: $planDayOfWeek');
      }
      return CompletionStatusType.pending;
    }

    final plannedDateOnly = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);

    if (actualDate != null) {
      final actualDateOnly = DateTime(actualDate.year, actualDate.month, actualDate.day);

      if (actualDateOnly.isAtSameMomentAs(plannedDateOnly)) {
        return CompletionStatusType.onTime;
      }

      if (actualDateOnly.isBefore(plannedDateOnly)) {
        return CompletionStatusType.early;
      }

      return CompletionStatusType.makeup;
    }

    if (today.isAtSameMomentAs(plannedDateOnly)) {
      return CompletionStatusType.dueToday;
    }

    if (today.isAfter(plannedDateOnly)) {
      return CompletionStatusType.overdue;
    }

    return CompletionStatusType.pending;
  }

  // ============================================================
  // 🔥 Firebase 查詢方法
  // ============================================================

  Future<Map<String, WorkoutCompletionRecord>> getWeeklyCompletions({
    required String planId,
    String? userId,
    DateTime? referenceDate,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return {};

    try {
      final weekStart = WorkoutDateHelper.getWeekStart(referenceDate);
      final weekEnd = WorkoutDateHelper.getWeekEnd(referenceDate);

      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: uid)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      Map<String, WorkoutCompletionRecord> completions = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();

        final statusType = calculateStatus(
          planDayOfWeek: planDayOfWeek,
          actualDate: actualDate,
          referenceDate: referenceDate,
        );

        final normalizedKey = WorkoutDateHelper.normalizeToChinese(planDayOfWeek);

        completions[normalizedKey] = WorkoutCompletionRecord(
          id: doc.id,
          planId: planId,
          planName: data['planName'] ?? '',
          planDayOfWeek: normalizedKey,
          actualDate: actualDate,
          actualDayOfWeek: data['actualDayOfWeek'],
          statusType: statusType,
          duration: data['totalDuration'] ?? 0,
          calories: (data['caloriesBurned'] ?? 0).toDouble(),
          exerciseCount: data['exercisesCompleted'] ?? 0,
          setCount: data['setsCompleted'] ?? 0,
          sessionId: data['sessionId'],
        );
      }

      return completions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取本週完成記錄失敗: $e');
      }
      return {};
    }
  }

  Future<WeeklyCompletionSummary> getWeeklyPlanProgress({
    required String planId,
    required List<String> planDays,
    String? userId,
    DateTime? referenceDate,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) {
      return WeeklyCompletionSummary(
        planId: planId,
        planName: '',
        totalDays: planDays.length,
      );
    }

    try {
      final completions = await getWeeklyCompletions(
        planId: planId,
        userId: uid,
        referenceDate: referenceDate,
      );

      int completedOnTime = 0;
      int completedMakeup = 0;
      int completedEarly = 0;
      int overdue = 0;
      int pending = 0;
      int dueToday = 0;

      List<DayCompletionInfo> dayProgressList = [];

      for (final dayOfWeek in planDays) {
        final normalizedDay = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
        final completion = completions[normalizedDay];
        final plannedDate = WorkoutDateHelper.getDateForWeekdayString(dayOfWeek, referenceDate);

        CompletionStatusType status;

        if (completion != null) {
          status = completion.statusType;
        } else {
          status = calculateStatus(
            planDayOfWeek: dayOfWeek,
            actualDate: null,
            referenceDate: referenceDate,
          );
        }

        switch (status) {
          case CompletionStatusType.onTime:
            completedOnTime++;
            break;
          case CompletionStatusType.makeup:
            completedMakeup++;
            break;
          case CompletionStatusType.early:
            completedEarly++;
            break;
          case CompletionStatusType.overdue:
            overdue++;
            break;
          case CompletionStatusType.pending:
            pending++;
            break;
          case CompletionStatusType.dueToday:
            dueToday++;
            break;
        }

        if (plannedDate != null) {
          dayProgressList.add(DayCompletionInfo(
            dayOfWeek: normalizedDay,
            date: plannedDate,
            hasPlannedWorkout: true,
            status: status,
            completionRecord: completion,
          ));
        }
      }

      dayProgressList.sort((a, b) => a.date.compareTo(b.date));

      return WeeklyCompletionSummary(
        planId: planId,
        planName: completions.values.isNotEmpty
            ? completions.values.first.planName
            : '',
        totalDays: planDays.length,
        completedOnTime: completedOnTime,
        completedMakeup: completedMakeup,
        completedEarly: completedEarly,
        overdue: overdue,
        pending: pending,
        dueToday: dueToday,
        dayProgress: dayProgressList,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取週進度總覽失敗: $e');
      }
      return WeeklyCompletionSummary(
        planId: planId,
        planName: '',
        totalDays: planDays.length,
      );
    }
  }

  // ============================================================
  // 🔥 v4.2：教練端方法 - 同時查詢計畫訓練和自由訓練
  // ============================================================

  /// 🔥 v4.2：獲取學員的所有訓練記錄（計畫 + 自由訓練）
  Future<List<TraineeWorkoutLog>> getTraineeWorkoutLogs({
    required String traineeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      List<TraineeWorkoutLog> allRecords = [];

      // ========== 1. 查詢計畫訓練（workoutCompletions）==========
      Query completionsQuery = _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .orderBy('actualDate', descending: true);

      if (startDate != null) {
        completionsQuery = completionsQuery.where('actualDate', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        completionsQuery = completionsQuery.where('actualDate', 
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final completionsSnapshot = await completionsQuery.limit(limit).get();

      for (var doc in completionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();
        final sessionId = data['sessionId'] as String?;

        final statusType = calculateStatus(
          planDayOfWeek: planDayOfWeek,
          actualDate: actualDate,
        );

        // 從 workoutSessions 讀取 feedback
        Map<String, dynamic>? feedback;
        if (sessionId != null && sessionId.isNotEmpty) {
          try {
            final sessionDoc = await _firestore
                .collection('workoutSessions')
                .doc(sessionId)
                .get();

            if (sessionDoc.exists) {
              final sessionData = sessionDoc.data();
              feedback = sessionData?['feedback'] as Map<String, dynamic>?;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 讀取 session feedback 失敗: $e');
            }
          }
        }

        allRecords.add(TraineeWorkoutLog(
          id: doc.id,
          planId: data['planId'] ?? '',
          planName: data['planName'] ?? '',
          planDayOfWeek: planDayOfWeek,
          actualDate: actualDate,
          actualDayOfWeek: data['actualDayOfWeek'],
          statusType: statusType,
          duration: data['totalDuration'] ?? 0,
          calories: (data['caloriesBurned'] ?? 0).toDouble(),
          exerciseCount: data['exercisesCompleted'] ?? 0,
          setCount: data['setsCompleted'] ?? 0,
          sessionId: sessionId,
          isPlanWorkout: true, // 🔥 標記為計畫訓練
          needsHelp: feedback?['needHelp'] ?? false,
          helpMessage: feedback?['helpMessage'],
          rpe: feedback?['rpe'],
          fatigueLevel: feedback?['fatigueLevel'],
          mood: feedback?['mood'],
          note: feedback?['note'],
        ));
      }

      // ========== 2. 查詢自由訓練（workoutSessions）==========
      Query sessionsQuery = _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: traineeId)
          .orderBy('endedAt', descending: true);

      if (startDate != null) {
        sessionsQuery = sessionsQuery.where('endedAt', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        sessionsQuery = sessionsQuery.where('endedAt', 
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final sessionsSnapshot = await sessionsQuery.limit(limit).get();

      // 收集已經在計畫訓練中的 sessionId，避免重複
      final existingSessionIds = allRecords
          .where((r) => r.sessionId != null)
          .map((r) => r.sessionId!)
          .toSet();

      for (var doc in sessionsSnapshot.docs) {
        // 跳過已經在計畫訓練中的記錄
        if (existingSessionIds.contains(doc.id)) {
          continue;
        }

        final data = doc.data() as Map<String, dynamic>;
        
        // 🔥 判斷是否為自由訓練（沒有 planId 或 planId 為空）
        final planId = data['planId'] as String?;
        final isFreestyle = planId == null || planId.isEmpty;
        
        // 只處理自由訓練（計畫訓練已經在上面處理過了）
        if (!isFreestyle) {
          continue;
        }

        final endedAt = (data['endedAt'] as Timestamp?)?.toDate();
        final feedback = data['feedback'] as Map<String, dynamic>?;
        
        // 計算訓練時長
        final startedAt = (data['startedAt'] as Timestamp?)?.toDate();
        int duration = data['totalDurationSeconds'] ?? 0;
        if (duration == 0 && startedAt != null && endedAt != null) {
          duration = endedAt.difference(startedAt).inMinutes;
        } else {
          duration = (duration / 60).round(); // 秒轉分鐘
        }

        // 計算動作數和組數
        final exercises = data['exercises'] as List<dynamic>? ?? [];
        int exerciseCount = exercises.length;
        int setCount = 0;
        for (var ex in exercises) {
          if (ex is Map<String, dynamic>) {
            final sets = ex['sets'] as List<dynamic>? ?? [];
            setCount += sets.length;
          }
        }

        allRecords.add(TraineeWorkoutLog(
          id: doc.id,
          planId: '',
          planName: data['name'] ?? '自由訓練',
          planDayOfWeek: '', // 自由訓練沒有計畫日
          actualDate: endedAt,
          actualDayOfWeek: endedAt != null ? _getChineseDayOfWeek(endedAt.weekday) : null,
          statusType: CompletionStatusType.onTime, // 自由訓練視為準時
          duration: duration,
          calories: (data['totalCalories'] ?? 0).toDouble(),
          exerciseCount: exerciseCount,
          setCount: setCount,
          sessionId: doc.id,
          isPlanWorkout: false, // 🔥 標記為自由訓練
          needsHelp: feedback?['needHelp'] ?? false,
          helpMessage: feedback?['helpMessage'],
          rpe: feedback?['rpe'],
          fatigueLevel: feedback?['fatigueLevel'],
          mood: feedback?['mood'],
          note: feedback?['note'],
        ));
      }

      // 按日期排序（最新的在前）
      allRecords.sort((a, b) {
        final dateA = a.actualDate ?? DateTime(1970);
        final dateB = b.actualDate ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      // 限制總數
      if (allRecords.length > limit) {
        allRecords = allRecords.sublist(0, limit);
      }

      if (kDebugMode) {
        final planCount = allRecords.where((r) => r.isPlanWorkout).length;
        final freeCount = allRecords.where((r) => !r.isPlanWorkout).length;
        final needHelpCount = allRecords.where((r) => r.needsHelp).length;
        debugPrint('✅ 獲取學員訓練記錄: ${allRecords.length} 筆');
        debugPrint('   計畫訓練: $planCount 筆，自由訓練: $freeCount 筆');
        debugPrint('   需要協助: $needHelpCount 筆');
      }

      return allRecords;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取學員訓練記錄失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 輔助方法：獲取中文星期
  String _getChineseDayOfWeek(int weekday) {
    const days = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return days[weekday];
  }

  /// 🔥 獲取需要協助的訓練記錄
  Future<List<TraineeWorkoutLog>> getTraineeNeedHelpLogs({
    required String traineeId,
    int limit = 20,
  }) async {
    final allLogs = await getTraineeWorkoutLogs(
      traineeId: traineeId,
      limit: limit * 2,
    );

    return allLogs.where((log) => log.needsHelp).toList();
  }

  /// 🔥 v4.2：獲取學員的執行統計（同時統計計畫和自由訓練）
  Future<Map<String, dynamic>> getTraineeStatistics({
    required String traineeId,
    int days = 30,
  }) async {
    try {
      // 使用 getTraineeWorkoutLogs 來獲取所有記錄
      final startDate = DateTime.now().subtract(Duration(days: days));
      final allLogs = await getTraineeWorkoutLogs(
        traineeId: traineeId,
        startDate: startDate,
        limit: 200,
      );

      int totalCompleted = allLogs.length;
      int planCount = allLogs.where((r) => r.isPlanWorkout).length;
      int freeCount = allLogs.where((r) => !r.isPlanWorkout).length;
      int onTimeCount = 0;
      int makeupCount = 0;
      int earlyCount = 0;
      int totalDuration = 0;
      double totalCalories = 0;
      int needsHelpCount = 0;

      for (var log in allLogs) {
        switch (log.statusType) {
          case CompletionStatusType.onTime:
            onTimeCount++;
            break;
          case CompletionStatusType.makeup:
            makeupCount++;
            break;
          case CompletionStatusType.early:
            earlyCount++;
            break;
          default:
            break;
        }

        totalDuration += log.duration;
        totalCalories += log.calories;
        
        if (log.needsHelp) {
          needsHelpCount++;
        }
      }

      return {
        'totalCompleted': totalCompleted,
        'planCount': planCount,
        'freeCount': freeCount,
        'onTimeCount': onTimeCount,
        'makeupCount': makeupCount,
        'earlyCount': earlyCount,
        'onTimeRate': totalCompleted > 0
            ? ((onTimeCount + earlyCount) / totalCompleted * 100).round()
            : 0,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories.round(),
        'avgDuration': totalCompleted > 0
            ? (totalDuration / totalCompleted).round()
            : 0,
        'period': '$days 天',
        'needsHelpCount': needsHelpCount,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取學員統計失敗: $e');
      }
      return {
        'totalCompleted': 0,
        'planCount': 0,
        'freeCount': 0,
        'onTimeCount': 0,
        'makeupCount': 0,
        'earlyCount': 0,
        'onTimeRate': 0,
        'totalDuration': 0,
        'totalCalories': 0,
        'avgDuration': 0,
        'period': '$days 天',
        'needsHelpCount': 0,
      };
    }
  }
}

// ============================================================
// 🔥 資料模型
// ============================================================

/// 🔥 v4.2：學員訓練日誌（含 feedback 和訓練類型）
class TraineeWorkoutLog {
  final String id;
  final String planId;
  final String planName;
  final String planDayOfWeek;
  final DateTime? actualDate;
  final String? actualDayOfWeek;
  final CompletionStatusType statusType;
  final int duration;
  final double calories;
  final int exerciseCount;
  final int setCount;
  final String? sessionId;

  // 🔥 v4.2：訓練類型
  final bool isPlanWorkout; // true = 計畫訓練, false = 自由訓練

  // 🔥 feedback 欄位
  final bool needsHelp;
  final String? helpMessage;
  final int? rpe;
  final String? fatigueLevel;
  final String? mood;
  final String? note;

  TraineeWorkoutLog({
    required this.id,
    required this.planId,
    required this.planName,
    required this.planDayOfWeek,
    this.actualDate,
    this.actualDayOfWeek,
    required this.statusType,
    required this.duration,
    required this.calories,
    required this.exerciseCount,
    required this.setCount,
    this.sessionId,
    this.isPlanWorkout = true,
    this.needsHelp = false,
    this.helpMessage,
    this.rpe,
    this.fatigueLevel,
    this.mood,
    this.note,
  });

  CompletionStatus get status => CompletionStatus.fromType(statusType);

  bool get hasFeedback =>
      needsHelp ||
      (rpe != null) ||
      (note != null && note!.isNotEmpty) ||
      (helpMessage != null && helpMessage!.isNotEmpty);

  /// 獲取訓練類型標籤
  String get workoutTypeLabel => isPlanWorkout ? '計畫' : '自由';

  String get fatigueLevelText {
    switch (fatigueLevel) {
      case 'low':
        return '輕鬆';
      case 'medium':
        return '適中';
      case 'high':
        return '疲憊';
      case 'exhausted':
        return '極度疲憊';
      default:
        return fatigueLevel ?? '-';
    }
  }

  String get moodText {
    switch (mood) {
      case 'great':
        return '很棒';
      case 'good':
        return '不錯';
      case 'okay':
        return '普通';
      case 'tired':
        return '疲倦';
      case 'bad':
        return '不好';
      default:
        return mood ?? '-';
    }
  }
}

/// 單日進度資訊
class DayCompletionInfo {
  final String dayOfWeek;
  final DateTime date;
  final bool hasPlannedWorkout;
  final CompletionStatusType status;
  final WorkoutCompletionRecord? completionRecord;

  DayCompletionInfo({
    required this.dayOfWeek,
    required this.date,
    required this.hasPlannedWorkout,
    required this.status,
    this.completionRecord,
  });

  CompletionStatus get statusInfo => CompletionStatus.fromType(status);
}

/// 週進度總覽
class WeeklyCompletionSummary {
  final String planId;
  final String planName;
  final int totalDays;
  final int completedOnTime;
  final int completedMakeup;
  final int completedEarly;
  final int overdue;
  final int pending;
  final int dueToday;
  final List<DayCompletionInfo> dayProgress;

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

  int get totalCompleted => completedOnTime + completedMakeup + completedEarly;

  double get completionRate =>
      totalDays > 0 ? (totalCompleted / totalDays * 100) : 0;

  double get onTimeRate =>
      totalCompleted > 0
          ? ((completedOnTime + completedEarly) / totalCompleted * 100)
          : 0;
}