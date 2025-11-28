// lib/services/stats_service.dart
// 🔥 優化版 - 並行載入、快取機制、修正資料讀取

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // 🔥 快取
  NutritionGoals? _cachedGoals;
  DateTime? _goalsCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // 🕐 獲取台灣時間
  DateTime get _taiwanNow => DateTime.now().toUtc().add(const Duration(hours: 8));

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get _todayTaiwan => _formatDate(_taiwanNow);

  // ========== 用戶目標（含快取）==========

  Future<NutritionGoals> getUserNutritionGoals() async {
    // 使用快取
    if (_cachedGoals != null && _goalsCacheTime != null) {
      if (DateTime.now().difference(_goalsCacheTime!) < _cacheExpiry) {
        return _cachedGoals!;
      }
    }

    if (currentUserId == null) {
      return NutritionGoals.defaultGoals();
    }

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        _cachedGoals = NutritionGoals(
          calories: ((data['dailyCalories'] ?? data['targetCalories'] ?? 1850) as num).toDouble(),
          protein: ((data['targetProtein'] ?? 52) as num).toDouble(),
          carbs: ((data['targetCarbs'] ?? 178) as num).toDouble(),
          fat: ((data['targetFat'] ?? 122) as num).toDouble(),
          water: ((data['waterTargetDefault'] ?? 2000) as num).toDouble(),
        );
        _goalsCacheTime = DateTime.now();
        return _cachedGoals!;
      }
    } catch (e) {
      print('獲取用戶營養目標失敗: $e');
    }

    return NutritionGoals.defaultGoals();
  }

  // 清除快取
  void clearCache() {
    _cachedGoals = null;
    _goalsCacheTime = null;
  }

  // ========== 🔥 優化：一次性載入所有統計數據 ==========

  Future<AllStatsData> getAllStats({int days = 7}) async {
    if (currentUserId == null) {
      return AllStatsData.empty();
    }

    // 🔥 並行載入所有數據
    final results = await Future.wait([
      getUserNutritionGoals(),
      _loadNutritionAndWaterStats(days: days),
    ]);

    NutritionGoals goals = results[0] as NutritionGoals;
    Map<String, dynamic> statsData = results[1] as Map<String, dynamic>;

    List<DailyNutritionStats> nutritionStats = statsData['nutrition'] ?? [];
    List<DailyWaterStats> waterStats = statsData['water'] ?? [];

    // 計算摘要
    NutritionSummary nutritionSummary = _calculateNutritionSummary(nutritionStats);
    WaterSummary waterSummary = _calculateWaterSummary(waterStats);

    return AllStatsData(
      goals: goals,
      nutritionStats: nutritionStats,
      waterStats: waterStats,
      nutritionSummary: nutritionSummary,
      waterSummary: waterSummary,
    );
  }

  // 🔥 一次性載入營養和喝水數據
  Future<Map<String, dynamic>> _loadNutritionAndWaterStats({int days = 7}) async {
    if (currentUserId == null) return {'nutrition': [], 'water': []};

    DateTime nowTaiwan = _taiwanNow;
    NutritionGoals goals = await getUserNutritionGoals();

    List<DailyNutritionStats> nutritionStats = [];
    List<DailyWaterStats> waterStats = [];

    // 🔥 並行載入每一天的數據
    List<Future<Map<String, dynamic>>> futures = [];
    
    for (int i = days - 1; i >= 0; i--) {
      DateTime date = nowTaiwan.subtract(Duration(days: i));
      futures.add(_loadDayData(date, goals));
    }

    List<Map<String, dynamic>> allDayData = await Future.wait(futures);

    for (var dayData in allDayData) {
      nutritionStats.add(dayData['nutrition'] as DailyNutritionStats);
      waterStats.add(dayData['water'] as DailyWaterStats);
    }

    return {
      'nutrition': nutritionStats,
      'water': waterStats,
    };
  }

  // 載入單日數據
  Future<Map<String, dynamic>> _loadDayData(DateTime date, NutritionGoals goals) async {
    String dateStr = _formatDate(date);

    // 🔥 並行載入 dailySummary、waterLogs 和 nutritionLogs（計算餐數）
    final results = await Future.wait([
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('dailySummary')
          .doc(dateStr)
          .get(),
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('waterLogs')
          .doc(dateStr)
          .get(),
      // 🔥 新增：從 nutritionLogs 計算餐數
      _firestore
          .collection('nutritionLogs')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isEqualTo: dateStr)
          .get(),
    ]);

    DocumentSnapshot summaryDoc = results[0] as DocumentSnapshot;
    DocumentSnapshot waterDoc = results[1] as DocumentSnapshot;
    QuerySnapshot nutritionLogsSnapshot = results[2] as QuerySnapshot;

    // 營養數據
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double targetCalories = goals.calories;
    double targetProtein = goals.protein;
    double targetCarbs = goals.carbs;
    double targetFat = goals.fat;
    
    // 🔥 修正：從 nutritionLogs 計算餐數
    int mealCount = nutritionLogsSnapshot.docs.length;

    if (summaryDoc.exists) {
      Map<String, dynamic> data = summaryDoc.data() as Map<String, dynamic>;
      totalCalories = ((data['totalCalories'] ?? 0) as num).toDouble();
      totalProtein = ((data['totalProtein'] ?? 0) as num).toDouble();
      totalCarbs = ((data['totalCarbs'] ?? 0) as num).toDouble();
      totalFat = ((data['totalFat'] ?? 0) as num).toDouble();

      // 使用該日儲存的目標（如果有）
      if (data['targetCalories'] != null) {
        targetCalories = (data['targetCalories'] as num).toDouble();
      }
      if (data['targetProtein'] != null) {
        targetProtein = (data['targetProtein'] as num).toDouble();
      }
      if (data['targetCarbs'] != null) {
        targetCarbs = (data['targetCarbs'] as num).toDouble();
      }
      if (data['targetFat'] != null) {
        targetFat = (data['targetFat'] as num).toDouble();
      }
    }

    // 喝水數據
    double waterAmount = 0;
    double waterGoal = goals.water;

    if (waterDoc.exists) {
      Map<String, dynamic> data = waterDoc.data() as Map<String, dynamic>;
      waterAmount = ((data['totalWater'] ?? 0) as num).toDouble();
      waterGoal = ((data['targetWater'] ?? goals.water) as num).toDouble();
    }

    return {
      'nutrition': DailyNutritionStats(
        date: date,
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        targetCalories: targetCalories,
        targetProtein: targetProtein,
        targetCarbs: targetCarbs,
        targetFat: targetFat,
        mealCount: mealCount,
      ),
      'water': DailyWaterStats(
        date: date,
        amount: waterAmount,
        goal: waterGoal,
      ),
    };
  }

  // 計算營養摘要
  NutritionSummary _calculateNutritionSummary(List<DailyNutritionStats> stats) {
    if (stats.isEmpty) return NutritionSummary.empty();

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int caloriesCompletedDays = 0;
    int proteinCompletedDays = 0;
    int carbsCompletedDays = 0;
    int fatCompletedDays = 0;
    int totalMeals = 0;
    int daysWithData = 0;

    for (var day in stats) {
      if (day.calories > 0 || day.mealCount > 0) {
        daysWithData++;
      }

      totalCalories += day.calories;
      totalProtein += day.protein;
      totalCarbs += day.carbs;
      totalFat += day.fat;
      totalMeals += day.mealCount;

      // 達到 80% 算達標
      if (day.targetCalories > 0 && day.calories >= day.targetCalories * 0.8) {
        caloriesCompletedDays++;
      }
      if (day.targetProtein > 0 && day.protein >= day.targetProtein * 0.8) {
        proteinCompletedDays++;
      }
      if (day.targetCarbs > 0 && day.carbs >= day.targetCarbs * 0.8) {
        carbsCompletedDays++;
      }
      if (day.targetFat > 0 && day.fat >= day.targetFat * 0.8) {
        fatCompletedDays++;
      }
    }

    int totalDays = stats.length;

    return NutritionSummary(
      totalCalories: totalCalories,
      avgCalories: daysWithData > 0 ? totalCalories / daysWithData : 0,
      totalProtein: totalProtein,
      avgProtein: daysWithData > 0 ? totalProtein / daysWithData : 0,
      totalCarbs: totalCarbs,
      avgCarbs: daysWithData > 0 ? totalCarbs / daysWithData : 0,
      totalFat: totalFat,
      avgFat: daysWithData > 0 ? totalFat / daysWithData : 0,
      caloriesCompletionRate: totalDays > 0 ? (caloriesCompletedDays / totalDays * 100) : 0,
      proteinCompletionRate: totalDays > 0 ? (proteinCompletedDays / totalDays * 100) : 0,
      carbsCompletionRate: totalDays > 0 ? (carbsCompletedDays / totalDays * 100) : 0,
      fatCompletionRate: totalDays > 0 ? (fatCompletedDays / totalDays * 100) : 0,
      totalMeals: totalMeals,
      avgMeals: daysWithData > 0 ? totalMeals / daysWithData : 0,
      daysWithData: daysWithData,
      totalDays: totalDays,
    );
  }

  // 計算喝水摘要
  WaterSummary _calculateWaterSummary(List<DailyWaterStats> stats) {
    if (stats.isEmpty) return WaterSummary.empty();

    double totalAmount = 0;
    int completedDays = 0;
    int daysWithData = 0;

    for (var day in stats) {
      if (day.amount > 0) {
        daysWithData++;
      }
      totalAmount += day.amount;
      if (day.goal > 0 && day.amount >= day.goal * 0.8) {
        completedDays++;
      }
    }

    return WaterSummary(
      totalAmount: totalAmount,
      avgAmount: daysWithData > 0 ? totalAmount / daysWithData : 0,
      completedDays: completedDays,
      completionRate: stats.isNotEmpty ? (completedDays / stats.length * 100) : 0,
      daysWithData: daysWithData,
      totalDays: stats.length,
    );
  }

  // ========== 訓練統計 ==========

  Future<List<DailyWorkoutStats>> getWeeklyWorkoutStats() async {
    if (currentUserId == null) return [];

    DateTime nowTaiwan = _taiwanNow;
    DateTime startOfWeek = nowTaiwan.subtract(Duration(days: nowTaiwan.weekday - 1));

    List<DailyWorkoutStats> weekStats = [];

    for (int i = 0; i < 7; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      String dateStr = _formatDate(date);

      QuerySnapshot snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: currentUserId)
          .where('date', isEqualTo: dateStr)
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

  Future<MonthlyOverview> getMonthlyOverview() async {
    if (currentUserId == null) {
      return MonthlyOverview(
        totalWorkouts: 0,
        totalDuration: 0,
        totalCalories: 0,
        avgDuration: 0,
      );
    }

    DateTime nowTaiwan = _taiwanNow;
    DateTime startOfMonth = DateTime(nowTaiwan.year, nowTaiwan.month, 1);
    String startDateStr = _formatDate(startOfMonth);

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: startDateStr)
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

  /// 🔥 獲取訓練類型分佈
  Future<Map<String, int>> getWorkoutTypeDistribution({int days = 30}) async {
    if (currentUserId == null) return {};

    DateTime nowTaiwan = _taiwanNow;
    DateTime startDate = nowTaiwan.subtract(Duration(days: days));
    String startDateStr = _formatDate(startDate);

    QuerySnapshot snapshot = await _firestore
        .collection('workoutLogs')
        .where('userId', isEqualTo: currentUserId)
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .get();

    Map<String, int> distribution = {};
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String type = data['workoutType'] ?? data['type'] ?? 'other';
      distribution[type] = (distribution[type] ?? 0) + 1;
    }

    return distribution;
  }

  // ========== 舊方法保留（向後相容）==========

  Future<List<DailyNutritionStats>> getWeeklyNutritionStats() async {
    AllStatsData data = await getAllStats(days: 7);
    return data.nutritionStats;
  }

  Future<List<DailyWaterStats>> getWeeklyWaterStats() async {
    AllStatsData data = await getAllStats(days: 7);
    return data.waterStats;
  }

  Future<NutritionSummary> getNutritionSummary({int days = 7}) async {
    AllStatsData data = await getAllStats(days: days);
    return data.nutritionSummary;
  }

  Future<WaterSummary> getWaterSummary({int days = 7}) async {
    AllStatsData data = await getAllStats(days: days);
    return data.waterSummary;
  }

  Future<List<DailyNutritionStats>> getMonthlyNutritionStats() async {
    DateTime now = _taiwanNow;
    AllStatsData data = await getAllStats(days: now.day);
    return data.nutritionStats;
  }

  Future<List<DailyWaterStats>> getWaterStats({int days = 7}) async {
    AllStatsData data = await getAllStats(days: days);
    return data.waterStats;
  }
}

