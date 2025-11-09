// lib/services/workout_service.dart
// 🔧 最終修正版 - 移除 WorkoutLog，只使用 WorkoutModel

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';

class WorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ========== 運動記錄相關 ==========

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
          'date': date,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(summaryRef, {
          'totalDuration': duration,
          'totalCalories': calories,
          'workoutCount': 1,
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // 🔥 獲取今日訓練記錄
  Future<List<WorkoutModel>> getTodayWorkouts() async {
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

  // ========== 統計數據相關 ==========

  // 🔥 獲取本週運動統計（兼容 trainee_home_page.dart 的調用）
  Future<Map<String, dynamic>> getWeeklyWorkoutStats() async {
    if (_currentUserId == null) {
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0.0,
      };
    }

    try {
      DateTime now = DateTime.now();
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      String startDate = startOfWeek.toIso8601String().split('T')[0];

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
    } catch (e) {
      print('獲取本週運動統計失敗: $e');
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0.0,
      };
    }
  }

  // 🔥 獲取本週運動統計（別名，保持兼容性）
  Future<Map<String, dynamic>> getWeeklySummary() async {
    return await getWeeklyWorkoutStats();
  }

  // 🔥 獲取歷史訓練記錄
  Future<List<WorkoutModel>> getWorkoutHistory({int days = 30}) async {
    if (_currentUserId == null) return [];

    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: days));
    String startDateStr = startDate.toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: _currentUserId)
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .orderBy('date', descending: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => WorkoutModel.fromFirestore(
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

  Future<void> markPlanAsCompleted(String planId) async {
    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ========== 自訓練（AdHoc Session）相關 ==========

  /// 🔥 開始自訓練會話
  Future<String> startAdHocSession({
    required List<Map<String, dynamic>> exercises,
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc();

    await sessionRef.set({
      'userId': uid,
      'source': 'self',
      'planId': null,
      'startedAt': FieldValue.serverTimestamp(),
      'totalActiveSec': 0,
      'totalRestSec': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 初始化每個動作和組數
    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final exRef = sessionRef.collection('exercises').doc('ex$i');
      final plannedSets = (ex['plannedSets'] ?? 1) as int;

      await exRef.set({
        'exerciseName': ex['name'],
        'type': ex['type'] ?? 'reps',
        'plannedSets': plannedSets,
        'plannedReps': ex['plannedReps'],
        'plannedDurationSec': ex['plannedDurationSec'],
        'restSec': ex['restSec'] ?? 90,
        'currentSetIndex': 0,
      });

      // 初始化所有組為 pending 狀態
      for (int s = 0; s < plannedSets; s++) {
        await exRef.collection('sets').doc('$s').set({
          'index': s,
          'status': 'pending',
          'targetReps': ex['plannedReps'],
          'targetDurationSec': ex['plannedDurationSec'],
          'restPlannedSec': ex['restSec'] ?? 90,
        });
      }
    }

    return sessionRef.id;
  }

  /// 🔥 開始某一組
  Future<void> adHocStartSet(
    String sessionId,
    String exerciseDocId,
    int setIndex,
  ) async {
    final uid = _currentUserId!;
    final setRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId)
        .collection('sets')
        .doc('$setIndex');

    await setRef.update({
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔥 完成某一組（立刻進入休息狀態）
  Future<void> adHocCompleteSet({
    required String sessionId,
    required String exerciseDocId,
    required int setIndex,
    int? reps,
    double? weight,
    int? durationSec,
    double? rpe,
    String? note,
  }) async {
    final uid = _currentUserId!;
    final setRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId)
        .collection('sets')
        .doc('$setIndex');

    await setRef.update({
      'status': 'resting',
      'completedAt': FieldValue.serverTimestamp(),
      if (reps != null) 'actualReps': reps,
      if (weight != null) 'weight': weight,
      if (durationSec != null) 'actualDurationSec': durationSec,
      if (rpe != null) 'rpe': rpe,
      if (note != null) 'note': note,
    });
  }

  /// 🔥 結束休息
  Future<void> adHocEndRest({
    required String sessionId,
    required String exerciseDocId,
    required int setIndex,
    required int restTakenSec,
  }) async {
    final uid = _currentUserId!;
    final exRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId);

    final setRef = exRef.collection('sets').doc('$setIndex');

    await setRef.update({'restTakenSec': restTakenSec});

    final exSnap = await exRef.get();
    final totalSets = (exSnap.data()?['plannedSets'] ?? 0) as int;
    final next = setIndex + 1;

    await exRef.update({
      'currentSetIndex': next < totalSets ? next : setIndex,
    });

    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    await sessionRef.update({
      'totalRestSec': FieldValue.increment(restTakenSec),
    });
  }

  /// 🔥 完成自訓練會話
  Future<void> finishAdHocSession({
    required String sessionId,
    int? sessionRpe,
    double? calories,
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
      if (calories != null) 'calories': calories,
    });

    final snap = await sessionRef.get();
    final startedAt =
        (snap.data()?['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    await _firestore.collection('workoutLogs').add({
      'type': 'self_workout',
      'name': '自選訓練',
      'duration': ((snap.data()?['totalActiveSec'] ?? 0) as int) ~/ 60,
      'caloriesBurned': calories,
      'userId': uid,
      'date': Timestamp.fromDate(startedAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔥 略過某一組
  Future<void> adHocSkipSet({
    required String sessionId,
    required String exerciseDocId,
    required int setIndex,
  }) async {
    final uid = _currentUserId!;
    final setRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId)
        .collection('sets')
        .doc('$setIndex');

    await setRef.update({
      'status': 'skipped',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔥 新增組數
  Future<void> adHocAddSet({
    required String sessionId,
    required String exerciseDocId,
    required int targetReps,
    int? targetDurationSec,
  }) async {
    final uid = _currentUserId!;
    final exRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId);

    final exSnap = await exRef.get();
    final planned = (exSnap.data()?['plannedSets'] ?? 0) as int;
    final newIndex = planned;

    await exRef.update({'plannedSets': planned + 1});

    await exRef.collection('sets').doc('$newIndex').set({
      'index': newIndex,
      'status': 'pending',
      'targetReps': targetReps,
      'targetDurationSec': targetDurationSec,
      'restPlannedSec': exSnap.data()?['restSec'] ?? 90,
    });
  }

  /// 🔥 獲取會話實時數據
  Stream<DocumentSnapshot> watchSession(String sessionId) {
    final uid = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .snapshots();
  }

  /// 🔥 獲取動作實時數據
  Stream<DocumentSnapshot> watchExercise(String sessionId, String exerciseDocId) {
    final uid = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId)
        .snapshots();
  }

  /// 🔥 獲取所有組數實時數據
  Stream<QuerySnapshot> watchSets(String sessionId, String exerciseDocId) {
    final uid = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .collection('exercises')
        .doc(exerciseDocId)
        .collection('sets')
        .orderBy('index')
        .snapshots();
  }
}