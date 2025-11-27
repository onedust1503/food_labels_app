// lib/services/nutrition_service.dart
// 飲食記錄服務層 - 完整版本(支援詳細營養素 + 快速新增 + 組合標記 + 掃描記錄)
// ✨ v2.1: 新增 addScanLog 方法和 recordMethod 參數

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nutrition_log.dart';
import '../constants/collections.dart';

class NutritionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== 核心功能 ==========

  /// 新增飲食記錄(從食物資料庫選擇或掃描)
  /// 
  /// [recordMethod] 記錄方式，可選值:
  /// - 'search': 從食物資料庫搜尋 (預設)
  /// - 'scan': OCR 掃描
  /// - 'quick' / 'manual': 手動輸入
  /// - 'combo': 組合記錄
  /// 
  /// 如果不傳入 recordMethod，會自動根據 foodData 中的標記判斷
  Future<void> addFoodLog({
    required Map<String, dynamic> foodData,
    required double servings,
    required String mealType,
    String? recordMethod,  // ✅ 新增：可選的記錄方式參數
  }) async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // 計算基本營養素
    double totalCalories = ((foodData['calories'] ?? 0) as num).toDouble() * servings;
    double totalProtein = ((foodData['protein'] ?? 0) as num).toDouble() * servings;
    double totalCarbs = ((foodData['carbs'] ?? 0) as num).toDouble() * servings;
    double totalFat = ((foodData['fat'] ?? 0) as num).toDouble() * servings;

    // ✅ 計算詳細營養素
    double totalSaturatedFat = ((foodData['saturatedFat'] ?? 0) as num).toDouble() * servings;
    double totalTransFat = ((foodData['transFat'] ?? 0) as num).toDouble() * servings;
    double totalFiber = ((foodData['fiber'] ?? 0) as num).toDouble() * servings;
    double totalSugar = ((foodData['sugar'] ?? 0) as num).toDouble() * servings;
    double totalSodium = ((foodData['sodium'] ?? 0) as num).toDouble() * servings;
    double totalCholesterol = ((foodData['cholesterol'] ?? 0) as num).toDouble() * servings;

    // ✅ 決定記錄方式：優先使用傳入的參數，否則自動檢測
    String finalRecordMethod = recordMethod ?? 'search';
    if (recordMethod == null) {
      // 自動檢測
      if (foodData['isScanned'] == true) {
        finalRecordMethod = 'scan';
      } else if (foodData['isManual'] == true) {
        finalRecordMethod = 'quick';
      }
    }

    // 儲存到 Firestore
    await _firestore.collection(Collections.nutritionLogs).add({
      'userId': userId,
      'date': today,
      'mealType': mealType,
      'foodName': foodData['name'] ?? '未命名食物',
      'foodId': foodData['id'],
      'servings': servings,
      'servingSize': foodData['servingSize'] ?? '1份',
      
      // 基本營養素
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      
      // ✅ 詳細營養素
      'saturatedFat': totalSaturatedFat,
      'transFat': totalTransFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'sodium': totalSodium,
      'cholesterol': totalCholesterol,
      
      'recordMethod': finalRecordMethod, // ✅ 使用決定後的記錄方式
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 更新當日總計
    await _updateDailySummary(userId, today, {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    });
    
    print('✅ 記錄成功: ${foodData['name']} [$finalRecordMethod]');
  }

  /// 🆕 快速新增飲食記錄(手動輸入/OCR掃描)
  /// 
  /// 使用場景:
  /// - 手動輸入營養素
  /// - OCR 掃描食品標籤
  /// - 一次性食物記錄(不加入食物庫)
  /// 
  /// 所有營養素都是「每份」的數值,會自動乘以份數計算總量
  Future<void> addQuickLog({
    required String foodName,
    required String mealType,
    required double servings,
    required String servingSize,
    // 基本營養素 (每份的量)
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    // ✅ 詳細營養素 (每份的量,選填)
    double saturatedFat = 0,
    double transFat = 0,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    double cholesterol = 0,
    // ✅ 記錄方式 (新增參數)
    String recordMethod = 'quick',
  }) async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    // 計算實際攝取總量 (每份 × 份數)
    double totalCalories = calories * servings;
    double totalProtein = protein * servings;
    double totalCarbs = carbs * servings;
    double totalFat = fat * servings;
    double totalSaturatedFat = saturatedFat * servings;
    double totalTransFat = transFat * servings;
    double totalFiber = fiber * servings;
    double totalSugar = sugar * servings;
    double totalSodium = sodium * servings;
    double totalCholesterol = cholesterol * servings;

    // 儲存到 Firestore nutritionLogs
    await _firestore.collection(Collections.nutritionLogs).add({
      'userId': userId,
      'date': today,
      'mealType': mealType,
      'foodName': foodName,
      'foodId': null, // 快速新增沒有 foodId
      'servings': servings,
      'servingSize': servingSize,
      
      // 基本營養素 (總量)
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      
      // ✅ 詳細營養素 (總量)
      'saturatedFat': totalSaturatedFat,
      'transFat': totalTransFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'sodium': totalSodium,
      'cholesterol': totalCholesterol,
      
      'recordMethod': recordMethod, // ✅ 使用傳入的記錄方式
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 更新當日總計
    await _updateDailySummary(userId, today, {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    });

    print('✅ 快速新增成功: $foodName (${servings} ${servingSize}) [$recordMethod]');
  }

  /// 🆕 OCR 掃描記錄專用方法
  /// 
  /// 使用場景:
  /// - OCR 掃描食品標籤後記錄
  /// 
  /// 營養素數值會自動乘以份數計算總量
  Future<void> addScanLog({
    required String foodName,
    required String mealType,
    required double servings,
    String servingSize = '每份',
    // 基本營養素 (每份的量)
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    // 詳細營養素 (每份的量,選填)
    double? sugar,
    double? sodium,
    double? saturatedFat,
    double? transFat,
    double? fiber,        // 🔥 新增
    double? cholesterol,  // 🔥 新增
  }) async {
    await addQuickLog(
      foodName: foodName,
      mealType: mealType,
      servings: servings,
      servingSize: servingSize,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: sugar ?? 0,
      sodium: sodium ?? 0,
      saturatedFat: saturatedFat ?? 0,
      transFat: transFat ?? 0,
      fiber: fiber ?? 0,          // 🔥 新增
      cholesterol: cholesterol ?? 0,  // 🔥 新增
      recordMethod: 'scan', // ✅ 標記為掃描記錄
    );
    
    print('📷 掃描記錄成功: $foodName');
  }

  /// 🆕 記錄食物 (帶組合標記)
  /// 用於從組合記錄食物時,標記來源組合
  Future<void> addFoodLogWithComboTag({
    required Map<String, dynamic> foodData,
    required double servings,
    required String mealType,
    required String comboId,
    required String comboName,
    required Timestamp timestamp, // 使用統一的時間戳
  }) async {
    try {
      String userId = _auth.currentUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];

      // 計算營養素
      double calories = ((foodData['calories'] ?? 0) as num).toDouble() * servings;
      double protein = ((foodData['protein'] ?? 0) as num).toDouble() * servings;
      double carbs = ((foodData['carbs'] ?? 0) as num).toDouble() * servings;
      double fat = ((foodData['fat'] ?? 0) as num).toDouble() * servings;

      // 🆕 新增到 nutritionLogs,並加入組合標記
      await _firestore.collection(Collections.nutritionLogs).add({
        'userId': userId,
        'date': today,
        'mealType': mealType,
        'foodId': foodData['id'],
        'foodName': foodData['name'],
        'servingSize': foodData['servingSize'],
        'servings': servings,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'saturatedFat': ((foodData['saturatedFat'] ?? 0) as num).toDouble() * servings,
        'transFat': ((foodData['transFat'] ?? 0) as num).toDouble() * servings,
        'fiber': ((foodData['fiber'] ?? 0) as num).toDouble() * servings,
        'sugar': ((foodData['sugar'] ?? 0) as num).toDouble() * servings,
        'sodium': ((foodData['sodium'] ?? 0) as num).toDouble() * servings,
        'cholesterol': ((foodData['cholesterol'] ?? 0) as num).toDouble() * servings,
        
        // ✨ 組合標記 (新增欄位)
        'isFromCombo': true,
        'comboId': comboId,
        'comboName': comboName,
        
        'recordMethod': 'combo', // 標記為組合記錄
        'createdAt': timestamp, // 使用傳入的統一時間戳
        'updatedAt': timestamp,
      });

      // 更新每日總計
      await _updateDailySummary(userId, today, {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      });

      print('✅ 記錄食物 (來自組合: $comboName): ${foodData['name']}');
    } catch (e) {
      print('❌ 記錄食物失敗: $e');
      rethrow;
    }
  }

  /// 更新每日總計
  Future<void> _updateDailySummary(
    String userId,
    String date,
    Map<String, double> nutrients,
  ) async {
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

  /// 獲取今日營養總計
  Future<Map<String, dynamic>> getTodayNutrition() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

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

  /// 獲取今日飲食記錄(Map 版本)
  Future<List<Map<String, dynamic>>> getTodayLogs() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

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

  // ========== 型別安全版本(使用模型)==========

  /// 獲取今日飲食記錄(返回模型)
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

  /// 獲取今日飲食記錄(即時串流)
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

  /// 獲取使用者的所有記錄(即時串流)
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

  /// 獲取最近 N 天的記錄
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

  /// 獲取特定日期的記錄
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

  // ========== 記錄管理 ==========

  /// 刪除記錄(會更新 dailySummary)
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

      // 更新每日總計(扣除)
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

  /// 更新記錄
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

  /// 計算某天的總熱量(從 nutritionLogs 計算)
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

  /// 獲取特定日期的營養總計(從 dailySummary)
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