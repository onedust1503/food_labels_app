// lib/services/user_goals_service.dart
// 🎯 統一的用戶目標管理服務
// 解決目標設定不同步的問題

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 用戶目標數據模型
class UserGoals {
  final int targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final int targetWater;
  final int weeklyWorkoutDays;
  
  // 身體數據（用於計算 TDEE）
  final double? height;
  final double? weight;
  final int? age;
  final String? gender;
  final String? activityLevel;
  final String? fitnessGoal;

  UserGoals({
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.targetWater,
    this.weeklyWorkoutDays = 5,
    this.height,
    this.weight,
    this.age,
    this.gender,
    this.activityLevel,
    this.fitnessGoal,
  });

  /// 從 Firebase 文檔創建
  factory UserGoals.fromFirestore(Map<String, dynamic> data) {
    return UserGoals(
      targetCalories: (data['dailyCalories'] ?? data['targetCalories'] ?? 1850) as int,
      targetProtein: ((data['targetProtein'] ?? 52) as num).toDouble(),
      targetCarbs: ((data['targetCarbs'] ?? 178) as num).toDouble(),
      targetFat: ((data['targetFat'] ?? 122) as num).toDouble(),
      targetWater: (data['waterTargetDefault'] ?? data['targetWater'] ?? 2000) as int,
      weeklyWorkoutDays: (data['weeklyWorkoutDays'] ?? 5) as int,
      height: (data['height'] as num?)?.toDouble(),
      weight: (data['weight'] as num?)?.toDouble(),
      age: data['age'] as int?,
      gender: data['gender'] as String?,
      activityLevel: data['activityLevel'] as String?,
      fitnessGoal: data['goal'] as String?,
    );
  }

  /// 預設目標值
  factory UserGoals.defaults() {
    return UserGoals(
      targetCalories: 1850,
      targetProtein: 52,
      targetCarbs: 178,
      targetFat: 122,
      targetWater: 2000,
      weeklyWorkoutDays: 5,
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'targetWater': targetWater,
      'weeklyWorkoutDays': weeklyWorkoutDays,
    };
  }
}

