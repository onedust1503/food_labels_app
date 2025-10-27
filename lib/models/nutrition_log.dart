// lib/models/nutrition_log.dart
// 飲食記錄資料模型

import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionLog {
  final String id;
  final String userId;
  final String foodId;
  final String foodName;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String mealType; // breakfast, lunch, dinner, snack
  final String servingSize;
  final int servings;
  final String recordMethod; // manual, search, scan
  final DateTime date;
  final DateTime createdAt;

  NutritionLog({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealType,
    this.servingSize = '',
    this.servings = 1,
    this.recordMethod = 'manual',
    required this.date,
    required this.createdAt,
  });

  // 從 Firestore 文件建立物件
  factory NutritionLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NutritionLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      foodId: data['foodId'] ?? '',
      foodName: data['foodName'] ?? '',
      calories: _toInt(data['calories']),
      protein: _toDouble(data['protein']),
      carbs: _toDouble(data['carbs']),
      fat: _toDouble(data['fat']),
      mealType: data['mealType'] ?? '',
      servingSize: data['servingSize'] ?? '',
      servings: _toInt(data['servings']),
      recordMethod: data['recordMethod'] ?? 'manual',
      date: _toDateTime(data['date']),
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  // 轉換為 Firestore 文件格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'foodId': foodId,
      'foodName': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'mealType': mealType,
      'servingSize': servingSize,
      'servings': servings,
      'recordMethod': recordMethod,
      'date': date.toIso8601String(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // 複製並修改部分欄位
  NutritionLog copyWith({
    String? id,
    String? userId,
    String? foodId,
    String? foodName,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? mealType,
    String? servingSize,
    int? servings,
    String? recordMethod,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return NutritionLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      mealType: mealType ?? this.mealType,
      servingSize: servingSize ?? this.servingSize,
      servings: servings ?? this.servings,
      recordMethod: recordMethod ?? this.recordMethod,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ========== 輔助方法 ==========
  
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'NutritionLog(id: $id, foodName: $foodName, calories: $calories, date: $date)';
  }
}