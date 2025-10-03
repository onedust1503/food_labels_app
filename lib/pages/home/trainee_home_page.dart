// lib/pages/home/trainee_home_page.dart
// 🎯 在現有基礎上增強學員主頁功能

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../nutrition/food_search_page.dart';
import '../nutrition/nutrition_log_list_page.dart'; // 🔥 新增

class TraineeHomePage extends StatefulWidget {
  const TraineeHomePage({super.key});

  @override
  State<TraineeHomePage> createState() => _TraineeHomePageState();
}

class _TraineeHomePageState extends State<TraineeHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
  
  // 喝水追蹤
  int waterIntake = 0;
  int waterTarget = 2000;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);
      
      firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        // 載入用戶資料
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
        
        // 🔥 載入今日營養數據
        await _loadTodayNutrition();
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  // 🔥 新增方法：載入今日營養數據
  Future<void> _loadTodayNutrition() async {
    try {
      String userId = firebaseUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];
      
      // 讀取今日總計
      DocumentSnapshot summaryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(today)
          .get();
      
      if (summaryDoc.exists) {
        Map<String, dynamic> data = summaryDoc.data() as Map<String, dynamic>;
        
        setState(() {
          todayCalories = (data['totalCalories'] ?? 0).toInt();
          targetCalories = (data['targetCalories'] ?? 1850).toInt();
          
          double totalProtein = (data['totalProtein'] ?? 0).toDouble();
          double totalCarbs = (data['totalCarbs'] ?? 0).toDouble();
          double totalFat = (data['totalFat'] ?? 0).toDouble();
          
          double targetProtein = (data['targetProtein'] ?? 52).toDouble();
          double targetCarbs = (data['targetCarbs'] ?? 178).toDouble();
          double targetFat = (data['targetFat'] ?? 122).toDouble();
          
          // 計算百分比（避免除以零）
          proteinPercent = targetProtein > 0 ? (totalProtein / targetProtein).clamp(0.0, 1.0) : 0.0;
          carbsPercent = targetCarbs > 0 ? (totalCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0;
          fatPercent = targetFat > 0 ? (totalFat / targetFat).clamp(0.0, 1.0) : 0.0;
          
          // 更新顯示文字
          proteinAmount = '${totalProtein.toStringAsFixed(1)}/${targetProtein.toStringAsFixed(0)}g';
          carbsAmount = '${totalCarbs.toStringAsFixed(1)}/${targetCarbs.toStringAsFixed(0)}g';
          fatAmount = '${totalFat.toStringAsFixed(1)}/${targetFat.toStringAsFixed(0)}g';
        });
      } else {
        // 沒有今日數據，使用預設值（已經在初始化時設定為 0）
        if (kDebugMode) {
          debugPrint('今日尚無營養記錄');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入營養數據失敗: $e');
      }
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
      customHomePage: _buildEnhancedHomePage(),
    );
  }

  Widget _buildEnhancedHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部用戶資訊
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFF3B82F6),
                    child: Text(
                      realUserName.isNotEmpty ? realUserName[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          realUserName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '保持健康生活',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      // 🔥 新增：手動刷新數據
                      _loadTodayNutrition();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('數據已更新'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text(
                '追蹤你的卡路里',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildPeriodSelector(),
              const SizedBox(height: 20),
              
              _buildCalorieCard(),
              const SizedBox(height: 20),
              
              _buildNutritionCard(), // 🔥 已修改為可點擊
              const SizedBox(height: 20),
              
              _buildWaterIntakeCard(),
              const SizedBox(height: 20),
              
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['今日', '本週', '本月', '本年'].map((period) {
          bool isSelected = period == '今日';
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {},
              selectedColor: Colors.white,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalorieCard() {
    double percentage = targetCalories > 0 ? (todayCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD4F4DD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, size: 20),
              const SizedBox(width: 8),
              const Text(
                '每日結果',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
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
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7FD957),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$todayCalories',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$targetCalories',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
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

  // 🔥 修改：營養素卡片改為可點擊
  Widget _buildNutritionCard() {
    return InkWell(
      onTap: () async {
        // 導航到飲食記錄列表
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NutritionLogListPage(),
          ),
        );
        // 返回後刷新數據
        _loadTodayNutrition();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.restaurant, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '營養素',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 20),
            _buildNutritionBar('碳水化合物', carbsPercent, Colors.red[300]!, carbsAmount),
            const SizedBox(height: 12),
            _buildNutritionBar('蛋白質', proteinPercent, Colors.green[300]!, proteinAmount),
            const SizedBox(height: 12),
            _buildNutritionBar('脂肪', fatPercent, Colors.purple[300]!, fatAmount),
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildWaterIntakeCard() {
    double waterPercentage = waterTarget > 0 ? (waterIntake / waterTarget).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日飲水量',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$waterIntake / $waterTarget ml',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: waterPercentage,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                waterIntake += 200;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已添加 200ml 水'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.restaurant_menu,
            label: '記錄飲食',
            color: Colors.orange,
            onTap: () async {
              // 導航到食物搜尋頁面
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodSearchPage(),
                ),
              );
              // 返回後自動刷新數據
              _loadTodayNutrition();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.fitness_center,
            label: '開始訓練',
            color: Colors.green,
            onTap: () {
              if (kDebugMode) {
                debugPrint('導航到訓練頁面');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}