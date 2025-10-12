// lib/services/workout_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 運動記錄相關 ==========

  // 🔥 添加運動記錄
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

    // 更新當日總計
    await _updateDailySummary(today, duration, caloriesBurned ?? 0);
  }

  // 更新每日運動總計
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
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // 🔥 獲取今日運動記錄 - 修正排序
  Future<List<WorkoutModel>> getTodayWorkouts() async {
    if (_currentUserId == null) return [];

    String today = DateTime.now().toIso8601String().split('T')[0];

    // ✅ 修正：改用 date 排序，不用 createdAt
    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: _currentUserId)
        .where('date', isEqualTo: today)
        .orderBy('date', descending: true)  // ✅ 改用 date
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
      return {'totalDuration': 0, 'totalCalories': 0.0, 'workoutCount': 0};
    }

    String today = DateTime.now().toIso8601String().split('T')[0];

    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('workoutSummary')
        .doc(today)
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }

    return {'totalDuration': 0, 'totalCalories': 0.0, 'workoutCount': 0};
  }

  // 🔥 獲取本週運動統計
  Future<Map<String, dynamic>> getWeeklyWorkoutStats() async {
    if (_currentUserId == null) {
      return {'workoutDays': 0, 'totalDuration': 0, 'totalCalories': 0.0};
    }

    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    String startDate = weekStart.toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('workoutSummary')
        .where('date', isGreaterThanOrEqualTo: startDate)
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
    // TODO: 更新當日統計（減少對應的時長和卡路里）
  }

  // ========== 訓練計畫相關 ==========

  // 🔥 創建訓練計畫（教練端）
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

  // 🔥 獲取學員的訓練計畫（學員端）
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

  // 🔥 獲取教練創建的所有計畫（教練端）
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

  // 🔥 標記訓練為完成
  Future<void> markPlanAsCompleted(String planId) async {
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}