// lib/services/food_database_service.dart
// 食物資料庫服務 - 修復版(支援 JSON 導入的資料 + 優雅處理權限錯誤)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FoodDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ 獲取所有食物 - 修復版(移除 isPublic 限制 + 優雅處理 customFoods 錯誤)
  Future<List<Map<String, dynamic>>> getAllFoods() async {
    try {
      if (kDebugMode) {
        print('🔍 開始獲取所有食物...');
      }

      // ✅ 移除 isPublic 限制,因為 JSON 導入的資料沒有這個欄位
      QuerySnapshot snapshot = await _firestore
          .collection('foods')
          .orderBy('name')
          .limit(500)
          .get();

      if (kDebugMode) {
        print('📊 從 Firestore 獲取到 ${snapshot.docs.length} 筆食物');
      }

      List<Map<String, dynamic>> allFoods = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // ✅ 如果使用者已登入,嘗試獲取使用者的自訂食物 (但不強制)
      if (_auth.currentUser != null) {
        String userId = _auth.currentUser!.uid;
        
        try {
          // ✅ 嘗試讀取自訂食物
          QuerySnapshot customSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('customFoods')
              .orderBy('name')
              .get();

          if (kDebugMode) {
            print('👤 使用者自訂食物: ${customSnapshot.docs.length} 筆');
          }

          List<Map<String, dynamic>> customFoods = customSnapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['isCustom'] = true;
            return data;
          }).toList();

          allFoods.addAll(customFoods);
          
        } catch (e) {
          // ✅ 關鍵修改: 如果讀取 customFoods 失敗,只記錄警告,不影響主功能
          if (kDebugMode) {
            print('⚠️ 無法讀取自訂食物 (可能是權限問題): $e');
            print('   → 繼續使用系統食物 (${allFoods.length} 筆)');
          }
          // ✅ 不拋出異常,繼續執行
        }
      }

      if (kDebugMode) {
        print('✅ getAllFoods 成功: 共 ${allFoods.length} 項食物');
        if (allFoods.isNotEmpty) {
          print('📝 範例食物: ${allFoods.first['name']} (${allFoods.first['category']})');
        }
      }
      
      return allFoods;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取所有食物失敗: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
      }
      return [];
    }
  }

  /// ✅ 搜尋食物 - 修復版(支援中文模糊搜尋)
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    try {
      // 1️⃣ 先獲取所有食物
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      if (kDebugMode) {
        print('🔍 搜尋: "$query", 資料庫共 ${allFoods.length} 項食物');
      }

      // 2️⃣ 如果沒有輸入關鍵字,返回所有食物
      if (query.isEmpty || query.trim().isEmpty) {
        if (kDebugMode) {
          print('✅ 返回所有 ${allFoods.length} 項食物');
        }
        return allFoods;
      }

      // 3️⃣ 客戶端模糊搜尋 (支援中文)
      String lowerQuery = query.toLowerCase().trim();
      
      List<Map<String, dynamic>> results = allFoods.where((food) {
        String foodName = (food['name'] ?? '').toString().toLowerCase();
        String category = (food['category'] ?? '').toString().toLowerCase();
        
        // 搜尋名稱或分類包含關鍵字
        return foodName.contains(lowerQuery) || 
               category.contains(lowerQuery);
      }).toList();

      if (kDebugMode) {
        print('✅ 找到 ${results.length} 項符合 "$query" 的食物');
        if (results.isNotEmpty) {
          print('📝 範例結果: ${results.first['name']}');
        }
      }
      
      return results;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 搜尋食物失敗: $e');
      }
      return [];
    }
  }

  /// 獲取所有食物(分類)
  Future<Map<String, List<Map<String, dynamic>>>> getAllFoodsByCategory() async {
    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      Map<String, List<Map<String, dynamic>>> foodsByCategory = {};

      for (var food in allFoods) {
        String category = food['category'] ?? '其他';

        if (!foodsByCategory.containsKey(category)) {
          foodsByCategory[category] = [];
        }
        foodsByCategory[category]!.add(food);
      }

      if (kDebugMode) {
        print('📂 共 ${foodsByCategory.length} 個分類');
        foodsByCategory.forEach((category, foods) {
          print('  - $category: ${foods.length} 項');
        });
      }

      return foodsByCategory;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取分類失敗: $e');
      }
      return {};
    }
  }

  /// 新增自訂食物
  Future<void> addCustomFood({
    required String name,
    required String category,
    required String servingSize,
    required int servingSizeGram,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double saturatedFat = 0,
    double transFat = 0,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    double cholesterol = 0,
    bool isPublic = false,
  }) async {
    String userId = _auth.currentUser!.uid;

    await _firestore.collection('foods').add({
      'name': name,
      'category': category,
      'servingSize': servingSize,
      'servingSizeGram': servingSizeGram,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'saturatedFat': saturatedFat,
      'transFat': transFat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'cholesterol': cholesterol,
      'isPublic': isPublic,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      print('✅ 新增自訂食物: $name');
    }
  }

  /// 獲取食物詳細資訊
  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('foods')
          .doc(foodId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取食物詳情失敗: $e');
      }
      return null;
    }
  }

  /// 獲取我的自訂食物
  Future<List<Map<String, dynamic>>> getMyCustomFoods() async {
    try {
      String userId = _auth.currentUser!.uid;

      QuerySnapshot snapshot = await _firestore
          .collection('foods')
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取自訂食物失敗: $e');
      }
      return [];
    }
  }

  /// ✅ 初始化基礎食物資料庫(只需執行一次)
  /// 注意: 如果你使用 JSON 導入,就不需要這個方法
  Future<void> initializeFoodDatabase() async {
    try {
      // 檢查是否已經初始化過
      QuerySnapshot existing = await _firestore.collection('foods').limit(1).get();
      if (existing.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠️ 食物資料庫已存在,跳過初始化');
        }
        return;
      }

      if (kDebugMode) {
        print('🚀 開始初始化食物資料庫...');
      }

      List<Map<String, dynamic>> basicFoods = [
        {
          'name': '白飯',
          'category': '中式主食',
          'servingSize': '1碗',
          'servingSizeGram': 200,
          'calories': 280,
          'protein': 5.2,
          'carbs': 62.0,
          'fat': 0.6,
          'saturatedFat': 0.2,
          'transFat': 0.0,
          'fiber': 0.6,
          'sugar': 0.1,
          'sodium': 2.0,
          'cholesterol': 0.0,
          'createdBy': 'system',
        },
        {
          'name': '雞胸肉',
          'category': '蛋白質',
          'servingSize': '1份',
          'servingSizeGram': 100,
          'calories': 165,
          'protein': 31.0,
          'carbs': 0.0,
          'fat': 3.6,
          'saturatedFat': 1.0,
          'transFat': 0.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 74.0,
          'cholesterol': 85.0,
          'createdBy': 'system',
        },
      ];

      WriteBatch batch = _firestore.batch();
      for (var food in basicFoods) {
        DocumentReference docRef = _firestore.collection('foods').doc();
        batch.set(docRef, {
          ...food,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      if (kDebugMode) {
        print('✅ 食物資料庫初始化完成!共新增 ${basicFoods.length} 項食物');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 初始化失敗: $e');
      }
    }
  }
}