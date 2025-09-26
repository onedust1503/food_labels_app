import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // *** 新增：用於 kDebugMode ***
// *** 新增：導入 Firebase 相關套件 ***
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// *** 新增：導入新的導航組件 ***
import '../../components/page_wrapper_with_navigation.dart';

// 臨時模擬數據類型
class MockUserModel {
  final String id;
  final String name;
  MockUserModel({required this.id, required this.name});
}

class MockTodayWorkoutModel {
  final String id;
  final int completedExercises;
  final int totalExercises;
  final String nextExercise;
  MockTodayWorkoutModel({
    required this.id,
    required this.completedExercises,
    required this.totalExercises,
    required this.nextExercise,
  });
}

class MockWeekProgressModel {
  final DateTime date;
  final bool isCompleted;
  final String dayName;
  MockWeekProgressModel({
    required this.date,
    required this.isCompleted,
    required this.dayName,
  });
}

class MockActivityModel {
  final String id;
  final String title;
  final String type;
  final DateTime date;
  MockActivityModel({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
  });
}

class TraineeHomePage extends StatefulWidget {
  // *** 修復：添加 key 參數 ***
  const TraineeHomePage({super.key});

  @override
  State<TraineeHomePage> createState() => _TraineeHomePageState();
}

class _TraineeHomePageState extends State<TraineeHomePage> {
  // *** 修改：新增 Firebase 實例 ***
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🔥 需要從 Firebase 獲取的數據 - 現在使用模擬數據
  MockUserModel? currentUser;
  MockTodayWorkoutModel? todayWorkout;
  List<MockWeekProgressModel> weekProgress = [];
  List<MockActivityModel> recentActivities = [];
  bool isLoading = true;

  // *** 新增：真實用戶資料變數 ***
  User? firebaseUser;
  String realUserName = '';
  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// 初始化頁面數據 - 使用模擬數據
  /// 🔥 Firebase 串接點 1: 載入用戶基本資料和今日數據 (暫時註解)
  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);
      
      // *** 新增：獲取真實用戶資料 ***
      firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userEmail = firebaseUser!.email ?? '';
        
        // 從 Firestore 獲取用戶詳細資料
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser!.uid)
              .get();
          
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            realUserName = userData['displayName'] ?? firebaseUser!.displayName ?? '學員';
          } else {
            realUserName = firebaseUser!.displayName ?? '學員';
          }
        } catch (e) {
          // *** 修復：使用 debugPrint 替代 print ***
          if (kDebugMode) {
            debugPrint('獲取用戶資料失敗: $e');
          }
          realUserName = firebaseUser!.displayName ?? '學員';
        }
      } else {
        realUserName = '學員';
      }
      
      // 模擬加載延遲
      await Future.delayed(const Duration(seconds: 1));
      
      // 🔥 模擬數據替代 Firebase 獲取 (保持原本邏輯)
      currentUser = MockUserModel(id: 'user123', name: realUserName); // *** 修改：使用真實姓名 ***
      
      todayWorkout = MockTodayWorkoutModel(
        id: 'workout123',
        completedExercises: 2,
        totalExercises: 5,
        nextExercise: '啞鈴彎舉',
      );
      
      weekProgress = [
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 6)), isCompleted: true, dayName: '週一'),
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 5)), isCompleted: true, dayName: '週二'),
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 4)), isCompleted: false, dayName: '週三'),
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 3)), isCompleted: true, dayName: '週四'),
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 2)), isCompleted: false, dayName: '週五'),
        MockWeekProgressModel(date: DateTime.now().subtract(const Duration(days: 1)), isCompleted: true, dayName: '週六'),
        MockWeekProgressModel(date: DateTime.now(), isCompleted: false, dayName: '週日'),
      ];
      
      recentActivities = [
        MockActivityModel(id: '1', title: '完成胸部訓練', type: 'workout', date: DateTime.now().subtract(const Duration(hours: 2))),
        MockActivityModel(id: '2', title: '記錄午餐營養', type: 'nutrition', date: DateTime.now().subtract(const Duration(hours: 4))),
        MockActivityModel(id: '3', title: '教練回覆訊息', type: 'message', date: DateTime.now().subtract(const Duration(hours: 6))),
      ];
      
      setState(() => isLoading = false);
    } catch (e) {
      // *** 修復：使用 debugPrint 替代 print ***
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 顯示載入畫面
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // *** 修改：使用新的頁面包裝器替代原本的 Scaffold ***
    return const PageWrapperWithNavigation(
      isCoach: false,
    );
  }
}