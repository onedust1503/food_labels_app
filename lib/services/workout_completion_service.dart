// lib/services/workout_completion_service.dart
// 🔥 訓練完成狀態計算服務 v1.0
// 負責計算和判斷訓練的完成狀態

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/completion_status.dart';

class WorkoutCompletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 星期格式轉換工具
  // ============================================================
  
  /// 星期幾對照表（多種格式支援）
  static const Map<int, List<String>> _weekdayFormats = {
    1: ['星期一', '週一', 'monday', 'mon', '一'],
    2: ['星期二', '週二', 'tuesday', 'tue', '二'],
    3: ['星期三', '週三', 'wednesday', 'wed', '三'],
    4: ['星期四', '週四', 'thursday', 'thu', '四'],
    5: ['星期五', '週五', 'friday', 'fri', '五'],
    6: ['星期六', '週六', 'saturday', 'sat', '六'],
    7: ['星期日', '週日', 'sunday', 'sun', '日'],
  };

  /// 將任意格式的星期字串轉換為 weekday 數字 (1-7)
  static int? parseWeekday(String dayStr) {
    final normalized = dayStr.toLowerCase().trim();
    
    for (final entry in _weekdayFormats.entries) {
      for (final format in entry.value) {
        if (normalized == format.toLowerCase() || normalized.contains(format.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 獲取標準格式的星期字串（完整格式：星期一）
  static String getStandardWeekday(int weekday) {
    return _weekdayFormats[weekday]?[0] ?? '未知';
  }

  /// 獲取短格式的星期字串（週一）
  static String getShortWeekday(int weekday) {
    return _weekdayFormats[weekday]?[1] ?? '未知';
  }

  /// 判斷兩個星期字串是否相同（格式無關）
  static bool isSameWeekday(String day1, String day2) {
    final weekday1 = parseWeekday(day1);
    final weekday2 = parseWeekday(day2);
    
    if (weekday1 == null || weekday2 == null) return false;
    return weekday1 == weekday2;
  }

  // ============================================================
  // 🔥 日期工具函數
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

  /// 獲取指定星期幾在本週的具體日期
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

  // ============================================================
  // 🔥 狀態計算核心邏輯
  // ============================================================

  /// 🔥 計算單筆訓練的完成狀態類型
  /// 
  /// [planDayOfWeek] - 計畫的星期幾（例：星期一）
  /// [actualDate] - 實際完成日期（null 表示未完成）
  /// [referenceDate] - 參考日期（用於計算本週，預設為今天）
  CompletionStatusType calculateStatus({
    required String planDayOfWeek,
    DateTime? actualDate,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 計算計畫日在本週的具體日期
    final plannedDate = getDateForWeekdayString(planDayOfWeek, referenceDate);
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
      final weekStart = getWeekStart(referenceDate);
      final weekEnd = getWeekEnd(referenceDate);

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

        completions[planDayOfWeek] = WorkoutCompletionRecord(
          id: doc.id,
          planId: planId,
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
  Future<WeeklyPlanProgress> getWeeklyPlanProgress({
    required String planId,
    required List<String> planDays, // 計畫的訓練日（例：['星期一', '星期三', '星期五']）
    String? userId,
    DateTime? referenceDate,
  }) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) {
      return WeeklyPlanProgress(
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
      
      List<DayProgress> dayProgressList = [];

      for (final dayOfWeek in planDays) {
        final completion = completions[dayOfWeek];
        final plannedDate = getDateForWeekdayString(dayOfWeek, referenceDate);
        
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
          dayProgressList.add(DayProgress(
            dayOfWeek: dayOfWeek,
            date: plannedDate,
            hasPlannedWorkout: true,
            status: status,
            completionRecord: completion,
          ));
        }
      }

      // 按日期排序
      dayProgressList.sort((a, b) => a.date.compareTo(b.date));

      return WeeklyPlanProgress(
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
      return WeeklyPlanProgress(
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
        final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
        
        // 這裡需要更精確的判斷邏輯
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