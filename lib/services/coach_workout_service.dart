// lib/services/coach_workout_service.dart
// 🎯 教練端專用服務 - 學員進度查詢
// ✅ 整合混合模式資料結構（按時/補做標記）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CoachWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 教練儀表板 - 學員進度總覽
  // ============================================================

  /// 獲取教練所有學員的計畫進度總覽
  /// 返回：List<StudentProgressSummary>
  Future<List<StudentProgressSummary>> getCoachStudentsProgress() async {
    if (currentUserId == null) return [];

    try {
      // 1. 獲取所有配對的學員
      final pairsSnapshot = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      if (pairsSnapshot.docs.isEmpty) return [];

      List<StudentProgressSummary> results = [];

      for (final pairDoc in pairsSnapshot.docs) {
        final traineeId = pairDoc.data()['traineeId'] as String?;
        if (traineeId == null) continue;

        try {
          // 2. 獲取學員基本資料
          final userDoc = await _firestore
              .collection('users')
              .doc(traineeId)
              .get();

          if (!userDoc.exists) continue;

          final userData = userDoc.data() as Map<String, dynamic>;
          final studentName = userData['displayName'] ?? '未命名學員';
          final goal = userData['goal'] ?? '';

          // 3. 獲取該學員的所有進行中計畫
          final plansSnapshot = await _firestore
              .collection('workoutPlans')
              .where('traineeId', isEqualTo: traineeId)
              .where('status', isEqualTo: 'active')
              .get();

          int totalPlans = plansSnapshot.docs.length;
          int totalCompletions = 0;
          int onScheduleCompletions = 0;
          int thisWeekCompletions = 0;
          int thisWeekPlannedDays = 0;
          bool needsAttention = false;

          // 4. 計算本週進度
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));

          for (final planDoc in plansSnapshot.docs) {
            final planData = planDoc.data();
            final days = planData['days'] as List<dynamic>? ?? [];
            thisWeekPlannedDays += days.length;

            // 查詢該計畫本週的完成記錄
            final completionsSnapshot = await _firestore
                .collection('users')
                .doc(traineeId)
                .collection('workoutCompletions')
                .where('planId', isEqualTo: planDoc.id)
                .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
                .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
                .get();

            for (final completion in completionsSnapshot.docs) {
              final data = completion.data();
              totalCompletions++;
              thisWeekCompletions++;
              if (data['isOnSchedule'] == true) {
                onScheduleCompletions++;
              }
            }
          }

          // 5. 判斷是否需要關注
          // - 本週無訓練紀錄
          // - 按時率低於 50%
          // - 進度嚴重落後
          if (thisWeekCompletions == 0 && thisWeekPlannedDays > 0) {
            needsAttention = true;
          }
          if (totalCompletions > 3 && onScheduleCompletions / totalCompletions < 0.5) {
            needsAttention = true;
          }

          // 6. 計算按時率
          double onScheduleRate = totalCompletions > 0
              ? (onScheduleCompletions / totalCompletions * 100)
              : 0;

          // 7. 計算本週完成率
          double weeklyCompletionRate = thisWeekPlannedDays > 0
              ? (thisWeekCompletions / thisWeekPlannedDays * 100).clamp(0, 100)
              : 0;

          results.add(StudentProgressSummary(
            traineeId: traineeId,
            traineeName: studentName,
            goal: goal,
            totalPlans: totalPlans,
            totalCompletions: totalCompletions,
            onScheduleRate: onScheduleRate,
            thisWeekCompletions: thisWeekCompletions,
            thisWeekPlannedDays: thisWeekPlannedDays,
            weeklyCompletionRate: weeklyCompletionRate,
            needsAttention: needsAttention,
          ));
        } catch (e) {
          debugPrint('處理學員 $traineeId 進度失敗: $e');
        }
      }

      // 8. 排序：需關注的優先，然後按完成率排序
      results.sort((a, b) {
        if (a.needsAttention && !b.needsAttention) return -1;
        if (!a.needsAttention && b.needsAttention) return 1;
        return a.weeklyCompletionRate.compareTo(b.weeklyCompletionRate);
      });

      return results;
    } catch (e) {
      debugPrint('獲取學員進度總覽失敗: $e');
      return [];
    }
  }

  // ============================================================
  // 🔥 單一學員 - 計畫進度詳情
  // ============================================================

  /// 獲取單一學員的所有計畫摘要
  Future<List<PlanProgressSummary>> getStudentPlansSummary(String traineeId) async {
    try {
      // 1. 獲取該學員的所有計畫
      final plansSnapshot = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: traineeId)
          .orderBy('createdAt', descending: true)
          .get();

      if (plansSnapshot.docs.isEmpty) return [];

      List<PlanProgressSummary> results = [];

      for (final planDoc in plansSnapshot.docs) {
        final planData = planDoc.data();
        final planId = planDoc.id;
        final planName = planData['planName'] ?? '未命名計畫';
        final status = planData['status'] ?? 'active';
        final days = planData['days'] as List<dynamic>? ?? [];

        // 2. 計算計畫總天數
        int totalDays = days.length;

        // 3. 獲取完成統計
        final stats = await getPlanStatistics(traineeId, planId);

        // 4. 獲取本週進度
        final weeklyProgress = await getWeeklyPlanProgress(traineeId, planId, days);

        results.add(PlanProgressSummary(
          planId: planId,
          planName: planName,
          status: status,
          totalDays: totalDays,
          totalCompletions: stats['totalCompletions'] ?? 0,
          onScheduleCount: stats['onScheduleCount'] ?? 0,
          onScheduleRate: stats['onScheduleRate']?.toDouble() ?? 0,
          totalDuration: stats['totalDuration'] ?? 0,
          totalCalories: stats['totalCalories']?.toDouble() ?? 0,
          weeklyProgress: weeklyProgress,
          startDate: _parseDate(planData['startDate']),
          endDate: _parseDate(planData['endDate']),
        ));
      }

      return results;
    } catch (e) {
      debugPrint('獲取學員計畫摘要失敗: $e');
      return [];
    }
  }

  /// 獲取單一計畫的統計數據
  Future<Map<String, dynamic>> getPlanStatistics(String traineeId, String planId) async {
    try {
      final completionsSnapshot = await _firestore
          .collection('users')
          .doc(traineeId)
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .orderBy('actualDate', descending: true)
          .get();

      if (completionsSnapshot.docs.isEmpty) {
        return {
          'totalCompletions': 0,
          'onScheduleCount': 0,
          'onScheduleRate': 0,
          'totalDuration': 0,
          'totalCalories': 0.0,
        };
      }

      int totalCompletions = completionsSnapshot.docs.length;
      int onScheduleCount = 0;
      int totalDuration = 0;
      double totalCalories = 0;

      for (final doc in completionsSnapshot.docs) {
        final data = doc.data();
        if (data['isOnSchedule'] == true) {
          onScheduleCount++;
        }
        totalDuration += (data['totalDuration'] as num?)?.toInt() ?? 0;
        totalCalories += (data['caloriesBurned'] as num?)?.toDouble() ?? 0;
      }

      double onScheduleRate = totalCompletions > 0
          ? (onScheduleCount / totalCompletions * 100)
          : 0;

      return {
        'totalCompletions': totalCompletions,
        'onScheduleCount': onScheduleCount,
        'onScheduleRate': onScheduleRate.round(),
        'totalDuration': totalDuration,
        'totalCalories': totalCalories,
        'avgDuration': totalCompletions > 0 ? (totalDuration / totalCompletions).round() : 0,
      };
    } catch (e) {
      debugPrint('獲取計畫統計失敗: $e');
      return {};
    }
  }

  /// 獲取本週計畫進度（混合模式）
  Future<Map<String, WeekDayProgress>> getWeeklyPlanProgress(
    String traineeId,
    String planId,
    List<dynamic> planDays,
  ) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // 查詢本週完成記錄
      final completionsSnapshot = await _firestore
          .collection('users')
          .doc(traineeId)
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      // 建立 planDayOfWeek -> 完成記錄 的映射
      Map<String, WeekDayProgress> result = {};

      // 初始化所有計畫日
      for (final day in planDays) {
        final dayOfWeek = day['dayOfWeek'] as String? ?? '';
        if (dayOfWeek.isNotEmpty) {
          result[dayOfWeek] = WeekDayProgress(
            dayOfWeek: dayOfWeek,
            isPlanned: true,
            isCompleted: false,
            isOnSchedule: false,
          );
        }
      }

      // 標記已完成的
      for (final doc in completionsSnapshot.docs) {
        final data = doc.data();
        final planDayOfWeek = data['planDayOfWeek'] as String? ?? '';
        final isOnSchedule = data['isOnSchedule'] as bool? ?? false;
        final actualDate = (data['actualDate'] as Timestamp?)?.toDate();
        final duration = (data['totalDuration'] as num?)?.toInt() ?? 0;
        final calories = (data['caloriesBurned'] as num?)?.toDouble() ?? 0;

        if (planDayOfWeek.isNotEmpty && result.containsKey(planDayOfWeek)) {
          result[planDayOfWeek] = WeekDayProgress(
            dayOfWeek: planDayOfWeek,
            isPlanned: true,
            isCompleted: true,
            isOnSchedule: isOnSchedule,
            actualDate: actualDate,
            duration: duration,
            calories: calories,
          );
        }
      }

      return result;
    } catch (e) {
      debugPrint('獲取週進度失敗: $e');
      return {};
    }
  }

  // ============================================================
  // 🔥 輔助方法
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 獲取今日星期幾（英文 key）
  static String getTodayKey() {
    final weekday = DateTime.now().weekday;
    const dayKeys = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    return dayKeys[weekday - 1];
  }

  /// 獲取今日星期幾（中文）
  static String getTodayDisplayName() {
    final weekday = DateTime.now().weekday;
    const dayNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return dayNames[weekday - 1];
  }

  /// 星期 key 轉中文
  static String dayKeyToDisplayName(String key) {
    const map = {
      'monday': '週一',
      'tuesday': '週二',
      'wednesday': '週三',
      'thursday': '週四',
      'friday': '週五',
      'saturday': '週六',
      'sunday': '週日',
    };
    return map[key] ?? key;
  }
}

