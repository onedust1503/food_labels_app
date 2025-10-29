// lib/pages/stats/workout_stats_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/stats_service.dart';

class WorkoutStatsPage extends StatefulWidget {
  const WorkoutStatsPage({super.key});

  @override
  State<WorkoutStatsPage> createState() => _WorkoutStatsPageState();
}

class _WorkoutStatsPageState extends State<WorkoutStatsPage> {
  final StatsService _statsService = StatsService();
  
  bool _isLoading = true;
  List<DailyWorkoutStats> _weeklyStats = [];
  Map<String, int> _typeDistribution = {};
  MonthlyOverview? _monthlyOverview;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final weeklyStats = await _statsService.getWeeklyWorkoutStats();
      final typeDistribution = await _statsService.getWorkoutTypeDistribution();
      final monthlyOverview = await _statsService.getMonthlyOverview();

      setState(() {
        _weeklyStats = weeklyStats;
        _typeDistribution = typeDistribution;
        _monthlyOverview = monthlyOverview;
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
        title: const Text('運動統計'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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
                    _buildMonthlyOverview(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('📈 本週運動時長'),
                    const SizedBox(height: 12),
                    _buildDurationLineChart(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('🔥 每日卡路里消耗'),
                    const SizedBox(height: 12),
                    _buildCaloriesBarChart(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('🥧 運動類型分布'),
                    const SizedBox(height: 12),
                    _buildTypePieChart(),
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

  // 本月總覽卡片
  Widget _buildMonthlyOverview() {
    if (_monthlyOverview == null) return const SizedBox.shrink();

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
            blurRadius: 10,
            offset: const Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月運動總覽',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem(
                '${_monthlyOverview!.totalWorkouts}',
                '次訓練',
                Icons.fitness_center,
              ),
              _buildOverviewItem(
                '${_monthlyOverview!.totalDuration}',
                '分鐘',
                Icons.timer,
              ),
              _buildOverviewItem(
                '${_monthlyOverview!.totalCalories.toInt()}',
                '大卡',
                Icons.local_fire_department,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // 運動時長折線圖 - 優化版
  Widget _buildDurationLineChart() {
    if (_weeklyStats.isEmpty) {
      return _buildEmptyChart('本週還沒有運動記錄');
    }

    double maxDuration = _weeklyStats
        .map((e) => e.duration.toDouble())
        .reduce((a, b) => a > b ? a : b);
    double yMax = (maxDuration * 1.2).ceilToDouble();

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
          maxY: yMax > 0 ? yMax : 60,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax > 0 ? yMax / 5 : 10,
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
                interval: yMax > 0 ? yMax / 5 : 10,
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
                  if (value.toInt() < 0 || value.toInt() >= _weeklyStats.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyStats[value.toInt()].date;
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
            LineChartBarData(
              spots: List.generate(
                _weeklyStats.length,
                (index) => FlSpot(
                  index.toDouble(),
                  _weeklyStats[index].duration.toDouble(),
                ),
              ),
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              isStrokeJoinRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.orange,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.3),
                    Colors.orange.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 卡路里消耗柱狀圖 - 優化版
  Widget _buildCaloriesBarChart() {
    if (_weeklyStats.isEmpty) {
      return _buildEmptyChart('本週還沒有運動記錄');
    }

    double maxCalories = _weeklyStats
        .map((e) => e.calories)
        .reduce((a, b) => a > b ? a : b);
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
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: yMax > 0 ? yMax : 300,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yMax > 0 ? yMax / 5 : 50,
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
                interval: yMax > 0 ? yMax / 5 : 50,
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
                  if (value.toInt() < 0 || value.toInt() >= _weeklyStats.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weeklyStats[value.toInt()].date;
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
            _weeklyStats.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: _weeklyStats[index].calories,
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange,
                      Colors.orange.shade300,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 運動類型分布圓餅圖 - 優化版
  Widget _buildTypePieChart() {
    if (_typeDistribution.isEmpty) {
      return _buildEmptyChart('本月還沒有運動記錄');
    }

    final typeNames = {
      'strength': '重訓',
      'cardio': '有氧',
      'flexibility': '柔軟度',
      'sports': '運動',
      'other': '其他',
    };

    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.pink,
    ];

    int colorIndex = 0;
    List<PieChartSectionData> sections = [];
    
    _typeDistribution.forEach((type, count) {
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '${typeNames[type] ?? type}\n$count次',
          color: colors[colorIndex % colors.length],
          radius: 110,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          titlePositionPercentageOffset: 0.55,
        ),
      );
      colorIndex++;
    });

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
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  // 空資料提示卡片 - 優化版
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
              Icons.bar_chart_outlined,
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