// lib/pages/nutrition/nutrition_analysis_page.dart
// 營養分析頁面 - 近期趨勢圖表 + 時間軸視圖

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class NutritionAnalysisPage extends StatefulWidget {
  final String userId;
  
  const NutritionAnalysisPage({
    super.key,
    required this.userId,
  });

  @override
  State<NutritionAnalysisPage> createState() => _NutritionAnalysisPageState();
}

class _NutritionAnalysisPageState extends State<NutritionAnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🎯 時間範圍選擇 (7天 / 30天)
  int _selectedDays = 7;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: StreamBuilder<QuerySnapshot>(
        stream: _getRecentLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // 📊 處理數據
          final logs = snapshot.data!.docs;
          final dailyData = _processDailyData(logs);
          final timelineData = _processTimelineData(logs);

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // 時間範圍選擇器
              _buildPeriodSelector(),
              
              const SizedBox(height: 20),
              
              // 📊 熱量趨勢圖
              _buildCaloriesTrendChart(dailyData),
              
              const SizedBox(height: 20),
              
              // 🥧 營養素分佈圓餅圖
              _buildNutrientsPieChart(dailyData),
              
              const SizedBox(height: 20),
              
              // ⏱️ 時間軸記錄列表
              _buildTimelineHeader(),
              
              const SizedBox(height: 12),
              
              ...timelineData.map((item) => _buildTimelineItem(item)),
              
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  /// 🎯 獲取近期記錄流
  Stream<QuerySnapshot> _getRecentLogsStream() {
    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: _selectedDays - 1));
    String startDateStr = startDate.toIso8601String().split('T')[0];

    return _firestore
        .collection('nutritionLogs')
        .where('userId', isEqualTo: widget.userId)
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .snapshots();
  }

  /// 📊 處理每日數據 (用於圖表)
  Map<String, Map<String, dynamic>> _processDailyData(List<QueryDocumentSnapshot> logs) {
    Map<String, Map<String, dynamic>> dailyData = {};

    for (var doc in logs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String date = data['date'] ?? '';
      
      if (!dailyData.containsKey(date)) {
        dailyData[date] = {
          'calories': 0.0,
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 0.0,
          'count': 0,
        };
      }
      
      dailyData[date]!['calories'] += (data['calories'] ?? 0);
      dailyData[date]!['protein'] += (data['protein'] ?? 0);
      dailyData[date]!['carbs'] += (data['carbs'] ?? 0);
      dailyData[date]!['fat'] += (data['fat'] ?? 0);
      dailyData[date]!['count'] += 1;
    }

    return dailyData;
  }

  /// ⏱️ 處理時間軸數據 (用於列表)
  List<Map<String, dynamic>> _processTimelineData(List<QueryDocumentSnapshot> logs) {
    List<Map<String, dynamic>> timelineData = [];

    for (var doc in logs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      timelineData.add({
        'id': doc.id,
        'foodName': data['foodName'] ?? '未知食物',
        'mealType': (data['mealType'] ?? 'snack').toLowerCase(),
        'calories': (data['calories'] ?? 0).toDouble(),
        'protein': (data['protein'] ?? 0).toDouble(),
        'carbs': (data['carbs'] ?? 0).toDouble(),
        'fat': (data['fat'] ?? 0).toDouble(),
        'servings': (data['servings'] ?? 1).toDouble(),
        'servingSize': data['servingSize'] ?? '份',
        'date': data['date'] ?? '',
        'createdAt': data['createdAt'],
      });
    }

    // 按時間倒序排列 (最新的在上面)
    timelineData.sort((a, b) {
      if (a['createdAt'] == null && b['createdAt'] == null) return 0;
      if (a['createdAt'] == null) return 1;
      if (b['createdAt'] == null) return -1;
      
      DateTime dateA = (a['createdAt'] as Timestamp).toDate();
      DateTime dateB = (b['createdAt'] as Timestamp).toDate();
      return dateB.compareTo(dateA);
    });

    return timelineData;
  }

  /// 🎚️ 時間範圍選擇器
  Widget _buildPeriodSelector() {
    return SoftCard(
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton('7 天', 7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPeriodButton('30 天', 30),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int days) {
    bool isSelected = _selectedDays == days;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDays = days;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 📊 熱量趨勢圖
  Widget _buildCaloriesTrendChart(Map<String, Map<String, dynamic>> dailyData) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.calories.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: AppColors.calories,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '熱量趨勢',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // 平均值
              _buildAverageLabel(dailyData),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 圖表
          SizedBox(
            height: 220,
            child: dailyData.isEmpty
                ? _buildNoDataChart()
                : _buildBarChart(dailyData),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageLabel(Map<String, Map<String, dynamic>> dailyData) {
    if (dailyData.isEmpty) return const SizedBox.shrink();
    
    double totalCalories = 0;
    for (var data in dailyData.values) {
      totalCalories += data['calories'];
    }
    double average = totalCalories / dailyData.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.calories.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.calories.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '平均',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${average.toInt()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.calories,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            '大卡',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 柱狀圖
  Widget _buildBarChart(Map<String, Map<String, dynamic>> dailyData) {
    // 生成完整的日期範圍
    DateTime now = DateTime.now();
    List<DateTime> dates = List.generate(
      _selectedDays,
      (index) => now.subtract(Duration(days: _selectedDays - 1 - index)),
    );

    // 準備圖表數據
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 0; i < dates.length; i++) {
      String dateStr = dates[i].toIso8601String().split('T')[0];
      double calories = dailyData[dateStr]?['calories'] ?? 0;
      
      if (calories > maxY) maxY = calories;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: calories,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.calories.withOpacity(0.7),
                  AppColors.calories,
                ],
              ),
              width: _selectedDays == 7 ? 24 : 12,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        minY: 0,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.divider.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                  DateTime date = dates[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // tooltipBgColor: AppColors.cardBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String dateStr = dates[group.x.toInt()].toIso8601String().split('T')[0];
              double calories = dailyData[dateStr]?['calories'] ?? 0;
              
              return BarTooltipItem(
                '${calories.toInt()} 大卡\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: DateFormat('M/d').format(dates[group.x.toInt()]),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
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

  /// 🥧 營養素分佈圓餅圖
  Widget _buildNutrientsPieChart(Map<String, Map<String, dynamic>> dailyData) {
    // 計算總營養素
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var data in dailyData.values) {
      totalProtein += data['protein'];
      totalCarbs += data['carbs'];
      totalFat += data['fat'];
    }

    double total = totalProtein + totalCarbs + totalFat;
    
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '營養素分佈',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          if (total == 0)
            _buildNoDataPieChart()
          else
            Row(
              children: [
                // 圓餅圖
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(
                            value: totalCarbs,
                            color: AppColors.carbs,
                            title: '${(totalCarbs / total * 100).toInt()}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: totalProtein,
                            color: AppColors.protein,
                            title: '${(totalProtein / total * 100).toInt()}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: totalFat,
                            color: AppColors.fat,
                            title: '${(totalFat / total * 100).toInt()}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // 圖例
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('碳水', totalCarbs, AppColors.carbs),
                      const SizedBox(height: 12),
                      _buildLegendItem('蛋白質', totalProtein, AppColors.protein),
                      const SizedBox(height: 12),
                      _buildLegendItem('脂肪', totalFat, AppColors.fat),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)} g',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// ⏱️ 時間軸標題
  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timeline,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '時間軸記錄',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// ⏱️ 時間軸項目
  Widget _buildTimelineItem(Map<String, dynamic> item) {
    String mealType = item['mealType'];
    DateTime? createdAt;
    
    if (item['createdAt'] != null) {
      createdAt = (item['createdAt'] as Timestamp).toDate();
    }
    
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 左側時間和餐別標示
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                createdAt != null ? DateFormat('M/d').format(createdAt) : '--',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                createdAt != null ? DateFormat('HH:mm').format(createdAt) : '--:--',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.getMealLightColor(mealType),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppColors.getMealEmoji(mealType),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // 分隔線
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.getMealColor(mealType).withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 右側內容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['foodName'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: AppColors.calories,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['calories'].toInt()} 大卡',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildMiniNutrient('P', item['protein'], AppColors.protein),
                    const SizedBox(width: 8),
                    _buildMiniNutrient('C', item['carbs'], AppColors.carbs),
                    const SizedBox(width: 8),
                    _buildMiniNutrient('F', item['fat'], AppColors.fat),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniNutrient(String label, double value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '暫無數據',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataPieChart() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: AppColors.textTertiary.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '暫無數據',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '載入中...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                '載入失敗',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '暫無分析數據',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '開始記錄飲食後\n即可查看詳細分析',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}