// ============================================================
// 📦 數據模型
// ============================================================

/// 學員進度摘要（教練儀表板用）
class StudentProgressSummary {
  final String traineeId;
  final String traineeName;
  final String goal;
  final int totalPlans;
  final int totalCompletions;
  final double onScheduleRate;
  final int thisWeekCompletions;
  final int thisWeekPlannedDays;
  final double weeklyCompletionRate;
  final bool needsAttention;

  StudentProgressSummary({
    required this.traineeId,
    required this.traineeName,
    required this.goal,
    required this.totalPlans,
    required this.totalCompletions,
    required this.onScheduleRate,
    required this.thisWeekCompletions,
    required this.thisWeekPlannedDays,
    required this.weeklyCompletionRate,
    required this.needsAttention,
  });

  /// 本週進度文字
  String get weeklyProgressText => '$thisWeekCompletions/$thisWeekPlannedDays';

  /// 按時率文字
  String get onScheduleRateText => '${onScheduleRate.round()}%';
}

/// 計畫進度摘要（學員詳情用）
class PlanProgressSummary {
  final String planId;
  final String planName;
  final String status;
  final int totalDays;
  final int totalCompletions;
  final int onScheduleCount;
  final double onScheduleRate;
  final int totalDuration;
  final double totalCalories;
  final Map<String, WeekDayProgress> weeklyProgress;
  final DateTime? startDate;
  final DateTime? endDate;