// ========== 數據模型 ==========

/// 🔥 新增：一次性載入所有數據
class AllStatsData {
  final NutritionGoals goals;
  final List<DailyNutritionStats> nutritionStats;
  final List<DailyWaterStats> waterStats;
  final NutritionSummary nutritionSummary;
  final WaterSummary waterSummary;

  AllStatsData({
    required this.goals,
    required this.nutritionStats,
    required this.waterStats,
    required this.nutritionSummary,
    required this.waterSummary,
  });

  factory AllStatsData.empty() {
    return AllStatsData(
      goals: NutritionGoals.defaultGoals(),
      nutritionStats: [],
      waterStats: [],
      nutritionSummary: NutritionSummary.empty(),
      waterSummary: WaterSummary.empty(),
    );
  }
}

/// 營養目標
class NutritionGoals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double water;

  NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
  });

  factory NutritionGoals.defaultGoals() {
    return NutritionGoals(
      calories: 1850,
      protein: 52,
      carbs: 178,
      fat: 122,
      water: 2000,
    );
  }
}

/// 每日訓練統計
class DailyWorkoutStats {
  final DateTime date;
  final int duration;
  final double calories;
  final int workoutCount;

  DailyWorkoutStats({
    required this.date,
    required this.duration,
    required this.calories,
    required this.workoutCount,
  });
}

