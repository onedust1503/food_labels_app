// lib/pages/home/trainee_home_page.dart
// ✨ 明亮版莫蘭迪風格 + 動態配色 + 微動畫效果

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../nutrition/food_search_page.dart';
import '../nutrition/nutrition_log_list_page.dart';
import '../water/water_log_page.dart';
import '../../services/water_service.dart';
import '../../components/weekly_summary_card.dart';
import '../../services/workout_service.dart';
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
  
  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 營養追蹤數據
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
  
  // 🔥 新增：動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  @override
  void dispose() {
    _nutritionStreamSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // 🔥 新增：初始化動畫
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
        
        _listenToTodayNutrition();
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
        
        if (kDebugMode) {
          debugPrint('✅ 營養資料已更新: 卡路里=$todayCalories');
        }
      } else if (mounted) {
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

  Future<void> _loadTodayNutrition() async {
    if (kDebugMode) {
      debugPrint('手動刷新（資料已自動同步）');
    }
  }

  Future<Map<String, dynamic>> _loadWeeklyStats() async {
    try {
      final waterStats = await _waterService.getWeeklyStats();
      final workoutStats = await WorkoutService().getWeeklyWorkoutStats();
      
      return {
        'daysCompleted': waterStats['daysCompleted'] ?? 0,
        'totalDays': 7,
        'avgCalories': todayCalories.toDouble(),
        'avgWater': (waterStats['avgDaily'] ?? 0).toDouble(),
        'workoutDays': workoutStats['workoutDays'] ?? 0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入本週統計失敗: $e');
      }
      return {
        'daysCompleted': 0,
        'totalDays': 7,
        'avgCalories': 0.0,
        'avgWater': 0.0,
        'workoutDays': 0,
      };
    }
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

                  // 🔥 本週統計卡片
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _loadWeeklyStats(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        
                        final stats = snapshot.data!;
                        return WeeklySummaryCard(
                          daysCompleted: stats['daysCompleted'],
                          totalDays: stats['totalDays'],
                          avgCalories: stats['avgCalories'],
                          avgWater: stats['avgWater'],
                          workoutDays: stats['workoutDays'],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🔥 卡路里卡片 - 使用動態漸層
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildCalorieCard(),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🔥 營養素卡片 - 使用亮色高亮
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
                  
                  // 🔥 快速操作按鈕 - 使用活力漸層
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

  // 🔥 優化：用戶頭部 - 更明亮的設計
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
          // 🔥 更亮的頭像漸層
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
          // 🔥 重新整理按鈕加動畫
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

  // 🔥 優化：期間選擇器 - 更明顯的選中效果
  Widget _buildPeriodSelector() {
    final periods = ['今日', '本週', '本月', '本年'];
    const selectedPeriod = '今日';
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final isSelected = period == selectedPeriod;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.defaultCurve,
              child: InkWell(
                onTap: () {
                  // TODO: 實作期間切換
                },
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

  // 🔥 優化：卡路里卡片 - 動態漸層 + 百分比陰影
  Widget _buildCalorieCard() {
    double percentage = targetCalories > 0 ? (todayCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
    
    // 🎯 根據達成率選擇漸層
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
              // 🔥 百分比數字加陰影
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

  // 🔥 優化:營養素卡片 - 使用亮色高亮
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
            // 🔥 碳水化合物 - 活力橘
            _buildNutritionBar('碳水化合物', carbsPercent, AppColors.accent1, carbsAmount),
            const SizedBox(height: 18),
            // 🔥 蛋白質 - 活力綠
            _buildNutritionBar('蛋白質', proteinPercent, AppColors.accent2, proteinAmount),
            const SizedBox(height: 18),
            // 🔥 脂肪 - 柔和紫
            _buildNutritionBar('脂肪', fatPercent, AppColors.accent3, fatAmount),
          ],
        ),
      ),
    );
  }

  // 🔥 優化：營養素進度條 - 更明顯的顏色
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

  // 🔥 優化：飲水卡片 - 更清新的設計
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
                // 🔥 快速新增按鈕
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
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [100, 200, 300, 400, 500, 600].map((amount) {
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
              }).toList(),
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

  Future<void> _quickAddWater(int amount) async {
    try {
      await _waterService.addWaterLog(amount: amount);
      if (mounted) {
        AppModal.showSuccessSnackBar(context, '已記錄 ${amount}ml 💧');
      }
    } catch (e) {
      if (mounted) {
        AppModal.showErrorSnackBar(context, '記錄失敗: $e');
      }
    }
  }

  // 🔥 優化：快速操作按鈕 - 使用活力漸層
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