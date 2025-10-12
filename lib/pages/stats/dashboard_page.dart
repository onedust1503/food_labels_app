// lib/pages/stats/dashboard_page.dart
import 'package:flutter/material.dart';
import '../../services/stats_service.dart';
import 'workout_stats_page.dart';
import 'nutrition_stats_page.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final StatsService _statsService = StatsService();
  
  bool _isLoading = true;
  MonthlyOverview? _monthlyOverview;
  List<DailyWorkoutStats> _weeklyWorkout = [];
  List<DailyNutritionStats> _weeklyNutrition = [];
  List<DailyWaterStats> _weeklyWater = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final monthlyOverview = await _statsService.getMonthlyOverview();
      final weeklyWorkout = await _statsService.getWeeklyWorkoutStats();
      final weeklyNutrition = await _statsService.getWeeklyNutritionStats();
      final weeklyWater = await _statsService.getWeeklyWaterStats();

      setState(() {
        _monthlyOverview = monthlyOverview;
        _weeklyWorkout = weeklyWorkout;
        _weeklyNutrition = weeklyNutrition;
        _weeklyWater = weeklyWater;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 快速統計卡片
                        _buildQuickStats(),
                        const SizedBox(height: 16),

                        // 運動總覽
                        _buildWorkoutOverview(),
                        const SizedBox(height: 16),

                        // 營養總覽
                        _buildNutritionOverview(),
                        const SizedBox(height: 16),

                        // 本週達標狀況
                        _buildWeeklyAchievements(),
                        const SizedBox(height: 100), // 底部間距
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          '數據儀表板',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue, Colors.purple],
            ),
          ),
        ),
      ),
    );
  }

  // 快速統計卡片
  Widget _buildQuickStats() {
    int weeklyWorkouts = _weeklyWorkout.where((d) => d.workoutCount > 0).length;
    int weeklyMeals = _weeklyNutrition.fold(0, (sum, d) => sum + d.mealCount);
    int waterDaysCompleted = _weeklyWater.where((d) => d.progress >= 100).length;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            '本週運動',
            '$weeklyWorkouts',
            '天',
            Icons.fitness_center,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            '本週飲食',
            '$weeklyMeals',
            '餐',
            Icons.restaurant,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            '喝水達標',
            '$waterDaysCompleted',
            '天',
            Icons.water_drop,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 運動總覽
  Widget _buildWorkoutOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🏋️ 運動總覽',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkoutStatsPage(),
                    ),
                  );
                },
                child: const Text(
                  '查看詳情 >',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_monthlyOverview != null) ...[
            _buildOverviewRow(
              '本月訓練',
              '${_monthlyOverview!.totalWorkouts} 次',
            ),
            const SizedBox(height: 8),
            _buildOverviewRow(
              '總時長',
              '${_monthlyOverview!.totalDuration} 分鐘',
            ),
            const SizedBox(height: 8),
            _buildOverviewRow(
              '消耗卡路里',
              '${_monthlyOverview!.totalCalories.toInt()} 大卡',
            ),
          ],
        ],
      ),
    );
  }

  // 營養總覽
  Widget _buildNutritionOverview() {
    double weeklyCalories = _weeklyNutrition.fold(
      0,
      (sum, d) => sum + d.calories,
    );
    double avgCalories = _weeklyNutrition.isNotEmpty 
        ? weeklyCalories / 7 
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.teal],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🥗 營養總覽',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NutritionStatsPage(),
                    ),
                  );
                },
                child: const Text(
                  '查看詳情 >',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOverviewRow(
            '本週總攝取',
            '${weeklyCalories.toInt()} 大卡',
          ),
          const SizedBox(height: 8),
          _buildOverviewRow(
            '日均攝取',
            '${avgCalories.toInt()} 大卡',
          ),
          const SizedBox(height: 8),
          _buildOverviewRow(
            '記錄餐數',
            '${_weeklyNutrition.fold(0, (sum, d) => sum + d.mealCount)} 餐',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 本週達標狀況
  Widget _buildWeeklyAchievements() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 本週達標狀況',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._weeklyWater.asMap().entries.map((entry) {
            int index = entry.key;
            DailyWaterStats stats = entry.value;
            String dayName = DateFormat('E', 'zh_TW').format(stats.date);
            bool isCompleted = stats.progress >= 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted 
                          ? Colors.green.shade100 
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isCompleted ? Icons.check : Icons.water_drop,
                        color: isCompleted ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: stats.progress / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? Colors.green : Colors.blue,
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${stats.amount.toInt()}ml',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
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
}