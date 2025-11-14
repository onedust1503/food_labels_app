// lib/pages/home/trainee_home_page.dart
// ✅ 整合新設計系統 + 保留所有原有功能

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

// ✅ 新增：引入設計系統
import '../../theme/app_theme.dart';

class TraineeHomePage extends StatefulWidget {
  const TraineeHomePage({super.key});

  @override
  State<TraineeHomePage> createState() => _TraineeHomePageState();
}

class _TraineeHomePageState extends State<TraineeHomePage> {
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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _nutritionStreamSubscription?.cancel();
    super.dispose();
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PageWrapperWithNavigation(
      isCoach: false,
      customHomePage: _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      // ✅ 使用設計系統的背景漸層
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 頂部用戶資訊
                _buildUserHeader(),
                const SizedBox(height: AppSizes.gapXXLarge),
                
                // 標題
                Text(
                  '追蹤你的卡路里',
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.gapMedium),
                
                // 期間選擇器
                _buildPeriodSelector(),
                const SizedBox(height: AppSizes.gapXLarge),

                // 本週統計卡片
                FutureBuilder<Map<String, dynamic>>(
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
                const SizedBox(height: AppSizes.gapLarge),
                
                // 卡路里卡片
                _buildCalorieCard(),
                const SizedBox(height: AppSizes.gapLarge),
                
                // 營養素卡片
                _buildNutritionCard(),
                const SizedBox(height: AppSizes.gapLarge),
                
                // 喝水卡片
                _buildWaterIntakeCard(),
                const SizedBox(height: AppSizes.gapLarge),
                
                // 快速操作按鈕
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 使用新設計系統的用戶頭部
  Widget _buildUserHeader() {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, size: AppSizes.iconLarge, color: AppColors.textPrimary),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            tooltip: '打開選單',
          ),
        ),
        // 頭像 - 使用漸層
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.small,
          ),
          child: Center(
            child: Text(
              realUserName.isNotEmpty ? realUserName[0].toUpperCase() : 'S',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.gapMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                realUserName,
                style: AppTextStyles.h4,
              ),
              Text(
                '保持健康生活',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.primary, size: AppSizes.iconLarge),
          onPressed: () {
            _loadTodayNutrition();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('數據已更新'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ✅ 使用新設計系統的期間選擇器
  Widget _buildPeriodSelector() {
    final periods = ['今日', '本週', '本月', '本年'];
    const selectedPeriod = '今日';
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final isSelected = period == selectedPeriod;
          return Padding(
            padding: const EdgeInsets.only(right: AppSizes.gapSmall),
            child: InkWell(
              onTap: () {
                // TODO: 實作期間切換
              },
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingLarge,
                  vertical: AppSizes.paddingSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  boxShadow: isSelected ? AppShadows.small : null,
                ),
                child: Text(
                  period,
                  style: AppTextStyles.label.copyWith(
                    color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✅ 使用新設計系統的卡路里卡片
  Widget _buildCalorieCard() {
    double percentage = targetCalories > 0 ? (todayCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: AppSizes.cardPaddingLarge,
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, size: AppSizes.iconMedium, color: Colors.white),
              const SizedBox(width: AppSizes.gapSmall),
              Text(
                '每日結果',
                style: AppTextStyles.h4.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.gapLarge),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '${(percentage * 100).toInt()}%',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 48,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$todayCalories',
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                        Text(
                          '$targetCalories',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.8),
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

  // ✅ 使用新設計系統的營養素卡片
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
      borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
      child: Container(
        padding: AppSizes.cardPaddingLarge,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant, size: AppSizes.iconMedium, color: AppColors.primary),
                    const SizedBox(width: AppSizes.gapSmall),
                    Text('營養素', style: AppTextStyles.h4),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, size: AppSizes.iconSmall, color: AppColors.textTertiary),
              ],
            ),
            const SizedBox(height: AppSizes.gapLarge),
            _buildNutritionBar('碳水化合物', carbsPercent, AppColors.accent1, carbsAmount),
            const SizedBox(height: AppSizes.gapMedium),
            _buildNutritionBar('蛋白質', proteinPercent, AppColors.accent2, proteinAmount),
            const SizedBox(height: AppSizes.gapMedium),
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
                Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: AppSizes.gapSmall),
                Text(
                  '${(value * 100).toInt()}%',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              amount,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.gapSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ✅ 使用新設計系統的喝水卡片
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
          borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
          child: Container(
            padding: AppSizes.cardPaddingLarge,
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
              boxShadow: AppShadows.small,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.water_drop, color: AppColors.info, size: AppSizes.iconLarge),
                ),
                const SizedBox(width: AppSizes.gapMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('今日飲水量', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          Icon(Icons.arrow_forward_ios, size: AppSizes.iconSmall, color: AppColors.textTertiary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$waterIntake / $waterTarget ml',
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(height: AppSizes.gapSmall),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        child: LinearProgressIndicator(
                          value: waterPercentage,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.gapSmall),
                IconButton(
                  onPressed: _showQuickAddWaterDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(AppSizes.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.small,
                    ),
                    child: Icon(Icons.add, color: Colors.white, size: AppSizes.iconMedium),
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
      padding: AppSizes.cardPaddingLarge,
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSizes.gapMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                ),
                const SizedBox(height: AppSizes.gapSmall),
                Container(
                  width: 150,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
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
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXXLarge),
      ),
      builder: (context) => Container(
        padding: AppSizes.cardPaddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSizes.gapLarge),
            Text('快速記錄喝水', style: AppTextStyles.h3),
            const SizedBox(height: AppSizes.gapLarge),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: AppSizes.gapMedium,
              crossAxisSpacing: AppSizes.gapMedium,
              children: [100, 200, 300, 400, 500, 600].map((amount) {
                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _quickAddWater(amount);
                  },
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop, color: AppColors.info, size: AppSizes.iconXLarge),
                        const SizedBox(height: AppSizes.gapSmall),
                        Text(
                          '${amount}ml',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSizes.gapMedium),
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
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingMedium),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: Text('查看詳細記錄', style: AppTextStyles.button.copyWith(color: AppColors.primary)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: AppSizes.gapSmall),
                Text('已記錄 ${amount}ml 💧'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記錄失敗: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ✅ 使用新設計系統的快速操作按鈕
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
        const SizedBox(width: AppSizes.gapMedium),
        Expanded(
          child: _buildActionButton(
            icon: Icons.fitness_center,
            label: '開始訓練',
            gradient: AppColors.secondaryGradient,
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
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingLarge),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: AppShadows.medium,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: AppSizes.iconXLarge),
            const SizedBox(height: AppSizes.gapSmall),
            Text(
              label,
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}