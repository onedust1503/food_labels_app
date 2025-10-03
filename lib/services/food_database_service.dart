import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 初始化基礎食物資料庫（只需執行一次）
  // 建議：在 APP 第一次啟動時，或在管理後台執行
  Future<void> initializeFoodDatabase() async {
    // 檢查是否已經初始化過
    QuerySnapshot existing = await _firestore.collection('foods').limit(1).get();
    if (existing.docs.isNotEmpty) {
      print('食物資料庫已存在，跳過初始化');
      return;
    }

    print('開始初始化食物資料庫...');

    List<Map<String, dynamic>> basicFoods = [
      // 主食類
      {
        'name': '白飯',
        'category': '主食',
        'servingSize': '1碗',
        'servingSizeGram': 200,
        'calories': 280,
        'protein': 5.2,
        'carbs': 62.0,
        'fat': 0.6,
        'fiber': 0.6,
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
        'fiber': 3.2,
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
        'fiber': 3.3,
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
        'fiber': 5.0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // 蛋白質類
      {
        'name': '雞胸肉',
        'category': '蛋白質',
        'servingSize': '1份',
        'servingSizeGram': 100,
        'calories': 165,
        'protein': 31.0,
        'carbs': 0,
        'fat': 3.6,
        'fiber': 0,
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
        'fiber': 0,
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
        'carbs': 0,
        'fat': 13.4,
        'fiber': 0,
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
        'fiber': 0.3,
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
        'carbs': 0,
        'fat': 15.0,
        'fiber': 0,
        'isPublic': true,
        'createdBy': 'system',
      },

      // 蔬菜類
      {
        'name': '花椰菜',
        'category': '蔬菜',
        'servingSize': '1碗',
        'servingSizeGram': 100,
        'calories': 34,
        'protein': 2.8,
        'carbs': 6.6,
        'fat': 0.4,
        'fiber': 2.6,
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
        'fiber': 2.2,
        'isPublic': true,
        'createdBy': 'system',
      },

      // 水果類
      {
        'name': '香蕉',
        'category': '水果',
        'servingSize': '1根',
        'servingSizeGram': 100,
        'calories': 89,
        'protein': 1.1,
        'carbs': 22.8,
        'fat': 0.3,
        'fiber': 2.6,
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
        'fiber': 3.6,
        'isPublic': true,
        'createdBy': 'system',
      },

      // 堅果類
      {
        'name': '杏仁',
        'category': '堅果',
        'servingSize': '1把',
        'servingSizeGram': 30,
        'calories': 173,
        'protein': 6.3,
        'carbs': 6.1,
        'fat': 14.9,
        'fiber': 3.5,
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
    print('食物資料庫初始化完成！共新增 ${basicFoods.length} 項食物');
  }

  // 搜尋食物（所有人共用）
  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.isEmpty) return [];

    // Firestore 不支援 LIKE 查詢，這裡使用前綴搜尋
    // 更好的方案：整合 Algolia 或使用 Cloud Functions
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

  // 獲取所有食物（分類）
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
      String category = food['category'];

      if (!foodsByCategory.containsKey(category)) {
        foodsByCategory[category] = [];
      }
      foodsByCategory[category]!.add(food);
    }

    return foodsByCategory;
  }

  // 新增自訂食物（使用者可以新增）
  Future<void> addCustomFood({
    required String name,
    required String category,
    required String servingSize,
    required int servingSizeGram,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
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
      'fiber': fiber,
      'isPublic': isPublic,
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}