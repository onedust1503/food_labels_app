// lib/services/workout_service.dart
// 🔥 修正版 - 統一訓練記錄 + 詳細組數資訊

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

  Future<Map<String, dynamic>> getWeeklySummary() async {
    return await getWeeklyWorkoutStats();
  }

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

  // ========== 自由訓練（AdHoc Session）相關 ==========

  /// 🔥 開始自由訓練會話
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

  /// 🔥 完成自由訓練會話 - ✅ 創建一筆統一記錄
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

    // 1. 標記 session 為已完成
    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
      if (calories != null) 'calories': calories,
    });

    final sessionSnap = await sessionRef.get();
    final sessionData = sessionSnap.data();
    if (sessionData == null) {
      print('⚠️ Session 資料不存在');
      return;
    }

    final startedAt = (sessionData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endedAt = (sessionData['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = startedAt.toIso8601String().split('T')[0];
    
    // 計算總時長(分鐘)
    final totalDurationMin = endedAt.difference(startedAt).inMinutes.clamp(1, 300);

    // 2. 獲取所有動作的詳細資訊
    final exercisesSnap = await sessionRef.collection('exercises').get();
    
    if (exercisesSnap.docs.isEmpty) {
      print('⚠️ 沒有任何動作記錄');
      return;
    }

    // 收集所有動作的組數詳情
    List<Map<String, dynamic>> exerciseDetails = [];
    int totalCompletedSets = 0;
    double estimatedCalories = 0;

    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      
      // 獲取該動作的所有組數
      final setsSnap = await exDoc.reference.collection('sets').get();
      
      if (setsSnap.docs.isEmpty) continue;

      List<Map<String, dynamic>> setsInfo = [];
      int completedSets = 0;
      
      for (final setDoc in setsSnap.docs) {
        final setData = setDoc.data();
        final status = setData['status'] as String?;
        
        // 只記錄已完成或休息中的組
        if (status == 'completed' || status == 'resting') {
          completedSets++;
          setsInfo.add({
            'setIndex': setData['index'],
            'reps': setData['actualReps'],
            'weight': setData['weight'],
            'durationSec': setData['actualDurationSec'],
            'rpe': setData['rpe'],
            'note': setData['note'],
          });
        }
      }

      if (completedSets > 0) {
        totalCompletedSets += completedSets;
        estimatedCalories += completedSets * 12.0; // 每組約12卡
        
        exerciseDetails.add({
          'name': exerciseName,
          'completedSets': completedSets,
          'sets': setsInfo,
          'category': exData['category'] ?? '未分類',
        });
      }
    }

    if (exerciseDetails.isEmpty) {
      print('⚠️ 沒有完成任何組數');
      return;
    }

    // 3. 🎯 創建一筆統一的 workoutLog
    final logRef = _firestore.collection('workoutLogs').doc();
    await logRef.set({
      'userId': uid,
      'date': dateStr,
      'type': 'weight_training',
      'name': '自由訓練', // 統一名稱
      'duration': totalDurationMin,
      'caloriesBurned': calories ?? estimatedCalories,
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'intensity': 'medium',
      'notes': '自由訓練 - ${exerciseDetails.length} 個動作',
      'sessionId': sessionId, // 🔥 關鍵：保留 sessionId 用於查詢詳情
      'createdAt': FieldValue.serverTimestamp(),
      
      // 🔥 新增：儲存動作摘要(用於列表顯示)
      'exerciseSummary': exerciseDetails.map((ex) => {
        'name': ex['name'],
        'sets': ex['completedSets'],
      }).toList(),
    });

    // 4. 更新每日統計
    await _updateDailySummary(dateStr, totalDurationMin, calories ?? estimatedCalories);

    print('✅ Ad-hoc session 完成: $sessionId');
    print('   總時長: $totalDurationMin 分鐘');
    print('   總卡路里: ${(calories ?? estimatedCalories).toStringAsFixed(1)}');
    print('   總組數: $totalCompletedSets');
    print('   動作數: ${exerciseDetails.length}');
  }

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

  // 🔥 新增：獲取訓練詳情(包含所有組數)
  Future<Map<String, dynamic>?> getWorkoutSessionDetails(String sessionId) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);
    
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) return null;
    
    final sessionData = sessionSnap.data()!;
    
    // 獲取所有動作
    final exercisesSnap = await sessionRef.collection('exercises').get();
    List<Map<String, dynamic>> exercises = [];
    
    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      
      // 獲取所有組數
      final setsSnap = await exDoc.reference.collection('sets').orderBy('index').get();
      List<Map<String, dynamic>> sets = setsSnap.docs
          .map((setDoc) => setDoc.data())
          .toList();
      
      exercises.add({
        'name': exData['exerciseName'],
        'type': exData['type'],
        'category': exData['category'],
        'sets': sets,
      });
    }
    
    return {
      'sessionId': sessionId,
      'startedAt': sessionData['startedAt'],
      'endedAt': sessionData['endedAt'],
      'totalRestSec': sessionData['totalRestSec'],
      'exercises': exercises,
    };
  }

  Stream<DocumentSnapshot> watchSession(String sessionId) {
    final uid = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .snapshots();
  }

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