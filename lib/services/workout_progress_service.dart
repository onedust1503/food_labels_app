// lib/services/workout_progress_service.dart
// ✅ 修正版 - 從 workoutLogs 讀取 planId 計算完成天數
// 🔧 關鍵修正：getCompletedDays 改為查詢 workoutLogs 而非 workoutCompletions
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';

/// 訓練進度追蹤服務
/// 負責記錄和計算訓練計畫的完成進度
class WorkoutProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// 📊 計算訓練計畫的總天數
  /// 根據日期範圍和每週訓練天數計算
  int calculateTotalDays(WorkoutPlanModel plan) {
    if (plan.endDate == null) {
      // 如果沒有結束日期,返回每週的訓練天數
      return plan.days.length;
    }

    // 計算日期範圍的天數
    final daysDifference = plan.endDate!.difference(plan.startDate).inDays + 1;
    
    // 計算有多少週
    final weeks = (daysDifference / 7).ceil();
    
    // 計算總訓練天數
    final totalDays = weeks * plan.days.length;
    
    return totalDays;
  }

  /// 📝 記錄訓練完成
  /// 當用戶完成一天的訓練時調用
  /// ✅ 簡化版：減少查詢條件，降低索引需求
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

    // ✅ 簡化查詢：只用 3 個條件（減少索引複雜度）
    // 移除了日期範圍的 where 條件，改在代碼中過濾
    final existingRecords = await _firestore
        .collection('workoutCompletions')
        .where('planId', isEqualTo: planId)
        .where('userId', isEqualTo: _currentUserId)
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .get();

    // ✅ 在代碼中過濾今天的記錄（避免複雜的日期範圍查詢）
    final todayRecords = existingRecords.docs.where((doc) {
      final data = doc.data();
      final completionDate = (data['completionDate'] as Timestamp).toDate();
      return completionDate.year == dateOnly.year &&
             completionDate.month == dateOnly.month &&
             completionDate.day == dateOnly.day;
    }).toList();

    if (todayRecords.isNotEmpty) {
      // 如果已經記錄過，更新記錄
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
    } else {
      // 如果沒有記錄，創建新記錄
      final completion = WorkoutCompletionRecord(
        planId: planId,
        userId: _currentUserId!,
        completionDate: dateOnly,
        dayOfWeek: dayOfWeek,
        exercisesCompleted: exercisesCompleted,
        totalExercises: totalExercises,
        totalDuration: totalDuration,
        notes: notes,
        createdAt: now,
      );

      await _firestore
          .collection('workoutCompletions')
          .add(completion.toFirestore());
    }
  }

  /// 📈 獲取訓練計畫的完成天數
  /// 返回該計畫已完成的訓練天數
  /// 🔥 關鍵修正：從 workoutLogs 讀取（與 workout_plan_execution_page 保存位置一致）
  Future<int> getCompletedDays(String planId) async {
    if (_currentUserId == null) return 0;

    try {
      // ✅ 優先從 workoutLogs 讀取（主要資料來源）
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      if (kDebugMode) {
        debugPrint('📊 計畫進度查詢: planId=$planId');
        debugPrint('   workoutLogs 找到 ${logsSnapshot.docs.length} 筆');
      }

      if (logsSnapshot.docs.isNotEmpty) {
        return logsSnapshot.docs.length;
      }

      // 🔄 備用：如果 workoutLogs 沒有，檢查 workoutCompletions（舊資料相容）
      final completionsSnapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      if (kDebugMode) {
        debugPrint('   workoutCompletions 找到 ${completionsSnapshot.docs.length} 筆');
      }

      return completionsSnapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫進度失敗: $e');
      }
      return 0;
    }
  }

  /// 📊 獲取每週完成狀態
  /// 返回 Map<星期幾, 完成次數>
  /// 🔥 修正：同時從 workoutLogs 和 workoutCompletions 讀取
  Future<Map<String, int>> getWeeklyCompletion(String planId) async {
    if (_currentUserId == null) return {};

    final Map<String, int> weeklyCompletion = {};

    try {
      // ✅ 從 workoutLogs 讀取（主要來源）
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        // 從訓練名稱中提取星期幾（格式：planName - dayOfWeek）
        final name = data['name'] as String? ?? '';
        final parts = name.split(' - ');
        if (parts.length >= 2) {
          final dayOfWeek = parts.last.trim().toLowerCase();
          weeklyCompletion[dayOfWeek] = (weeklyCompletion[dayOfWeek] ?? 0) + 1;
        }
      }

      // 🔄 備用：從 workoutCompletions 讀取（舊資料）
      if (weeklyCompletion.isEmpty) {
        final completionsSnapshot = await _firestore
            .collection('workoutCompletions')
            .where('planId', isEqualTo: planId)
            .where('userId', isEqualTo: _currentUserId)
            .get();

        for (var doc in completionsSnapshot.docs) {
          final data = doc.data();
          final dayOfWeek = data['dayOfWeek'] as String;
          weeklyCompletion[dayOfWeek] = (weeklyCompletion[dayOfWeek] ?? 0) + 1;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取每週完成狀態失敗: $e');
      }
    }

    return weeklyCompletion;
  }

  /// 🗓️ 檢查今天是否已完成訓練
  /// 檢查特定計畫和星期幾的訓練是否已完成
  /// 🔥 修正：從 workoutLogs 讀取
  Future<bool> isCompletedToday(String planId, String dayOfWeek) async {
    if (_currentUserId == null) return false;

    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];

    try {
      // ✅ 從 workoutLogs 檢查今日記錄
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isEqualTo: today)
          .get();

      if (logsSnapshot.docs.isNotEmpty) {
        return true;
      }

      // 🔄 備用：從 workoutCompletions 檢查
      final completionsSnapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .get();

      // 在代碼中過濾今天的記錄
      final todayRecords = completionsSnapshot.docs.where((doc) {
        final data = doc.data();
        final completionDate = (data['completionDate'] as Timestamp).toDate();
        return completionDate.year == now.year &&
               completionDate.month == now.month &&
               completionDate.day == now.day;
      });

      return todayRecords.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 檢查今日完成狀態失敗: $e');
      }
      return false;
    }
  }

  /// 📅 獲取計畫的所有完成記錄
  /// 返回按日期排序的完成記錄列表
  Future<List<WorkoutCompletionRecord>> getCompletionHistory(
      String planId) async {
    if (_currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('workoutCompletions')
        .where('planId', isEqualTo: planId)
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('completionDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutCompletionRecord.fromFirestore(
              doc.data(),
              doc.id,
            ))
        .toList();
  }

  /// 🎯 計算完成進度百分比
  /// 返回 0.0 - 1.0 之間的值
  Future<double> getCompletionProgress(WorkoutPlanModel plan) async {
    if (plan.id == null) return 0.0;

    final totalDays = calculateTotalDays(plan);
    if (totalDays == 0) return 0.0;

    final completedDays = await getCompletedDays(plan.id!);

    return completedDays / totalDays;
  }

  /// 📊 獲取訓練統計
  /// 返回該計畫的詳細統計信息
  /// 🔥 修正：從 workoutLogs 讀取統計
  Future<Map<String, dynamic>> getWorkoutStats(String planId) async {
    if (_currentUserId == null) {
      return {
        'totalCompletions': 0,
        'totalExercises': 0,
        'totalDuration': 0,
        'averageDuration': 0,
      };
    }

    try {
      // ✅ 從 workoutLogs 讀取統計
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      int totalCompletions = logsSnapshot.docs.length;
      int totalExercises = 0;
      int totalDuration = 0;

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        totalExercises += (data['totalExercises'] ?? 1) as int;
        totalDuration += (data['duration'] ?? 0) as int;
      }

      // 如果 workoutLogs 沒有資料，嘗試從 workoutCompletions 讀取
      if (totalCompletions == 0) {
        final completionsSnapshot = await _firestore
            .collection('workoutCompletions')
            .where('planId', isEqualTo: planId)
            .where('userId', isEqualTo: _currentUserId)
            .get();

        totalCompletions = completionsSnapshot.docs.length;

        for (var doc in completionsSnapshot.docs) {
          final data = doc.data();
          totalExercises += (data['exercisesCompleted'] ?? 0) as int;
          totalDuration += (data['totalDuration'] ?? 0) as int;
        }
      }

      return {
        'totalCompletions': totalCompletions,
        'totalExercises': totalExercises,
        'totalDuration': totalDuration,
        'averageDuration':
            totalCompletions > 0 ? (totalDuration / totalCompletions).round() : 0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取訓練統計失敗: $e');
      }
      return {
        'totalCompletions': 0,
        'totalExercises': 0,
        'totalDuration': 0,
        'averageDuration': 0,
      };
    }
  }

  /// 🔥 刪除完成記錄
  /// 用於取消某次訓練的完成狀態
  Future<void> deleteCompletionRecord(String recordId) async {
    await _firestore.collection('workoutCompletions').doc(recordId).delete();
  }

  /// 📆 獲取特定日期範圍的完成記錄
  /// ✅ 新增方法：用於更靈活的查詢
  Future<List<WorkoutCompletionRecord>> getCompletionsByDateRange({
    required String planId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_currentUserId == null) return [];

    final snapshot = await _firestore
        .collection('workoutCompletions')
        .where('planId', isEqualTo: planId)
        .where('userId', isEqualTo: _currentUserId)
        .get();

    // 在代碼中過濾日期範圍
    final filtered = snapshot.docs.where((doc) {
      final data = doc.data();
      final completionDate = (data['completionDate'] as Timestamp).toDate();
      return completionDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             completionDate.isBefore(endDate.add(const Duration(days: 1)));
    }).map((doc) => WorkoutCompletionRecord.fromFirestore(
          doc.data(),
          doc.id,
        )).toList();

    // 按日期排序
    filtered.sort((a, b) => b.completionDate.compareTo(a.completionDate));

    return filtered;
  }
}

