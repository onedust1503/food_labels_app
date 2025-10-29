// lib/pages/stats/nutrition_stats_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/stats_service.dart';

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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '載入統計數據中...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('📊 本週卡路里攝取'),
                    const SizedBox(height: 12),
                    _buildCaloriesLineChart(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('🥩 三大營養素趨勢'),
                    const SizedBox(height: 12),
                    _buildMacrosLineChart(),
                    const SizedBox(height: 24),
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

  // 卡路里趨勢圖 - 優化版
  Widget _buildCaloriesLineChart() {
    if (_weeklyNutrition.isEmpty) {
      return _buildEmptyChart('本週還沒有飲食記錄');
    }

    double maxCalories = _weeklyNutrition
        .map((e) => e.calories)
        .reduce((a, b) => a > b ? a : b);
    maxCalories = maxCalories > _caloriesGoal ? maxCalories : _caloriesGoal;
    double yMax = (maxCalories * 1.2).ceilToDouble();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 5,
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
                interval: yMax / 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= _weeklyNutrition.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyNutrition[value.toInt()].date;
                  final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
                  final weekdayIndex = date.weekday - 1;
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '週${weekdays[weekdayIndex]}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
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
            // 實際攝取
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
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: Colors.green,
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.4),
                    Colors.green.withOpacity(0.08),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
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

  // 三大營養素趨勢圖 - 優化版
  Widget _buildMacrosLineChart() {
    if (_weeklyNutrition.isEmpty) {
      return _buildEmptyChart('本週還沒有飲食記錄');
    }

    double maxValue = 0;
    for (var stats in _weeklyNutrition) {
      if (stats.protein > maxValue) maxValue = stats.protein;
      if (stats.carbs > maxValue) maxValue = stats.carbs;
      if (stats.fat > maxValue) maxValue = stats.fat;
    }
    double yMax = (maxValue * 1.2).ceilToDouble();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 圖例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('蛋白質', Colors.red),
              const SizedBox(width: 16),
              _buildLegend('碳水', Colors.blue),
              const SizedBox(width: 16),
              _buildLegend('脂肪', Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: yMax > 0 ? yMax : 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax > 0 ? yMax / 5 : 20,
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
                      interval: yMax > 0 ? yMax / 5 : 20,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= _weeklyNutrition.length) {
                          return const SizedBox.shrink();
                        }
                        final date = _weeklyNutrition[value.toInt()].date;
                        final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
                        final weekdayIndex = date.weekday - 1;
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '週${weekdays[weekdayIndex]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
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
                    barWidth: 2.8,
                    isStrokeCapRound: true,
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
                    barWidth: 2.8,
                    isStrokeCapRound: true,
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
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 喝水統計柱狀圖 - 優化版
  Widget _buildWaterBarChart() {
    if (_weeklyWater.isEmpty) {
      return _buildEmptyChart('本週還沒有喝水記錄');
    }

    double maxAmount = _weeklyWater
        .map((e) => e.amount)
        .reduce((a, b) => a > b ? a : b);
    double yMax = maxAmount > 2000 ? (maxAmount * 1.2).ceilToDouble() : 2500;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax / 5,
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
                interval: yMax / 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= _weeklyWater.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyWater[value.toInt()].date;
                  final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
                  final weekdayIndex = date.weekday - 1;
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '週${weekdays[weekdayIndex]}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
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
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: _weeklyWater[index].amount,
                    gradient: LinearGradient(
                      colors: _weeklyWater[index].amount >= 2000
                          ? [Colors.blue, Colors.lightBlue.shade300]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 26,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
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
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '開始記錄以查看統計',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}