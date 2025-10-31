// lib/services/unified_workout_service.dart
// 🔧 統一訓練記錄服務 - 增強版：詳細調試 + 更強容錯

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UnifiedWorkoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// 🔥 統一新增運動記錄（同時寫入新舊兩個系統）
  Future<String> addWorkoutLog({
    required String type,
    required String name,
    required int duration,
    required int sets,
    required int reps,
    double? weight,
    double? caloriesBurned,
    String? intensity,
    String? notes,
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
      'sets': sets,
      'reps': reps,
      if (weight != null) 'weight': weight,
      'caloriesBurned': calories,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
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
        met = 4.5; // 🔧 降低重量訓練的 MET 值
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
        met = 4.0; // 🔧 降低預設值
    }

    // 🔧 使用更合理的體重（如果沒有提供重量，使用 65kg）
    double bodyWeight = 65.0;
    
    // 🔧 如果是重量訓練且有重量，不使用重量作為體重
    // 重量是訓練負重，不是體重
    
    // 卡路里 = MET × 體重(kg) × 時間(小時)
    double hours = duration / 60.0;
    double calories = met * bodyWeight * hours;
    
    // 🔧 確保最小值為 10 卡
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
          // 輸出第一筆記錄詳情
          if (newSnapshot.docs.isNotEmpty) {
            var firstDoc = newSnapshot.docs.first.data() as Map<String, dynamic>;
            debugPrint('   第一筆: ${firstDoc['name']} (date: ${firstDoc['date']})');
          }
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
        
        // 🔧 詳細調試：輸出所有文檔的 date 欄位
        if (oldSnapshot.docs.isEmpty) {
          debugPrint('⚠️ 舊系統也沒有數據！');
          debugPrint('   嘗試查詢所有該用戶的記錄...');
          
          // 查詢所有記錄看看有什麼
          QuerySnapshot allDocs = await _firestore
              .collection('workoutLogs')
              .where('userId', isEqualTo: _currentUserId!)
              .limit(10)
              .get();
          
          debugPrint('   該用戶總共有 ${allDocs.docs.length} 筆記錄');
          for (var doc in allDocs.docs) {
            var data = doc.data() as Map<String, dynamic>;
            debugPrint('   - ID: ${doc.id}, date: ${data['date']}, name: ${data['name']}');
          }
        } else {
          // 輸出找到的記錄
          for (var doc in oldSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;
            debugPrint('   找到: ${data['name']} (date: ${data['date']})');
          }
        }
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
        debugPrint('   堆疊追蹤: ${StackTrace.current}');
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
}