/// 訓練完成記錄模型
class WorkoutCompletionRecord {
  final String? id;
  final String planId; // 所屬訓練計畫 ID
  final String userId; // 用戶 ID
  final DateTime completionDate; // 完成日期
  final String dayOfWeek; // 星期幾 (monday, tuesday, etc.)
  final int exercisesCompleted; // 完成的運動數量
  final int totalExercises; // 總運動數量
  final int totalDuration; // 總時長（分鐘）
  final String? notes; // 備註
  final DateTime createdAt;

  WorkoutCompletionRecord({
    this.id,
    required this.planId,
    required this.userId,
    required this.completionDate,
    required this.dayOfWeek,
    required this.exercisesCompleted,
    required this.totalExercises,
    required this.totalDuration,
    this.notes,
    required this.createdAt,
  });

  factory WorkoutCompletionRecord.fromFirestore(
    Map<String, dynamic> data,
    String docId,
  ) {
    return WorkoutCompletionRecord(
      id: docId,
      planId: data['planId'] ?? '',
      userId: data['userId'] ?? '',
      completionDate: (data['completionDate'] as Timestamp).toDate(),
      dayOfWeek: data['dayOfWeek'] ?? '',
      exercisesCompleted: data['exercisesCompleted'] ?? 0,
      totalExercises: data['totalExercises'] ?? 0,
      totalDuration: data['totalDuration'] ?? 0,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'planId': planId,
      'userId': userId,
      'completionDate': Timestamp.fromDate(completionDate),
      'dayOfWeek': dayOfWeek,
      'exercisesCompleted': exercisesCompleted,
      'totalExercises': totalExercises,
      'totalDuration': totalDuration,
      if (notes != null) 'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}