/// 🎯 統一的用戶目標服務
class UserGoalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // 快取目標數據
  UserGoals? _cachedGoals;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// 🔥 獲取用戶目標（從 users 集合）
  Future<UserGoals> getUserGoals({bool forceRefresh = false}) async {
    if (currentUserId == null) {
      return UserGoals.defaults();
    }

    // 檢查快取
    if (!forceRefresh && 
        _cachedGoals != null && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedGoals!;
    }

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _cachedGoals = UserGoals.fromFirestore(data);
        _cacheTime = DateTime.now();
        
        if (kDebugMode) {
          debugPrint('✅ 載入用戶目標: 熱量=${_cachedGoals!.targetCalories}, 喝水=${_cachedGoals!.targetWater}');
        }
        
        return _cachedGoals!;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入用戶目標失敗: $e');
      }
    }

    return UserGoals.defaults();
  }

  /// 🔥 監聽用戶目標變化（即時更新）
  Stream<UserGoals> getUserGoalsStream() {
    if (currentUserId == null) {
      return Stream.value(UserGoals.defaults());
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            _cachedGoals = UserGoals.fromFirestore(data);
            _cacheTime = DateTime.now();
            return _cachedGoals!;
          }
          return UserGoals.defaults();
        });
  }

  /// 🔥 更新用戶目標（同時更新到多個位置確保一致性）
  Future<void> updateUserGoals({
    int? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    int? targetWater,
    int? weeklyWorkoutDays,
  }) async {
    if (currentUserId == null) throw Exception('用戶未登入');

    String today = DateTime.now().toIso8601String().split('T')[0];

    // 準備更新數據
    Map<String, dynamic> goalsUpdate = {};
    if (targetCalories != null) goalsUpdate['dailyCalories'] = targetCalories;
    if (targetProtein != null) goalsUpdate['targetProtein'] = targetProtein;
    if (targetCarbs != null) goalsUpdate['targetCarbs'] = targetCarbs;
    if (targetFat != null) goalsUpdate['targetFat'] = targetFat;
    if (targetWater != null) goalsUpdate['waterTargetDefault'] = targetWater;
    if (weeklyWorkoutDays != null) goalsUpdate['weeklyWorkoutDays'] = weeklyWorkoutDays;
    goalsUpdate['updatedAt'] = FieldValue.serverTimestamp();

    // 使用批次寫入確保一致性
    WriteBatch batch = _firestore.batch();

    // 1️⃣ 更新 users/{userId} - 主要目標儲存位置
    DocumentReference userRef = _firestore.collection('users').doc(currentUserId);
    batch.set(userRef, goalsUpdate, SetOptions(merge: true));

    // 2️⃣ 同步到今日的 dailySummary（主頁讀取的位置）
    DocumentReference dailySummaryRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('dailySummary')
        .doc(today);
    
    Map<String, dynamic> summaryUpdate = {};
    if (targetCalories != null) summaryUpdate['targetCalories'] = targetCalories;
    if (targetProtein != null) summaryUpdate['targetProtein'] = targetProtein;
    if (targetCarbs != null) summaryUpdate['targetCarbs'] = targetCarbs;
    if (targetFat != null) summaryUpdate['targetFat'] = targetFat;
    
    if (summaryUpdate.isNotEmpty) {
      batch.set(dailySummaryRef, summaryUpdate, SetOptions(merge: true));
    }

    // 3️⃣ 同步到今日的 waterLogs（喝水頁面讀取的位置）
    if (targetWater != null) {
      DocumentReference waterLogRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('waterLogs')
          .doc(today);
      
      batch.set(waterLogRef, {
        'targetWater': targetWater,
      }, SetOptions(merge: true));
    }

    // 執行批次寫入
    await batch.commit();

    // 清除快取
    _cachedGoals = null;
    _cacheTime = null;

    if (kDebugMode) {
      debugPrint('✅ 用戶目標已更新並同步到所有位置');
    }
  }

  /// 🔥 確保今日的目標數據存在（每日首次訪問時調用）
  Future<void> ensureTodayGoalsExist() async {
    if (currentUserId == null) return;

    String today = DateTime.now().toIso8601String().split('T')[0];
    UserGoals goals = await getUserGoals();

    // 檢查今日 dailySummary 是否存在
    DocumentSnapshot dailySummaryDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('dailySummary')
        .doc(today)
        .get();

    if (!dailySummaryDoc.exists) {
      // 創建今日的 dailySummary 並設定目標
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('dailySummary')
          .doc(today)
          .set({
        'date': today,
        'targetCalories': goals.targetCalories,
        'targetProtein': goals.targetProtein,
        'targetCarbs': goals.targetCarbs,
        'targetFat': goals.targetFat,
        'totalCalories': 0,
        'totalProtein': 0.0,
        'totalCarbs': 0.0,
        'totalFat': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 創建今日 dailySummary 並設定目標');
      }
    } else {
      // 檢查是否需要更新目標（目標可能已經修改）
      Map<String, dynamic> data = dailySummaryDoc.data() as Map<String, dynamic>;
      int existingTarget = (data['targetCalories'] ?? 0) as int;
      
      // 如果目標不一致，更新之
      if (existingTarget != goals.targetCalories) {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('dailySummary')
            .doc(today)
            .update({
          'targetCalories': goals.targetCalories,
          'targetProtein': goals.targetProtein,
          'targetCarbs': goals.targetCarbs,
          'targetFat': goals.targetFat,
        });

        if (kDebugMode) {
          debugPrint('✅ 更新今日 dailySummary 的目標值');
        }
      }
    }

    // 檢查今日 waterLogs 是否存在
    DocumentSnapshot waterLogDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('waterLogs')
        .doc(today)
        .get();

    if (!waterLogDoc.exists) {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('waterLogs')
          .doc(today)
          .set({
        'date': today,
        'targetWater': goals.targetWater,
        'totalWater': 0,
        'logs': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('✅ 創建今日 waterLogs 並設定目標');
      }
    }
  }

  /// 🔥 根據身體數據計算建議的 TDEE 和營養素目標
  static Map<String, dynamic> calculateRecommendedGoals({
    required double height, // cm
    required double weight, // kg
    required int age,
    required String gender, // 'male' or 'female'
    required String activityLevel, // sedentary, light, moderate, active, very_active
    required String fitnessGoal, // 減重, 增肌, 維持
  }) {
    // 1. 計算 BMR (Mifflin-St Jeor 公式)
    double bmr;
    if (gender == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // 2. 活動係數
    double activityMultiplier;
    switch (activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2; // 久坐
        break;
      case 'light':
        activityMultiplier = 1.375; // 輕度活動
        break;
      case 'moderate':
        activityMultiplier = 1.55; // 中度活動
        break;
      case 'active':
        activityMultiplier = 1.725; // 高度活動
        break;
      case 'very_active':
        activityMultiplier = 1.9; // 非常活躍
        break;
      default:
        activityMultiplier = 1.375;
    }

    // 3. 計算 TDEE
    double tdee = bmr * activityMultiplier;

    // 4. 根據目標調整
    int targetCalories;
    switch (fitnessGoal) {
      case '減重':
        targetCalories = (tdee - 500).round(); // 減少 500 卡
        break;
      case '增肌':
        targetCalories = (tdee + 300).round(); // 增加 300 卡
        break;
      case '維持':
      default:
        targetCalories = tdee.round();
    }

    // 5. 計算三大營養素（根據目標調整比例）
    double proteinRatio, carbsRatio, fatRatio;
    
    switch (fitnessGoal) {
      case '減重':
        proteinRatio = 0.30; // 30% 蛋白質
        carbsRatio = 0.40;   // 40% 碳水
        fatRatio = 0.30;     // 30% 脂肪
        break;
      case '增肌':
        proteinRatio = 0.30; // 30% 蛋白質
        carbsRatio = 0.45;   // 45% 碳水
        fatRatio = 0.25;     // 25% 脂肪
        break;
      case '維持':
      default:
        proteinRatio = 0.25; // 25% 蛋白質
        carbsRatio = 0.50;   // 50% 碳水
        fatRatio = 0.25;     // 25% 脂肪
    }

    // 蛋白質：1g = 4 卡
    // 碳水：1g = 4 卡
    // 脂肪：1g = 9 卡
    double targetProtein = (targetCalories * proteinRatio) / 4;
    double targetCarbs = (targetCalories * carbsRatio) / 4;
    double targetFat = (targetCalories * fatRatio) / 9;

    // 6. 計算喝水目標 (體重 × 30-35ml)
    int targetWater = (weight * 33).round();

    return {
      'bmr': bmr.round(),
      'tdee': tdee.round(),
      'targetCalories': targetCalories,
      'targetProtein': targetProtein.round(),
      'targetCarbs': targetCarbs.round(),
      'targetFat': targetFat.round(),
      'targetWater': targetWater,
    };
  }
}