  PlanProgressSummary({
    required this.planId,
    required this.planName,
    required this.status,
    required this.totalDays,
    required this.totalCompletions,
    required this.onScheduleCount,
    required this.onScheduleRate,
    required this.totalDuration,
    required this.totalCalories,
    required this.weeklyProgress,
    this.startDate,
    this.endDate,
  });

  /// 是否進行中
  bool get isActive => status == 'active';

  /// 按時率文字
  String get onScheduleRateText => '${onScheduleRate.round()}%';

  /// 總時長文字（小時:分鐘）
  String get totalDurationText {
    if (totalDuration < 60) return '$totalDuration 分鐘';
    final hours = totalDuration ~/ 60;
    final mins = totalDuration % 60;
    return '$hours 小時 $mins 分鐘';
  }
}

/// 週進度項目
class WeekDayProgress {
  final String dayOfWeek;
  final bool isPlanned;
  final bool isCompleted;
  final bool isOnSchedule;
  final DateTime? actualDate;
  final int? duration;
  final double? calories;

  WeekDayProgress({
    required this.dayOfWeek,
    required this.isPlanned,
    required this.isCompleted,
    required this.isOnSchedule,
    this.actualDate,
    this.duration,
    this.calories,
  });

  /// 中文顯示
  String get displayName => CoachWorkoutService.dayKeyToDisplayName(dayOfWeek);
}