// lib/services/stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ========== 運動統計 ==========

  /// 獲取本週運動數據（7天）
  Future<List<DailyWorkoutStats>> getWeeklyWorkoutStats() async {
    if (currentUserId == null) return [];

    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    List<DailyWorkoutStats> weekStats = [];

    for (int i = 0; i < 7; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      int totalDuration = 0;
      double totalCalories = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalDuration += (data['duration'] ?? 0) as int;
        totalCalories += ((data['caloriesBurned'] ?? 0) as num).toDouble();
      }

      weekStats.add(DailyWorkoutStats(
        date: date,
        duration: totalDuration,
        calories: totalCalories,
        workoutCount: snapshot.docs.length,
      ));
    }

    return weekStats;
  }

  /// 獲取運動類型分布（本月）
  Future<Map<String, int>> getWorkoutTypeDistribution() async {
    if (currentUserId == null) return {};

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

    Map<String, int> distribution = {};

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String type = data['exerciseType'] ?? 'other';
      distribution[type] = (distribution[type] ?? 0) + 1;
    }

    return distribution;
  }

  /// 獲取本月總覽數據
  Future<MonthlyOverview> getMonthlyOverview() async {
    if (currentUserId == null) {
      return MonthlyOverview(
        totalWorkouts: 0,
        totalDuration: 0,
        totalCalories: 0,
        avgDuration: 0,
      );
    }

    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();

    int totalWorkouts = snapshot.docs.length;
    int totalDuration = 0;
    double totalCalories = 0;

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      totalDuration += (data['duration'] ?? 0) as int;
      totalCalories += ((data['caloriesBurned'] ?? 0) as num).toDouble();
    }

    return MonthlyOverview(
      totalWorkouts: totalWorkouts,
      totalDuration: totalDuration,
      totalCalories: totalCalories,
      avgDuration: totalWorkouts > 0 ? totalDuration ~/ totalWorkouts : 0,
    );
  }

  // ========== 營養統計 ==========

  /// 獲取本週營養數據（7天）
  Future<List<DailyNutritionStats>> getWeeklyNutritionStats() async {
    if (currentUserId == null) return [];

    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    List<DailyNutritionStats> weekStats = [];

    for (int i = 0; i < 7; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('foodLogs')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalCalories += ((data['calories'] ?? 0) as num).toDouble();
        totalProtein += ((data['protein'] ?? 0) as num).toDouble();
        totalCarbs += ((data['carbs'] ?? 0) as num).toDouble();
        totalFat += ((data['fat'] ?? 0) as num).toDouble();
      }

      weekStats.add(DailyNutritionStats(
        date: date,
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        mealCount: snapshot.docs.length,
      ));
    }

    return weekStats;
  }

  /// 獲取喝水統計（本週）
  Future<List<DailyWaterStats>> getWeeklyWaterStats() async {
    if (currentUserId == null) return [];

    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    List<DailyWaterStats> weekStats = [];

    for (int i = 0; i < 7; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('waterLogs')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      double totalAmount = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalAmount += ((data['amount'] ?? 0) as num).toDouble();
      }

      weekStats.add(DailyWaterStats(
        date: date,
        amount: totalAmount,
        goal: 2000, // 預設目標 2000ml
      ));
    }

    return weekStats;
  }
}

// ========== 數據模型 ==========

class DailyWorkoutStats {
  final DateTime date;
  final int duration; // 分鐘
  final double calories;
  final int workoutCount;

  DailyWorkoutStats({
    required this.date,
    required this.duration,
    required this.calories,
    required this.workoutCount,
  });
}

class MonthlyOverview {
  final int totalWorkouts;
  final int totalDuration; // 分鐘
  final double totalCalories;
  final int avgDuration;

  MonthlyOverview({
    required this.totalWorkouts,
    required this.totalDuration,
    required this.totalCalories,
    required this.avgDuration,
  });
}

class DailyNutritionStats {
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;

  DailyNutritionStats({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealCount,
  });
}

class DailyWaterStats {
  final DateTime date;
  final double amount; // ml
  final double goal;

  DailyWaterStats({
    required this.date,
    required this.amount,
    required this.goal,
  });

  double get progress => (amount / goal * 100).clamp(0, 100);
}