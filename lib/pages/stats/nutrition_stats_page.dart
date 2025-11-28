// lib/pages/stats/nutrition_stats_page.dart
// 🔥 優化版 - 響應式設計、快速載入、精簡佈局
// ✨ 明亮版莫蘭迪風格

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
  
  bool _isLoading = true;
  bool _isSwitching = false; // 切換時的輕量載入狀態
  AllStatsData? _weekData;   // 快取本週數據
  AllStatsData? _monthData;  // 快取本月數據
  AllStatsData _currentData = AllStatsData.empty();

  // 時間範圍選擇
  int _selectedPeriodIndex = 0;
  final List<String> _periods = ['本週', '本月'];

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

  // 🔥 優化：一次性載入，使用快取
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 🔥 一次性載入所有數據
      _weekData = await _statsService.getAllStats(days: 7);
      
      setState(() {
        _currentData = _weekData!;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  // 🔥 切換時間範圍（使用快取或載入）
  Future<void> _switchPeriod(int index) async {
    if (_selectedPeriodIndex == index) return;

    setState(() {
      _selectedPeriodIndex = index;
      _isSwitching = true;
    });

    try {
      if (index == 0) {
        // 本週
        if (_weekData == null) {
          _weekData = await _statsService.getAllStats(days: 7);
        }
        _currentData = _weekData!;
      } else {
        // 本月
        if (_monthData == null) {
          DateTime now = DateTime.now();
          _monthData = await _statsService.getAllStats(days: now.day);
        }
        _currentData = _monthData!;
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 獲取螢幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('營養統計'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 時間範圍選擇器
                        _buildPeriodSelector(),
                        const SizedBox(height: 16),
                        
                        // 今日進度卡片
                        _buildTodayProgress(isSmallScreen),
                        const SizedBox(height: 16),
                        
                        // 摘要卡片
                        _buildSummaryCards(isSmallScreen),
                        const SizedBox(height: 20),
                        
                        // 圖表區域
                        _buildChartTabs(isSmallScreen),
                        const SizedBox(height: 20),
                        
                        // 達標率
                        _buildSectionTitle('🎯 達標率'),
                        const SizedBox(height: 12),
                        _buildCompletionRates(isSmallScreen),
                        const SizedBox(height: 20),
                        
                        // 每日數據
                        _buildSectionTitle('📋 每日詳情'),
                        const SizedBox(height: 12),
                        _buildDailyList(isSmallScreen),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                // 切換時的載入指示器
                if (_isSwitching)
                  Container(
                    color: Colors.black12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.medium,
                        ),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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

  // 時間範圍選擇器
  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = index == _selectedPeriodIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchPeriod(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _periods[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
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
      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
    );
  }

  // 🔥 今日進度（響應式）
  Widget _buildTodayProgress(bool isSmallScreen) {
    if (_currentData.nutritionStats.isEmpty) {
      return _buildEmptyCard('還沒有數據');
    }

    final today = _currentData.nutritionStats.last;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '今日營養',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('MM/dd').format(today.date),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 主要營養素 - 2x2 網格
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isSmallScreen ? 1.8 : 2.0,  // 🔥 降低比例增加高度
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
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,  // 🔥 均勻分布
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
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
          // 🔥 使用 FittedBox 防止文字溢出
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
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: isSmallScreen ? 3 : 4,
            ),
          ),
        ],
      ),
    );
  }

  // 摘要卡片（響應式）
  Widget _buildSummaryCards(bool isSmallScreen) {
    final summary = _currentData.nutritionSummary;
    final waterSummary = _currentData.waterSummary;

    return Row(
      children: [
        Expanded(
          child: _buildMiniCard(
            icon: Icons.local_fire_department,
            color: AppColors.accent1,
            title: '平均',
            value: '${summary.avgCalories.toInt()}',
            unit: '大卡',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.restaurant,
            color: AppColors.accent2,
            title: '餐數',
            value: '${summary.totalMeals}',
            unit: '餐',
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniCard(
            icon: Icons.water_drop,
            color: AppColors.info,
            title: '喝水',
            value: '${waterSummary.completedDays}/${waterSummary.totalDays}',
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

  // 🔥 圖表 Tab 切換
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
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: '熱量趨勢'),
              Tab(text: '喝水統計'),
            ],
          ),
          SizedBox(
            height: isSmallScreen ? 220 : 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCaloriesChart(isSmallScreen),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildWaterChart(isSmallScreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 熱量趨勢圖
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
    double yMax = maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 2500;

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
              reservedSize: isSmallScreen ? 35 : 40,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}k',
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index < 0 || index >= stats.length) return const SizedBox();
                // 只顯示部分標籤避免擁擠
                if (stats.length > 7 && index % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d').format(stats[index].date),
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
          // 實際攝取
          LineChartBarData(
            spots: List.generate(
              stats.length,
              (i) => FlSpot(i.toDouble(), stats[i].calories),
            ),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: stats.length <= 10,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.primary,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // 目標線
          LineChartBarData(
            spots: List.generate(
              stats.length,
              (i) => FlSpot(i.toDouble(), stats[i].targetCalories),
            ),
            isCurved: false,
            color: Colors.red.shade300,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            dashArray: [4, 4],
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                String label = spot.barIndex == 0 ? '實際' : '目標';
                return LineTooltipItem(
                  '$label: ${spot.y.toInt()}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // 喝水統計圖
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
              reservedSize: isSmallScreen ? 40 : 45,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}L',
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
                if (index < 0 || index >= stats.length) return const SizedBox();
                if (stats.length > 7 && index % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d').format(stats[index].date),
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
        barGroups: List.generate(stats.length, (i) {
          final s = stats[i];
          final isCompleted = s.amount >= s.goal * 0.8;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: s.amount,
                color: isCompleted ? AppColors.info : AppColors.info.withValues(alpha: 0.4),
                width: stats.length > 15 ? 8 : (stats.length > 7 ? 12 : 16),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = stats[groupIndex];
              return BarTooltipItem(
                '${s.amount.toInt()}/${s.goal.toInt()}ml',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }

  // 達標率
  Widget _buildCompletionRates(bool isSmallScreen) {
    final summary = _currentData.nutritionSummary;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompletionCircle('熱量', summary.caloriesCompletionRate, AppColors.primary, isSmallScreen),
          _buildCompletionCircle('蛋白', summary.proteinCompletionRate, AppColors.accent2, isSmallScreen),
          _buildCompletionCircle('碳水', summary.carbsCompletionRate, AppColors.accent1, isSmallScreen),
          _buildCompletionCircle('脂肪', summary.fatCompletionRate, AppColors.accent3, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildCompletionCircle(String label, double rate, Color color, bool isSmallScreen) {
    double size = isSmallScreen ? 50 : 60;
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
                strokeWidth: isSmallScreen ? 4 : 5,
                backgroundColor: color.withValues(alpha: 0.2),
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
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isSmallScreen ? 10 : 11,
          ),
        ),
      ],
    );
  }

  // 每日詳情列表
  Widget _buildDailyList(bool isSmallScreen) {
    if (_currentData.nutritionStats.isEmpty) {
      return _buildEmptyCard('還沒有數據');
    }

    // 反轉順序，最新的在上面
    final stats = _currentData.nutritionStats.reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: List.generate(stats.length.clamp(0, 7), (i) {
          final day = stats[i];
          final isToday = DateFormat('yyyy-MM-dd').format(day.date) ==
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary.withValues(alpha: 0.08) : null,
              border: i < stats.length - 1
                  ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                  : null,
            ),
            child: Row(
              children: [
                // 日期
                SizedBox(
                  width: isSmallScreen ? 50 : 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MM/dd').format(day.date),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.primary : AppColors.textPrimary,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                      Text(
                        DateFormat('E', 'zh_TW').format(day.date),
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: isSmallScreen ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 熱量
                Expanded(
                  flex: 2,
                  child: _buildDayValue(
                    '${day.calories.toInt()}',
                    '大卡',
                    day.caloriesProgress >= 80,
                    isSmallScreen,
                  ),
                ),
                
                // 蛋白質
                Expanded(
                  child: _buildDayValue(
                    '${day.protein.toInt()}g',
                    '',
                    day.proteinProgress >= 80,
                    isSmallScreen,
                  ),
                ),
                
                // 碳水
                Expanded(
                  child: _buildDayValue(
                    '${day.carbs.toInt()}g',
                    '',
                    day.carbsProgress >= 80,
                    isSmallScreen,
                  ),
                ),
                
                // 脂肪
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
      ),
    );
  }

  Widget _buildDayValue(String value, String unit, bool isGood, bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isGood)
          Icon(
            Icons.check_circle,
            size: isSmallScreen ? 12 : 14,
            color: AppColors.success,
          ),
        if (isGood) const SizedBox(width: 2),
        Flexible(
          child: Text(
            value + unit,
            style: TextStyle(
              color: isGood ? AppColors.success : AppColors.textSecondary,
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: isGood ? FontWeight.w500 : FontWeight.normal,
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
            Icon(Icons.inbox_outlined, size: 40, color: AppColors.textTertiary),
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
          Icon(Icons.insert_chart_outlined, size: 36, color: AppColors.textTertiary),
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