/// 月度總覽
class MonthlyOverview {
  final int totalWorkouts;
  final int totalDuration;
  final double totalCalories;
  final int avgDuration;

  MonthlyOverview({
    required this.totalWorkouts,
    required this.totalDuration,
    required this.totalCalories,
    required this.avgDuration,
  });
}

/// 每日營養統計
class DailyNutritionStats {
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final int mealCount;

  DailyNutritionStats({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.targetCalories = 1850,
    this.targetProtein = 52,
    this.targetCarbs = 178,
    this.targetFat = 122,
    required this.mealCount,
  });

  double get caloriesProgress => targetCalories > 0 ? (calories / targetCalories * 100).clamp(0, 999) : 0;
  double get proteinProgress => targetProtein > 0 ? (protein / targetProtein * 100).clamp(0, 999) : 0;
  double get carbsProgress => targetCarbs > 0 ? (carbs / targetCarbs * 100).clamp(0, 999) : 0;
  double get fatProgress => targetFat > 0 ? (fat / targetFat * 100).clamp(0, 999) : 0;
}

/// 每日喝水統計
class DailyWaterStats {
  final DateTime date;
  final double amount;
  final double goal;

  DailyWaterStats({
    required this.date,
    required this.amount,
    required this.goal,
  });

  double get progress => goal > 0 ? (amount / goal * 100).clamp(0, 999) : 0;
}

