// lib/pages/stats/nutrition_stats_page.dart
// 🔥 優化版 - 響應式設計、快速載入、精簡佈局
// ✨ 現代柔和風格
// 🔥 修正：本週定義改為「週一到今天」

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/stats_service.dart';
import '../../theme/app_theme.dart';

class NutritionStatsPage extends StatefulWidget {
  const NutritionStatsPage({super.key});

  @override
  State<NutritionStatsPage> createState() => _NutritionStatsPageState();
}

class _NutritionStatsPageState extends State<NutritionStatsPage> 
    with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isSwitching = false;
  AllStatsData? _weekData;
  AllStatsData? _monthData;
  AllStatsData _currentData = AllStatsData.empty();

  int _selectedPeriodIndex = 0;
  final List<String> _periods = ['本週', '本月'];
  
  String _dateRangeText = '';
  int _actualDays = 7;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysFromMonday = now.weekday - 1;
    final monday = today.subtract(Duration(days: daysFromMonday));
    final days = daysFromMonday + 1;
    
    return {
      'startDate': monday,
      'endDate': today,
      'days': days,
      'text': '${DateFormat('MM/dd').format(monday)} - ${DateFormat('MM/dd').format(today)}',
    };
  }

  Map<String, dynamic> _getMonthRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final days = now.day;
    
    return {
      'startDate': firstDayOfMonth,
      'endDate': today,
      'days': days,
      'text': '${DateFormat('MM/dd').format(firstDayOfMonth)} - ${DateFormat('MM/dd').format(today)}',
    };
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final weekRange = _getWeekRange();
      _weekData = await _loadStatsForRange(
        weekRange['startDate'] as DateTime,
        weekRange['endDate'] as DateTime,
        weekRange['days'] as int,
      );
      
      setState(() {
        _currentData = _weekData!;
        _dateRangeText = weekRange['text'] as String;
        _actualDays = weekRange['days'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  Future<AllStatsData> _loadStatsForRange(DateTime startDate, DateTime endDate, int days) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return AllStatsData.empty();

    final goals = await _statsService.getUserNutritionGoals();
    
    List<DailyNutritionStats> nutritionStats = [];
    List<DailyWaterStats> waterStats = [];
    
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(userId)
            .collection('dailySummary')
            .doc(dateStr)
            .get(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('waterLogs')
            .doc(dateStr)
            .get(),
        _firestore
            .collection('nutritionLogs')
            .where('userId', isEqualTo: userId)
            .where('date', isEqualTo: dateStr)
            .get(),
      ]);
      
      final summaryDoc = results[0] as DocumentSnapshot;
      final waterDoc = results[1] as DocumentSnapshot;
      final nutritionLogsSnapshot = results[2] as QuerySnapshot;
      
      double calories = 0, protein = 0, carbs = 0, fat = 0;
      double targetCalories = goals.calories;
      double targetProtein = goals.protein;
      double targetCarbs = goals.carbs;
      double targetFat = goals.fat;
      int mealCount = nutritionLogsSnapshot.docs.length;
      
      if (summaryDoc.exists) {
        final data = summaryDoc.data() as Map<String, dynamic>;
        calories = ((data['totalCalories'] ?? 0) as num).toDouble();
        protein = ((data['totalProtein'] ?? 0) as num).toDouble();
        carbs = ((data['totalCarbs'] ?? 0) as num).toDouble();
        fat = ((data['totalFat'] ?? 0) as num).toDouble();
        targetCalories = ((data['targetCalories'] ?? goals.calories) as num).toDouble();
        targetProtein = ((data['targetProtein'] ?? goals.protein) as num).toDouble();
        targetCarbs = ((data['targetCarbs'] ?? goals.carbs) as num).toDouble();
        targetFat = ((data['targetFat'] ?? goals.fat) as num).toDouble();
      }
      
      nutritionStats.add(DailyNutritionStats(
        date: date,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        targetCalories: targetCalories,
        targetProtein: targetProtein,
        targetCarbs: targetCarbs,
        targetFat: targetFat,
        mealCount: mealCount,
      ));
      
      double waterAmount = 0;
      double waterGoal = goals.water;
      
      if (waterDoc.exists) {
        final data = waterDoc.data() as Map<String, dynamic>;
        waterAmount = ((data['totalWater'] ?? 0) as num).toDouble();
        waterGoal = ((data['goal'] ?? goals.water) as num).toDouble();
      }
      
      waterStats.add(DailyWaterStats(
        date: date,
        amount: waterAmount,
        goal: waterGoal,
      ));
    }
    
    final nutritionSummary = _calculateNutritionSummary(nutritionStats);
    final waterSummary = _calculateWaterSummary(waterStats);
    
    return AllStatsData(
      goals: goals,
      nutritionStats: nutritionStats,
      waterStats: waterStats,
      nutritionSummary: nutritionSummary,
      waterSummary: waterSummary,
    );
  }

  NutritionSummary _calculateNutritionSummary(List<DailyNutritionStats> stats) {
    if (stats.isEmpty) return NutritionSummary.empty();
    
    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    int totalMeals = 0;
    int caloriesCompletedDays = 0, proteinCompletedDays = 0;
    int carbsCompletedDays = 0, fatCompletedDays = 0;
    int daysWithData = 0;
    
    for (var day in stats) {
      if (day.calories > 0) daysWithData++;
      
      totalCalories += day.calories;
      totalProtein += day.protein;
      totalCarbs += day.carbs;
      totalFat += day.fat;
      totalMeals += day.mealCount;
      
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

  WaterSummary _calculateWaterSummary(List<DailyWaterStats> stats) {
    if (stats.isEmpty) return WaterSummary.empty();
    
    double totalAmount = 0;
    int completedDays = 0;
    int daysWithData = 0;
    
    for (var day in stats) {
      if (day.amount > 0) daysWithData++;
      totalAmount += day.amount;
      if (day.goal > 0 && day.amount >= day.goal) {
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

  Future<void> _switchPeriod(int index) async {
    if (_selectedPeriodIndex == index) return;

    setState(() {
      _selectedPeriodIndex = index;
      _isSwitching = true;
    });

    try {
      if (index == 0) {
        final weekRange = _getWeekRange();
        if (_weekData == null) {
          _weekData = await _loadStatsForRange(
            weekRange['startDate'] as DateTime,
            weekRange['endDate'] as DateTime,
            weekRange['days'] as int,
          );
        }
        _currentData = _weekData!;
        _dateRangeText = weekRange['text'] as String;
        _actualDays = weekRange['days'] as int;
      } else {
        final monthRange = _getMonthRange();
        if (_monthData == null) {
          _monthData = await _loadStatsForRange(
            monthRange['startDate'] as DateTime,
            monthRange['endDate'] as DateTime,
            monthRange['days'] as int,
          );
        }
        _currentData = _monthData!;
        _dateRangeText = monthRange['text'] as String;
        _actualDays = monthRange['days'] as int;
      }
    } catch (e) {
      _showSnackBar('載入失敗：$e');
    }

    setState(() => _isSwitching = false);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F3), // 🔥 暖色調背景
      appBar: AppBar(
        title: Text(
          '營養統計',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey[600], size: 22),
            onPressed: () {
              _weekData = null;
              _monthData = null;
              _loadData();
            },
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    _weekData = null;
                    _monthData = null;
                    await _loadData();
                  },
                  color: const Color(0xFFE07B54), // 🔥 暖橘色
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodSelector(),
                        const SizedBox(height: 18),
                        _buildTodayProgress(isSmallScreen),
                        const SizedBox(height: 18),
                        _buildSummaryCards(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildChartTabs(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildSectionTitle('達標率'),
                        const SizedBox(height: 14),
                        _buildCompletionRates(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildSectionTitle('每日詳情'),
                        const SizedBox(height: 14),
                        _buildDailyList(isSmallScreen),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                if (_isSwitching)
                  Container(
                    color: Colors.black12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE07B54)), // 🔥 暖橘色
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE07B54)), // 🔥 暖橘色
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text('載入統計資料中...', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = index == _selectedPeriodIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchPeriod(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFE07B54), Color(0xFFF4A261)], // 🔥 暖橘漸層
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _periods[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[500],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    if (isSelected && _dateRangeText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _dateRangeText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTodayProgress(bool isSmallScreen) {
    if (_currentData.nutritionStats.isEmpty) {
      return _buildEmptyCard('還沒有數據');
    }

    final today = _currentData.nutritionStats.last;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE07B54), Color(0xFFF4A261)], // 🔥 暖橘漸層
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07B54).withOpacity(0.30), // 🔥 暖橘陰影
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今日營養',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 17 : 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('MM/dd').format(today.date),
                  style: TextStyle(
                    color: const Color(0xFFE07B54), // 🔥 暖橘色
                    fontSize: isSmallScreen ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isSmallScreen ? 1.8 : 2.0,
            children: [
              _buildProgressItem('熱量', today.calories, today.targetCalories, '大卡', isSmallScreen),
              _buildProgressItem('蛋白質', today.protein, today.targetProtein, 'g', isSmallScreen),
              _buildProgressItem('碳水', today.carbs, today.targetCarbs, 'g', isSmallScreen),
              _buildProgressItem('脂肪', today.fat, today.targetFat, 'g', isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, double current, double target, String unit, bool isSmallScreen) {
    double progress = target > 0 ? (current / target).clamp(0.0, 1.5) : 0;
    int percentage = (progress * 100).toInt();
    
    Color progressColor = Colors.white;
    if (percentage > 120) progressColor = Colors.orange.shade300;
    else if (percentage > 100) progressColor = Colors.yellow.shade300;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 12,
        vertical: isSmallScreen ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${current.toInt()}/${target.toInt()}$unit',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: isSmallScreen ? 4 : 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isSmallScreen) {
    final summary = _currentData.nutritionSummary;
    final waterSummary = _currentData.waterSummary;

    return Row(
      children: [
        Expanded(
          child: _buildMiniCard(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE07B54), // 🔥 暖橘色
            title: '平均',
            value: '${summary.avgCalories.toInt()}',
            unit: '大卡',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFF4A261), // 🔥 金黃橘
            title: '餐數',
            value: '${summary.totalMeals}',
            unit: '餐',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF89B4D4),
            title: '喝水',
            value: '${waterSummary.completedDays}/$_actualDays',
            unit: '天達標',
            isSmallScreen: isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String unit,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 14,
        vertical: isSmallScreen ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 22 : 26),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isSmallScreen ? 10 : 11,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isSmallScreen ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTabs(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6F3), // 🔥 暖色調背景
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              indicator: BoxDecoration(
                color: const Color(0xFFE07B54), // 🔥 暖橘色
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '熱量趨勢'),
                Tab(text: '喝水統計'),
              ],
            ),
          ),
          SizedBox(
            height: isSmallScreen ? 240 : 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildCaloriesChart(isSmallScreen),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildWaterChart(isSmallScreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart(bool isSmallScreen) {
    if (_currentData.nutritionStats.isEmpty) {
      return _buildEmptyChartContent('還沒有數據');
    }

    final stats = _currentData.nutritionStats;
    double maxValue = 0;
    for (var s in stats) {
      if (s.calories > maxValue) maxValue = s.calories;
      if (s.targetCalories > maxValue) maxValue = s.targetCalories;
    }
    double yMax = maxValue > 0 ? ((maxValue * 1.2) / 500).ceil() * 500.0 : 2500;
    if (yMax < 500) yMax = 500;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE07B54), Color(0xFFF4A261)], // 🔥 暖橘漸層
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('實際攝取', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(width: 16),
              Row(
                children: [
                  Container(width: 6, height: 2, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Container(width: 6, height: 2, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(width: 6),
              Text('目標', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yMax / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: isSmallScreen ? 38 : 45,
                    interval: yMax / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == yMax) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '${value.toInt()}',
                          style: TextStyle(color: Colors.grey[400], fontSize: isSmallScreen ? 9 : 10),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= stats.length) return const SizedBox();
                      int interval = stats.length > 14 ? 3 : (stats.length > 7 ? 2 : 1);
                      if (index % interval != 0 && index != stats.length - 1) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('d').format(stats[index].date),
                          style: TextStyle(color: Colors.grey[400], fontSize: isSmallScreen ? 9 : 10),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    stats.length,
                    (i) => FlSpot(i.toDouble(), stats[i].calories),
                  ),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE07B54), Color(0xFFF4A261)], // 🔥 暖橘漸層
                  ),
                  barWidth: 3,
                  dotData: FlDotData(
                    show: stats.length <= 10,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2.5,
                      strokeColor: const Color(0xFFE07B54), // 🔥 暖橘色
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE07B54).withOpacity(0.25), // 🔥 暖橘漸層
                        const Color(0xFFF4A261).withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                    stats.length,
                    (i) => FlSpot(i.toDouble(), stats[i].targetCalories),
                  ),
                  isCurved: false,
                  color: Colors.grey.shade400,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  dashArray: [6, 4],
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (touchedSpot) => Colors.black87,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      String label = spot.barIndex == 0 ? '實際' : '目標';
                      Color color = spot.barIndex == 0 ? const Color(0xFFE07B54) : Colors.grey.shade400;
                      return LineTooltipItem(
                        '$label: ${spot.y.toInt()} 大卡',
                        TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterChart(bool isSmallScreen) {
    if (_currentData.waterStats.isEmpty) {
      return _buildEmptyChartContent('還沒有數據');
    }

    final stats = _currentData.waterStats;
    double maxValue = 0;
    for (var s in stats) {
      if (s.amount > maxValue) maxValue = s.amount;
      if (s.goal > maxValue) maxValue = s.goal;
    }
    double yMax = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 2500;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4D4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text('達標', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(width: 14),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4D4).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text('未達標', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(width: 14),
              Text('（需達 100%）', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
        ),
        Expanded(
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yMax / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: isSmallScreen ? 40 : 45,
                    interval: yMax / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == yMax) return const SizedBox();
                      return Text(
                        '${(value / 1000).toStringAsFixed(1)}L',
                        style: TextStyle(color: Colors.grey[400], fontSize: isSmallScreen ? 9 : 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= stats.length) return const SizedBox();
                      int interval = stats.length > 14 ? 3 : (stats.length > 7 ? 2 : 1);
                      if (index % interval != 0 && index != stats.length - 1) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('d').format(stats[index].date),
                          style: TextStyle(color: Colors.grey[400], fontSize: isSmallScreen ? 9 : 10),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(stats.length, (i) {
                final s = stats[i];
                final isCompleted = s.amount >= s.goal;
                double barWidth = stats.length > 20 ? 8 : (stats.length > 15 ? 10 : (stats.length > 7 ? 14 : 18));
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: s.amount,
                      color: isCompleted 
                          ? const Color(0xFF89B4D4) 
                          : const Color(0xFF89B4D4).withOpacity(0.4),
                      width: barWidth,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (touchedSpot) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final s = stats[groupIndex];
                    return BarTooltipItem(
                      '${s.amount.toInt()}/${s.goal.toInt()}ml',
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionRates(bool isSmallScreen) {
    final summary = _currentData.nutritionSummary;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompletionCircle('熱量', summary.caloriesCompletionRate, const Color(0xFFE07B54), isSmallScreen), // 🔥 暖橘色
              _buildCompletionCircle('蛋白', summary.proteinCompletionRate, const Color(0xFFF4A261), isSmallScreen),
              _buildCompletionCircle('碳水', summary.carbsCompletionRate, const Color(0xFF89B4D4), isSmallScreen),
              _buildCompletionCircle('脂肪', summary.fatCompletionRate, const Color(0xFFB8A9C9), isSmallScreen),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6F3), // 🔥 暖色調背景
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '營養素達到目標 80% 即算達標',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isSmallScreen ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCircle(String label, double rate, Color color, bool isSmallScreen) {
    double size = isSmallScreen ? 52 : 62;
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (rate / 100).clamp(0.0, 1.0),
                strokeWidth: isSmallScreen ? 5 : 6,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
              Text(
                '${rate.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isSmallScreen ? 10 : 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyList(bool isSmallScreen) {
    if (_currentData.nutritionStats.isEmpty) {
      return _buildEmptyCard('還沒有數據');
    }

    final stats = _currentData.nutritionStats.reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 14 : 18,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF6F3), // 🔥 暖色調背景
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isSmallScreen ? 50 : 60,
                  child: Text(
                    '日期',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '熱量',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '蛋白',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '碳水',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '脂肪',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isSmallScreen ? 10 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(stats.length.clamp(0, 10), (i) {
            final day = stats[i];
            final isToday = DateFormat('yyyy-MM-dd').format(day.date) ==
                DateFormat('yyyy-MM-dd').format(DateTime.now());
            
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 14 : 18,
                vertical: isSmallScreen ? 12 : 14,
              ),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFFFFF5EE) : null, // 🔥 淺橘色高亮
                border: i < stats.length.clamp(0, 10) - 1
                    ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: isSmallScreen ? 50 : 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday ? '今天' : DateFormat('MM/dd').format(day.date),
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday ? const Color(0xFFE07B54) : Colors.grey[800], // 🔥 暖橘色
                            fontSize: isSmallScreen ? 12 : 13,
                          ),
                        ),
                        if (!isToday)
                          Text(
                            DateFormat('E', 'zh_TW').format(day.date),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: isSmallScreen ? 10 : 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    flex: 2,
                    child: _buildDayValue(
                      '${day.calories.toInt()}',
                      '大卡',
                      day.caloriesProgress >= 80,
                      isSmallScreen,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildDayValue(
                      '${day.protein.toInt()}g',
                      '',
                      day.proteinProgress >= 80,
                      isSmallScreen,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildDayValue(
                      '${day.carbs.toInt()}g',
                      '',
                      day.carbsProgress >= 80,
                      isSmallScreen,
                    ),
                  ),
                  
                  Expanded(
                    child: _buildDayValue(
                      '${day.fat.toInt()}g',
                      '',
                      day.fatProgress >= 80,
                      isSmallScreen,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayValue(String value, String unit, bool isGood, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isGood)
          Icon(
            Icons.check_circle_rounded,
            size: isSmallScreen ? 12 : 14,
            color: const Color(0xFFE07B54), // 🔥 暖橘色
          ),
        if (isGood) const SizedBox(width: 2),
        Flexible(
          child: Text(
            value + unit,
            style: TextStyle(
              color: isGood ? const Color(0xFFE07B54) : Colors.grey[500], // 🔥 暖橘色
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: isGood ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartContent(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}