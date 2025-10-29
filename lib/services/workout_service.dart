// lib/services/workout_service.dart
// 🔧 完整版 - 包含所有統計方法

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 訓練記錄相關 ==========

  // 🔥 記錄訓練 (WorkoutLog 版本)
  Future<void> logWorkout({
    required String exerciseName,
    required int sets,
    required int reps,
    int? duration,
    double? caloriesBurned,
    String? notes,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    WorkoutLog log = WorkoutLog(
      userId: _currentUserId!,
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      duration: duration,
      caloriesBurned: caloriesBurned,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('workoutLogs').add(log.toFirestore());
  }

  // 🔥 添加運動記錄 (WorkoutModel 版本)
  Future<void> addWorkoutLog({
    required String type,
    required String name,
    required int duration,
    double? caloriesBurned,
    int? sets,
    int? reps,
    double? weight,
    double? distance,
    String? intensity,
    String? notes,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    String today = DateTime.now().toIso8601String().split('T')[0];

    WorkoutModel workout = WorkoutModel(
      userId: _currentUserId!,
      date: today,
      type: type,
      name: name,
      duration: duration,
      caloriesBurned: caloriesBurned,
      sets: sets,
      reps: reps,
      weight: weight,
      distance: distance,
      intensity: intensity,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('workoutLogs').add(workout.toFirestore());
    await _updateDailySummary(today, duration, caloriesBurned ?? 0);
  }

  // 🔥 更新每日運動總計
  Future<void> _updateDailySummary(String date, int duration, double calories) async {
    DocumentReference summaryRef = _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('workoutSummary')
        .doc(date);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(summaryRef);

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        transaction.update(summaryRef, {
          'totalDuration': (data['totalDuration'] ?? 0) + duration,
          'totalCalories': (data['totalCalories'] ?? 0) + calories,
          'workoutCount': (data['workoutCount'] ?? 0) + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(summaryRef, {
          'date': date,
          'totalDuration': duration,
          'totalCalories': calories,
          'workoutCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // 🔥 獲取今日訓練記錄 (WorkoutLog 版本)
  Future<List<WorkoutLog>> getTodayWorkouts() async {
    if (_currentUserId == null) return [];

    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: _currentUserId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutLog.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 獲取今日訓練記錄 (WorkoutModel 版本)
  Future<List<WorkoutModel>> getTodayWorkoutModels() async {
    if (_currentUserId == null) return [];

    String today = DateTime.now().toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: _currentUserId)
        .where('date', isEqualTo: today)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 獲取今日運動統計
  Future<Map<String, dynamic>> getTodayWorkoutSummary() async {
    if (_currentUserId == null) {
      return {
        'totalDuration': 0,
        'totalCalories': 0.0,
        'workoutCount': 0,
      };
    }

    String today = DateTime.now().toIso8601String().split('T')[0];

    try {
      DocumentSnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workoutSummary')
          .doc(today)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        return {
          'totalDuration': data['totalDuration'] ?? 0,
          'totalCalories': (data['totalCalories'] ?? 0).toDouble(),
          'workoutCount': data['workoutCount'] ?? 0,
        };
      }
    } catch (e) {
      print('獲取今日運動統計失敗: $e');
    }

    return {
      'totalDuration': 0,
      'totalCalories': 0.0,
      'workoutCount': 0,
    };
  }

  // 🔥 新增：獲取本週運動統計
  Future<Map<String, dynamic>> getWeeklyWorkoutStats() async {
    if (_currentUserId == null) {
      return {
        'daysCompleted': 0,
        'totalDays': 7,
        'avgCalories': 0.0,
        'avgWater': 0.0,
        'workoutDays': 0,
      };
    }

    try {
      // 計算本週的開始和結束日期
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 7));

      String startDate = startOfWeek.toIso8601String().split('T')[0];
      String endDate = endOfWeek.toIso8601String().split('T')[0];

      // 查詢本週的運動統計
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workoutSummary')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThan: endDate)
          .get();

      int workoutDays = snapshot.docs.length;
      double totalCalories = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalCalories += (data['totalCalories'] ?? 0).toDouble();
      }

      double avgCalories = workoutDays > 0 ? totalCalories / workoutDays : 0;

      return {
        'daysCompleted': workoutDays,
        'totalDays': 7,
        'avgCalories': avgCalories,
        'avgWater': 0.0, // 如果有喝水記錄可以在這裡計算
        'workoutDays': workoutDays,
      };
    } catch (e) {
      print('獲取本週運動統計失敗: $e');
      return {
        'daysCompleted': 0,
        'totalDays': 7,
        'avgCalories': 0.0,
        'avgWater': 0.0,
        'workoutDays': 0,
      };
    }
  }

  // 🔥 獲取歷史訓練記錄
  Future<List<WorkoutLog>> getWorkoutHistory({int days = 30}) async {
    if (_currentUserId == null) return [];

    DateTime startDate = DateTime.now().subtract(Duration(days: days));

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: _currentUserId)
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutLog.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 獲取訓練統計
  Future<Map<String, dynamic>> getWorkoutStats({int days = 30}) async {
    if (_currentUserId == null) {
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0,
      };
    }

    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: days));
    String startDateStr = startDate.toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('workoutSummary')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .get();

    int workoutDays = snapshot.docs.length;
    int totalDuration = 0;
    double totalCalories = 0;

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      totalDuration += (data['totalDuration'] ?? 0) as int;
      totalCalories += (data['totalCalories'] ?? 0).toDouble();
    }

    return {
      'workoutDays': workoutDays,
      'totalDuration': totalDuration,
      'totalCalories': totalCalories,
    };
  }

  // 🔥 刪除運動記錄
  Future<void> deleteWorkoutLog(String workoutId) async {
    await _firestore.collection('workoutLogs').doc(workoutId).delete();
  }

  // ========== 訓練計畫相關 ==========

  // 🔥 創建訓練計畫（舊版 - 單一學員）
  @Deprecated('使用 createTemplatePlan 和 assignWorkoutPlanToStudents 代替')
  Future<void> createWorkoutPlan({
    required String traineeId,
    required String planName,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required List<WorkoutPlanDay> days,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    WorkoutPlanModel plan = WorkoutPlanModel(
      coachId: _currentUserId!,
      traineeId: traineeId,
      planName: planName,
      description: description,
      startDate: startDate,
      endDate: endDate,
      days: days,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('workoutPlans').add(plan.toFirestore());
  }

  // 🔥 創建模板計畫
  Future<String> createTemplatePlan({
    required String planName,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required List<WorkoutPlanDay> days,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    WorkoutPlanModel plan = WorkoutPlanModel(
      coachId: _currentUserId!,
      traineeId: _currentUserId!,
      planName: planName,
      description: description,
      startDate: startDate,
      endDate: endDate,
      days: days,
      createdAt: DateTime.now(),
      status: 'template',
    );

    final docRef = await _firestore.collection('workoutPlans').add(plan.toFirestore());
    return docRef.id;
  }

  // 🔥 批次分配給多位學員
  Future<void> assignWorkoutPlanToStudents(
    String planId,
    List<String> studentIds,
  ) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    final planDoc = await _firestore.collection('workoutPlans').doc(planId).get();
    if (!planDoc.exists) {
      throw Exception('找不到原始訓練計畫');
    }
    final originalPlanData = planDoc.data() as Map<String, dynamic>;

    WriteBatch batch = _firestore.batch();

    for (String studentId in studentIds) {
      final newPlanData = Map<String, dynamic>.from(originalPlanData);
      newPlanData['traineeId'] = studentId;
      newPlanData['originalPlanId'] = planId;
      newPlanData['status'] = 'active';
      newPlanData['createdAt'] = FieldValue.serverTimestamp();

      final newPlanRef = _firestore.collection('workoutPlans').doc();
      batch.set(newPlanRef, newPlanData);
    }

    await batch.commit();
  }

  // 🔥 獲取學員的訓練計畫
  Future<List<WorkoutPlanModel>> getMyWorkoutPlans() async {
    if (_currentUserId == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('workoutPlans')
        .where('traineeId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutPlanModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 獲取教練創建的所有計畫
  Future<List<WorkoutPlanModel>> getCoachPlans() async {
    if (_currentUserId == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('workoutPlans')
        .where('coachId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutPlanModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 獲取特定學員的訓練計畫
  Future<List<WorkoutPlanModel>> getStudentPlans(String studentId) async {
    if (_currentUserId == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('workoutPlans')
        .where('traineeId', isEqualTo: studentId)
        .where('coachId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutPlanModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // 🔥 標記訓練為完成
  Future<void> markPlanAsCompleted(String planId) async {
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🔥 刪除訓練計畫
  Future<void> deleteWorkoutPlan(String planId) async {
    await _firestore.collection('workoutPlans').doc(planId).delete();
  }

  // 🔥 更新訓練計畫
  Future<void> updateWorkoutPlan({
    required String planId,
    String? planName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<WorkoutPlanDay>? days,
  }) async {
    Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (planName != null) updates['planName'] = planName;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = startDate;
    if (endDate != null) updates['endDate'] = endDate;
    if (days != null) {
      updates['days'] = days.map((day) => day.toFirestore()).toList();
    }

    await _firestore.collection('workoutPlans').doc(planId).update(updates);
  }
}