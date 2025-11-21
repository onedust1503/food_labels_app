// lib/services/food_database_service.dart
// 食物資料庫服務 - 完整版 (支援 JSON 導入 + 自訂食物管理 + 我的最愛)
// ✨ v2.0: 新增我的最愛功能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FoodDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 🎯 緩存機制 (避免重複查詢)
  List<Map<String, dynamic>>? _cachedFoods;
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // 🆕 最愛緩存
  Set<String>? _cachedFavoriteIds;
  DateTime? _lastFavoriteFetchTime;

  // ========== 食物資料庫查詢 ==========

  /// ✅ 獲取所有食物 (系統 + 自訂) - 帶緩存
  Future<List<Map<String, dynamic>>> getAllFoods({bool forceRefresh = false}) async {
    try {
      // 檢查緩存是否有效
      if (!forceRefresh && 
          _cachedFoods != null && 
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
        if (kDebugMode) {
          print('✅ 使用緩存資料 (${_cachedFoods!.length} 項)');
        }
        return _cachedFoods!;
      }

      if (kDebugMode) {
        print('🔍 開始獲取所有食物...');
      }

      // 1️⃣ 獲取系統食物
      QuerySnapshot snapshot = await _firestore
          .collection('foods')
          .orderBy('name')
          .limit(500)
          .get();

      if (kDebugMode) {
        print('📊 從 Firestore 獲取到 ${snapshot.docs.length} 筆系統食物');
      }

      List<Map<String, dynamic>> allFoods = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['isCustom'] = false; // 明確標記為系統食物
        return data;
      }).toList();

      // 2️⃣ 如果使用者已登入,嘗試獲取自訂食物
      if (_auth.currentUser != null) {
        String userId = _auth.currentUser!.uid;
        
        try {
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
            data['isCustom'] = true; // ✅ 標記為自訂食物
            return data;
          }).toList();

          allFoods.addAll(customFoods);
          
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 無法讀取自訂食物: $e');
          }
        }
      }

      // 更新緩存
      _cachedFoods = allFoods;
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        print('✅ getAllFoods 成功: 共 ${allFoods.length} 項食物 (已緩存)');
      }
      
      return allFoods;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取所有食物失敗: $e');
      }
      return _cachedFoods ?? []; // 如果有緩存就返回緩存
    }
  }

  /// 🆕 批次獲取多個食物 (用於組合功能)
  Future<List<Map<String, dynamic>>> getFoodsByIds(List<String> foodIds) async {
    if (foodIds.isEmpty) return [];

    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      return allFoods.where((food) => foodIds.contains(food['id'])).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 批次獲取食物失敗: $e');
      }
      return [];
    }
  }

  /// ✅ 搜尋食物 (支援中文模糊搜尋)
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      if (kDebugMode) {
        print('🔍 搜尋: "$query", 資料庫共 ${allFoods.length} 項食物');
      }

      if (query.isEmpty || query.trim().isEmpty) {
        return allFoods;
      }

      String lowerQuery = query.toLowerCase().trim();
      
      List<Map<String, dynamic>> results = allFoods.where((food) {
        String foodName = (food['name'] ?? '').toString().toLowerCase();
        String category = (food['category'] ?? '').toString().toLowerCase();
        
        return foodName.contains(lowerQuery) || 
               category.contains(lowerQuery);
      }).toList();

      if (kDebugMode) {
        print('✅ 找到 ${results.length} 項符合 "$query" 的食物');
      }
      
      return results;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 搜尋食物失敗: $e');
      }
      return [];
    }
  }

  /// 🆕 進階搜尋 (支援營養素範圍篩選)
  Future<List<Map<String, dynamic>>> searchFoodsAdvanced({
    String? nameQuery,
    String? category,
    double? minCalories,
    double? maxCalories,
    double? minProtein,
  }) async {
    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      return allFoods.where((food) {
        // 名稱篩選
        if (nameQuery != null && nameQuery.isNotEmpty) {
          String foodName = (food['name'] ?? '').toString().toLowerCase();
          if (!foodName.contains(nameQuery.toLowerCase())) {
            return false;
          }
        }
        
        // 分類篩選
        if (category != null && category.isNotEmpty) {
          if (food['category'] != category) {
            return false;
          }
        }
        
        // 熱量範圍
        if (minCalories != null) {
          double calories = (food['calories'] ?? 0).toDouble();
          if (calories < minCalories) return false;
        }
        if (maxCalories != null) {
          double calories = (food['calories'] ?? 0).toDouble();
          if (calories > maxCalories) return false;
        }
        
        // 蛋白質最低值
        if (minProtein != null) {
          double protein = (food['protein'] ?? 0).toDouble();
          if (protein < minProtein) return false;
        }
        
        return true;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 進階搜尋失敗: $e');
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
      }

      return foodsByCategory;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取分類失敗: $e');
      }
      return {};
    }
  }

  /// 獲取食物詳細資訊
  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
    try {
      // 先嘗試從緩存中找
      if (_cachedFoods != null) {
        try {
          return _cachedFoods!.firstWhere((food) => food['id'] == foodId);
        } catch (e) {
          // 緩存中找不到,繼續從資料庫查
        }
      }

      // 先嘗試系統食物
      DocumentSnapshot doc = await _firestore
          .collection('foods')
          .doc(foodId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          'isCustom': false,
          ...doc.data() as Map<String, dynamic>,
        };
      }

      // 再嘗試自訂食物
      if (_auth.currentUser != null) {
        doc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('customFoods')
            .doc(foodId)
            .get();

        if (doc.exists) {
          return {
            'id': doc.id,
            'isCustom': true,
            ...doc.data() as Map<String, dynamic>,
          };
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取食物詳情失敗: $e');
      }
      return null;
    }
  }

  /// 🆕 清除緩存 (當新增/刪除食物時呼叫)
  void clearCache() {
    _cachedFoods = null;
    _lastFetchTime = null;
    if (kDebugMode) {
      print('🗑️ 已清除食物緩存');
    }
  }

  // ========== 🆕 我的最愛功能 ==========

  /// ✅ 加入我的最愛
  Future<void> addToFavorites({
    required String refId,
    required String type, // 'food', 'custom', 'combo'
    required String name,
    required double calories,
    required String servingSize,
    Map<String, dynamic>? extraData, // 額外資料 (組合用)
  }) async {
    try {
      String userId = _auth.currentUser!.uid;
      
      // 檢查是否已存在
      QuerySnapshot existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .where('refId', isEqualTo: refId)
          .where('type', isEqualTo: type)
          .limit(1)
          .get();
      
      if (existing.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠️ 已在最愛中: $name');
        }
        return;
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .add({
        'refId': refId,
        'type': type,
        'name': name,
        'calories': calories,
        'servingSize': servingSize,
        'extraData': extraData,
        'addedAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'useCount': 0,
      });
      
      // 清除最愛緩存
      _clearFavoriteCache();
      
      if (kDebugMode) {
        print('✅ 已加入最愛: $name ($type)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 加入最愛失敗: $e');
      }
      rethrow;
    }
  }

  /// ✅ 從最愛移除
  Future<void> removeFromFavorites({
    required String refId,
    required String type,
  }) async {
    try {
      String userId = _auth.currentUser!.uid;
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .where('refId', isEqualTo: refId)
          .where('type', isEqualTo: type)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      // 清除最愛緩存
      _clearFavoriteCache();
      
      if (kDebugMode) {
        print('✅ 已從最愛移除: $refId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 移除最愛失敗: $e');
      }
      rethrow;
    }
  }

  /// ✅ 切換最愛狀態 (方便 UI 使用)
  Future<bool> toggleFavorite({
    required String refId,
    required String type,
    required String name,
    required double calories,
    required String servingSize,
    Map<String, dynamic>? extraData,
  }) async {
    bool isFav = await isFavorite(refId: refId, type: type);
    
    if (isFav) {
      await removeFromFavorites(refId: refId, type: type);
      return false;
    } else {
      await addToFavorites(
        refId: refId,
        type: type,
        name: name,
        calories: calories,
        servingSize: servingSize,
        extraData: extraData,
      );
      return true;
    }
  }

  /// ✅ 檢查是否為最愛
  Future<bool> isFavorite({
    required String refId,
    required String type,
  }) async {
    try {
      String uniqueKey = '${type}_$refId';
      
      // 使用緩存
      if (_cachedFavoriteIds != null &&
          _lastFavoriteFetchTime != null &&
          DateTime.now().difference(_lastFavoriteFetchTime!) < _cacheExpiry) {
        return _cachedFavoriteIds!.contains(uniqueKey);
      }
      
      // 重新載入緩存
      await _loadFavoriteIds();
      return _cachedFavoriteIds?.contains(uniqueKey) ?? false;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 檢查最愛狀態失敗: $e');
      }
      return false;
    }
  }

  /// 🆕 載入所有最愛 ID (用於緩存)
  Future<void> _loadFavoriteIds() async {
    try {
      String userId = _auth.currentUser!.uid;
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      
      _cachedFavoriteIds = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return '${data['type']}_${data['refId']}';
      }).toSet();
      
      _lastFavoriteFetchTime = DateTime.now();
      
      if (kDebugMode) {
        print('✅ 載入最愛 ID 緩存: ${_cachedFavoriteIds!.length} 項');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入最愛 ID 失敗: $e');
      }
    }
  }

  /// 🆕 清除最愛緩存
  void _clearFavoriteCache() {
    _cachedFavoriteIds = null;
    _lastFavoriteFetchTime = null;
  }

  /// ✅ 獲取我的最愛列表 (即時串流)
  Stream<List<Map<String, dynamic>>> getMyFavoritesStream() {
    String userId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('lastUsedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// ✅ 獲取我的最愛列表 (一次性)
  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    try {
      String userId = _auth.currentUser!.uid;
      
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('lastUsedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取最愛列表失敗: $e');
      }
      return [];
    }
  }

  /// ✅ 更新最愛使用記錄 (智慧排序用)
  Future<void> updateFavoriteUsage(String favoriteId) async {
    try {
      String userId = _auth.currentUser!.uid;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .update({
        'lastUsedAt': FieldValue.serverTimestamp(),
        'useCount': FieldValue.increment(1),
      });
      
      if (kDebugMode) {
        print('✅ 更新最愛使用記錄: $favoriteId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 更新使用記錄失敗: $e');
      }
    }
  }

  /// 🆕 批次檢查最愛狀態 (用於列表顯示)
  Future<Map<String, bool>> checkFavoritesBatch(List<Map<String, String>> items) async {
    try {
      // 確保緩存已載入
      if (_cachedFavoriteIds == null) {
        await _loadFavoriteIds();
      }
      
      Map<String, bool> results = {};
      for (var item in items) {
        String uniqueKey = '${item['type']}_${item['refId']}';
        results[uniqueKey] = _cachedFavoriteIds?.contains(uniqueKey) ?? false;
      }
      
      return results;
    } catch (e) {
      return {};
    }
  }

  // ========== 自訂食物管理 (users/{userId}/customFoods) ==========

  /// ✅ 新增自訂食物到個人資料夾
  Future<String> addCustomFood({
    required String name,
    required String category,
    required String servingSize,
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
  }) async {
    String userId = _auth.currentUser!.uid;

    DocumentReference docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('customFoods')
        .add({
      'name': name,
      'category': category,
      'servingSize': servingSize,
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 清除緩存,下次會重新載入
    clearCache();

    if (kDebugMode) {
      print('✅ 新增自訂食物: $name (ID: ${docRef.id})');
    }

    return docRef.id;
  }

  /// ✅ 獲取我的自訂食物列表
  Future<List<Map<String, dynamic>>> getMyCustomFoods() async {
    try {
      String userId = _auth.currentUser!.uid;

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customFoods')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> customFoods = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['isCustom'] = true;
        return data;
      }).toList();

      if (kDebugMode) {
        print('✅ 獲取自訂食物: ${customFoods.length} 項');
      }

      return customFoods;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取自訂食物失敗: $e');
      }
      return [];
    }
  }

  /// ✅ 獲取自訂食物即時串流
  Stream<List<Map<String, dynamic>>> getMyCustomFoodsStream() {
    String userId = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('customFoods')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id;
        data['isCustom'] = true;
        return data;
      }).toList();
    });
  }

  /// ✅ 更新自訂食物
  Future<void> updateCustomFood({
    required String foodId,
    required String name,
    required String category,
    required String servingSize,
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
  }) async {
    String userId = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('customFoods')
        .doc(foodId)
        .update({
      'name': name,
      'category': category,
      'servingSize': servingSize,
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
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 清除緩存
    clearCache();

    if (kDebugMode) {
      print('✅ 更新自訂食物: $name');
    }
  }

  /// ✅ 刪除自訂食物
  Future<void> deleteCustomFood(String foodId) async {
    String userId = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('customFoods')
        .doc(foodId)
        .delete();

    // 清除緩存
    clearCache();

    if (kDebugMode) {
      print('✅ 刪除自訂食物: $foodId');
    }
  }

  /// ✅ 獲取單一自訂食物詳情
  Future<Map<String, dynamic>?> getCustomFoodById(String foodId) async {
    try {
      String userId = _auth.currentUser!.uid;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customFoods')
          .doc(foodId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['isCustom'] = true;
        return data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取自訂食物詳情失敗: $e');
      }
      return null;
    }
  }

  /// 🆕 檢查食物名稱是否重複
  Future<bool> isFoodNameDuplicate(String name, {String? excludeFoodId}) async {
    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      return allFoods.any((food) {
        if (excludeFoodId != null && food['id'] == excludeFoodId) {
          return false; // 排除正在編輯的食物本身
        }
        return (food['name'] ?? '').toString().toLowerCase() == name.toLowerCase();
      });
    } catch (e) {
      return false;
    }
  }

  /// 🆕 獲取最近使用的食物 (從組合功能中統計)
  Future<List<Map<String, dynamic>>> getRecentlyUsedFoods({int limit = 10}) async {
    // 這個方法可以配合組合功能,統計最常用的食物
    // 目前先返回所有食物,之後可以加入使用頻率統計
    List<Map<String, dynamic>> allFoods = await getAllFoods();
    return allFoods.take(limit).toList();
  }

  // ========== 統計功能 ==========

  /// 🆕 獲取食物資料庫統計
  Future<Map<String, int>> getFoodStats() async {
    try {
      List<Map<String, dynamic>> allFoods = await getAllFoods();
      
      int systemFoods = allFoods.where((f) => f['isCustom'] == false).length;
      int customFoods = allFoods.where((f) => f['isCustom'] == true).length;
      
      Map<String, List<Map<String, dynamic>>> byCategory = await getAllFoodsByCategory();
      
      return {
        'total': allFoods.length,
        'system': systemFoods,
        'custom': customFoods,
        'categories': byCategory.length,
      };
    } catch (e) {
      return {
        'total': 0,
        'system': 0,
        'custom': 0,
        'categories': 0,
      };
    }
  }

  // ========== 初始化 (可選) ==========

  /// ✅ 初始化基礎食物資料庫(只需執行一次)
  /// 注意: 如果你使用 JSON 導入,就不需要這個方法
  Future<void> initializeFoodDatabase() async {
    try {
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
          'calories': 280,
          'protein': 5.2,
          'carbs': 62.0,
          'fat': 0.6,
          'createdBy': 'system',
        },
        {
          'name': '雞胸肉',
          'category': '蛋白質',
          'servingSize': '1份',
          'calories': 165,
          'protein': 31.0,
          'carbs': 0.0,
          'fat': 3.6,
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
      
      // 清除緩存
      clearCache();
      
      if (kDebugMode) {
        print('✅ 食物資料庫初始化完成!');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 初始化失敗: $e');
      }
    }
  }
}