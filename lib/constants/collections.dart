// lib/constants/collections.dart
// Firestore 集合名稱常量

class Collections {
  // 防止實例化
  Collections._();
  
  // ========== 主要集合 ==========
  static const String users = 'users';
  static const String nutritionLogs = 'nutritionLogs';
  static const String workoutLogs = 'workoutLogs';
  static const String foods = 'foods';
  static const String pairs = 'pairs';
  static const String pairRequests = 'pairRequests';
  static const String chatRooms = 'chatRooms';
  static const String notifications = 'notifications';
  static const String workoutPlans = 'workoutPlans';
  static const String scans = 'scans';
  static const String foodLogs = 'foodLogs';
  
  // ========== 子集合 ==========
  static const String dailySummary = 'dailySummary';
  static const String workoutSummary = 'workoutSummary';
  static const String waterLogs = 'waterLogs';
  static const String favoriteFoods = 'favoriteFoods';
  static const String messages = 'messages';
}