/// 營養摘要統計
class NutritionSummary {
  final double totalCalories;
  final double avgCalories;
  final double totalProtein;
  final double avgProtein;
  final double totalCarbs;
  final double avgCarbs;
  final double totalFat;
  final double avgFat;
  final double caloriesCompletionRate;
  final double proteinCompletionRate;
  final double carbsCompletionRate;
  final double fatCompletionRate;
  final int totalMeals;
  final double avgMeals;
  final int daysWithData;
  final int totalDays;

  NutritionSummary({
    required this.totalCalories,
    required this.avgCalories,
    required this.totalProtein,
    required this.avgProtein,
    required this.totalCarbs,
    required this.avgCarbs,
    required this.totalFat,
    required this.avgFat,
    required this.caloriesCompletionRate,
    required this.proteinCompletionRate,
    required this.carbsCompletionRate,
    required this.fatCompletionRate,
    required this.totalMeals,
    required this.avgMeals,
    required this.daysWithData,
    required this.totalDays,
  });

  factory NutritionSummary.empty() {
    return NutritionSummary(
      totalCalories: 0,
      avgCalories: 0,
      totalProtein: 0,
      avgProtein: 0,
      totalCarbs: 0,
      avgCarbs: 0,
      totalFat: 0,
      avgFat: 0,
      caloriesCompletionRate: 0,
      proteinCompletionRate: 0,
      carbsCompletionRate: 0,
      fatCompletionRate: 0,
      totalMeals: 0,
      avgMeals: 0,
      daysWithData: 0,
      totalDays: 0,
    );
  }
}

/// 喝水摘要統計
class WaterSummary {
  final double totalAmount;
  final double avgAmount;
  final int completedDays;
  final double completionRate;
  final int daysWithData;
  final int totalDays;

  WaterSummary({
    required this.totalAmount,
    required this.avgAmount,
    required this.completedDays,
    required this.completionRate,
    required this.daysWithData,
    required this.totalDays,
  });

  factory WaterSummary.empty() {
    return WaterSummary(
      totalAmount: 0,
      avgAmount: 0,
      completedDays: 0,
      completionRate: 0,
      daysWithData: 0,
      totalDays: 0,
    );
  }
}