// lib/services/nutrition_service.dart
// 飲食記錄服務層 - 改進版本（保留所有原有功能）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nutrition_log.dart';
import '../constants/collections.dart';

class NutritionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== 原有功能（保留並改進）==========

  /// 新增飲食記錄（原有方法）
  Future<void> addFoodLog({
    required Map<String, dynamic> foodData,
    required double servings,
    required String mealType,
  }) async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    double totalCalories = (foodData['calories'] ?? 0) * servings;
    double totalProtein = (foodData['protein'] ?? 0) * servings;
    double totalCarbs = (foodData['carbs'] ?? 0) * servings;
    double totalFat = (foodData['fat'] ?? 0) * servings;

    // ✅ 使用 Collections 常量
    await _firestore.collection(Collections.nutritionLogs).add({
      'userId': userId,
      'date': today,
      'mealType': mealType,
      'foodName': foodData['name'],
      'foodId': foodData['id'],
      'servings': servings,
      'servingSize': foodData['servingSize'],
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'recordMethod': 'search',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 更新當日總計
    await _updateDailySummary(userId, today, {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    });
  }

  /// 更新每日總計（原有方法）
  Future<void> _updateDailySummary(
    String userId,
    String date,
    Map<String, double> nutrients,
  ) async {
    // ✅ 使用 Collections 常量
    DocumentReference summaryRef = _firestore
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.dailySummary)
        .doc(date);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(summaryRef);

      if (snapshot.exists) {
        // 累加數值
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        transaction.update(summaryRef, {
          'totalCalories': (data['totalCalories'] ?? 0) + nutrients['calories']!,
          'totalProtein': (data['totalProtein'] ?? 0) + nutrients['protein']!,
          'totalCarbs': (data['totalCarbs'] ?? 0) + nutrients['carbs']!,
          'totalFat': (data['totalFat'] ?? 0) + nutrients['fat']!,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 創建新記錄
        transaction.set(summaryRef, {
          'date': date,
          'totalCalories': nutrients['calories'],
          'totalProtein': nutrients['protein'],
          'totalCarbs': nutrients['carbs'],
          'totalFat': nutrients['fat'],
          'targetCalories': 1850, // 預設目標
          'targetProtein': 52,
          'targetCarbs': 178,
          'targetFat': 122,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 獲取今日營養總計（原有方法）
  Future<Map<String, dynamic>> getTodayNutrition() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // ✅ 使用 Collections 常量
    DocumentSnapshot doc = await _firestore
        .collection(Collections.users)
        .doc(userId)
        .collection(Collections.dailySummary)
        .doc(today)
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }

    // 返回預設值
    return {
      'totalCalories': 0,
      'totalProtein': 0.0,
      'totalCarbs': 0.0,
      'totalFat': 0.0,
      'targetCalories': 1850,
      'targetProtein': 52,
      'targetCarbs': 178,
      'targetFat': 122,
    };
  }

  /// 獲取今日飲食記錄（原有方法）
  Future<List<Map<String, dynamic>>> getTodayLogs() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // ✅ 使用 Collections 常量
    QuerySnapshot snapshot = await _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
    }).toList();
  }

  // ========== 新增功能（使用模型）==========

  /// 🆕 獲取今日飲食記錄（返回模型）- 型別安全版本
  Future<List<NutritionLog>> getTodayLogsTyped() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => NutritionLog.fromFirestore(doc))
        .toList();
  }

  /// 🆕 獲取今日飲食記錄（即時串流）
  Stream<List<NutritionLog>> getTodayLogsStream() {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    return _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NutritionLog.fromFirestore(doc))
              .toList();
        });
  }

  /// 🆕 獲取使用者的所有記錄（即時串流）
  Stream<List<NutritionLog>> getUserLogsStream(String userId) {
    return _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NutritionLog.fromFirestore(doc))
              .toList();
        });
  }

  /// 🆕 獲取最近 N 天的記錄
  Stream<List<NutritionLog>> getRecentLogs(String userId, {int days = 30}) {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final startDateStr = startDate.toIso8601String().split('T')[0];

    return _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .orderBy('date', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NutritionLog.fromFirestore(doc))
              .toList();
        });
  }

  /// 🆕 獲取特定日期的記錄
  Stream<List<NutritionLog>> getLogsForDate(String userId, DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];

    return _firestore
        .collection(Collections.nutritionLogs)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateStr)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NutritionLog.fromFirestore(doc))
              .toList();
        });
  }

  /// 🆕 刪除記錄（會更新 dailySummary）
  Future<void> deleteLog(String logId) async {
    try {
      // 先獲取記錄資料
      final doc = await _firestore
          .collection(Collections.nutritionLogs)
          .doc(logId)
          .get();

      if (!doc.exists) {
        throw Exception('記錄不存在');
      }

      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'];
      final date = data['date'];
      final calories = (data['calories'] ?? 0).toDouble();
      final protein = (data['protein'] ?? 0).toDouble();
      final carbs = (data['carbs'] ?? 0).toDouble();
      final fat = (data['fat'] ?? 0).toDouble();

      // 刪除記錄
      await _firestore
          .collection(Collections.nutritionLogs)
          .doc(logId)
          .delete();

      // 更新每日總計（扣除）
      await _updateDailySummary(userId, date, {
        'calories': -calories,
        'protein': -protein,
        'carbs': -carbs,
        'fat': -fat,
      });

      print('✅ 刪除記錄成功: $logId');
    } catch (e) {
      print('❌ 刪除記錄失敗: $e');
      rethrow;
    }
  }

  /// 🆕 更新記錄
  Future<void> updateLog(String logId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(Collections.nutritionLogs)
          .doc(logId)
          .update(data);

      print('✅ 更新記錄成功: $logId');
    } catch (e) {
      print('❌ 更新記錄失敗: $e');
      rethrow;
    }
  }

  // ========== 統計查詢 ==========

  /// 🆕 計算某天的總熱量（從 nutritionLogs 計算）
  Future<int> getTotalCaloriesForDate(String userId, String date) async {
    try {
      final snapshot = await _firestore
          .collection(Collections.nutritionLogs)
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: date)
          .get();

      final logs = snapshot.docs
          .map((doc) => NutritionLog.fromFirestore(doc))
          .toList();

      return logs.fold<int>(0, (sum, log) => sum + log.calories);
    } catch (e) {
      print('❌ 計算總熱量失敗: $e');
      return 0;
    }
  }

  /// 🆕 獲取特定日期的營養總計（從 dailySummary）
  Future<Map<String, dynamic>> getNutritionForDate(String userId, String date) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.dailySummary)
          .doc(date)
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }

      return {
        'totalCalories': 0,
        'totalProtein': 0.0,
        'totalCarbs': 0.0,
        'totalFat': 0.0,
      };
    } catch (e) {
      print('❌ 獲取營養總計失敗: $e');
      return {
        'totalCalories': 0,
        'totalProtein': 0.0,
        'totalCarbs': 0.0,
        'totalFat': 0.0,
      };
    }
  }
}