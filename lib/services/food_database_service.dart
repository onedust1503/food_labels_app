// lib/services/food_database_service.dart
// 食物資料庫服務 - 完整版本(包含詳細營養素)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 初始化基礎食物資料庫（只需執行一次）
  /// ✅ 現在包含完整營養素資料
  Future<void> initializeFoodDatabase() async {
    // 檢查是否已經初始化過
    QuerySnapshot existing = await _firestore.collection('foods').limit(1).get();
    if (existing.docs.isNotEmpty) {
      print('食物資料庫已存在，跳過初始化');
      return;
    }

    print('開始初始化食物資料庫...');

    List<Map<String, dynamic>> basicFoods = [
      // ========== 主食類 ==========
      {
        'name': '白飯',
        'category': '主食',
        'servingSize': '1碗',
        'servingSizeGram': 200,
        'calories': 280,
        'protein': 5.2,
        'carbs': 62.0,
        'fat': 0.6,
        // ✅ 詳細營養素
        'saturatedFat': 0.2,
        'transFat': 0.0,
        'fiber': 0.6,
        'sugar': 0.1,
        'sodium': 2.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '糙米飯',
        'category': '主食',
        'servingSize': '1碗',
        'servingSizeGram': 200,
        'calories': 296,
        'protein': 6.4,
        'carbs': 64.0,
        'fat': 2.0,
        // ✅ 詳細營養素
        'saturatedFat': 0.4,
        'transFat': 0.0,
        'fiber': 3.2,
        'sugar': 0.8,
        'sodium': 4.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '地瓜',
        'category': '主食',
        'servingSize': '1條',
        'servingSizeGram': 150,
        'calories': 128,
        'protein': 1.5,
        'carbs': 30.0,
        'fat': 0.2,
        // ✅ 詳細營養素
        'saturatedFat': 0.0,
        'transFat': 0.0,
        'fiber': 3.3,
        'sugar': 6.5,
        'sodium': 55.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '燕麥',
        'category': '主食',
        'servingSize': '1碗',
        'servingSizeGram': 50,
        'calories': 185,
        'protein': 6.5,
        'carbs': 33.0,
        'fat': 3.5,
        // ✅ 詳細營養素
        'saturatedFat': 0.6,
        'transFat': 0.0,
        'fiber': 5.0,
        'sugar': 0.4,
        'sodium': 3.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // ========== 蛋白質類 ==========
      {
        'name': '雞胸肉',
        'category': '蛋白質',
        'servingSize': '1份',
        'servingSizeGram': 100,
        'calories': 165,
        'protein': 31.0,
        'carbs': 0.0,
        'fat': 3.6,
        // ✅ 詳細營養素
        'saturatedFat': 1.0,
        'transFat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 74.0,
        'cholesterol': 85.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '雞蛋',
        'category': '蛋白質',
        'servingSize': '1顆',
        'servingSizeGram': 50,
        'calories': 72,
        'protein': 6.3,
        'carbs': 0.4,
        'fat': 4.8,
        // ✅ 詳細營養素
        'saturatedFat': 1.6,
        'transFat': 0.0,
        'fiber': 0.0,
        'sugar': 0.2,
        'sodium': 71.0,
        'cholesterol': 186.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '鮭魚',
        'category': '蛋白質',
        'servingSize': '1片',
        'servingSizeGram': 100,
        'calories': 208,
        'protein': 20.0,
        'carbs': 0.0,
        'fat': 13.4,
        // ✅ 詳細營養素
        'saturatedFat': 3.1,
        'transFat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 59.0,
        'cholesterol': 55.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '豆腐',
        'category': '蛋白質',
        'servingSize': '1塊',
        'servingSizeGram': 100,
        'calories': 76,
        'protein': 8.1,
        'carbs': 1.9,
        'fat': 4.8,
        // ✅ 詳細營養素
        'saturatedFat': 0.7,
        'transFat': 0.0,
        'fiber': 0.3,
        'sugar': 0.6,
        'sodium': 7.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '牛肉',
        'category': '蛋白質',
        'servingSize': '1份',
        'servingSizeGram': 100,
        'calories': 250,
        'protein': 26.0,
        'carbs': 0.0,
        'fat': 15.0,
        // ✅ 詳細營養素
        'saturatedFat': 6.0,
        'transFat': 0.7,
        'fiber': 0.0,
        'sugar': 0.0,
        'sodium': 72.0,
        'cholesterol': 90.0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // ========== 蔬菜類 ==========
      {
        'name': '花椰菜',
        'category': '蔬菜',
        'servingSize': '1碗',
        'servingSizeGram': 100,
        'calories': 34,
        'protein': 2.8,
        'carbs': 6.6,
        'fat': 0.4,
        // ✅ 詳細營養素
        'saturatedFat': 0.1,
        'transFat': 0.0,
        'fiber': 2.6,
        'sugar': 1.7,
        'sodium': 33.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '菠菜',
        'category': '蔬菜',
        'servingSize': '1碗',
        'servingSizeGram': 100,
        'calories': 23,
        'protein': 2.9,
        'carbs': 3.6,
        'fat': 0.4,
        // ✅ 詳細營養素
        'saturatedFat': 0.1,
        'transFat': 0.0,
        'fiber': 2.2,
        'sugar': 0.4,
        'sodium': 79.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // ========== 水果類 ==========
      {
        'name': '香蕉',
        'category': '水果',
        'servingSize': '1根',
        'servingSizeGram': 100,
        'calories': 89,
        'protein': 1.1,
        'carbs': 22.8,
        'fat': 0.3,
        // ✅ 詳細營養素
        'saturatedFat': 0.1,
        'transFat': 0.0,
        'fiber': 2.6,
        'sugar': 12.2,
        'sodium': 1.0,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
      {
        'name': '蘋果',
        'category': '水果',
        'servingSize': '1顆',
        'servingSizeGram': 150,
        'calories': 78,
        'protein': 0.4,
        'carbs': 20.8,
        'fat': 0.3,
        // ✅ 詳細營養素
        'saturatedFat': 0.1,
        'transFat': 0.0,
        'fiber': 3.6,
        'sugar': 15.6,
        'sodium': 1.5,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // ========== 堅果類 ==========
      {
        'name': '杏仁',
        'category': '堅果',
        'servingSize': '1把',
        'servingSizeGram': 30,
        'calories': 173,
        'protein': 6.3,
        'carbs': 6.1,
        'fat': 14.9,
        // ✅ 詳細營養素
        'saturatedFat': 1.1,
        'transFat': 0.0,
        'fiber': 3.5,
        'sugar': 1.2,
        'sodium': 0.3,
        'cholesterol': 0.0,
        'isPublic': true,
        'createdBy': 'system',
      },
    ];

    // 批次寫入
    WriteBatch batch = _firestore.batch();
    for (var food in basicFoods) {
      DocumentReference docRef = _firestore.collection('foods').doc();
      batch.set(docRef, {
        ...food,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ 食物資料庫初始化完成！共新增 ${basicFoods.length} 項食物');
  }

  /// 搜尋食物（所有人共用）
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.isEmpty) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('foods')
        .where('isPublic', isEqualTo: true)
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
    }).toList();
  }

  /// 獲取所有食物（分類）
  Future<Map<String, List<Map<String, dynamic>>>> getAllFoodsByCategory() async {
    QuerySnapshot snapshot = await _firestore
        .collection('foods')
        .where('isPublic', isEqualTo: true)
        .orderBy('category')
        .orderBy('name')
        .get();

    Map<String, List<Map<String, dynamic>>> foodsByCategory = {};

    for (var doc in snapshot.docs) {
      Map<String, dynamic> food = {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      };
      String category = food['category'] ?? '其他';

      if (!foodsByCategory.containsKey(category)) {
        foodsByCategory[category] = [];
      }
      foodsByCategory[category]!.add(food);
    }

    return foodsByCategory;
  }

  /// 新增自訂食物（使用者可以新增到共用資料庫）
  /// ✅ 現在支援完整營養素
  Future<void> addCustomFood({
    required String name,
    required String category,
    required String servingSize,
    required int servingSizeGram,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    // ✅ 詳細營養素 (選填)
    double saturatedFat = 0,
    double transFat = 0,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    double cholesterol = 0,
    bool isPublic = false, // 預設為私人食物
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
      // ✅ 詳細營養素
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
  }

  /// 獲取食物詳細資訊
  Future<Map<String, dynamic>?> getFoodById(String foodId) async {
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
  }

  /// 獲取我的自訂食物
  Future<List<Map<String, dynamic>>> getMyCustomFoods() async {
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
  }
}