// lib/services/workout_progress_service.dart
// ✅ v4.1 重構版 - 增加 debug 資訊
// 🔧 關鍵修正：
//    1. 精確計算總訓練天數
//    2. 本週進度追蹤
//    3. 整合 PlanProgress 模型
//    4. 使用統一的 WorkoutDateHelper
//    5. v4.1：增加詳細 debug 資訊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';
import '../models/completion_status.dart';
import '../models/plan_progress.dart';
import '../utils/workout_date_helper.dart';

/// 訓練進度追蹤服務 v4.0
/// 負責記錄和計算訓練計畫的完成進度
class WorkoutProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 v4.0 新增：完整進度計算
  // ============================================================

  /// 🔥 獲取計畫的完整進度資訊
  Future<PlanProgress> getPlanProgress(WorkoutPlanModel plan) async {
    if (plan.id == null || _currentUserId == null) {
      return PlanProgress.empty(plan.id ?? '');
    }

    try {
      // 1. 計算總訓練天數
      final totalDays = PlanProgressCalculator.calculateTotalTrainingDays(plan);
      
      // 2. 獲取所有完成記錄
      final completionsSnapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: plan.id)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      // 3. 統計完成數據
      int completedDays = 0;
      int onTimeDays = 0;
      int earlyDays = 0;
      int makeupDays = 0;
      int totalDuration = 0;
      double totalCalories = 0;

      for (var doc in completionsSnapshot.docs) {
        final data = doc.data();
        completedDays++;
        totalDuration += (data['totalDuration'] as int?) ?? 0;
        totalCalories += (data['caloriesBurned'] as num?)?.toDouble() ?? 0;

        // 判斷完成類型
        final isOnSchedule = data['isOnSchedule'] as bool? ?? true;
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();

        if (actualDate != null && planDayOfWeek.isNotEmpty) {
          final plannedDate = WorkoutDateHelper.getDateForWeekdayString(
            planDayOfWeek,
            actualDate,
          );
          
          if (plannedDate != null) {
            final plannedDateOnly = DateTime(
              plannedDate.year, plannedDate.month, plannedDate.day);
            final actualDateOnly = DateTime(
              actualDate.year, actualDate.month, actualDate.day);

            if (actualDateOnly.isBefore(plannedDateOnly)) {
              earlyDays++;
            } else if (actualDateOnly.isAtSameMomentAs(plannedDateOnly)) {
              onTimeDays++;
            } else {
              makeupDays++;
            }
          } else {
            // 無法計算，使用 isOnSchedule
            if (isOnSchedule) {
              onTimeDays++;
            } else {
              makeupDays++;
            }
          }
        } else {
          if (isOnSchedule) {
            onTimeDays++;
          } else {
            makeupDays++;
          }
        }
      }

      // 4. 計算本週進度
      final currentWeek = await getWeeklyProgress(plan);

      return PlanProgress(
        planId: plan.id!,
        totalTrainingDays: totalDays,
        completedDays: completedDays,
        onTimeDays: onTimeDays,
        earlyDays: earlyDays,
        makeupDays: makeupDays,
        totalDuration: totalDuration,
        totalCalories: totalCalories,
        currentWeek: currentWeek,
        planStartDate: plan.startDate,
        planEndDate: plan.endDate,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫進度失敗: $e');
      }
      return PlanProgress.empty(plan.id!);
    }
  }

  /// 🔥 獲取本週進度
  Future<WeeklyProgress> getWeeklyProgress(
    WorkoutPlanModel plan, {
    DateTime? referenceDate,
  }) async {
    if (plan.id == null || _currentUserId == null) {
      debugPrint('⚠️ getWeeklyProgress: plan.id 或 userId 為空');
      return WeeklyProgress.empty();
    }

    final ref = referenceDate ?? DateTime.now();
    final weekStart = WorkoutDateHelper.getWeekStart(ref);
    final weekEnd = WorkoutDateHelper.getWeekEnd(ref);

    debugPrint('🔍 查詢本週完成記錄...');
    debugPrint('   planId: ${plan.id}');
    debugPrint('   userId: $_currentUserId');
    debugPrint('   weekStart: $weekStart');
    debugPrint('   weekEnd: $weekEnd');

    try {
      // 1. 獲取本週完成記錄
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: plan.id)
          .where('userId', isEqualTo: _currentUserId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(
            weekEnd.add(const Duration(days: 1))))
          .get();

      debugPrint('📊 查詢結果: ${snapshot.docs.length} 筆記錄');

      // 2. 轉換為 Map
      final Map<String, Map<String, dynamic>> completions = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        debugPrint('   找到記錄: $planDayOfWeek, actualDate: ${data['actualDate']}');
        
        if (planDayOfWeek.isNotEmpty) {
          final normalizedKey = WorkoutDateHelper.normalizeToChinese(planDayOfWeek);
          
          // 計算狀態類型
          final actualDate = (data['actualDate'] as Timestamp?)?.toDate();
          CompletionStatusType? statusType;
          
          if (actualDate != null) {
            final plannedDate = WorkoutDateHelper.getDateForWeekdayString(
              planDayOfWeek, actualDate);
            if (plannedDate != null) {
              final plannedOnly = DateTime(
                plannedDate.year, plannedDate.month, plannedDate.day);
              final actualOnly = DateTime(
                actualDate.year, actualDate.month, actualDate.day);
              
              if (actualOnly.isBefore(plannedOnly)) {
                statusType = CompletionStatusType.early;
              } else if (actualOnly.isAtSameMomentAs(plannedOnly)) {
                statusType = CompletionStatusType.onTime;
              } else {
                statusType = CompletionStatusType.makeup;
              }
            }
          }
          
          debugPrint('   正規化: $normalizedKey, status: $statusType');
          
          completions[normalizedKey] = {
            'completed': true,
            'actualDate': actualDate,
            'planDayOfWeek': normalizedKey,
            'isOnSchedule': data['isOnSchedule'] ?? true,
            'duration': data['totalDuration'] ?? 0,
            'calories': data['caloriesBurned'] ?? 0.0,
            'statusType': statusType,
          };
        }
      }

      debugPrint('📋 completions Map: ${completions.keys.toList()}');

      // 3. 計算本週應完成天數
      final shouldComplete = PlanProgressCalculator.calculateWeeklyTargetDays(
        plan, referenceDate: ref);

      // 4. 生成每天進度
      final days = PlanProgressCalculator.generateWeekDays(
        plan: plan,
        completions: completions,
        referenceDate: ref,
      );

      // 5. 統計各狀態數量
      int completed = 0;
      int onTimeCount = 0;
      int earlyCount = 0;
      int makeupCount = 0;
      int overdueCount = 0;
      int pendingCount = 0;
      int dueTodayCount = 0;

      for (final day in days) {
        if (!day.isTrainingDay) continue;
        
        switch (day.status) {
          case CompletionStatusType.onTime:
            completed++;
            onTimeCount++;
            break;
          case CompletionStatusType.early:
            completed++;
            earlyCount++;
            break;
          case CompletionStatusType.makeup:
            completed++;
            makeupCount++;
            break;
          case CompletionStatusType.overdue:
            overdueCount++;
            break;
          case CompletionStatusType.dueToday:
            dueTodayCount++;
            break;
          case CompletionStatusType.pending:
            if (day.isAfterPlanStart) {
              pendingCount++;
            }
            break;
        }
      }

      return WeeklyProgress(
        weekStart: weekStart,
        weekEnd: weekEnd,
        shouldComplete: shouldComplete,
        completed: completed,
        onTimeCount: onTimeCount,
        earlyCount: earlyCount,
        makeupCount: makeupCount,
        overdueCount: overdueCount,
        pendingCount: pendingCount,
        dueTodayCount: dueTodayCount,
        days: days,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取本週進度失敗: $e');
      }
      return WeeklyProgress.empty();
    }
  }

  // ============================================================
  // 🔥 原有方法（保留相容性）
  // ============================================================

  /// 📊 計算訓練計畫的總天數（舊版，保留相容）
  @Deprecated('Use PlanProgressCalculator.calculateTotalTrainingDays instead')
  int calculateTotalDays(WorkoutPlanModel plan) {
    return PlanProgressCalculator.calculateTotalTrainingDays(plan);
  }

  /// 🎯 計算完成進度百分比
  Future<double> getCompletionProgress(WorkoutPlanModel plan) async {
    if (plan.id == null) return 0.0;

    final totalDays = PlanProgressCalculator.calculateTotalTrainingDays(plan);
    if (totalDays <= 0) return 0.0;

    final completedDays = await getCompletedDays(plan.id!);

    return (completedDays / totalDays).clamp(0.0, 1.0);
  }

  // ============================================================
  // 🔥 完成記錄方法
  // ============================================================

  /// 📝 記錄訓練完成
  Future<void> recordWorkoutCompletion({
    required String planId,
    required String dayOfWeek,
    required int exercisesCompleted,
    required int totalExercises,
    required int totalDuration,
    String? notes,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);

    // 使用統一的日期工具正規化星期格式
    final normalizedDayOfWeek = WorkoutDateHelper.normalizeToChinese(dayOfWeek);

    // 查詢是否已有今日記錄
    final existingRecords = await _firestore
        .collection('workoutCompletions')
        .where('planId', isEqualTo: planId)
        .where('userId', isEqualTo: _currentUserId)
        .where('planDayOfWeek', isEqualTo: normalizedDayOfWeek)
        .get();

    // 在代碼中過濾今天的記錄
    final todayRecords = existingRecords.docs.where((doc) {
      final data = doc.data();
      final actualDate = data['actualDate'] as Timestamp?;
      if (actualDate == null) return false;
      final completionDate = actualDate.toDate();
      return completionDate.year == dateOnly.year &&
          completionDate.month == dateOnly.month &&
          completionDate.day == dateOnly.day;
    }).toList();

    if (todayRecords.isNotEmpty) {
      // 更新記錄
      await _firestore
          .collection('workoutCompletions')
          .doc(todayRecords.first.id)
          .update({
        'exercisesCompleted': exercisesCompleted,
        'totalExercises': totalExercises,
        'totalDuration': totalDuration,
        if (notes != null) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 更新訓練完成記錄: ${todayRecords.first.id}');
      }
    } else {
      // 創建新記錄
      final isOnSchedule = WorkoutDateHelper.isSameWeekday(
        normalizedDayOfWeek,
        WorkoutDateHelper.getTodayFullChinese(),
      );

      await _firestore.collection('workoutCompletions').add({
        'planId': planId,
        'userId': _currentUserId,
        'planDayOfWeek': normalizedDayOfWeek,
        'actualDayOfWeek': WorkoutDateHelper.getTodayFullChinese(),
        'actualDate': Timestamp.fromDate(now),
        'isOnSchedule': isOnSchedule,
        'exercisesCompleted': exercisesCompleted,
        'totalExercises': totalExercises,
        'totalDuration': totalDuration,
        if (notes != null) 'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 新增訓練完成記錄');
        debugPrint('   planDayOfWeek: $normalizedDayOfWeek');
        debugPrint('   isOnSchedule: $isOnSchedule');
      }
    }
  }

  // ============================================================
  // 🔥 查詢方法
  // ============================================================

  /// 📈 獲取訓練計畫的完成天數
  Future<int> getCompletedDays(String planId) async {
    if (_currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      if (kDebugMode) {
        debugPrint('📊 計畫進度查詢: planId=$planId, 找到 ${snapshot.docs.length} 筆');
      }

      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫進度失敗: $e');
      }
      return 0;
    }
  }

  /// 📊 獲取每週完成狀態（舊版，返回英文 key）
  Future<Map<String, int>> getWeeklyCompletion(String planId) async {
    if (_currentUserId == null) return {};

    final Map<String, int> weeklyCompletion = {};

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dayOfWeek = data['planDayOfWeek']?.toString() ??
            data['dayOfWeek']?.toString() ??
            '';

        if (dayOfWeek.isEmpty) continue;

        final englishKey = WorkoutDateHelper.normalizeToEnglish(dayOfWeek);
        weeklyCompletion[englishKey] = (weeklyCompletion[englishKey] ?? 0) + 1;
      }

      if (kDebugMode) {
        debugPrint('📊 每週完成狀態: $weeklyCompletion');
      }

      return weeklyCompletion;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取每週完成狀態失敗: $e');
      }
      return {};
    }
  }

  /// 🗓️ 檢查今天是否已完成訓練
  Future<bool> isCompletedToday(String planId, String dayOfWeek) async {
    if (_currentUserId == null) return false;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final normalizedDayOfWeek = WorkoutDateHelper.normalizeToChinese(dayOfWeek);

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .where('planDayOfWeek', isEqualTo: normalizedDayOfWeek)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('actualDate', isLessThan: Timestamp.fromDate(todayEnd))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 檢查今日完成狀態失敗: $e');
      }
      return false;
    }
  }

  /// 📅 獲取計畫的所有完成記錄
  Future<List<WorkoutCompletionRecord>> getCompletionHistory(String planId) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('actualDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return WorkoutCompletionRecord.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取完成記錄歷史失敗: $e');
      }
      return [];
    }
  }

  /// 📆 獲取特定日期範圍的完成記錄
  Future<List<WorkoutCompletionRecord>> getCompletionsByDateRange({
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('actualDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return WorkoutCompletionRecord.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取日期範圍完成記錄失敗: $e');
      }
      return [];
    }
  }

  // ============================================================
  // 🔥 統計方法
  // ============================================================

  /// 📊 獲取計畫統計摘要
  Future<Map<String, dynamic>> getPlanStatsSummary(String planId) async {
    if (_currentUserId == null) return {};

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      int totalCompletions = snapshot.docs.length;
      int onScheduleCount = 0;
      int totalDuration = 0;
      double totalCalories = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['isOnSchedule'] == true) onScheduleCount++;
        totalDuration += (data['totalDuration'] as int?) ?? 0;
        totalCalories += (data['caloriesBurned'] as num?)?.toDouble() ?? 0;
      }

      return {
        'totalCompletions': totalCompletions,
        'onScheduleCount': onScheduleCount,
        'offScheduleCount': totalCompletions - onScheduleCount,
        'onScheduleRate': totalCompletions > 0
            ? (onScheduleCount / totalCompletions * 100).round()
            : 0,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories.round(),
        'avgDuration': totalCompletions > 0
            ? (totalDuration / totalCompletions).round()
            : 0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫統計失敗: $e');
      }
      return {};
    }
  }

  /// 🔥 獲取多個計畫的進度（批量）
  Future<Map<String, PlanProgress>> getBatchPlanProgress(
    List<WorkoutPlanModel> plans,
  ) async {
    final Map<String, PlanProgress> results = {};
    
    for (final plan in plans) {
      if (plan.id != null) {
        results[plan.id!] = await getPlanProgress(plan);
      }
    }
    
    return results;
  }
}