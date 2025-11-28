// lib/pages/home/trainee_home_page.dart
// ✨ 明亮版莫蘭迪風格 + 動態配色 + 微動畫效果
// 🔥 修正：加入 UserGoalsService 確保目標同步
// 🔥 新增：今日/本週/本月/本年切換功能，數據連動

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../nutrition/food_search_page.dart';
import '../nutrition/nutrition_log_list_page.dart';
import '../water/water_log_page.dart';
import '../../services/water_service.dart';
import '../../services/user_goals_service.dart';
import 'dart:async';
import '../improved_workout_log_page.dart';

// ✅ 引入明亮版設計系統
import '../../theme/app_theme.dart';
// ✅ 引入 AppModal
import '../../components/ui/app_modal.dart';

class TraineeHomePage extends StatefulWidget {
  const TraineeHomePage({super.key});

  @override
  State<TraineeHomePage> createState() => _TraineeHomePageState();
}

class _TraineeHomePageState extends State<TraineeHomePage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WaterService _waterService = WaterService();
  final UserGoalsService _goalsService = UserGoalsService();
  
  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 🔥 新增：時間段選擇
  String _selectedPeriod = '今日';
  final List<String> _periods = ['今日', '本週', '本月', '本年'];
  bool _isLoadingPeriodStats = false;
  
  // 🔥 新增：時間段統計數據
  PeriodStatsData _periodStats = PeriodStatsData.empty();
  
  // 🔥 新增：運動目標設定（可自訂）
  Map<String, int> _workoutGoals = {
    '今日': 1,
    '本週': 3,
    '本月': 12,
    '本年': 144,
  };
  
  // 營養追蹤數據（今日實時）
  int todayCalories = 0;
  int targetCalories = 1850;
  double carbsPercent = 0.0;
  double proteinPercent = 0.0;
  double fatPercent = 0.0;
  String carbsAmount = '0/178g';
  String proteinAmount = '0/52g';
  String fatAmount = '0/122g';

  // Stream 訂閱
  StreamSubscription<DocumentSnapshot>? _nutritionStreamSubscription;
  
  // ✨ 自訂水杯
  List<int> customCups = [100, 200, 300, 500];
  bool _isLoadingCups = true;
  
  // 🔥 動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
    _loadCustomCups();
  }

  @override
  void dispose() {
    _nutritionStreamSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ✨ 載入自訂水杯
  Future<void> _loadCustomCups() async {
    try {
      final cups = await _waterService.getCustomCups();
      if (mounted) {
        setState(() {
          customCups = cups;
          _isLoadingCups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCups = false);
      }
    }
  }

  // 🔥 初始化動畫
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);
      
      firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
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
          if (kDebugMode) {
            debugPrint('獲取用戶資料失敗: $e');
          }
          realUserName = firebaseUser!.displayName ?? '學員';
        }
        
        // 🔥 關鍵：確保今日的目標數據存在且同步
        await _goalsService.ensureTodayGoalsExist();
        
        // 🔥 載入運動目標設定
        await _loadWorkoutGoals();
        
        _listenToTodayNutrition();
        
        // 🔥 載入當前時間段統計
        await _loadPeriodStats();
      }
      
      setState(() => isLoading = false);
      
      // 🔥 啟動進場動畫
      _animationController.forward();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  void _listenToTodayNutrition() {
    String userId = firebaseUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];
    
    _nutritionStreamSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('dailySummary')
        .doc(today)
        .snapshots()
        .listen((DocumentSnapshot doc) {
      if (doc.exists && mounted) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          todayCalories = ((data['totalCalories'] ?? 0) as num).toInt();
          targetCalories = ((data['targetCalories'] ?? 1850) as num).toInt();
          
          double totalProtein = ((data['totalProtein'] ?? 0) as num).toDouble();
          double totalCarbs = ((data['totalCarbs'] ?? 0) as num).toDouble();
          double totalFat = ((data['totalFat'] ?? 0) as num).toDouble();
          
          double targetProtein = ((data['targetProtein'] ?? 52) as num).toDouble();
          double targetCarbs = ((data['targetCarbs'] ?? 178) as num).toDouble();
          double targetFat = ((data['targetFat'] ?? 122) as num).toDouble();
          
          proteinPercent = targetProtein > 0 ? (totalProtein / targetProtein).clamp(0.0, 1.0) : 0.0;
          carbsPercent = targetCarbs > 0 ? (totalCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0;
          fatPercent = targetFat > 0 ? (totalFat / targetFat).clamp(0.0, 1.0) : 0.0;
          
          proteinAmount = '${totalProtein.toStringAsFixed(1)}/${targetProtein.toStringAsFixed(0)}g';
          carbsAmount = '${totalCarbs.toStringAsFixed(1)}/${targetCarbs.toStringAsFixed(0)}g';
          fatAmount = '${totalFat.toStringAsFixed(1)}/${targetFat.toStringAsFixed(0)}g';
        });
        
        // 🔥 如果是「今日」模式，同步更新 periodStats
        if (_selectedPeriod == '今日') {
          _updateTodayPeriodStats();
        }
        
        if (kDebugMode) {
          debugPrint('✅ 營養資料已更新: 卡路里=$todayCalories/$targetCalories');
        }
      } else if (mounted) {
        // 🔥 如果文檔不存在，重新確保今日目標存在
        _goalsService.ensureTodayGoalsExist();
        
        setState(() {
          todayCalories = 0;
          carbsPercent = 0.0;
          proteinPercent = 0.0;
          fatPercent = 0.0;
          carbsAmount = '0/178g';
          proteinAmount = '0/52g';
          fatAmount = '0/122g';
        });
      }
    }, onError: (e) {
      if (kDebugMode) {
        debugPrint('監聽營養資料失敗: $e');
      }
    });
  }

  // 🔥 新增：更新今日的 periodStats
  void _updateTodayPeriodStats() {
    if (_selectedPeriod != '今日') return;
    
    // 計算今日是否達標（熱量達到 80% 以上）
    bool isCaloriesCompleted = targetCalories > 0 && todayCalories >= targetCalories * 0.8;
    
    // 🔥 修正：completionRate 在今日模式下表示「達標百分比」
    // 如果達標，顯示 100%；否則顯示當前進度
    double completionRate = 0;
    if (isCaloriesCompleted) {
      completionRate = 100;
    } else if (targetCalories > 0) {
      completionRate = (todayCalories / targetCalories * 100).clamp(0, 99);
    }
    
    setState(() {
      _periodStats = PeriodStatsData(
        daysCompleted: isCaloriesCompleted ? 1 : 0,
        totalDays: 1,
        avgCalories: todayCalories.toDouble(),
        avgWater: _periodStats.avgWater,
        workoutDays: _periodStats.workoutDays,
        completionRate: completionRate,
      );
    });
  }

  // 🔥 新增：載入時間段統計數據（優化版 - 減少 Firestore 請求）
  Future<void> _loadPeriodStats() async {
    if (firebaseUser == null) return;
    
    setState(() => _isLoadingPeriodStats = true);
    
    try {
      final String userId = firebaseUser!.uid;
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      
      int days;
      DateTime startDate;
      switch (_selectedPeriod) {
        case '今日':
          days = 1;
          startDate = today;
          break;
        case '本週':
          // 🔥 修正：計算本週一（週一 = 1, 週日 = 7）
          final int daysFromMonday = now.weekday - 1; // 週一=0, 週二=1, ..., 週日=6
          startDate = today.subtract(Duration(days: daysFromMonday));
          days = daysFromMonday + 1; // 從週一到今天的天數
          break;
        case '本月':
          days = now.day;
          startDate = DateTime(now.year, now.month, 1);
          break;
        case '本年':
          final firstDayOfYear = DateTime(now.year, 1, 1);
          days = today.difference(firstDayOfYear).inDays + 1;
          startDate = firstDayOfYear;
          break;
        default:
          days = 7;
          startDate = today.subtract(const Duration(days: 6));
      }
      
      final String startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final String endDateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      if (kDebugMode) {
        debugPrint('📊 載入 $_selectedPeriod 統計: $startDateStr ~ $endDateStr ($days 天)');
      }
      
      // 🔥 並行載入所有數據（使用範圍查詢，減少請求次數）
      final results = await Future.wait([
        _loadNutritionStatsOptimized(userId, startDateStr, endDateStr, days),
        _loadWaterStatsOptimized(userId, startDateStr, endDateStr),
        _loadWorkoutStatsOptimized(userId, startDateStr, endDateStr),
      ]);
      
      final nutritionStats = results[0] as Map<String, dynamic>;
      final waterStats = results[1] as Map<String, dynamic>;
      final workoutStats = results[2] as Map<String, dynamic>;
      
      if (mounted) {
        setState(() {
          _periodStats = PeriodStatsData(
            daysCompleted: nutritionStats['daysCompleted'] ?? 0,
            totalDays: days,
            avgCalories: nutritionStats['avgCalories'] ?? 0.0,
            avgWater: waterStats['avgWater'] ?? 0.0,
            workoutDays: workoutStats['workoutDays'] ?? 0,
            completionRate: nutritionStats['completionRate'] ?? 0.0,
          );
          _isLoadingPeriodStats = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入時間段統計失敗: $e');
      }
      if (mounted) {
        setState(() => _isLoadingPeriodStats = false);
      }
    }
  }

  // 🔥 優化版：營養統計（一次查詢所有日期）
  Future<Map<String, dynamic>> _loadNutritionStatsOptimized(
    String userId, 
    String startDate, 
    String endDate,
    int totalDays,
  ) async {
    try {
      // 使用範圍查詢一次取得所有資料
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDate)
          .get();
      
      double totalCalories = 0;
      int daysWithData = 0;
      int daysCompleted = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final calories = ((data['totalCalories'] ?? 0) as num).toDouble();
        final target = ((data['targetCalories'] ?? 1850) as num).toDouble();
        
        if (calories > 0) {
          totalCalories += calories;
          daysWithData++;
          
          // 達標標準：攝取 >= 目標的 80%
          if (target > 0 && calories >= target * 0.8) {
            daysCompleted++;
          }
        }
      }
      
      return {
        'avgCalories': daysWithData > 0 ? totalCalories / daysWithData : 0.0,
        'daysCompleted': daysCompleted,
        'completionRate': totalDays > 0 ? (daysCompleted / totalDays * 100) : 0.0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入營養統計失敗: $e');
      }
      return {'avgCalories': 0.0, 'daysCompleted': 0, 'completionRate': 0.0};
    }
  }

  // 🔥 優化版：喝水統計（一次查詢所有日期）
  Future<Map<String, dynamic>> _loadWaterStatsOptimized(
    String userId, 
    String startDate, 
    String endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDate)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDate)
          .get();
      
      double totalWater = 0;
      int daysWithData = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final water = ((data['totalWater'] ?? 0) as num).toDouble();
        
        if (water > 0) {
          totalWater += water;
          daysWithData++;
        }
      }
      
      return {
        'avgWater': daysWithData > 0 ? totalWater / daysWithData : 0.0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入喝水統計失敗: $e');
      }
      return {'avgWater': 0.0};
    }
  }

  // 🔥 優化版：運動統計（一次查詢所有記錄）
  Future<Map<String, dynamic>> _loadWorkoutStatsOptimized(
    String userId,
    String startDate, 
    String endDate,
  ) async {
    try {
      // 查詢指定日期範圍內的運動記錄
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();
      
      // 使用 Set 計算不重複的運動天數
      Set<String> workoutDates = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          workoutDates.add(dateStr);
        }
      }
      
      if (kDebugMode) {
        debugPrint('🏋️ 運動統計: $startDate ~ $endDate, 找到 ${snapshot.docs.length} 筆記錄, ${workoutDates.length} 天');
      }
      
      return {'workoutDays': workoutDates.length};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入運動統計失敗: $e');
      }
      return {'workoutDays': 0};
    }
  }

  // 🔥 新增：載入運動目標設定
  Future<void> _loadWorkoutGoals() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser!.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final goals = data['workoutGoals'] as Map<String, dynamic>?;
        
        if (goals != null) {
          // 🔥 修正：統一使用 weekly/monthly 作為 key（與運動統計頁面一致）
          final weekly = (goals['weekly'] ?? goals['daily'] ?? 3) as int;
          final monthly = (goals['monthly'] ?? 12) as int;
          
          setState(() {
            _workoutGoals = {
              '今日': 1,  // 今日固定為 1
              '本週': weekly,
              '本月': monthly,
              '本年': (weekly * 52).clamp(1, 365),  // 根據每週目標計算
            };
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入運動目標失敗: $e');
      }
    }
  }

  // 🔥 新增：儲存運動目標設定
  Future<void> _saveWorkoutGoals() async {
    try {
      // 🔥 修正：統一使用 weekly/monthly 作為 key（與運動統計頁面一致）
      await _firestore
          .collection('users')
          .doc(firebaseUser!.uid)
          .set({
            'workoutGoals': {
              'weekly': _workoutGoals['本週'],
              'monthly': _workoutGoals['本月'],
            },
          }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('儲存運動目標失敗: $e');
      }
    }
  }

  // 🔥 新增：顯示運動目標設定對話框
  void _showWorkoutGoalDialog() {
    final weeklyController = TextEditingController(
      text: _workoutGoals['本週'].toString(),
    );
    final monthlyController = TextEditingController(
      text: _workoutGoals['本月'].toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.fitness_center, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('設定運動目標'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weeklyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '每週運動目標',
                suffixText: '天',
                hintText: '建議 3-5 天',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: monthlyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '每月運動目標',
                suffixText: '天',
                hintText: '建議 12-20 天',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '今日目標固定為 1 天\n本年目標將根據每週目標自動計算',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final weekly = int.tryParse(weeklyController.text) ?? 3;
              final monthly = int.tryParse(monthlyController.text) ?? 12;
              
              setState(() {
                _workoutGoals = {
                  '今日': 1,
                  '本週': weekly.clamp(1, 7),
                  '本月': monthly.clamp(1, 31),
                  '本年': (weekly * 52).clamp(1, 365), // 根據每週目標計算
                };
              });
              
              await _saveWorkoutGoals();
              Navigator.pop(context);
              
              // 重新載入統計
              _loadPeriodStats();
              
              if (mounted) {
                AppModal.showSuccessSnackBar(context, '運動目標已更新');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  // 🔥 新增：切換時間段
  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    
    setState(() {
      _selectedPeriod = period;
    });
    
    _loadPeriodStats();
  }

  Future<void> _loadTodayNutrition() async {
    if (kDebugMode) {
      debugPrint('手動刷新(資料已自動同步)');
    }
    await _loadPeriodStats();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    return PageWrapperWithNavigation(
      isCoach: false,
      customHomePage: _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildUserHeader(),
                  const SizedBox(height: 32),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '追蹤你的卡路里',
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildPeriodSelector(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 28),

                  // 🔥 統計卡片 - 根據選擇的時間段顯示
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildPeriodSummaryCard(),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🔥 卡路里卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCalorieCard(),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🔥 營養素卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildNutritionCard(),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🔥 飲水卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildWaterIntakeCard(),
                  ),
                  const SizedBox(height: 28),
                  
                  // 🔥 快速操作按鈕
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildQuickActions(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, size: 28, color: AppColors.textPrimary),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: '打開選單',
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppShadows.medium,
            ),
            child: Center(
              child: Text(
                realUserName.isNotEmpty ? realUserName[0].toUpperCase() : 'S',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  realUserName,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '保持健康生活',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedRotation(
            turns: isLoading ? 1.0 : 0.0,
            duration: AppAnimations.slow,
            child: IconButton(
              icon: Icon(Icons.refresh, color: AppColors.primary, size: 26),
              onPressed: () {
                _loadTodayNutrition();
                AppModal.showSuccessSnackBar(context, '數據已更新');
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 修改：期間選擇器 - 加入切換功能
  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map((period) {
          final isSelected = period == _selectedPeriod;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.defaultCurve,
              child: InkWell(
                onTap: () => _onPeriodChanged(period),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected ? AppShadows.medium : AppShadows.small,
                  ),
                  child: Text(
                    period,
                    style: AppTextStyles.label.copyWith(
                      color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🔥 新增：根據時間段顯示的統計卡片
  Widget _buildPeriodSummaryCard() {
    if (_isLoadingPeriodStats) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.medium,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        ),
      );
    }

    String periodTitle;
    switch (_selectedPeriod) {
      case '今日':
        periodTitle = '今日表現';
        break;
      case '本週':
        periodTitle = '本週表現';
        break;
      case '本月':
        periodTitle = '本月表現';
        break;
      case '本年':
        periodTitle = '本年表現';
        break;
      default:
        periodTitle = '本週表現';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    periodTitle,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_periodStats.completionRate.toInt()}%',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.accent2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.check_circle_outline,
                label: '達標天數',
                value: '${_periodStats.daysCompleted}/${_periodStats.totalDays}',
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                label: '平均熱量',
                value: '${_periodStats.avgCalories.toInt()} 卡',
              ),
              _buildStatItem(
                icon: Icons.water_drop,
                label: '平均喝水',
                value: '${_periodStats.avgWater.toInt()} ml',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 🔥 運動統計區塊 - 加入進度條和達標提示
          _buildWorkoutSection(),
        ],
      ),
    );
  }

  // 🔥 新增：運動統計區塊
  Widget _buildWorkoutSection() {
    final goal = _workoutGoals[_selectedPeriod] ?? 1;
    final current = _periodStats.workoutDays;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = (goal - current).clamp(0, goal);
    final isCompleted = current >= goal;
    
    // 根據達成率決定獎盃等級
    IconData trophyIcon;
    Color trophyColor;
    if (progress >= 1.0) {
      trophyIcon = Icons.emoji_events; // 🏆 金盃
      trophyColor = Colors.amber;
    } else if (progress >= 0.5) {
      trophyIcon = Icons.workspace_premium; // 🥈 銀牌
      trophyColor = Colors.grey.shade300;
    } else if (progress > 0) {
      trophyIcon = Icons.military_tech; // 🥉 銅牌
      trophyColor = Colors.orange.shade300;
    } else {
      trophyIcon = Icons.directions_run; // 🏃 跑步
      trophyColor = Colors.white.withValues(alpha: 0.7);
    }
    
    return InkWell(
      onTap: _showWorkoutGoalDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 標題列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedPeriod == '今日' ? '今日運動' : '${_selectedPeriod}運動',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 設定提示
                    Icon(
                      Icons.settings,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 14,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$current/$goal 天',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        trophyIcon,
                        color: trophyColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 進度條
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.amber : Colors.white,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            
            // 達標提示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCompleted 
                      ? '🎉 目標達成！' 
                      : '還差 $remaining 天達標',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isCompleted 
                        ? Colors.amber 
                        : Colors.white.withValues(alpha: 0.8),
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieCard() {
    double percentage = targetCalories > 0 ? (todayCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
    final cardGradient = AppColors.getProgressGradient(percentage);
    
    return AnimatedContainer(
      duration: AppAnimations.normal,
      curve: AppAnimations.defaultCurve,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.emphasized,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                '每日結果',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '${(percentage * 100).toInt()}%',
                style: AppTextStyles.highlight.copyWith(
                  color: Colors.white,
                  shadows: AppShadows.textShadow,
                ),
              ),
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: TweenAnimationBuilder<double>(
                        duration: AppAnimations.slow,
                        curve: Curves.easeInOut,
                        tween: Tween<double>(begin: 0.0, end: percentage),
                        builder: (context, value, _) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 12,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$todayCalories',
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$targetCalories',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NutritionLogListPage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.large,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant, 
                        size: 22, 
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '營養素', 
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, size: 18, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: 24),
            _buildNutritionBar('碳水化合物', carbsPercent, AppColors.accent1, carbsAmount),
            const SizedBox(height: 18),
            _buildNutritionBar('蛋白質', proteinPercent, AppColors.accent2, proteinAmount),
            const SizedBox(height: 18),
            _buildNutritionBar('脂肪', fatPercent, AppColors.accent3, fatAmount),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionBar(String label, double value, Color color, String amount) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label, 
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(value * 100).toInt()}%',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              amount,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            duration: AppAnimations.normal,
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0.0, end: value),
            builder: (context, animatedValue, _) {
              return LinearProgressIndicator(
                value: animatedValue,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 12,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWaterIntakeCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _waterService.getTodayWaterStream(),
      initialData: {
        'totalWater': 0,
        'targetWater': 2000,
        'logs': [],
      },
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildWaterCardSkeleton();
        }

        final data = snapshot.data ?? {
          'totalWater': 0,
          'targetWater': 2000,
          'logs': [],
        };
        
        final waterIntake = (data['totalWater'] ?? 0) as int;
        final waterTarget = (data['targetWater'] ?? 2000) as int;
        final waterPercentage = waterTarget > 0 
            ? (waterIntake / waterTarget).clamp(0.0, 1.0) 
            : 0.0;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WaterLogPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.info.withValues(alpha: 0.08),
                  AppColors.info.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: AppShadows.medium,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop, 
                    color: AppColors.info, 
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '今日飲水量', 
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios, 
                            size: 16, 
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$waterIntake / $waterTarget ml',
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          duration: AppAnimations.normal,
                          curve: Curves.easeInOut,
                          tween: Tween<double>(begin: 0.0, end: waterPercentage),
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white.withValues(alpha: 0.5),
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                              minHeight: 10,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _showQuickAddWaterDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.info, AppColors.info.withValues(alpha: 0.8)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.small,
                    ),
                    child: const Icon(
                      Icons.add, 
                      color: Colors.white, 
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaterCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 150,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddWaterDialog() {
    AppModal.showBottomSheet(
      context: context,
      child: ModalContainer(
        title: '快速記錄喝水',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingCups)
              const CircularProgressIndicator()
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  ...customCups.map((amount) {
                    return InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await _quickAddWater(amount);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.info.withValues(alpha: 0.15),
                              AppColors.info.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop, 
                              color: AppColors.info, 
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${amount}ml',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showCustomCupsDialog();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.warning.withValues(alpha: 0.15),
                            AppColors.warning.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tune, 
                            color: AppColors.warning, 
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '自訂',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showManualAddWaterDialog();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0.15),
                            AppColors.success.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit, 
                            color: AppColors.success, 
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '手動',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WaterLogPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  '查看詳細記錄', 
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualAddWaterDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.water_drop, color: AppColors.info),
            const SizedBox(width: 12),
            const Text('記錄喝水'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '水量(毫升)',
                hintText: '例如:200',
                suffixText: 'ml',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.info, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: '備註(選填)',
                hintText: '例如:早餐後',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.info, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _quickAddWater(amount, note: noteController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showCustomCupsDialog() {
    final controllers = customCups.map((amount) {
      return TextEditingController(text: amount.toString());
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_drink, color: AppColors.info),
            const SizedBox(width: 12),
            const Text('自訂水杯容量'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: controllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '水杯 ${index + 1}',
                      suffixText: 'ml',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.info, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCups = controllers
                  .map((c) => int.tryParse(c.text) ?? 100)
                  .where((amount) => amount > 0)
                  .toList();
              
              if (newCups.length == 4) {
                Navigator.pop(context);
                try {
                  await _waterService.updateCustomCups(newCups);
                  if (mounted) {
                    setState(() {
                      customCups = newCups;
                    });
                    AppModal.showSuccessSnackBar(context, '水杯設定已更新');
                  }
                } catch (e) {
                  if (mounted) {
                    AppModal.showErrorSnackBar(context, '更新失敗: $e');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddWater(int amount, {String? note}) async {
    try {
      await _waterService.addWaterLog(amount: amount, note: note);
      if (mounted) {
        AppModal.showSuccessSnackBar(context, '已記錄 ${amount}ml 💧');
      }
    } catch (e) {
      if (mounted) {
        AppModal.showErrorSnackBar(context, '記錄失敗: $e');
      }
    }
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.restaurant_menu,
            label: '記錄飲食',
            gradient: AppColors.warmGradient,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodSearchPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.fitness_center,
            label: '開始訓練',
            gradient: AppColors.energyGradient,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImprovedWorkoutLogPage(
                    isCoach: false,
                    traineeId: null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.large,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔥 新增：時間段統計數據模型
class PeriodStatsData {
  final int daysCompleted;
  final int totalDays;
  final double avgCalories;
  final double avgWater;
  final int workoutDays;
  final double completionRate;

  PeriodStatsData({
    required this.daysCompleted,
    required this.totalDays,
    required this.avgCalories,
    required this.avgWater,
    required this.workoutDays,
    required this.completionRate,
  });

  factory PeriodStatsData.empty() {
    return PeriodStatsData(
      daysCompleted: 0,
      totalDays: 1,
      avgCalories: 0,
      avgWater: 0,
      workoutDays: 0,
      completionRate: 0,
    );
  }
}