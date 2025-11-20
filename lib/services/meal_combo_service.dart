// lib/services/meal_combo_service.dart
// 餐點組合服務層 - 管理使用者的組合餐點
// ✅ 改進版: 記錄時加入組合標籤和批次時間戳

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'nutrition_service.dart';

class MealComboService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NutritionService _nutritionService = NutritionService();

  // ========== 組合管理 ==========

  /// ✅ 建立新組合
  Future<String> createCombo({
    required String comboName,
    required String category,
    required List<Map<String, dynamic>> foods, // [{foodData, servings}]
  }) async {
    String userId = _auth.currentUser!.uid;

    // 計算組合的總營養素
    Map<String, double> totals = _calculateComboNutrition(foods);

    DocumentReference docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealCombos')
        .add({
      'comboName': comboName,
      'category': category,
      'foods': foods.map((item) => {
        'foodId': item['foodData']['id'],
        'foodName': item['foodData']['name'],
        'servings': item['servings'],
        'servingSize': item['foodData']['servingSize'],
        'calories': (item['foodData']['calories'] ?? 0) * item['servings'],
        'protein': (item['foodData']['protein'] ?? 0) * item['servings'],
        'carbs': (item['foodData']['carbs'] ?? 0) * item['servings'],
        'fat': (item['foodData']['fat'] ?? 0) * item['servings'],
        'saturatedFat': (item['foodData']['saturatedFat'] ?? 0) * item['servings'],
        'transFat': (item['foodData']['transFat'] ?? 0) * item['servings'],
        'fiber': (item['foodData']['fiber'] ?? 0) * item['servings'],
        'sugar': (item['foodData']['sugar'] ?? 0) * item['servings'],
        'sodium': (item['foodData']['sodium'] ?? 0) * item['servings'],
        'cholesterol': (item['foodData']['cholesterol'] ?? 0) * item['servings'],
        'isCustom': item['foodData']['isCustom'] ?? false,
      }).toList(),
      'totalCalories': totals['calories'],
      'totalProtein': totals['protein'],
      'totalCarbs': totals['carbs'],
      'totalFat': totals['fat'],
      'itemCount': foods.length,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      print('✅ 建立組合: $comboName (ID: ${docRef.id})');
    }

    return docRef.id;
  }

  /// ✅ 獲取我的組合列表
  Future<List<Map<String, dynamic>>> getMyCombos() async {
    try {
      String userId = _auth.currentUser!.uid;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mealCombos')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> combos = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (kDebugMode) {
        print('✅ 獲取組合: ${combos.length} 項');
      }

      return combos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取組合失敗: $e');
      }
      return [];
    }
  }

  /// ✅ 獲取組合即時串流
  Stream<List<Map<String, dynamic>>> getMyCombosStream() {
    String userId = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('mealCombos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// ✅ 更新組合
  Future<void> updateCombo({
    required String comboId,
    required String comboName,
    required String category,
    required List<Map<String, dynamic>> foods,
  }) async {
    String userId = _auth.currentUser!.uid;

    Map<String, double> totals = _calculateComboNutrition(foods);

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealCombos')
        .doc(comboId)
        .update({
      'comboName': comboName,
      'category': category,
      'foods': foods.map((item) => {
        'foodId': item['foodData']['id'],
        'foodName': item['foodData']['name'],
        'servings': item['servings'],
        'servingSize': item['foodData']['servingSize'],
        'calories': (item['foodData']['calories'] ?? 0) * item['servings'],
        'protein': (item['foodData']['protein'] ?? 0) * item['servings'],
        'carbs': (item['foodData']['carbs'] ?? 0) * item['servings'],
        'fat': (item['foodData']['fat'] ?? 0) * item['servings'],
        'saturatedFat': (item['foodData']['saturatedFat'] ?? 0) * item['servings'],
        'transFat': (item['foodData']['transFat'] ?? 0) * item['servings'],
        'fiber': (item['foodData']['fiber'] ?? 0) * item['servings'],
        'sugar': (item['foodData']['sugar'] ?? 0) * item['servings'],
        'sodium': (item['foodData']['sodium'] ?? 0) * item['servings'],
        'cholesterol': (item['foodData']['cholesterol'] ?? 0) * item['servings'],
        'isCustom': item['foodData']['isCustom'] ?? false,
      }).toList(),
      'totalCalories': totals['calories'],
      'totalProtein': totals['protein'],
      'totalCarbs': totals['carbs'],
      'totalFat': totals['fat'],
      'itemCount': foods.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      print('✅ 更新組合: $comboName');
    }
  }

  /// ✅ 刪除組合
  Future<void> deleteCombo(String comboId) async {
    String userId = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('mealCombos')
        .doc(comboId)
        .delete();

    if (kDebugMode) {
      print('✅ 刪除組合: $comboId');
    }
  }

  /// ✅ 獲取單一組合詳情
  Future<Map<String, dynamic>?> getComboById(String comboId) async {
    try {
      String userId = _auth.currentUser!.uid;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mealCombos')
          .doc(comboId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取組合詳情失敗: $e');
      }
      return null;
    }
  }

  // ========== 組合記錄功能 (改進版) ==========

  /// ✅ 記錄組合(會分別記錄每個食物,並標記為組合)
  /// 🆕 改進: 
  /// 1. 所有食物使用相同的時間戳 (同一餐)
  /// 2. 加入 comboId 和 comboName 標記
  /// 3. 加入 isFromCombo 標記
  Future<void> logCombo({
    required String comboId,
    required String comboName,
    required List<dynamic> foods, // 來自 combo 的 foods 陣列
    required String mealType,
  }) async {
    try {
      if (kDebugMode) {
        print('🍽️ 開始記錄組合: $comboName');
      }

      // 🆕 生成統一的時間戳 (確保所有食物是同一時間記錄的)
      final Timestamp batchTimestamp = Timestamp.now();

      // 為每個食物建立記錄
      for (var food in foods) {
        Map<String, dynamic> foodData = {
          'id': food['foodId'],
          'name': food['foodName'],
          'servingSize': food['servingSize'],
          'calories': food['calories'] / food['servings'], // 還原每份熱量
          'protein': food['protein'] / food['servings'],
          'carbs': food['carbs'] / food['servings'],
          'fat': food['fat'] / food['servings'],
          'saturatedFat': (food['saturatedFat'] ?? 0) / food['servings'],
          'transFat': (food['transFat'] ?? 0) / food['servings'],
          'fiber': (food['fiber'] ?? 0) / food['servings'],
          'sugar': (food['sugar'] ?? 0) / food['servings'],
          'sodium': (food['sodium'] ?? 0) / food['servings'],
          'cholesterol': (food['cholesterol'] ?? 0) / food['servings'],
        };

        // 🆕 使用 NutritionService 記錄,但加入組合標記
        await _nutritionService.addFoodLogWithComboTag(
          foodData: foodData,
          servings: food['servings'].toDouble(),
          mealType: mealType,
          // 🆕 組合標記
          comboId: comboId,
          comboName: comboName,
          timestamp: batchTimestamp, // 🆕 使用統一時間戳
        );
      }

      if (kDebugMode) {
        print('✅ 組合記錄完成: $comboName (共 ${foods.length} 項食物)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 記錄組合失敗: $e');
      }
      rethrow;
    }
  }

  // ========== 輔助方法 ==========

  /// 計算組合的總營養素
  Map<String, double> _calculateComboNutrition(List<Map<String, dynamic>> foods) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var item in foods) {
      Map<String, dynamic> food = item['foodData'];
      double servings = item['servings'];

      totalCalories += (food['calories'] ?? 0) * servings;
      totalProtein += (food['protein'] ?? 0) * servings;
      totalCarbs += (food['carbs'] ?? 0) * servings;
      totalFat += (food['fat'] ?? 0) * servings;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  /// ✅ 複製組合
  Future<String> duplicateCombo(String comboId) async {
    try {
      Map<String, dynamic>? original = await getComboById(comboId);
      if (original == null) {
        throw Exception('組合不存在');
      }

      String userId = _auth.currentUser!.uid;

      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mealCombos')
          .add({
        'comboName': '${original['comboName']} (複製)',
        'category': original['category'],
        'foods': original['foods'],
        'totalCalories': original['totalCalories'],
        'totalProtein': original['totalProtein'],
        'totalCarbs': original['totalCarbs'],
        'totalFat': original['totalFat'],
        'itemCount': original['itemCount'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ 複製組合: ${original['comboName']}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 複製組合失敗: $e');
      }
      rethrow;
    }
  }
}