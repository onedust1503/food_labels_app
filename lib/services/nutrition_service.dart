import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NutritionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 新增飲食記錄
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

    // 新增記錄
    await _firestore.collection('nutritionLogs').add({
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

  // 更新每日總計
  Future<void> _updateDailySummary(String userId, String date, Map<String, double> nutrients) async {
    DocumentReference summaryRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('dailySummary')
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

  // 獲取今日營養總計
  Future<Map<String, dynamic>> getTodayNutrition() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('dailySummary')
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

  // 獲取今日飲食記錄
  Future<List<Map<String, dynamic>>> getTodayLogs() async {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    QuerySnapshot snapshot = await _firestore
        .collection('nutritionLogs')
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
}