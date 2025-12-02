// lib/services/unified_workout_service.dart
// 🔧 統一訓練記錄服務 - 完整整合版 v4
// ✅ 保留所有原有功能
// ✅ 新增 Plan Session 方法（教練計畫訓練）
// ✅ 新增整合讀取方法（同時顯示自由訓練和計畫訓練）
// ✅ 修正 adHocEndRest 狀態更新
// ✅ 🔥 新增：精確卡路里計算（基於 Compendium of Physical Activities 2024 MET 值）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class UnifiedWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // 🔥 精確卡路里計算系統（基於 Compendium of Physical Activities 2024）
  // 參考來源: https://pacompendium.com/
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
    // 計算相對重量比例
    double relativeWeight = weight / bodyWeight;
    
    // 調整係數
    if (relativeWeight >= 0.8) {
      // 重量 >= 80% 體重：高強度
      return baseMet * 1.3;
    } else if (relativeWeight >= 0.5) {
      // 重量 >= 50% 體重：中高強度
      return baseMet * 1.2;
    } else if (relativeWeight >= 0.3) {
      // 重量 >= 30% 體重：中等強度
      return baseMet * 1.1;
    }
    // < 30% 體重：基礎強度，不調整
    return baseMet;
  }

  /// 🔥 計算單組卡路里（精確版）
  /// 公式: (MET × 3.5 × 體重kg) / 200 × 時間(分鐘)
  double calculateSetCaloriesAccurate({
    required String exerciseName,
    String? category,
    required int reps,
    required double weight,
    required int durationSeconds,
    double? bodyWeight,
  }) {
    final userWeight = bodyWeight ?? _defaultBodyWeight;
    
    // 1. 獲取基礎 MET 值
    double met = _getMetForExercise(exerciseName, category);
    
    // 2. 根據重量調整 MET
    if (weight > 0) {
      met = _adjustMetForWeight(met, weight, userWeight);
    }
    
    // 3. 計算卡路里
    double minutes = durationSeconds / 60.0;
    double calories = (met * 3.5 * userWeight) / 200 * minutes;
    
    // 4. 確保最小值
    return calories < 1.0 ? 1.0 : calories;
  }

  /// 🔥 計算整個訓練的卡路里（精確版）- 用於 finishAdHocSession
  Future<double> _calculateSessionCaloriesFromFirestore({
    required DocumentReference sessionRef,
    double? bodyWeight,
  }) async {
    final userWeight = bodyWeight ?? _defaultBodyWeight;
    double totalCalories = 0;

    final exercisesSnap = await sessionRef.collection('exercises').get();
    
    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      final category = exData['category'] as String?;
      
      final setsSnap = await exDoc.reference.collection('sets').get();
      
      for (final setDoc in setsSnap.docs) {
        final setData = setDoc.data();
        final status = setData['status'] as String?;
        
        // 只計算已完成的組
        if (status == 'completed' || status == 'resting') {
          final reps = (setData['actualReps'] ?? setData['targetReps'] ?? 12) as int;
          final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
          final duration = (setData['actualDurationSec'] ?? 30) as int;
          
          totalCalories += calculateSetCaloriesAccurate(
            exerciseName: exerciseName,
            category: category,
            reps: reps,
            weight: weight,
            durationSeconds: duration,
            bodyWeight: userWeight,
          );
        }
      }
    }

    return totalCalories;
  }

  // ========== 運動記錄相關 ==========

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

    String today = DateTime.now().toIso8601String().split('T')[0];
    final now = DateTime.now();

    // 計算卡路里
    double calories = caloriesBurned ?? _calculateCalories(type, duration, weight);

    // 準備數據
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
        debugPrint('✅ 訓練記錄已保存:');
        debugPrint('   ID: ${workoutRef.id}');
        debugPrint('   日期: $today');
        debugPrint('   名稱: $name');
        if (planId != null) {
          debugPrint('   計畫ID: $planId');
        }
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

  /// 🔧 簡易卡路里計算（用於非 session 的記錄）
  double _calculateCalories(String type, int duration, double? weight) {
    // MET 值（代謝當量）
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

    // 使用標準體重 65kg
    double bodyWeight = _defaultBodyWeight;
    
    // 🔥 修正公式: (MET × 3.5 × 體重kg) / 200 × 時間(分鐘)
    double calories = (met * 3.5 * bodyWeight) / 200 * duration;
    
    // 確保最小值為 5 卡
    return calories < 5 ? 5 : calories;
  }

  /// 🔥 獲取今日訓練記錄（增強版 - 詳細調試）
  Future<List<Map<String, dynamic>>> getTodayWorkouts() async {
    if (_currentUserId == null) {
      if (kDebugMode) {
        debugPrint('❌ 用戶未登入');
      }
      return [];
    }

    String today = DateTime.now().toIso8601String().split('T')[0];

    if (kDebugMode) {
      debugPrint('🔍 查詢今日訓練:');
      debugPrint('   用戶ID: $_currentUserId');
      debugPrint('   日期: $today');
    }

    try {
      // 🔧 方案 1: 先嘗試從新系統讀取（有 orderBy）
      try {
        QuerySnapshot newSnapshot = await _firestore
            .collection('users')
            .doc(_currentUserId!)
            .collection('workouts')
            .where('date', isEqualTo: today)
            .orderBy('timestamp', descending: true)
            .get();

        if (newSnapshot.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('✅ 從新系統（有排序）讀取到 ${newSnapshot.docs.length} 筆記錄');
          }
          return newSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 新系統（有排序）查詢失敗: $e');
          debugPrint('   嘗試無排序查詢...');
        }
      }

      // 🔧 方案 2: 新系統無排序查詢
      QuerySnapshot newSnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workouts')
          .where('date', isEqualTo: today)
          .get();

      if (newSnapshot.docs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ 從新系統（無排序）讀取到 ${newSnapshot.docs.length} 筆記錄');
        }
        
        // 手動排序
        var workouts = newSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList();
        
        // 按 timestamp 排序（新的在前）
        workouts.sort((a, b) {
          final aTime = a['timestamp'] ?? 0;
          final bTime = b['timestamp'] ?? 0;
          return (bTime as num).compareTo(aTime as num);
        });
        
        return workouts;
      }

      // 🔧 方案 3: 從舊系統讀取（有 orderBy）
      if (kDebugMode) {
        debugPrint('⚠️ 新系統無數據，嘗試從舊系統讀取...');
      }

      try {
        QuerySnapshot oldSnapshot = await _firestore
            .collection('workoutLogs')
            .where('userId', isEqualTo: _currentUserId!)
            .where('date', isEqualTo: today)
            .orderBy('timestamp', descending: true)
            .get();

        if (oldSnapshot.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('✅ 從舊系統（有排序）讀取到 ${oldSnapshot.docs.length} 筆記錄');
          }
          return oldSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 舊系統（有排序）查詢失敗: $e');
        }
      }

      // 🔧 方案 4: 舊系統無排序查詢
      QuerySnapshot oldSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: _currentUserId!)
          .where('date', isEqualTo: today)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 從舊系統（無排序）讀取到 ${oldSnapshot.docs.length} 筆記錄');
      }

      var workouts = oldSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
      
      // 手動排序
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
      return {
        'totalDuration': 0,
        'totalCalories': 0.0,
        'workoutCount': 0,
      };
    }

    String today = DateTime.now().toIso8601String().split('T')[0];

    try {
      // 先嘗試從 workoutSummary 讀取
      DocumentSnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workoutSummary')
          .doc(today)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('✅ 從 workoutSummary 讀取統計: $data');
        }
        return {
          'totalDuration': data['totalDuration'] ?? 0,
          'totalCalories': (data['totalCalories'] ?? 0).toDouble(),
          'workoutCount': data['workoutCount'] ?? 0,
        };
      }

      // 如果沒有統計，手動計算今日訓練
      if (kDebugMode) {
        debugPrint('⚠️ workoutSummary 無數據，手動計算統計...');
      }

      final workouts = await getTodayWorkouts();
      
      if (workouts.isEmpty) {
        return {
          'totalDuration': 0,
          'totalCalories': 0.0,
          'workoutCount': 0,
        };
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
      if (kDebugMode) {
        debugPrint('❌ 讀取統計失敗: $e');
      }
      return {
        'totalDuration': 0,
        'totalCalories': 0.0,
        'workoutCount': 0,
      };
    }
  }

  /// 🔥 獲取今日訓練總結（別名方法，供頁面使用）
  Future<Map<String, dynamic>> getTodayWorkoutSummary() async {
    return getTodayStats();
  }

  /// 🔥 獲取本週訓練統計（別名方法）
  Future<Map<String, dynamic>> getWeeklyWorkoutStats() async {
    return getWeeklyStats();
  }

  /// 🔥 刪除運動記錄（同時刪除新舊系統）
  Future<void> deleteWorkout(String workoutId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    try {
      // 先從新系統獲取數據
      DocumentSnapshot workoutDoc = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workouts')
          .doc(workoutId)
          .get();

      Map<String, dynamic>? data;
      
      if (workoutDoc.exists) {
        data = workoutDoc.data() as Map<String, dynamic>;
      } else {
        // 如果新系統沒有，從舊系統獲取
        if (kDebugMode) {
          debugPrint('⚠️ 新系統無此記錄，從舊系統獲取');
        }
        DocumentSnapshot oldDoc = await _firestore
            .collection('workoutLogs')
            .doc(workoutId)
            .get();
        
        if (oldDoc.exists) {
          data = oldDoc.data() as Map<String, dynamic>;
        }
      }

      if (data != null) {
        String date = data['date'];
        int duration = data['duration'] ?? 0;
        double calories = (data['caloriesBurned'] ?? 0).toDouble();

        // 刪除新舊兩個系統的記錄
        await _firestore.collection('workoutLogs').doc(workoutId).delete();
        await _firestore
            .collection('users')
            .doc(_currentUserId!)
            .collection('workouts')
            .doc(workoutId)
            .delete();

        // 更新統計
        await _updateDailySummaryAfterDelete(date, duration, calories);

        if (kDebugMode) {
          debugPrint('✅ 已刪除訓練記錄: $workoutId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 刪除失敗: $e');
      }
      rethrow;
    }
  }

  /// 🔥 刪除運動記錄（別名方法）
  Future<void> deleteWorkoutLog(String workoutId) async {
    return deleteWorkout(workoutId);
  }

  /// 刪除後更新統計
  Future<void> _updateDailySummaryAfterDelete(
      String date, int duration, double calories) async {
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

  /// ✅ 獲取訓練歷史記錄
  Future<List<Map<String, dynamic>>> getWorkoutHistory({int days = 30}) async {
    if (_currentUserId == null) return [];

    try {
      // 計算起始日期
      final DateTime startDate = DateTime.now().subtract(Duration(days: days));
      final String startDateStr = startDate.toIso8601String().split('T')[0];

      if (kDebugMode) {
        debugPrint('📋 查詢訓練歷史: 從 $startDateStr 開始，共 $days 天');
      }

      // 從 workoutSessions 集合查詢
      final QuerySnapshot snapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .orderBy('date', descending: true)
          .orderBy('completedAt', descending: true)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 找到 ${snapshot.docs.length} 筆訓練記錄');
      }

      // 轉換為 Map 列表
      final List<Map<String, dynamic>> workouts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // 添加文檔 ID
        return data;
      }).toList();

      return workouts;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 獲取訓練歷史失敗: $e');
        debugPrint('堆疊追蹤: $stackTrace');
      }
      return [];
    }
  }

  /// 🔥 獲取本週訓練統計
  Future<Map<String, dynamic>> getWeeklyStats() async {
    if (_currentUserId == null) {
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0.0,
      };
    }

    try {
      // 獲取過去7天的數據
      DateTime now = DateTime.now();
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      String startDate = weekAgo.toIso8601String().split('T')[0];

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('workoutSummary')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 週統計: 找到 ${snapshot.docs.length} 天的記錄');
      }

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
      if (kDebugMode) {
        debugPrint('❌ 讀取週統計失敗: $e');
      }
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0.0,
      };
    }
  }

  // ========== 訓練計畫相關 ==========

  /// 🔥 獲取訓練計畫的進度
  Future<Map<String, int>> getPlanProgress(String planId) async {
    if (_currentUserId == null) return {};

    try {
      // 查詢該計畫的所有完成記錄
      QuerySnapshot snapshot = await _firestore
          .collection('planCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: _currentUserId)
          .get();

      Map<String, int> completions = {};
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String dayOfWeek = data['dayOfWeek'] as String;
        
        // 計算每個星期幾的完成次數
        completions[dayOfWeek] = (completions[dayOfWeek] ?? 0) + 1;
      }

      if (kDebugMode) {
        debugPrint('✅ 計畫進度: $completions');
      }

      return completions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取計畫進度失敗: $e');
      }
      return {};
    }
  }

  /// 🔥 記錄計畫訓練日完成
  Future<void> recordPlanDayCompletion({
    required String planId,
    required String dayOfWeek,
    required DateTime date,
  }) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    try {
      await _firestore.collection('planCompletions').add({
        'planId': planId,
        'userId': _currentUserId,
        'dayOfWeek': dayOfWeek,
        'completedDate': date.toIso8601String().split('T')[0],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 計畫訓練日完成記錄已保存: $dayOfWeek');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 記錄計畫完成失敗: $e');
      }
      throw Exception('記錄計畫完成失敗: $e');
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
        'startDate': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
        'days': days,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      DocumentReference docRef = await _firestore
          .collection('workoutPlans')
          .add(planData);

      if (kDebugMode) {
        debugPrint('✅ 訓練計畫已創建: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 創建訓練計畫失敗: $e');
      }
      rethrow;
    }
  }

  /// 🔥 獲取學員的訓練計畫（學員端）
  Future<List<Map<String, dynamic>>> getMyWorkoutPlans() async {
    if (_currentUserId == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 找到 ${snapshot.docs.length} 個訓練計畫');
      }

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取訓練計畫失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 獲取教練創建的所有計畫（教練端）
  Future<List<Map<String, dynamic>>> getCoachPlans() async {
    if (_currentUserId == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('workoutPlans')
          .where('coachId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 找到 ${snapshot.docs.length} 個教練計畫');
      }

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取教練計畫失敗: $e');
      }
      return [];
    }
  }

  /// 🔥 標記訓練為完成
  Future<void> markPlanAsCompleted(String planId) async {
    if (_currentUserId == null) throw Exception('用戶未登入');

    try {
      await _firestore.collection('workoutPlans').doc(planId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 訓練計畫已標記為完成: $planId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 標記完成失敗: $e');
      }
      rethrow;
    }
  }

  // ========== 🔥 自由訓練（AdHoc Session）相關 ==========

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
      debugPrint('✅ 開始自由訓練: ${sessionRef.id}');
    }

    return sessionRef.id;
  }

  /// 🔥 開始當前組
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

  /// 🔥 結束休息（已修正：狀態改為 completed）
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

    // 🔥 修正：休息結束後，狀態改為 completed
    await setRef.update({
      'restTakenSec': restTakenSec,
      'status': 'completed',  // ✅ 關鍵修正
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

  /// 🔥 自由訓練中新增動作
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

    // 獲取當前動作數量，決定新動作的索引
    final exercisesSnapshot = await sessionRef.collection('exercises').get();
    final newIndex = exercisesSnapshot.docs.length;
    final exerciseDocId = 'ex$newIndex';

    // 新增動作文檔
    final exRef = sessionRef.collection('exercises').doc(exerciseDocId);
    await exRef.set({
      'exerciseName': exercise['name'] ?? '自訂動作',
      'type': exercise['type'] ?? 'reps',
      'category': exercise['category'] ?? '其他',
      'plannedSets': 0, // 初始為 0，用戶自己新增組數
      'plannedReps': exercise['plannedReps'] ?? 12,
      'restSec': exercise['restSec'] ?? 90,
      'currentSetIndex': 0,
      'addedDuringSession': true, // 標記為訓練中新增
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      debugPrint('訓練中新增動作: ${exercise['name']} (索引: $newIndex)');
    }
  }


  /// 🔥 完成自由訓練會話 - 使用精確卡路里計算
  Future<void> finishAdHocSession({
    required String sessionId,
    int? sessionRpe,
    double? calories,
    double? userBodyWeight, // 🔥 新增：可選的用戶體重參數
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    final bodyWeight = userBodyWeight ?? _defaultBodyWeight;

    // 1. 標記 session 為已完成
    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
    });

    final sessionSnap = await sessionRef.get();
    final sessionData = sessionSnap.data();
    if (sessionData == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Session 資料不存在');
      }
      return;
    }

    final startedAt = (sessionData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endedAt = (sessionData['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = startedAt.toIso8601String().split('T')[0];
    
    // 計算總時長(秒和分鐘)
    final totalDurationSec = endedAt.difference(startedAt).inSeconds.clamp(1, 18000);
    final totalDurationMin = (totalDurationSec / 60).ceil().clamp(1, 300);

    // 2. 獲取所有動作的詳細資訊並計算卡路里
    final exercisesSnap = await sessionRef.collection('exercises').get();
    
    if (exercisesSnap.docs.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 沒有任何動作記錄');
      }
      return;
    }

    // 收集所有動作的組數詳情
    List<Map<String, dynamic>> exerciseDetails = [];
    int totalCompletedSets = 0;
    double totalCalories = 0; // 🔥 使用精確計算

    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      final category = exData['category'] as String?;
      
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
          
          final reps = (setData['actualReps'] ?? setData['targetReps'] ?? 12) as int;
          final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
          final duration = (setData['actualDurationSec'] ?? 30) as int;
          
          // 🔥 精確計算每組卡路里
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
            'calories': setCalories.roundToDouble(), // 🔥 記錄每組卡路里
            'rpe': setData['rpe'],
            'note': setData['note'],
            'status': status,
          });
        } else if (status == 'skipped') {
          // 🔥 修正：只記錄有實際數據的 skipped 組
          final hasData = setData['actualReps'] != null || 
                          setData['weight'] != null ||
                          setData['reps'] != null;
          if (hasData) {
            setsInfo.add({
              'setIndex': setData['index'],
              'reps': setData['actualReps'] ?? setData['reps'],
              'weight': setData['weight'],
              'status': 'skipped',
            });
          }
        }
        // 🔥 不記錄 pending 狀態的空組
      }

      if (completedSets > 0 || setsInfo.isNotEmpty) {
        totalCompletedSets += completedSets;
        
        exerciseDetails.add({
          'name': exerciseName,
          'exerciseName': exerciseName,
          'completedSets': completedSets,
          'sets': setsInfo,
          'category': category ?? '未分類',
        });
      }
    }

    if (exerciseDetails.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 沒有完成任何組數');
      }
      return;
    }

    // 🔥 使用傳入的卡路里或精確計算值
    final finalCalories = calories ?? totalCalories;

    // ===== 🔥 使用 WriteBatch 同時寫入兩個集合 =====
    final batch = _firestore.batch();

    // 4a. ✅ 寫入 workoutLogs (供列表頁面讀取)
    final workoutLogRef = _firestore.collection('workoutLogs').doc();
    batch.set(workoutLogRef, {
      'userId': uid,
      'date': dateStr,
      'type': 'weight_training',
      'name': '自由訓練',
      'duration': totalDurationMin,
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'intensity': 'medium',
      'notes': '自由訓練 - ${exerciseDetails.length} 個動作',
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': startedAt.millisecondsSinceEpoch,
    });

    // 4b. ✅ 寫入 workoutSessions (供詳細頁面讀取)
    final workoutSessionRef = _firestore.collection('workoutSessions').doc(sessionId);
    batch.set(workoutSessionRef, {
      'userId': uid,
      'date': dateStr,
      'name': '自由訓練',
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
      'sessionId': sessionId,
      'source': 'self',
      'exercises': exerciseDetails,
    });

    // ✅ 提交批次寫入
    await batch.commit();

    // 5. 更新每日統計
    await _updateDailySummary(dateStr, totalDurationMin, finalCalories);

    if (kDebugMode) {
      debugPrint('✅ Ad-hoc session 完成: $sessionId');
      debugPrint('   總時長: $totalDurationMin 分鐘 ($totalDurationSec 秒)');
      debugPrint('   🔥 精確卡路里: ${finalCalories.toStringAsFixed(1)} (基於 MET 計算)');
      debugPrint('   總組數: $totalCompletedSets');
      debugPrint('   動作數: ${exerciseDetails.length}');
      debugPrint('   ✅ 已同時寫入 workoutLogs 和 workoutSessions');
    }
  }

  // ========== 🎯 教練計畫訓練（Plan Session）相關 ==========

  /// 🔥 開始教練計畫訓練會話
  Future<String> startPlanSession({
    required String planId,
    required String planName,
    required String dayOfWeek,
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
      'source': 'plan',
      'planId': planId,
      'planName': planName,
      'dayOfWeek': dayOfWeek,
      'startedAt': FieldValue.serverTimestamp(),
      'totalActiveSec': 0,
      'totalRestSec': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 建立每個動作和組數
    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final exRef = sessionRef.collection('exercises').doc('ex$i');
      final plannedSets = (ex['sets'] ?? ex['plannedSets'] ?? 3) as int;
      final plannedReps = ex['reps'] ?? ex['plannedReps'];

      await exRef.set({
        'exerciseName': ex['name'],
        'category': ex['type'] ?? ex['category'] ?? '未分類',
        'type': 'reps',
        'plannedSets': plannedSets,
        'plannedReps': plannedReps,
        'restSec': ex['restSec'] ?? 90,
        'currentSetIndex': 0,
        'notes': ex['notes'],
      });

      // 建立每組的初始狀態
      for (int s = 0; s < plannedSets; s++) {
        await exRef.collection('sets').doc('$s').set({
          'index': s,
          'status': 'pending',
          'targetReps': plannedReps,
          'restPlannedSec': ex['restSec'] ?? 90,
        });
      }
    }

    if (kDebugMode) {
      debugPrint('✅ 開始計畫訓練: ${sessionRef.id}');
      debugPrint('   計畫: $planName');
      debugPrint('   動作數: ${exercises.length}');
    }

    return sessionRef.id;
  }

  /// 🔥 完成教練計畫訓練會話 - 使用精確卡路里計算
  Future<void> finishPlanSession({
    required String sessionId,
    required String planId,
    required String planName,
    required String dayOfWeek,
    int? sessionRpe,
    double? calories,
    double? userBodyWeight, // 🔥 新增：可選的用戶體重參數
  }) async {
    final uid = _currentUserId!;
    final sessionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('workoutSessions')
        .doc(sessionId);

    final bodyWeight = userBodyWeight ?? _defaultBodyWeight;

    // 1. 更新 session 結束時間
    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      if (sessionRpe != null) 'sessionRpe': sessionRpe,
    });

    // 2. 獲取 session 資料
    final sessionSnap = await sessionRef.get();
    final sessionData = sessionSnap.data();
    if (sessionData == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Plan Session 資料不存在');
      }
      return;
    }

    final startedAt = (sessionData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endedAt = (sessionData['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final dateStr = startedAt.toIso8601String().split('T')[0];
    
    // 計算總時長
    final totalDurationSec = endedAt.difference(startedAt).inSeconds.clamp(1, 18000);
    final totalDurationMin = (totalDurationSec / 60).ceil().clamp(1, 300);

    // 3. 獲取所有動作的詳細資訊並計算卡路里
    final exercisesSnap = await sessionRef.collection('exercises').get();
    
    if (exercisesSnap.docs.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 沒有任何動作記錄');
      }
      return;
    }

    // 收集所有動作的組數詳情
    List<Map<String, dynamic>> exerciseDetails = [];
    int totalCompletedSets = 0;
    double totalCalories = 0; // 🔥 使用精確計算

    for (final exDoc in exercisesSnap.docs) {
      final exData = exDoc.data();
      final exerciseName = exData['exerciseName'] ?? '未命名動作';
      final category = exData['category'] ?? '未分類';
      
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
          
          final reps = (setData['actualReps'] ?? setData['targetReps'] ?? 12) as int;
          final weight = (setData['weight'] as num?)?.toDouble() ?? 0.0;
          final duration = (setData['actualDurationSec'] ?? 30) as int;
          
          // 🔥 精確計算每組卡路里
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
        } else if (status == 'skipped') {
          // 只記錄有實際數據的 skipped 組
          final hasData = setData['actualReps'] != null || 
                          setData['weight'] != null;
          if (hasData) {
            setsInfo.add({
              'setIndex': setData['index'],
              'reps': setData['actualReps'],
              'weight': setData['weight'],
              'status': 'skipped',
            });
          }
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
        });
      }
    }

    if (exerciseDetails.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 沒有完成任何組數');
      }
      return;
    }

    // 🔥 使用傳入的卡路里或精確計算值
    final finalCalories = calories ?? totalCalories;

    // ===== 🔥 使用 WriteBatch 同時寫入多個集合 =====
    final batch = _firestore.batch();

    // 4a. ✅ 寫入 workoutLogs (供列表頁面讀取)
    final workoutLogRef = _firestore.collection('workoutLogs').doc();
    batch.set(workoutLogRef, {
      'userId': uid,
      'date': dateStr,
      'type': 'weight_training',
      'name': '計畫訓練',
      'planId': planId,           // ✅ 關鍵：記錄 planId
      'planName': planName,       // ✅ 記錄計畫名稱
      'dayOfWeek': dayOfWeek,
      'duration': totalDurationMin,
      'caloriesBurned': finalCalories.roundToDouble(),
      'totalSets': totalCompletedSets,
      'totalExercises': exerciseDetails.length,
      'intensity': 'medium',
      'notes': '$planName - ${exerciseDetails.length} 個動作',
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': startedAt.millisecondsSinceEpoch,
    });

    // 4b. ✅ 寫入 workoutSessions (供詳細頁面讀取)
    final workoutSessionRef = _firestore.collection('workoutSessions').doc(sessionId);
    batch.set(workoutSessionRef, {
      'userId': uid,
      'date': dateStr,
      'name': planName,
      'planId': planId,
      'planName': planName,
      'dayOfWeek': dayOfWeek,
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
      'sessionId': sessionId,
      'source': 'plan',
      'exercises': exerciseDetails,
    });

    // 4c. ✅ 記錄計畫完成進度（用於追蹤）
    final completionRef = _firestore.collection('workoutCompletions').doc();
    batch.set(completionRef, {
      'planId': planId,
      'userId': uid,
      'completionDate': Timestamp.fromDate(DateTime(startedAt.year, startedAt.month, startedAt.day)),
      'dayOfWeek': dayOfWeek,
      'exercisesCompleted': exerciseDetails.length,
      'totalExercises': exercisesSnap.docs.length,
      'totalDuration': totalDurationMin,
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ✅ 提交批次寫入
    await batch.commit();

    // 5. 更新每日統計
    await _updateDailySummary(dateStr, totalDurationMin, finalCalories);

    if (kDebugMode) {
      debugPrint('✅ 計畫訓練已完成並保存:');
      debugPrint('   sessionId: $sessionId');
      debugPrint('   planId: $planId');
      debugPrint('   日期: $dateStr');
      debugPrint('   時長: $totalDurationMin 分鐘');
      debugPrint('   動作: ${exerciseDetails.length} 個');
      debugPrint('   完成組數: $totalCompletedSets');
      debugPrint('   🔥 精確卡路里: ${finalCalories.toStringAsFixed(1)}');
    }
  }

  // ========== 🔥 整合讀取方法 ==========

  /// 🔥 獲取今日所有訓練（整合 workoutLogs 和 workoutSessions）
  Future<List<Map<String, dynamic>>> getTodayWorkoutsUnified() async {
    if (_currentUserId == null) return [];

    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];
    
    List<Map<String, dynamic>> allWorkouts = [];

    try {
      // 1️⃣ 從 workoutLogs 讀取
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

      // 2️⃣ 檢查 workoutSessions 是否有額外的記錄（避免重複）
      final existingSessionIds = allWorkouts
          .where((w) => w['sessionId'] != null)
          .map((w) => w['sessionId'] as String)
          .toSet();

      final sessionsSnapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: _currentUserId)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        // 避免重複
        if (existingSessionIds.contains(doc.id)) continue;

        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? '訓練記錄',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['totalCalories'] ?? data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'],
          'totalExercises': data['totalExercises'],
          'sessionId': doc.id,
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['completedAt'] ?? data['endedAt'],
          'timestamp': data['timestamp'],
          'source': data['planId'] != null ? 'plan' : 'self',
        });
      }

      // 3️⃣ 按時間排序（最新的在前）
      allWorkouts.sort((a, b) {
        final aTime = a['timestamp'] ?? 
            (a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch : 0);
        final bTime = b['timestamp'] ?? 
            (b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch : 0);
        return (bTime as int).compareTo(aTime as int);
      });

      if (kDebugMode) {
        debugPrint('✅ 今日訓練（整合）: ${allWorkouts.length} 筆');
      }

      return allWorkouts;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getTodayWorkoutsUnified 錯誤: $e');
      }
      return [];
    }
  }

  // ========== 訓練記錄詳情相關 ==========

  /// 🔥 獲取訓練詳情(包含所有組數) - 從 workoutSessions 讀取
  Future<Map<String, dynamic>?> getWorkoutSessionDetails(String sessionId) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      // 🔥 先嘗試從頂層 workoutSessions 讀取
      final topLevelDoc = await _firestore
          .collection('workoutSessions')
          .doc(sessionId)
          .get();

      if (topLevelDoc.exists) {
        final data = topLevelDoc.data()!;
        if (kDebugMode) {
          debugPrint('✅ 從 workoutSessions 頂層讀取到詳情');
        }
        return {
          'sessionId': sessionId,
          'startedAt': data['startedAt'] ?? data['timestamp'],
          'endedAt': data['endedAt'] ?? data['completedAt'],
          'totalRestSec': data['totalRestSec'] ?? 0,
          'calories': data['totalCalories'] ?? data['caloriesBurned'] ?? 0.0,
          'totalCalories': data['totalCalories'] ?? data['caloriesBurned'] ?? 0.0,
          'caloriesBurned': data['caloriesBurned'] ?? data['totalCalories'] ?? 0.0,
          'totalDurationSeconds': data['totalDurationSeconds'] ?? 0,
          'exercises': data['exercises'] ?? [],
          'name': data['name'] ?? '自由訓練',
          'duration': data['duration'] ?? 0,
          'planId': data['planId'],
          'planName': data['planName'],
          'source': data['source'] ?? 'self',
        };
      }

      // 🔥 如果頂層沒有，從 users/{uid}/workoutSessions 讀取並組合子集合
      if (kDebugMode) {
        debugPrint('⚠️ 頂層無資料，從 users/$uid/workoutSessions 讀取');
      }

      final sessionRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .doc(sessionId);
      
      final sessionSnap = await sessionRef.get();
      if (!sessionSnap.exists) {
        if (kDebugMode) {
          debugPrint('❌ Session 不存在: $sessionId');
        }
        return null;
      }
      
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
          'exerciseName': exData['exerciseName'],
          'type': exData['type'],
          'category': exData['category'],
          'sets': sets,
        });
      }
      
      return {
        'sessionId': sessionId,
        'startedAt': sessionData['startedAt'],
        'endedAt': sessionData['endedAt'],
        'totalRestSec': sessionData['totalRestSec'] ?? 0,
        'calories': sessionData['calories'] ?? 0.0,
        'totalCalories': sessionData['calories'] ?? 0.0,
        'exercises': exercises,
        'planId': sessionData['planId'],
        'planName': sessionData['planName'],
        'source': sessionData['source'] ?? 'self',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getWorkoutSessionDetails 錯誤: $e');
      }
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

  /// 🔥 取得今日訓練 sessions (用於訓練記錄頁面)
  Future<List<Map<String, dynamic>>> getTodayWorkoutSessions([String? traineeId]) async {
    try {
      final userId = traineeId ?? _currentUserId;
      if (userId == null) return [];

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      if (kDebugMode) {
        debugPrint('📅 查詢今日訓練 sessions: ${DateFormat('yyyy-MM-dd').format(today)}');
      }

      final snapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 找到 ${snapshot.docs.length} 筆今日訓練 sessions');
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'sessionId': doc.id,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'totalDurationSeconds': data['totalDurationSeconds'] ?? 0,
          'totalCalories': (data['totalCalories'] ?? 0.0).toDouble(),
          'exercises': data['exercises'] ?? [],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getTodayWorkoutSessions 錯誤: $e');
      }
      return [];
    }
  }

  /// 🔥 取得所有訓練 sessions (用於統計計算)
  Future<List<Map<String, dynamic>>> getAllWorkoutSessions([String? traineeId]) async {
    try {
      final userId = traineeId ?? _currentUserId;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      if (kDebugMode) {
        debugPrint('✅ 找到 ${snapshot.docs.length} 筆歷史訓練 sessions');
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'sessionId': doc.id,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
          'totalDurationSeconds': data['totalDurationSeconds'] ?? 0,
          'totalCalories': (data['totalCalories'] ?? 0.0).toDouble(),
          'exercises': data['exercises'] ?? [],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getAllWorkoutSessions 錯誤: $e');
      }
      return [];
    }
  }

  // ========== 🔥 保留原有的卡路里計算方法（向後相容） ==========

  /// 🔥 改進的卡路里計算（保留原有方法）
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

  /// 🔥 計算整個 session 的總卡路里（保留原有方法）
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