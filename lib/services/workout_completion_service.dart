// lib/services/workout_completion_service.dart
// 🔥 訓練完成狀態計算服務 v3.0
// ✅ v3.0 更新：使用新類名避免衝突
//    - WeeklyPlanProgress → WeeklyCompletionSummary
//    - DayProgress → DayCompletionInfo
// ✅ 重構：使用統一的 WorkoutDateHelper
// ✅ 職責：專注於狀態計算邏輯

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

  /// 🔥 計算單筆訓練的完成狀態類型
  ///
  /// [planDayOfWeek] - 計畫的星期幾（例：星期一、monday）
  /// [actualDate] - 實際完成日期（null 表示未完成）
  /// [referenceDate] - 參考日期（用於計算本週，預設為今天）
  CompletionStatusType calculateStatus({
    required String planDayOfWeek,
    DateTime? actualDate,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 🔥 使用統一的日期工具計算計畫日在本週的具體日期
    final plannedDate = WorkoutDateHelper.getDateForWeekdayString(planDayOfWeek, referenceDate);
    if (plannedDate == null) {
      if (kDebugMode) {
        debugPrint('⚠️ 無法解析星期格式: $planDayOfWeek');
      }
      return CompletionStatusType.pending;
    }

    final plannedDateOnly = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);

    // 情況 1：已完成
    if (actualDate != null) {
      final actualDateOnly = DateTime(actualDate.year, actualDate.month, actualDate.day);

      // 在計畫日當天完成 → 準時
      if (actualDateOnly.isAtSameMomentAs(plannedDateOnly)) {
        return CompletionStatusType.onTime;
      }

      // 在計畫日之前完成 → 提前
      if (actualDateOnly.isBefore(plannedDateOnly)) {
        return CompletionStatusType.early;
      }

      // 在計畫日之後完成 → 補做
      return CompletionStatusType.makeup;
    }

    // 情況 2：未完成

    // 今天是計畫日 → 今日待做
    if (today.isAtSameMomentAs(plannedDateOnly)) {
      return CompletionStatusType.dueToday;
    }

    // 計畫日已過 → 逾期
    if (today.isAfter(plannedDateOnly)) {
      return CompletionStatusType.overdue;
    }

    // 計畫日還沒到 → 待完成
    return CompletionStatusType.pending;
  }

  /// 🔥 批量計算訓練狀態（用於列表顯示）
  List<WorkoutCompletionRecord> calculateStatusBatch({
    required List<Map<String, dynamic>> completions,
    DateTime? referenceDate,
  }) {
    return completions.map((data) {
      final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
      final actualDate = data['actualDate'] != null
          ? (data['actualDate'] as Timestamp).toDate()
          : null;

      final statusType = calculateStatus(
        planDayOfWeek: planDayOfWeek,
        actualDate: actualDate,
        referenceDate: referenceDate,
      );

      return WorkoutCompletionRecord(
        id: data['id'] ?? '',
        planId: data['planId'] ?? '',
        planName: data['planName'] ?? '',
        planDayOfWeek: planDayOfWeek,
        actualDate: actualDate,
        actualDayOfWeek: data['actualDayOfWeek'],
        statusType: statusType,
        duration: data['totalDuration'] ?? data['duration'] ?? 0,
        calories: (data['caloriesBurned'] ?? 0).toDouble(),
        exerciseCount: data['exercisesCompleted'] ?? data['totalExercises'] ?? 0,
        setCount: data['setsCompleted'] ?? data['totalSets'] ?? 0,
        sessionId: data['sessionId'],
      );
    }).toList();
  }

  // ============================================================
  // 🔥 Firebase 查詢方法
  // ============================================================

  /// 獲取指定用戶本週的計畫完成情況
  Future<Map<String, WorkoutCompletionRecord>> getWeeklyCompletions({
    required String planId,
    String? userId,
    DateTime? referenceDate,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return {};

    try {
      // 🔥 使用統一的日期工具
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

        // 🔥 使用正規化的 key
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

      if (kDebugMode) {
        debugPrint('✅ 本週完成記錄: ${completions.length} 筆');
        for (var entry in completions.entries) {
          debugPrint('   ${entry.key}: ${entry.value.status.label}');
        }
      }

      return completions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取本週完成記錄失敗: $e');
      }
      return {};
    }
  }

  /// 🔥 獲取計畫的週進度總覽
  /// v3.0：返回 WeeklyCompletionSummary（舊名 WeeklyPlanProgress）
  Future<WeeklyCompletionSummary> getWeeklyPlanProgress({
    required String planId,
    required List<String> planDays, // 計畫的訓練日（例：['星期一', '星期三', '星期五']）
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
      // 獲取本週的完成記錄
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

      // 🔥 v3.0：使用 DayCompletionInfo（舊名 DayProgress）
      List<DayCompletionInfo> dayProgressList = [];

      for (final dayOfWeek in planDays) {
        // 🔥 正規化星期格式後查找
        final normalizedDay = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
        final completion = completions[normalizedDay];
        final plannedDate = WorkoutDateHelper.getDateForWeekdayString(dayOfWeek, referenceDate);

        CompletionStatusType status;

        if (completion != null) {
          status = completion.statusType;
        } else {
          // 沒有完成記錄，計算應該是什麼狀態
          status = calculateStatus(
            planDayOfWeek: dayOfWeek,
            actualDate: null,
            referenceDate: referenceDate,
          );
        }

        // 統計各狀態數量
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
          // 🔥 v3.0：使用 DayCompletionInfo
          dayProgressList.add(DayCompletionInfo(
            dayOfWeek: normalizedDay,
            date: plannedDate,
            hasPlannedWorkout: true,
            status: status,
            completionRecord: completion,
          ));
        }
      }

      // 按日期排序
      dayProgressList.sort((a, b) => a.date.compareTo(b.date));

      // 🔥 v3.0：返回 WeeklyCompletionSummary
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

  /// 🔥 獲取學員的所有計畫訓練記錄（教練端使用）
  Future<List<WorkoutCompletionRecord>> getTraineeWorkoutLogs({
    required String traineeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .orderBy('actualDate', descending: true);

      if (startDate != null) {
        query = query.where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();

        final statusType = calculateStatus(
          planDayOfWeek: planDayOfWeek,
          actualDate: actualDate,
        );

        return WorkoutCompletionRecord(
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
          sessionId: data['sessionId'],
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取學員訓練記錄失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 獲取學員的執行統計（教練端儀表板使用）
  Future<Map<String, dynamic>> getTraineeStatistics({
    required String traineeId,
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('userId', isEqualTo: traineeId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      int totalCompleted = snapshot.docs.length;
      int onTimeCount = 0;
      int makeupCount = 0;
      int earlyCount = 0;
      int totalDuration = 0;
      double totalCalories = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();

        final status = calculateStatus(
          planDayOfWeek: planDayOfWeek,
          actualDate: actualDate,
        );

        switch (status) {
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

        totalDuration += (data['totalDuration'] ?? 0) as int;
        totalCalories += ((data['caloriesBurned'] ?? 0) as num).toDouble();
      }

      return {
        'totalCompleted': totalCompleted,
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
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取學員統計失敗: $e');
      }
      return {
        'totalCompleted': 0,
        'onTimeCount': 0,
        'makeupCount': 0,
        'earlyCount': 0,
        'onTimeRate': 0,
        'totalDuration': 0,
        'totalCalories': 0,
        'avgDuration': 0,
        'period': '$days 天',
      };
    }
  }
}