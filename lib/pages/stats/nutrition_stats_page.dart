// lib/pages/stats/nutrition_stats_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/stats_service.dart';
import 'package:intl/intl.dart';

class NutritionStatsPage extends StatefulWidget {
  const NutritionStatsPage({super.key});

  @override
  State<NutritionStatsPage> createState() => _NutritionStatsPageState();
}

class _NutritionStatsPageState extends State<NutritionStatsPage> {
  final StatsService _statsService = StatsService();
  
  bool _isLoading = true;
  List<DailyNutritionStats> _weeklyNutrition = [];
  List<DailyWaterStats> _weeklyWater = [];

  // 營養目標（可以之後從用戶設定讀取）
  final double _caloriesGoal = 2000;
  final double _proteinGoal = 150;
  final double _carbsGoal = 250;
  final double _fatGoal = 65;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final weeklyNutrition = await _statsService.getWeeklyNutritionStats();
      final weeklyWater = await _statsService.getWeeklyWaterStats();

      setState(() {
        _weeklyNutrition = weeklyNutrition;
        _weeklyWater = weeklyWater;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('營養統計'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 今日營養達標率
                    _buildTodayProgress(),
                    const SizedBox(height: 24),

                    // 本週卡路里趨勢
                    _buildSectionTitle('📈 本週卡路里趨勢'),
                    const SizedBox(height: 12),
                    _buildCaloriesLineChart(),
                    const SizedBox(height: 24),

                    // 三大營養素趨勢
                    _buildSectionTitle('🥗 三大營養素趨勢'),
                    const SizedBox(height: 12),
                    _buildMacrosLineChart(),
                    const SizedBox(height: 24),

                    // 喝水統計
                    _buildSectionTitle('💧 本週喝水統計'),
                    const SizedBox(height: 12),
                    _buildWaterBarChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 今日營養達標率
  Widget _buildTodayProgress() {
    if (_weeklyNutrition.isEmpty) {
      return const SizedBox.shrink();
    }

    final today = _weeklyNutrition.last;
    final caloriesProgress = (today.calories / _caloriesGoal * 100).clamp(0, 100);
    final proteinProgress = (today.protein / _proteinGoal * 100).clamp(0, 100);
    final carbsProgress = (today.carbs / _carbsGoal * 100).clamp(0, 100);
    final fatProgress = (today.fat / _fatGoal * 100).clamp(0, 100);

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
          const Text(
            '今日營養達標率',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressItem(
            '熱量',
            today.calories,
            _caloriesGoal,
            caloriesProgress.toDouble(),
            '大卡',
          ),
          const SizedBox(height: 12),
          _buildProgressItem(
            '蛋白質',
            today.protein,
            _proteinGoal,
            proteinProgress.toDouble(),
            'g',
          ),
          const SizedBox(height: 12),
          _buildProgressItem(
            '碳水',
            today.carbs,
            _carbsGoal,
            carbsProgress.toDouble(),
            'g',
          ),
          const SizedBox(height: 12),
          _buildProgressItem(
            '脂肪',
            today.fat,
            _fatGoal,
            fatProgress.toDouble(),
            'g',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String label,
    double current,
    double goal,
    double progress,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            Text(
              '${current.toInt()} / ${goal.toInt()} $unit',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: Colors.white30,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  // 卡路里趨勢圖
  Widget _buildCaloriesLineChart() {
    if (_weeklyNutrition.isEmpty) {
      return _buildEmptyChart('本週還沒有飲食記錄');
    }

    return Container(
      height: 250,
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 500,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= _weeklyNutrition.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyNutrition[value.toInt()].date;
                  return Text(
                    DateFormat('E', 'zh_TW').format(date).substring(0, 1),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                _weeklyNutrition.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _weeklyNutrition[index].calories,
                ),
              ),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
            // 目標線
            LineChartBarData(
              spots: List.generate(
                _weeklyNutrition.length,
                (index) => FlSpot(index.toDouble(), _caloriesGoal),
              ),
              isCurved: false,
              color: Colors.red.withOpacity(0.5),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }

  // 三大營養素趨勢圖
  Widget _buildMacrosLineChart() {
    if (_weeklyNutrition.isEmpty) {
      return _buildEmptyChart('本週還沒有飲食記錄');
    }

    return Container(
      height: 250,
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}g',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= _weeklyNutrition.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyNutrition[value.toInt()].date;
                  return Text(
                    DateFormat('E', 'zh_TW').format(date).substring(0, 1),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // 蛋白質
            LineChartBarData(
              spots: List.generate(
                _weeklyNutrition.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _weeklyNutrition[index].protein,
                ),
              ),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            // 碳水
            LineChartBarData(
              spots: List.generate(
                _weeklyNutrition.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _weeklyNutrition[index].carbs,
                ),
              ),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            // 脂肪
            LineChartBarData(
              spots: List.generate(
                _weeklyNutrition.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _weeklyNutrition[index].fat,
                ),
              ),
              isCurved: true,
              color: Colors.orange,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  // 喝水統計柱狀圖
  Widget _buildWaterBarChart() {
    if (_weeklyWater.isEmpty) {
      return _buildEmptyChart('本週還沒有喝水記錄');
    }

    return Container(
      height: 250,
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
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 500,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}ml',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= _weeklyWater.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyWater[value.toInt()].date;
                  return Text(
                    DateFormat('E', 'zh_TW').format(date).substring(0, 1),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            _weeklyWater.length,
            (index) {
              final stats = _weeklyWater[index];
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: stats.amount,
                    color: stats.progress >= 100 
                        ? Colors.blue 
                        : Colors.blue.withOpacity(0.5),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}