// lib/services/unified_workout_service.dart
// 🔧 統一訓練記錄服務 - 完整版：包含訓練計畫功能
// ✅ 新增: getTodayWorkoutSessions, getAllWorkoutSessions, getWorkoutSessionDetails
// ✅ 改進: 更準確的卡路里計算

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class UnifiedWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

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

  /// 🔧 修正的卡路里計算（基於運動類型和時長）
  double _calculateCalories(String type, int duration, double? weight) {
    // MET 值（代謝當量）- 更保守的估計
    double met = 5.0;

    switch (type.toLowerCase()) {
      case 'weight_training':
      case '重量訓練':
        met = 4.5;
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
    double bodyWeight = 65.0;
    
    // 卡路里 = MET × 體重(kg) × 時間(小時)
    double hours = duration / 60.0;
    double calories = met * bodyWeight * hours;
    
    // 確保最小值為 10 卡
    return calories < 10 ? 10 : calories;
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

  /// ✅ 新增：獲取訓練歷史記錄
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

  // ========== 訓練記錄詳情相關 (新增) ==========

  /// 🔥 取得今日訓練 sessions (用於訓練記錄頁面)
  /// ✅ 直接從 workoutSessions 讀取，確保數據一致
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
          .limit(100) // 限制最近100筆
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

  /// 🔥 取得訓練 session 詳細資料
  Future<Map<String, dynamic>?> getWorkoutSessionDetails(String sessionId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 查詢 session 詳情: $sessionId');
      }

      final doc = await _firestore
          .collection('workoutSessions')
          .doc(sessionId)
          .get();

      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint('❌ Session 不存在: $sessionId');
        }
        return null;
      }

      final data = doc.data()!;
      
      if (kDebugMode) {
        debugPrint('✅ 成功取得 session 詳情');
      }

      return {
        'sessionId': doc.id,
        'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        'totalDurationSeconds': data['totalDurationSeconds'] ?? 0,
        'totalCalories': (data['totalCalories'] ?? 0.0).toDouble(),
        'exercises': data['exercises'] ?? [],
        'userId': data['userId'],
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getWorkoutSessionDetails 錯誤: $e');
      }
      return null;
    }
  }

  // ========== 改進的卡路里計算 (新增) ==========

  /// 🔥 改進的卡路里計算
  /// 根據運動類型、時長、重量和組數計算更準確的卡路里消耗
  double calculateCaloriesForExercise({
    required String exerciseName,
    required int durationSeconds,
    double? weight,
    int? sets,
    int? reps,
  }) {
    // 1. 根據動作名稱判斷運動類型和強度
    double met = _getMetValueFromExerciseName(exerciseName);
    
    // 2. 如果有重量訓練，根據重量調整 MET 值
    if (weight != null && weight > 0) {
      // 重量越大，消耗越高
      // 假設：20kg 以下是輕量，20-40kg 是中量，40kg 以上是重量
      if (weight >= 40) {
        met = met * 1.3; // 重量增加 30%
      } else if (weight >= 20) {
        met = met * 1.15; // 中量增加 15%
      }
    }

    // 3. 根據組數和次數調整（高組數高次數代表更高強度）
    if (sets != null && reps != null) {
      int totalReps = sets * reps;
      if (totalReps > 50) {
        met = met * 1.2; // 高訓練量增加 20%
      } else if (totalReps > 30) {
        met = met * 1.1; // 中訓練量增加 10%
      }
    }

    // 4. 計算卡路里
    // 公式: 卡路里 = MET × 體重(kg) × 時間(小時)
    const double standardBodyWeight = 70.0; // 標準體重 70kg
    double hours = durationSeconds / 3600.0;
    double calories = met * standardBodyWeight * hours;

    // 5. 確保最小值
    if (calories < 1.0) {
      calories = durationSeconds / 60.0; // 每分鐘至少 1 卡
    }

    if (kDebugMode) {
      debugPrint('💪 卡路里計算: $exerciseName');
      debugPrint('   MET: ${met.toStringAsFixed(1)}');
      debugPrint('   時長: ${durationSeconds}秒');
      debugPrint('   結果: ${calories.toStringAsFixed(1)} 卡');
    }

    return calories;
  }

  /// 根據動作名稱取得 MET 值
  double _getMetValueFromExerciseName(String name) {
    final nameLower = name.toLowerCase();

    // 高強度動作 (MET 6.0-8.0)
    if (nameLower.contains('深蹲') || 
        nameLower.contains('squat') ||
        nameLower.contains('硬舉') || 
        nameLower.contains('deadlift')) {
      return 7.0;
    }

    // 中高強度 (MET 5.0-6.0)
    if (nameLower.contains('臥推') || 
        nameLower.contains('bench press') ||
        nameLower.contains('肩推') || 
        nameLower.contains('shoulder press') ||
        nameLower.contains('划船') || 
        nameLower.contains('row')) {
      return 5.5;
    }

    // 中等強度 (MET 4.0-5.0)
    if (nameLower.contains('彎舉') || 
        nameLower.contains('curl') ||
        nameLower.contains('飛鳥') || 
        nameLower.contains('fly') ||
        nameLower.contains('下拉') || 
        nameLower.contains('pulldown')) {
      return 4.5;
    }

    // 低強度 (MET 3.0-4.0)
    if (nameLower.contains('伸展') || 
        nameLower.contains('stretch') ||
        nameLower.contains('捲腹') || 
        nameLower.contains('crunch')) {
      return 3.5;
    }

    // 有氧運動 (MET 6.0-8.0)
    if (nameLower.contains('跑步') || 
        nameLower.contains('running') ||
        nameLower.contains('踩腳踏車') || 
        nameLower.contains('cycling')) {
      return 7.0;
    }

    // 預設中等強度
    return 5.0;
  }

  /// 🔥 計算整個 session 的總卡路里
  double calculateSessionTotalCalories(List<dynamic> exercises) {
    double totalCalories = 0.0;

    for (var exercise in exercises) {
      final exerciseName = exercise['exerciseName'] as String? ?? '';
      final sets = exercise['sets'] as List? ?? [];
      
      // 計算該動作的總時長（所有組的時長加總）
      int totalDurationSeconds = 0;
      double totalWeight = 0.0;
      int validSetsCount = 0;

      for (var set in sets) {
        final duration = set['duration'] as int? ?? 0;
        final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
        
        totalDurationSeconds += duration;
        if (weight > 0) {
          totalWeight += weight;
          validSetsCount++;
        }
      }

      // 計算平均重量
      double avgWeight = validSetsCount > 0 ? totalWeight / validSetsCount : 0.0;

      // 計算該動作的卡路里
      if (totalDurationSeconds > 0) {
        double exerciseCalories = calculateCaloriesForExercise(
          exerciseName: exerciseName,
          durationSeconds: totalDurationSeconds,
          weight: avgWeight > 0 ? avgWeight : null,
          sets: sets.length,
          reps: null, // 這裡可以進一步計算總次數
        );

        totalCalories += exerciseCalories;
      }
    }

    if (kDebugMode) {
      debugPrint('🔥 Session 總卡路里: ${totalCalories.toStringAsFixed(1)}');
    }

    return totalCalories;
  }
}