// lib/services/unified_workout_service.dart
// 🔧 統一訓練記錄服務 - 重構版 v7.1
// ✅ v7.1 新增：getAllMyPlans() 獲取所有計畫（含已結束）
// ✅ v7.1 新增：getMyEndedPlans() 獲取已結束計畫
// ✅ 使用統一的 WorkoutDateHelper（刪除重複的日期處理邏輯）
// ✅ 修復 startPlanSession 重複建立 sets 問題
// ✅ 保留所有原有功能
// ✅ 精確卡路里計算（基於 Compendium of Physical Activities 2024 MET 值）
// ✅ 訓練命名功能、動作追蹤、混合模式進度追蹤

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';
import '../models/completion_status.dart';
import '../utils/workout_date_helper.dart';

class UnifiedWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 精確卡路里計算系統（基於 Compendium of Physical Activities 2024）
  // ============================================================

  /// 預設體重 (kg)
  static const double _defaultBodyWeight = 65.0;

  /// MET 值對照表 - 依動作類型
  static const Map<String, double> _exerciseMets = {
    // 複合動作 - 高 MET
    '深蹲': 7.0, 'squat': 7.0,
    '硬舉': 7.5, 'deadlift': 7.5,
    '臥推': 5.5, 'bench press': 5.5, 'bench': 5.5,
    '上斜': 5.5, 'incline': 5.5,
    '下斜': 5.5, 'decline': 5.5,
    '划船': 6.0, 'row': 6.0,
    '肩推': 5.5, 'shoulder press': 5.5, 'press': 5.5,
    '引體向上': 6.5, 'pull up': 6.5, 'pullup': 6.5, 'chin up': 6.5,
    '下拉': 5.5, 'lat pulldown': 5.5, 'pulldown': 5.5,
    '弓步': 6.5, 'lunge': 6.5,
    '腿推': 6.0, 'leg press': 6.0,

    // 孤立動作 - 中等 MET
    '彎舉': 4.0, 'curl': 4.0, 'bicep': 4.0,
    '三頭': 4.0, 'tricep': 4.0,
    '飛鳥': 4.5, 'fly': 4.5, 'flye': 4.5,
    '側平舉': 4.0, 'lateral': 4.0, 'raise': 4.0,
    '腿彎': 5.0, 'leg curl': 5.0, 'hamstring': 5.0,
    '腿伸': 5.0, 'leg extension': 5.0, 'quad': 5.0,
    '小腿': 4.0, 'calf': 4.0,
    '夾胸': 4.5, 'pec': 4.5,

    // 核心訓練
    '捲腹': 4.0, 'crunch': 4.0, 'ab': 4.0,
    '平板': 4.0, 'plank': 4.0,
    '仰臥起坐': 4.5, 'sit up': 4.5,

    // 徒手訓練
    '伏地挺身': 5.5, 'push up': 5.5, 'pushup': 5.5,
    '撐體': 5.0, 'dip': 5.0,

    // 有氧
    '跑步': 9.0, 'running': 9.0, 'run': 9.0,
    '跳繩': 12.3, 'jump rope': 12.3, 'rope': 12.3,
    '踩腳踏車': 7.0, 'cycling': 7.0, 'bike': 7.0,
    '橢圓機': 6.0, 'elliptical': 6.0,
    '划船機': 7.0, 'rowing': 7.0,
  };

  /// MET 值對照表 - 依肌群分類
  static const Map<String, double> _categoryMets = {
    '腿部': 6.5, '腿': 6.5, 'legs': 6.5, 'leg': 6.5,
    '背部': 6.0, '背': 6.0, 'back': 6.0,
    '胸部': 5.5, '胸': 5.5, 'chest': 5.5,
    '肩部': 5.0, '肩': 5.0, 'shoulders': 5.0, 'shoulder': 5.0,
    '核心': 4.5, 'core': 4.5, 'abs': 4.5,
    '手臂': 4.0, 'arms': 4.0, 'arm': 4.0,
    '二頭': 4.0, 'biceps': 4.0,
    '三頭': 4.0, 'triceps': 4.0,
    '有氧': 7.0, 'cardio': 7.0,
    '全身': 6.0, 'full body': 6.0,
  };

  // ============================================================
  // 🔥 卡路里計算方法
  // ============================================================

  /// 🔥 獲取動作的 MET 值
  double _getMetForExercise(String exerciseName, String? category) {
    final nameLower = exerciseName.toLowerCase();

    // 1. 先檢查特定動作名稱
    for (var entry in _exerciseMets.entries) {
      if (nameLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // 2. 檢查肌群分類
    if (category != null) {
      final catLower = category.toLowerCase();
      for (var entry in _categoryMets.entries) {
        if (catLower.contains(entry.key.toLowerCase())) {
          return entry.value;
        }
      }
    }

    // 3. 預設值（中等強度重訓）
    return 5.0;
  }

  /// 🔥 根據重量調整 MET 值
  double _adjustMetForWeight(double baseMet, double weight, double bodyWeight) {
    double relativeWeight = weight / bodyWeight;

    if (relativeWeight >= 0.8) {
      return baseMet * 1.3;
    } else if (relativeWeight >= 0.5) {
      return baseMet * 1.2;
    } else if (relativeWeight >= 0.3) {
      return baseMet * 1.1;
    }
    return baseMet;
  }

  /// 🔥 計算單組卡路里（精確版）
  double calculateSetCaloriesAccurate({
    required String exerciseName,
    String? category,
    required int reps,
    required double weight,
    required int durationSeconds,
    double? bodyWeight,
  }) {
    final userWeight = bodyWeight ?? _defaultBodyWeight;

    double met = _getMetForExercise(exerciseName, category);

    if (weight > 0) {
      met = _adjustMetForWeight(met, weight, userWeight);
    }

    double minutes = durationSeconds / 60.0;
    double calories = (met * 3.5 * userWeight) / 200 * minutes;

    return calories < 1.0 ? 1.0 : calories;
  }

  /// 🔧 簡易卡路里計算（用於非 session 的記錄）
  double _calculateCalories(String type, int duration, double? weight) {
    double met = 5.0;

    switch (type.toLowerCase()) {
      case 'weight_training':
      case '重量訓練':
        met = 5.0;
        break;
      case 'cardio':
      case '有氧運動':
        met = 7.0;
        break;
      case 'yoga':
      case '瑜伽':
        met = 3.0;
        break;
      case 'stretching':
      case '伸展':
        met = 2.5;
        break;
      default:
        met = 4.0;
    }

    double bodyWeight = _defaultBodyWeight;
    double calories = (met * 3.5 * bodyWeight) / 200 * duration;

    return calories < 5 ? 5 : calories;
  }

  // ============================================================
  // 🔥 運動記錄 CRUD
  // ============================================================

  /// 🔥 統一新增運動記錄（同時寫入新舊兩個系統）
  Future<String> addWorkoutLog({
    required String type,
    required String name,
    required int duration,
    int? sets,
    int? reps,
    double? weight,
    double? caloriesBurned,
    String? intensity,
    String? notes,
    String? planId,
    String? planName,
    String? sessionId,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    String today = WorkoutDateHelper.formatDate(DateTime.now());
    final now = DateTime.now();

    double calories = caloriesBurned ?? _calculateCalories(type, duration, weight);

    Map<String, dynamic> workoutData = {
      'userId': _currentUserId!,
      'date': today,
      'type': type,
      'name': name,
      'duration': duration,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (weight != null) 'weight': weight,
      'caloriesBurned': calories,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
      if (planId != null) 'planId': planId,
      if (planName != null) 'planName': planName,
      if (sessionId != null) 'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': now.millisecondsSinceEpoch,
    };

    try {
      // 1️⃣ 寫入 workoutLogs（舊系統）
      DocumentReference workoutRef = await _firestore
          .collection('workoutLogs')
          .add(workoutData);

      // 2️⃣ 寫入 users/{userId}/workouts（新系統）
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workouts')
          .doc(workoutRef.id)
          .set(workoutData);

      // 3️⃣ 更新當日統計
      await _updateDailySummary(today, duration, calories);

      if (kDebugMode) {
        debugPrint('✅ 訓練記錄已保存: ${workoutRef.id}');
      }

      return workoutRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 保存訓練記錄失敗: $e');
      }
      rethrow;
    }
  }

  /// 更新每日運動總計
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
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(summaryRef, {
          'userId': _currentUserId!,
          'date': date,
          'totalDuration': duration,
          'totalCalories': calories,
          'workoutCount': 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 🔥 獲取今日訓練記錄
  Future<List<Map<String, dynamic>>> getTodayWorkouts() async {
    if (_currentUserId == null) return [];

    String today = WorkoutDateHelper.formatDate(DateTime.now());

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isEqualTo: today)
          .get();

      var workouts = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();

      workouts.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return (bTime as num).compareTo(aTime as num);
      });

      return workouts;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入訓練記錄失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 獲取今日訓練統計
  Future<Map<String, dynamic>> getTodayStats() async {
    if (_currentUserId == null) {
      return {'totalDuration': 0, 'totalCalories': 0.0, 'workoutCount': 0};
    }

    String today = WorkoutDateHelper.formatDate(DateTime.now());

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

      final workouts = await getTodayWorkouts();
      if (workouts.isEmpty) {
        return {'totalDuration': 0, 'totalCalories': 0.0, 'workoutCount': 0};
      }

      int totalDuration = 0;
      double totalCalories = 0.0;
      for (var workout in workouts) {
        totalDuration += (workout['duration'] ?? 0) as int;
        totalCalories += ((workout['caloriesBurned'] ?? 0) as num).toDouble();
      }

      return {
        'totalDuration': totalDuration,
        'totalCalories': totalCalories,
        'workoutCount': workouts.length,
      };
    } catch (e) {
      return {'totalDuration': 0, 'totalCalories': 0.0, 'workoutCount': 0};
    }
  }

  /// 別名方法
  Future<Map<String, dynamic>> getTodayWorkoutSummary() async => getTodayStats();
  Future<Map<String, dynamic>> getWeeklyWorkoutStats() async => getWeeklyStats();

  /// 🔥 獲取本週訓練統計
  Future<Map<String, dynamic>> getWeeklyStats() async {
    if (_currentUserId == null) {
      return {'workoutDays': 0, 'totalDuration': 0, 'totalCalories': 0.0};
    }

    try {
      DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
      String startDate = WorkoutDateHelper.formatDate(weekAgo);

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
        totalCalories += ((data['totalCalories'] ?? 0) as num).toDouble();
      }

      return {
        'workoutDays': workoutDays,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories,
      };
    } catch (e) {
      return {'workoutDays': 0, 'totalDuration': 0, 'totalCalories': 0.0};
    }
  }

  /// 🔥 刪除運動記錄
  Future<void> deleteWorkout(String workoutId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    try {
      DocumentSnapshot workoutDoc = await _firestore
          .collection('workoutLogs')
          .doc(workoutId)
          .get();

      if (workoutDoc.exists) {
        Map<String, dynamic> data = workoutDoc.data() as Map<String, dynamic>;
        String date = data['date'];
        int duration = data['duration'] ?? 0;
        double calories = (data['caloriesBurned'] ?? 0).toDouble();

        await _firestore.collection('workoutLogs').doc(workoutId).delete();
        await _firestore
            .collection('users')
            .doc(_currentUserId!)
            .collection('workouts')
            .doc(workoutId)
            .delete();

        await _updateDailySummaryAfterDelete(date, duration, calories);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteWorkoutLog(String workoutId) async => deleteWorkout(workoutId);

  Future<void> _updateDailySummaryAfterDelete(String date, int duration, double calories) async {
    DocumentReference summaryRef = _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('workoutSummary')
        .doc(date);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(summaryRef);

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int newDuration = (data['totalDuration'] ?? 0) - duration;
        double newCalories = (data['totalCalories'] ?? 0) - calories;
        int newCount = (data['workoutCount'] ?? 1) - 1;

        if (newCount <= 0) {
          transaction.delete(summaryRef);
        } else {
          transaction.update(summaryRef, {
            'totalDuration': newDuration < 0 ? 0 : newDuration,
            'totalCalories': newCalories < 0 ? 0 : newCalories,
            'workoutCount': newCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /// 獲取訓練歷史記錄
  Future<List<Map<String, dynamic>>> getWorkoutHistory({int days = 30}) async {
    if (_currentUserId == null) return [];

    try {
      final DateTime startDate = DateTime.now().subtract(Duration(days: days));
      final String startDateStr = WorkoutDateHelper.formatDate(startDate);

      final QuerySnapshot snapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // 🔥 自由訓練（AdHoc Session）
  // ============================================================

  /// 🔥 開始自由訓練會話
  Future<String> startAdHocSession({
    required List<Map<String, dynamic>> exercises,
    String workoutName = '自由訓練',
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc();

    await sessionRef.set({
      'userId': uid,
      'name': workoutName,
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
        'category': ex['category'] ?? '未分類',
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

    if (kDebugMode) {
      debugPrint('✅ 開始自由訓練: ${sessionRef.id}, 名稱: $workoutName');
    }

    return sessionRef.id;
  }

  /// 🔥 開始當前組
  Future<void> adHocStartSet(String sessionId, String exerciseDocId, int setIndex) async {
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

  /// 🔥 完成當前組
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

    await setRef.update({
      'restTakenSec': restTakenSec,
      'status': 'completed',
    });

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

  /// 🔥 略過當前組
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

  /// 🔥 新增一組
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

  /// 🔥 訓練中新增動作
  Future<void> adHocAddExercise({
    required String sessionId,
    required Map<String, dynamic> exercise,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('用戶未登入');

    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    final exercisesSnapshot = await sessionRef.collection('exercises').get();
    final newIndex = exercisesSnapshot.docs.length;
    final exerciseDocId = 'ex$newIndex';

    final exRef = sessionRef.collection('exercises').doc(exerciseDocId);
    await exRef.set({
      'exerciseName': exercise['name'] ?? '自訂動作',
      'type': exercise['type'] ?? 'reps',
      'category': exercise['category'] ?? '其他',
      'plannedSets': 0,
      'plannedReps': exercise['plannedReps'] ?? 12,
      'restSec': exercise['restSec'] ?? 90,
      'currentSetIndex': 0,
      'addedDuringSession': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      debugPrint('訓練中新增動作: ${exercise['name']} (索引: $newIndex)');
    }
  }

  /// 🔥 完成自由訓練會話
  Future<void> finishAdHocSession({
    required String sessionId,
    int? sessionRpe,
    double? calories,
    double? userBodyWeight,
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    final bodyWeight = userBodyWeight ?? _defaultBodyWeight;

    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
    });

    final sessionSnap = await sessionRef.get();
    final sessionData = sessionSnap.data();
    if (sessionData == null) return;

    final workoutName = sessionData['name'] as String? ?? '自由訓練';
    final startedAt = (sessionData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endedAt = (sessionData['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = WorkoutDateHelper.formatDate(startedAt);

    final totalDurationSec = endedAt.difference(startedAt).inSeconds.clamp(1, 18000);
    final totalDurationMin = (totalDurationSec / 60).ceil().clamp(1, 300);

    final exercisesSnap = await sessionRef.collection('exercises').get();
    if (exercisesSnap.docs.isEmpty) return;

    List<Map<String, dynamic>> exerciseDetails = [];
    int totalCompletedSets = 0;
    double totalCalories = 0;
    int addedExercisesCount = 0;

    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      final category = exData['category'] as String?;
      final isAddedDuringSession = exData['addedDuringSession'] == true;

      if (isAddedDuringSession) addedExercisesCount++;

      final setsSnap = await exDoc.reference.collection('sets').get();
      if (setsSnap.docs.isEmpty) continue;

      List<Map<String, dynamic>> setsInfo = [];
      int completedSets = 0;

      for (final setDoc in setsSnap.docs) {
        final setData = setDoc.data();
        final status = setData['status'] as String?;

        if (status == 'completed' || status == 'resting') {
          completedSets++;

          final reps = (setData['actualReps'] ?? setData['targetReps'] ?? 12) as int;
          final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
          final duration = (setData['actualDurationSec'] ?? 30) as int;

          double setCalories = calculateSetCaloriesAccurate(
            exerciseName: exerciseName,
            category: category,
            reps: reps,
            weight: weight,
            durationSeconds: duration,
            bodyWeight: bodyWeight,
          );
          totalCalories += setCalories;

          setsInfo.add({
            'setIndex': setData['index'],
            'reps': setData['actualReps'] ?? reps,
            'weight': weight,
            'durationSec': duration,
            'calories': setCalories.roundToDouble(),
            'rpe': setData['rpe'],
            'note': setData['note'],
            'status': status,
          });
        }
      }

      if (completedSets > 0 || setsInfo.isNotEmpty) {
        totalCompletedSets += completedSets;
        exerciseDetails.add({
          'name': exerciseName,
          'exerciseName': exerciseName,
          'completedSets': completedSets,
          'sets': setsInfo,
          'category': category ?? '未分類',
          'addedDuringSession': isAddedDuringSession,
        });
      }
    }

    if (exerciseDetails.isEmpty) return;

    final finalCalories = calories ?? totalCalories;

    final batch = _firestore.batch();

    final workoutLogRef = _firestore.collection('workoutLogs').doc();
    batch.set(workoutLogRef, {
      'userId': uid,
      'date': dateStr,
      'type': 'weight_training',
      'name': workoutName,
      'duration': totalDurationMin,
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'addedExercisesCount': addedExercisesCount,
      'intensity': 'medium',
      'notes': '$workoutName - ${exerciseDetails.length} 個動作',
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': startedAt.millisecondsSinceEpoch,
    });

    final workoutSessionRef = _firestore.collection('workoutSessions').doc(sessionId);
    batch.set(workoutSessionRef, {
      'userId': uid,
      'date': dateStr,
      'name': workoutName,
      'duration': totalDurationMin,
      'timestamp': Timestamp.fromDate(startedAt),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'completedAt': Timestamp.fromDate(endedAt),
      'totalDurationSeconds': totalDurationSec,
      'totalCalories': finalCalories.roundToDouble(),
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'addedExercisesCount': addedExercisesCount,
      'sessionId': sessionId,
      'source': 'self',
      'exercises': exerciseDetails,
    });

    await batch.commit();
    await _updateDailySummary(dateStr, totalDurationMin, finalCalories);

    if (kDebugMode) {
      debugPrint('✅ Ad-hoc session 完成: $sessionId');
      debugPrint('   訓練名稱: $workoutName');
      debugPrint('   總時長: $totalDurationMin 分鐘');
      debugPrint('   卡路里: ${finalCalories.toStringAsFixed(1)}');
    }
  }

  // ============================================================
  // 🔥 教練計畫訓練（Plan Session）- v7.0 修復重複初始化
  // ============================================================

  /// 🔥 開始教練計畫訓練會話
  Future<String> startPlanSession({
    required String planId,
    required String planName,
    required String dayOfWeek,
    required List<Map<String, dynamic>> exercises,
    String? workoutName,
    bool createSets = false,
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc();

    final normalizedDayOfWeek = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
    final effectiveName = workoutName ?? '$planName - $normalizedDayOfWeek';

    await sessionRef.set({
      'userId': uid,
      'source': 'plan',
      'planId': planId,
      'planName': planName,
      'name': effectiveName,
      'dayOfWeek': normalizedDayOfWeek,
      'startedAt': FieldValue.serverTimestamp(),
      'totalActiveSec': 0,
      'totalRestSec': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final exRef = sessionRef.collection('exercises').doc('ex$i');
      final plannedSets = (ex['sets'] ?? ex['plannedSets'] ?? 3) as int;
      final plannedReps = ex['reps'] ?? ex['plannedReps'];

      await exRef.set({
        'exerciseName': ex['name'],
        'category': ex['type'] ?? ex['category'] ?? '未分類',
        'type': 'reps',
        'plannedSets': createSets ? plannedSets : 0,
        'plannedReps': plannedReps,
        'restSec': ex['restSec'] ?? 90,
        'currentSetIndex': 0,
        'notes': ex['notes'],
      });

      if (createSets) {
        for (int s = 0; s < plannedSets; s++) {
          await exRef.collection('sets').doc('$s').set({
            'index': s,
            'status': 'pending',
            'targetReps': plannedReps,
            'restPlannedSec': ex['restSec'] ?? 90,
          });
        }
      }
    }

    if (kDebugMode) {
      debugPrint('✅ 開始計畫訓練: ${sessionRef.id}');
      debugPrint('   計畫: $planName');
      debugPrint('   訓練名稱: $effectiveName');
      debugPrint('   動作數: ${exercises.length}');
      debugPrint('   🔥 createSets: $createSets');
    }

    return sessionRef.id;
  }

  /// 🔥 完成教練計畫訓練會話
  Future<void> finishPlanSession({
    required String sessionId,
    required String planId,
    required String planName,
    required String dayOfWeek,
    int? sessionRpe,
    double? calories,
    double? userBodyWeight,
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    final bodyWeight = userBodyWeight ?? _defaultBodyWeight;

    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
    });

    final sessionSnap = await sessionRef.get();
    final sessionData = sessionSnap.data();
    if (sessionData == null) return;

    final workoutName = sessionData['name'] as String? ?? planName;
    final startedAt = (sessionData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endedAt = (sessionData['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = WorkoutDateHelper.formatDate(startedAt);

    final totalDurationSec = endedAt.difference(startedAt).inSeconds.clamp(1, 18000);
    final totalDurationMin = (totalDurationSec / 60).ceil().clamp(1, 300);

    final exercisesSnap = await sessionRef.collection('exercises').get();
    if (exercisesSnap.docs.isEmpty) return;

    List<Map<String, dynamic>> exerciseDetails = [];
    int totalCompletedSets = 0;
    double totalCalories = 0;
    int addedExercisesCount = 0;

    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      final category = exData['category'] ?? '未分類';
      final isAddedDuringSession = exData['addedDuringSession'] == true;

      if (isAddedDuringSession) addedExercisesCount++;

      final setsSnap = await exDoc.reference.collection('sets').get();
      if (setsSnap.docs.isEmpty) continue;

      List<Map<String, dynamic>> setsInfo = [];
      int completedSets = 0;

      for (final setDoc in setsSnap.docs) {
        final setData = setDoc.data();
        final status = setData['status'] as String?;

        if (status == 'completed' || status == 'resting') {
          completedSets++;

          final reps = (setData['actualReps'] ?? setData['targetReps'] ?? 12) as int;
          final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
          final duration = (setData['actualDurationSec'] ?? 30) as int;

          double setCalories = calculateSetCaloriesAccurate(
            exerciseName: exerciseName,
            category: category,
            reps: reps,
            weight: weight,
            durationSeconds: duration,
            bodyWeight: bodyWeight,
          );
          totalCalories += setCalories;

          setsInfo.add({
            'setIndex': setData['index'],
            'reps': setData['actualReps'] ?? reps,
            'weight': weight,
            'durationSec': duration,
            'calories': setCalories.roundToDouble(),
            'rpe': setData['rpe'],
            'note': setData['note'],
            'status': 'completed',
          });
        }
      }

      if (completedSets > 0 || setsInfo.isNotEmpty) {
        totalCompletedSets += completedSets;
        exerciseDetails.add({
          'name': exerciseName,
          'exerciseName': exerciseName,
          'completedSets': completedSets,
          'sets': setsInfo,
          'category': category,
          'addedDuringSession': isAddedDuringSession,
        });
      }
    }

    if (exerciseDetails.isEmpty) return;

    final finalCalories = calories ?? totalCalories;

    final batch = _firestore.batch();

    final now = DateTime.now();
    final normalizedPlanDayOfWeek = WorkoutDateHelper.normalizeToChinese(dayOfWeek);
    final actualDayOfWeekFull = WorkoutDateHelper.getFullChinese(now.weekday);
    final isOnSchedule = WorkoutDateHelper.isSameWeekday(dayOfWeek, actualDayOfWeekFull);
    final weekNumber = WorkoutDateHelper.getWeekNumber(now);

    if (kDebugMode) {
      debugPrint('🔍 isOnSchedule 判斷 (v7.0):');
      debugPrint('   計畫日: $dayOfWeek → $normalizedPlanDayOfWeek');
      debugPrint('   實際日: $actualDayOfWeekFull');
      debugPrint('   結果: $isOnSchedule');
    }

    final workoutLogRef = _firestore.collection('workoutLogs').doc();
    batch.set(workoutLogRef, {
      'userId': uid,
      'date': dateStr,
      'type': 'weight_training',
      'name': workoutName,
      'planId': planId,
      'planName': planName,
      'dayOfWeek': normalizedPlanDayOfWeek,
      'duration': totalDurationMin,
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'addedExercisesCount': addedExercisesCount,
      'intensity': 'medium',
      'notes': '$workoutName - ${exerciseDetails.length} 個動作',
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': startedAt.millisecondsSinceEpoch,
    });

    final workoutSessionRef = _firestore.collection('workoutSessions').doc(sessionId);
    batch.set(workoutSessionRef, {
      'userId': uid,
      'date': dateStr,
      'name': workoutName,
      'planId': planId,
      'planName': planName,
      'dayOfWeek': normalizedPlanDayOfWeek,
      'duration': totalDurationMin,
      'timestamp': Timestamp.fromDate(startedAt),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'completedAt': Timestamp.fromDate(endedAt),
      'totalDurationSeconds': totalDurationSec,
      'totalCalories': finalCalories.roundToDouble(),
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'addedExercisesCount': addedExercisesCount,
      'sessionId': sessionId,
      'source': 'plan',
      'exercises': exerciseDetails,
    });

    final completionRef = _firestore.collection('workoutCompletions').doc();
    batch.set(completionRef, {
      'planId': planId,
      'userId': uid,
      'sessionId': sessionId,
      'planName': planName,
      'planDayOfWeek': normalizedPlanDayOfWeek,
      'plannedExercises': exercisesSnap.docs.length,
      'actualDate': Timestamp.fromDate(now),
      'actualDateString': dateStr,
      'actualDayOfWeek': actualDayOfWeekFull,
      'weekNumber': weekNumber,
      'year': now.year,
      'isOnSchedule': isOnSchedule,
      'exercisesCompleted': exerciseDetails.length,
      'totalExercises': exercisesSnap.docs.length,
      'totalDuration': totalDurationMin,
      'totalDurationSeconds': totalDurationSec,
      'caloriesBurned': finalCalories.roundToDouble(),
      'setsCompleted': totalCompletedSets,
      'addedExercisesCount': addedExercisesCount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    await _updateDailySummary(dateStr, totalDurationMin, finalCalories);

    if (kDebugMode) {
      debugPrint('✅ 計畫訓練已完成: $sessionId');
      debugPrint('   isOnSchedule: $isOnSchedule');
    }
  }

  // ============================================================
  // 🔥 混合模式進度追蹤
  // ============================================================

  /// 🔥 獲取本週計畫完成情況
  Future<Map<String, Map<String, dynamic>>> getWeeklyPlanCompletions(String planId) async {
    if (_currentUserId == null) return {};

    try {
      final weekStart = WorkoutDateHelper.getWeekStart();
      final weekEnd = WorkoutDateHelper.getWeekEnd();

      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .where('actualDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('actualDate', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd.add(const Duration(days: 1))))
          .get();

      Map<String, Map<String, dynamic>> completions = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final planDayOfWeek = data['planDayOfWeek'] as String? ?? data['dayOfWeek'] as String?;

        if (planDayOfWeek != null) {
          final normalizedKey = WorkoutDateHelper.normalizeToChinese(planDayOfWeek);

          completions[normalizedKey] = {
            'completed': true,
            'actualDate': (data['actualDate'] as Timestamp?)?.toDate(),
            'actualDayOfWeek': data['actualDayOfWeek'] ?? normalizedKey,
            'planDayOfWeek': normalizedKey,
            'isOnSchedule': data['isOnSchedule'] ?? true,
            'duration': data['totalDuration'] ?? 0,
            'calories': data['caloriesBurned'] ?? 0.0,
            'sessionId': data['sessionId'],
          };
        }
      }

      return completions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取本週計畫完成情況失敗: $e');
      }
      return {};
    }
  }

  /// 🔥 獲取計畫的統計數據
  Future<Map<String, dynamic>> getPlanStatistics(String planId) async {
    if (_currentUserId == null) return {};

    try {
      final snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('actualDate', descending: true)
          .limit(100)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalCompletions': 0,
          'onScheduleCount': 0,
          'onScheduleRate': 0.0,
          'totalDuration': 0,
          'totalCalories': 0.0,
          'recentCompletions': [],
        };
      }

      int totalCompletions = snapshot.docs.length;
      int onScheduleCount = 0;
      int totalDuration = 0;
      double totalCalories = 0.0;
      List<Map<String, dynamic>> recentCompletions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data['isOnSchedule'] == true) onScheduleCount++;
        totalDuration += (data['totalDuration'] ?? 0) as int;
        totalCalories += ((data['caloriesBurned'] ?? 0) as num).toDouble();

        if (recentCompletions.length < 10) {
          recentCompletions.add({
            'planDayOfWeek': data['planDayOfWeek'] ?? data['dayOfWeek'],
            'actualDate': (data['actualDate'] as Timestamp?)?.toDate(),
            'actualDayOfWeek': data['actualDayOfWeek'],
            'isOnSchedule': data['isOnSchedule'] ?? true,
            'duration': data['totalDuration'] ?? 0,
            'sessionId': data['sessionId'],
          });
        }
      }

      return {
        'totalCompletions': totalCompletions,
        'onScheduleCount': onScheduleCount,
        'onScheduleRate': totalCompletions > 0
            ? (onScheduleCount / totalCompletions * 100).round()
            : 0,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories.round(),
        'avgDuration': totalCompletions > 0
            ? (totalDuration / totalCompletions).round()
            : 0,
        'recentCompletions': recentCompletions,
      };
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // 🔥 訓練計畫管理
  // ============================================================

  /// 🔥 獲取訓練計畫的進度
  Future<Map<String, int>> getPlanProgress(String planId) async {
    if (_currentUserId == null) return {};

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      Map<String, int> completions = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String dayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        String normalizedDay = WorkoutDateHelper.normalizeToChinese(dayOfWeek);

        completions[normalizedDay] = (completions[normalizedDay] ?? 0) + 1;
      }

      return completions;
    } catch (e) {
      return {};
    }
  }

  /// 🔥 創建訓練計畫（教練端）
  Future<String> createWorkoutPlan({
    required String traineeId,
    required String planName,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required List<Map<String, dynamic>> days,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    try {
      Map<String, dynamic> planData = {
        'coachId': _currentUserId!,
        'traineeId': traineeId,
        'planName': planName,
        if (description != null) 'description': description,
        'startDate': WorkoutDateHelper.formatDate(startDate),
        if (endDate != null) 'endDate': WorkoutDateHelper.formatDate(endDate),
        'days': days,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      DocumentReference docRef = await _firestore.collection('workoutPlans').add(planData);

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// 🔥 獲取學員的訓練計畫列表（學員端）- 只獲取進行中
  Future<List<WorkoutPlanModel>> getMyWorkoutPlans() async {
    if (_currentUserId == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return WorkoutPlanModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // 🔥 v7.1 新增：獲取所有計畫（含已結束）
  // ============================================================

  /// 🔥 v7.1 獲取學員的所有訓練計畫（含已結束）
  Future<List<WorkoutPlanModel>> getAllMyPlans() async {
    if (_currentUserId == null) return [];

    try {
      // 不過濾 status，獲取所有計畫
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return WorkoutPlanModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取所有計畫失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 v7.1 獲取學員的已結束訓練計畫
  Future<List<WorkoutPlanModel>> getMyEndedPlans() async {
    if (_currentUserId == null) return [];

    try {
      // 獲取 status != 'active' 的計畫
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: _currentUserId)
          .where('status', whereIn: ['completed', 'cancelled', 'expired'])
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return WorkoutPlanModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取已結束計畫失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 v7.1 獲取計畫的教練備註
  Future<List<Map<String, dynamic>>> getPlanNotes(String planId) async {
    if (_currentUserId == null) return [];

    try {
      final planDoc = await _firestore
          .collection('workoutPlans')
          .doc(planId)
          .get();

      if (!planDoc.exists) return [];

      final data = planDoc.data()!;
      final notes = data['coachNotes'] as List<dynamic>? ?? [];

      return notes.map((note) {
        if (note is Map<String, dynamic>) {
          return {
            'content': note['content'] ?? '',
            'createdAt': note['createdAt'],
            'coachId': note['coachId'],
          };
        }
        return <String, dynamic>{};
      }).where((note) => note.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫備註失敗: $e');
      }
      return [];
    }
  }

  // ============================================================

  /// 🔥 獲取教練創建的所有計畫（教練端）
  Future<List<Map<String, dynamic>>> getCoachPlans() async {
    if (_currentUserId == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 🔥 標記訓練為完成
  Future<void> markPlanAsCompleted(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    await _firestore.collection('workoutPlans').doc(planId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // 🔥 訓練詳情和監聽
  // ============================================================

  /// 🔥 獲取訓練詳情
  Future<Map<String, dynamic>?> getWorkoutSessionDetails(String sessionId) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final topLevelDoc = await _firestore
          .collection('workoutSessions')
          .doc(sessionId)
          .get();

      if (topLevelDoc.exists) {
        final data = topLevelDoc.data()!;
        return {
          'sessionId': sessionId,
          'startedAt': data['startedAt'] ?? data['timestamp'],
          'endedAt': data['endedAt'] ?? data['completedAt'],
          'totalRestSec': data['totalRestSec'] ?? 0,
          'calories': data['totalCalories'] ?? data['caloriesBurned'] ?? 0.0,
          'totalCalories': data['totalCalories'] ?? data['caloriesBurned'] ?? 0.0,
          'exercises': data['exercises'] ?? [],
          'name': data['name'] ?? '自由訓練',
          'duration': data['duration'] ?? 0,
          'planId': data['planId'],
          'planName': data['planName'],
          'source': data['source'] ?? 'self',
          'addedExercisesCount': data['addedExercisesCount'] ?? 0,
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 🔥 監聽 Session 狀態
  Stream<DocumentSnapshot> watchSession(String sessionId) {
    final uid = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId)
        .snapshots();
  }

  /// 🔥 監聽動作狀態
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

  /// 🔥 監聽組數狀態
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

  /// 🔥 獲取今日訓練 sessions
  Future<List<Map<String, dynamic>>> getTodayWorkoutSessions([String? traineeId]) async {
    try {
      final userId = traineeId ?? _currentUserId;
      if (userId == null) return [];

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'sessionId': doc.id,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'totalDurationSeconds': data['totalDurationSeconds'] ?? 0,
          'totalCalories': (data['totalCalories'] ?? 0.0).toDouble(),
          'exercises': data['exercises'] ?? [],
          'name': data['name'] ?? '自由訓練',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 🔥 獲取今日訓練（整合版）
  Future<List<Map<String, dynamic>>> getTodayWorkoutsUnified() async {
    if (_currentUserId == null) return [];

    final dateStr = WorkoutDateHelper.formatDate(DateTime.now());
    List<Map<String, dynamic>> allWorkouts = [];

    try {
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名訓練',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'sessionId': data['sessionId'],
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['createdAt'],
          'timestamp': data['timestamp'],
          'source': data['planId'] != null ? 'plan' : (data['sessionId'] != null ? 'self' : 'manual'),
        });
      }

      allWorkouts.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });

      return allWorkouts;
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // 🔥 保留的卡路里計算方法（向後相容）
  // ============================================================

  double calculateCaloriesForExercise({
    required String exerciseName,
    required int durationSeconds,
    double? weight,
    int? sets,
    int? reps,
  }) {
    double met = _getMetForExercise(exerciseName, null);

    if (weight != null && weight > 0) {
      if (weight >= 40) {
        met = met * 1.3;
      } else if (weight >= 20) {
        met = met * 1.15;
      }
    }

    if (sets != null && reps != null) {
      int totalReps = sets * reps;
      if (totalReps > 50) {
        met = met * 1.2;
      } else if (totalReps > 30) {
        met = met * 1.1;
      }
    }

    const double standardBodyWeight = 65.0;
    double minutes = durationSeconds / 60.0;
    double calculatedCalories = (met * 3.5 * standardBodyWeight) / 200 * minutes;

    if (calculatedCalories < 1.0) {
      calculatedCalories = durationSeconds / 60.0;
    }

    return calculatedCalories;
  }

  double calculateSessionTotalCalories(List<dynamic> exercises) {
    double totalCalories = 0.0;

    for (var exercise in exercises) {
      final exerciseName = exercise['exerciseName'] as String? ?? '';
      final sets = exercise['sets'] as List? ?? [];

      int totalDurationSeconds = 0;
      double totalWeight = 0.0;
      int validSetsCount = 0;

      for (var set in sets) {
        final duration = set['duration'] as int? ?? set['durationSec'] as int? ?? 0;
        final setWeight = (set['weight'] as num?)?.toDouble() ?? 0.0;

        totalDurationSeconds += duration;
        if (setWeight > 0) {
          totalWeight += setWeight;
          validSetsCount++;
        }
      }

      double avgWeight = validSetsCount > 0 ? totalWeight / validSetsCount : 0.0;

      if (totalDurationSeconds > 0) {
        double exerciseCalories = calculateCaloriesForExercise(
          exerciseName: exerciseName,
          durationSeconds: totalDurationSeconds,
          weight: avgWeight > 0 ? avgWeight : null,
          sets: sets.length,
          reps: null,
        );

        totalCalories += exerciseCalories;
      }
    }

    return totalCalories;
  }
}