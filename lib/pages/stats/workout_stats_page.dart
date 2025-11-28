// lib/pages/stats/workout_stats_page.dart
// 🔥 優化版 - 莫蘭迪風格、響應式設計
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/stats_service.dart';
import '../../theme/app_theme.dart';

class WorkoutStatsPage extends StatefulWidget {
  const WorkoutStatsPage({super.key});

  @override
  State<WorkoutStatsPage> createState() => _WorkoutStatsPageState();
}

class _WorkoutStatsPageState extends State<WorkoutStatsPage> 
    with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  
  bool _isLoading = true;
  List<DailyWorkoutStats> _weeklyStats = [];
  Map<String, int> _typeDistribution = {};
  MonthlyOverview? _monthlyOverview;

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 🔥 並行載入
      final results = await Future.wait([
        _statsService.getWeeklyWorkoutStats(),
        _statsService.getWorkoutTypeDistribution(),
        _statsService.getMonthlyOverview(),
      ]);

      setState(() {
        _weeklyStats = results[0] as List<DailyWorkoutStats>;
        _typeDistribution = results[1] as Map<String, int>;
        _monthlyOverview = results[2] as MonthlyOverview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('運動統計'),
        backgroundColor: AppColors.accent1,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.accent1,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 本月總覽
                    _buildMonthlyOverview(isSmallScreen),
                    const SizedBox(height: 20),
                    
                    // 本週摘要卡片
                    _buildWeeklySummaryCards(isSmallScreen),
                    const SizedBox(height: 20),
                    
                    // 圖表區
                    _buildChartTabs(isSmallScreen),
                    const SizedBox(height: 20),
                    
                    // 運動類型分佈
                    _buildSectionTitle('🏋️ 運動類型分佈'),
                    const SizedBox(height: 12),
                    _buildTypePieChart(isSmallScreen),
                    const SizedBox(height: 20),
                    
                    // 每日詳情
                    _buildSectionTitle('📋 本週每日詳情'),
                    const SizedBox(height: 12),
                    _buildDailyList(isSmallScreen),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent1),
          ),
          const SizedBox(height: 16),
          Text(
            '載入統計資料中...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
    );
  }

  // 本月總覽卡片
  Widget _buildMonthlyOverview(bool isSmallScreen) {
    if (_monthlyOverview == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent1, AppColors.accent1.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '本月運動總覽',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('yyyy年M月').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                '${_monthlyOverview!.totalWorkouts}',
                '次訓練',
                Icons.fitness_center,
                isSmallScreen,
              ),
              _buildOverviewItem(
                '${_monthlyOverview!.totalDuration}',
                '分鐘',
                Icons.timer,
                isSmallScreen,
              ),
              _buildOverviewItem(
                '${_monthlyOverview!.totalCalories.toInt()}',
                '大卡',
                Icons.local_fire_department,
                isSmallScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(String value, String label, IconData icon, bool isSmallScreen) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: isSmallScreen ? 22 : 26),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 11 : 12,
          ),
        ),
      ],
    );
  }

  // 本週摘要卡片
  Widget _buildWeeklySummaryCards(bool isSmallScreen) {
    int totalWorkouts = _weeklyStats.fold(0, (sum, s) => sum + s.workoutCount);
    int totalDuration = _weeklyStats.fold(0, (sum, s) => sum + s.duration);
    double totalCalories = _weeklyStats.fold(0.0, (sum, s) => sum + s.calories);
    int activeDays = _weeklyStats.where((s) => s.workoutCount > 0).length;

    return Row(
      children: [
        Expanded(
          child: _buildMiniCard(
            icon: Icons.calendar_today,
            color: AppColors.accent2,
            title: '訓練天數',
            value: '$activeDays',
            unit: '/ 7 天',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.timer_outlined,
            color: AppColors.info,
            title: '本週時長',
            value: '$totalDuration',
            unit: '分鐘',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.local_fire_department,
            color: AppColors.accent1,
            title: '本週消耗',
            value: '${totalCalories.toInt()}',
            unit: '大卡',
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
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: isSmallScreen ? 10 : 11,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: isSmallScreen ? 9 : 10,
            ),
          ),
        ],
      ),
    );
  }

  // 圖表 Tab
  Widget _buildChartTabs(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.accent1,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent1,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: '運動時長'),
              Tab(text: '卡路里消耗'),
            ],
          ),
          SizedBox(
            height: isSmallScreen ? 220 : 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildDurationChart(isSmallScreen),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCaloriesChart(isSmallScreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 運動時長折線圖
  Widget _buildDurationChart(bool isSmallScreen) {
    if (_weeklyStats.isEmpty || _weeklyStats.every((s) => s.duration == 0)) {
      return _buildEmptyChartContent('本週還沒有運動記錄');
    }

    double maxDuration = _weeklyStats
        .map((e) => e.duration.toDouble())
        .reduce((a, b) => a > b ? a : b);
    double yMax = maxDuration > 0 ? (maxDuration * 1.3).ceilToDouble() : 60;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isSmallScreen ? 30 : 35,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: isSmallScreen ? 9 : 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= _weeklyStats.length) return const SizedBox();
                final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
                final weekdayIndex = _weeklyStats[index].date.weekday - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '週${weekdays[weekdayIndex]}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
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
              _weeklyStats.length,
              (i) => FlSpot(i.toDouble(), _weeklyStats[i].duration.toDouble()),
            ),
            isCurved: true,
            color: AppColors.accent1,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.accent1,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent1.withValues(alpha: 0.3),
                  AppColors.accent1.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots.map((spot) => LineTooltipItem(
                '${spot.y.toInt()} 分鐘',
                const TextStyle(color: Colors.white, fontSize: 12),
              )).toList();
            },
          ),
        ),
      ),
    );
  }

  // 卡路里消耗柱狀圖
  Widget _buildCaloriesChart(bool isSmallScreen) {
    if (_weeklyStats.isEmpty || _weeklyStats.every((s) => s.calories == 0)) {
      return _buildEmptyChartContent('本週還沒有運動記錄');
    }

    double maxCalories = _weeklyStats
        .map((e) => e.calories)
        .reduce((a, b) => a > b ? a : b);
    double yMax = maxCalories > 0 ? (maxCalories * 1.3).ceilToDouble() : 300;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isSmallScreen ? 30 : 35,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: isSmallScreen ? 9 : 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= _weeklyStats.length) return const SizedBox();
                final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
                final weekdayIndex = _weeklyStats[index].date.weekday - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '週${weekdays[weekdayIndex]}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(_weeklyStats.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _weeklyStats[i].calories,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent1,
                    AppColors.accent1.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} 大卡',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }

  // 運動類型分布圓餅圖
  Widget _buildTypePieChart(bool isSmallScreen) {
    if (_typeDistribution.isEmpty) {
      return _buildEmptyCard('本月還沒有運動記錄');
    }

    final typeNames = {
      'strength': '重訓',
      'cardio': '有氧',
      'flexibility': '柔軟度',
      'sports': '運動',
      'hiit': 'HIIT',
      'yoga': '瑜伽',
      'other': '其他',
    };

    final colors = [
      AppColors.accent1,
      AppColors.accent2,
      AppColors.accent3,
      AppColors.info,
      AppColors.primary,
      Colors.purple.shade300,
      Colors.grey.shade400,
    ];

    int total = _typeDistribution.values.fold(0, (a, b) => a + b);
    int colorIndex = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legends = [];

    _typeDistribution.forEach((type, count) {
      Color color = colors[colorIndex % colors.length];
      double percentage = (count / total * 100);
      
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '${percentage.toInt()}%',
          color: color,
          radius: isSmallScreen ? 50 : 60,
          titleStyle: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legends.add(
        _buildLegendItem(
          typeNames[type] ?? type,
          count,
          color,
          isSmallScreen,
        ),
      );

      colorIndex++;
    });

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          // 圓餅圖
          Expanded(
            flex: 3,
            child: SizedBox(
              height: isSmallScreen ? 140 : 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: isSmallScreen ? 25 : 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          // 圖例
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: legends,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: isSmallScreen ? 11 : 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count次',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 每日詳情列表
  Widget _buildDailyList(bool isSmallScreen) {
    if (_weeklyStats.isEmpty) {
      return _buildEmptyCard('本週還沒有數據');
    }

    final weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: List.generate(_weeklyStats.length, (i) {
          final day = _weeklyStats[i];
          final isToday = DateFormat('yyyy-MM-dd').format(day.date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final hasWorkout = day.workoutCount > 0;

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: isToday ? AppColors.accent1.withValues(alpha: 0.08) : null,
              border: i < _weeklyStats.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                  : null,
            ),
            child: Row(
              children: [
                // 日期
                SizedBox(
                  width: isSmallScreen ? 55 : 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdays[day.date.weekday - 1],
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.accent1 : AppColors.textPrimary,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                      Text(
                        DateFormat('MM/dd').format(day.date),
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: isSmallScreen ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 狀態圖標
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hasWorkout
                        ? AppColors.success.withValues(alpha: 0.2)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasWorkout ? Icons.check : Icons.remove,
                    size: 16,
                    color: hasWorkout ? AppColors.success : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 訓練數據
                Expanded(
                  child: hasWorkout
                      ? Row(
                          children: [
                            Expanded(
                              child: _buildDayStatItem(
                                Icons.fitness_center,
                                '${day.workoutCount}次',
                                isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _buildDayStatItem(
                                Icons.timer_outlined,
                                '${day.duration}分',
                                isSmallScreen,
                              ),
                            ),
                            Expanded(
                              child: _buildDayStatItem(
                                Icons.local_fire_department,
                                '${day.calories.toInt()}卡',
                                isSmallScreen,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '休息日',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: isSmallScreen ? 12 : 13,
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayStatItem(IconData icon, String value, bool isSmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 14 : 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isSmallScreen ? 11 : 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.fitness_center, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: AppColors.textTertiary),
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
          Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}