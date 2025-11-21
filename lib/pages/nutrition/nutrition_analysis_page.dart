// lib/pages/nutrition/nutrition_analysis_page.dart
// 營養分析頁面 - 近期趨勢圖表 + 時間軸視圖
// ✨ v3.3: 修復30天模式溢出問題

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
  
  int _selectedDays = 7;
  final ScrollController _chartScrollController = ScrollController();
  OverlayEntry? _tooltipOverlay;
  
  @override
  void dispose() {
    _chartScrollController.dispose();
    _removeTooltip();
    super.dispose();
  }
  
  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }
  
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

          final logs = snapshot.data!.docs;
          final dailyData = _processDailyData(logs);
          final timelineData = _processTimelineData(logs);

          return GestureDetector(
            onTap: _removeTooltip,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 20),
                _buildCaloriesTrendChart(dailyData),
                const SizedBox(height: 20),
                _buildNutrientsPieChart(dailyData),
                const SizedBox(height: 20),
                _buildTimelineHeader(),
                const SizedBox(height: 12),
                ...timelineData.map((item) => _buildTimelineItem(item)),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

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
        'isFromCombo': data['isFromCombo'] ?? false,
        'comboName': data['comboName'] ?? '',
        'comboId': data['comboId'] ?? '',
      });
    }

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

  Widget _buildPeriodSelector() {
    return SoftCard(
      child: Row(
        children: [
          Expanded(child: _buildPeriodButton('7 天', 7)),
          const SizedBox(width: 12),
          Expanded(child: _buildPeriodButton('30 天', 30)),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int days) {
    bool isSelected = _selectedDays == days;
    
    return GestureDetector(
      onTap: () {
        _removeTooltip();
        setState(() {
          _selectedDays = days;
        });
        if (days == 30) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_chartScrollController.hasClients) {
              _chartScrollController.animateTo(
                _chartScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
              : null,
          color: isSelected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
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
                child: const Icon(Icons.local_fire_department, color: AppColors.calories, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '熱量趨勢',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              _buildAverageLabel(dailyData),
            ],
          ),
          
          if (_selectedDays == 30) ...[
            const SizedBox(height: 12),
            _buildScrollHint(),
          ],
          
          const SizedBox(height: 16),
          
          // ✨ v3.3: 使用 ClipRect 確保不會溢出
          ClipRect(
            child: SizedBox(
              height: 220,
              child: dailyData.isEmpty
                  ? _buildNoDataChart()
                  : _selectedDays == 7
                      ? _buildPreciseBarChart7Days(dailyData)
                      : _buildPreciseBarChart30Days(dailyData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swipe, size: 16, color: AppColors.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            '左右滑動查看完整數據',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
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
        border: Border.all(color: AppColors.calories.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('平均', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Text('${average.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.calories)),
          const SizedBox(width: 2),
          const Text('大卡', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  double _calculateNiceMaxY(double maxValue) {
    if (maxValue == 0) return 2000;
    
    double niceMax = maxValue * 1.15;
    
    if (niceMax <= 500) {
      return ((niceMax / 100).ceil() * 100).toDouble();
    } else if (niceMax <= 1000) {
      return ((niceMax / 200).ceil() * 200).toDouble();
    } else if (niceMax <= 2000) {
      return ((niceMax / 500).ceil() * 500).toDouble();
    } else if (niceMax <= 5000) {
      return ((niceMax / 1000).ceil() * 1000).toDouble();
    } else if (niceMax <= 10000) {
      return ((niceMax / 2000).ceil() * 2000).toDouble();
    } else {
      return ((niceMax / 5000).ceil() * 5000).toDouble();
    }
  }

  /// ✨ 7天精準柱狀圖 - 已修正
  Widget _buildPreciseBarChart7Days(Map<String, Map<String, dynamic>> dailyData) {
    DateTime now = DateTime.now();
    List<DateTime> dates = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    
    List<double> values = [];
    for (var date in dates) {
      String dateStr = date.toIso8601String().split('T')[0];
      values.add(dailyData[dateStr]?['calories']?.toDouble() ?? 0);
    }
    
    double maxY = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0;
    double yMax = _calculateNiceMaxY(maxY);
    
    List<double> yTicks = [0, yMax * 0.25, yMax * 0.5, yMax * 0.75, yMax];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        const double yAxisWidth = 50;
        const double xAxisHeight = 24;
        final double chartHeight = constraints.maxHeight - xAxisHeight;
        
        return Stack(
          children: [
            // Y 軸標籤
            Positioned(
              left: 0,
              top: 0,
              bottom: xAxisHeight,
              width: yAxisWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: yTicks.reversed.map((v) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                )).toList(),
              ),
            ),
            
            // 圖表區域
            Positioned(
              left: yAxisWidth,
              top: 0,
              right: 0,
              bottom: xAxisHeight,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: values,
                  yMax: yMax,
                  yTicks: yTicks,
                  barColor: AppColors.calories,
                  todayIndex: 6,
                  todayColor: AppColors.primary,
                ),
                child: GestureDetector(
                  onTapDown: (details) {
                    final chartWidth = constraints.maxWidth - yAxisWidth;
                    int index = _getTappedBarIndex(details.localPosition, chartWidth, 7);
                    if (index >= 0 && index < 7) {
                      _showInstantTooltip(details.globalPosition, dates[index], values[index]);
                    }
                  },
                  onLongPressStart: (details) {
                    final chartWidth = constraints.maxWidth - yAxisWidth;
                    int index = _getTappedBarIndex(details.localPosition, chartWidth, 7);
                    if (index >= 0 && index < 7) {
                      _showInstantTooltip(details.globalPosition, dates[index], values[index]);
                    }
                  },
                  onLongPressEnd: (_) => _removeTooltip(),
                ),
              ),
            ),
            
            // X 軸標籤
            Positioned(
              left: yAxisWidth,
              right: 0,
              bottom: 0,
              height: xAxisHeight,
              child: Row(
                children: dates.asMap().entries.map((entry) {
                  int index = entry.key;
                  DateTime date = entry.value;
                  bool isToday = index == 6;
                  
                  return Expanded(
                    child: Center(
                      child: Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ✨ v3.3: 30天精準柱狀圖 - 完全重寫，使用 Positioned 避免溢出
  Widget _buildPreciseBarChart30Days(Map<String, Map<String, dynamic>> dailyData) {
    DateTime now = DateTime.now();
    List<DateTime> dates = List.generate(30, (index) => now.subtract(Duration(days: 29 - index)));
    
    List<double> values = [];
    for (var date in dates) {
      String dateStr = date.toIso8601String().split('T')[0];
      values.add(dailyData[dateStr]?['calories']?.toDouble() ?? 0);
    }
    
    double maxY = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0;
    double yMax = _calculateNiceMaxY(maxY);
    
    List<double> yTicks = [0, yMax * 0.25, yMax * 0.5, yMax * 0.75, yMax];
    
    const double yAxisWidth = 50;
    const double xAxisHeight = 24;  // ✨ 簡化：統一使用單行標籤
    const double barAreaWidth = 38;
    final double scrollableWidth = 30 * barAreaWidth;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final double chartHeight = constraints.maxHeight - xAxisHeight;
        
        return Stack(
          children: [
            // Y 軸標籤（固定）
            Positioned(
              left: 0,
              top: 0,
              bottom: xAxisHeight,
              width: yAxisWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: yTicks.reversed.map((v) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                )).toList(),
              ),
            ),
            
            // 可滑動區域 - 使用 Stack 內部定位避免溢出
            Positioned(
              left: yAxisWidth,
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: SingleChildScrollView(
                  controller: _chartScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: scrollableWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      children: [
                        // 柱狀圖區域
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          bottom: xAxisHeight,
                          child: CustomPaint(
                            painter: _BarChartPainter(
                              values: values,
                              yMax: yMax,
                              yTicks: yTicks,
                              barColor: AppColors.calories,
                              todayIndex: 29,
                              todayColor: AppColors.primary,
                            ),
                            child: GestureDetector(
                              onTapDown: (details) {
                                int index = _getTappedBarIndex(details.localPosition, scrollableWidth, 30);
                                if (index >= 0 && index < 30) {
                                  _showInstantTooltip(details.globalPosition, dates[index], values[index]);
                                }
                              },
                              onLongPressStart: (details) {
                                int index = _getTappedBarIndex(details.localPosition, scrollableWidth, 30);
                                if (index >= 0 && index < 30) {
                                  _showInstantTooltip(details.globalPosition, dates[index], values[index]);
                                }
                              },
                              onLongPressEnd: (_) => _removeTooltip(),
                            ),
                          ),
                        ),
                        
                        // X 軸標籤 - 固定在底部
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: xAxisHeight,
                          child: Row(
                            children: dates.asMap().entries.map((entry) {
                              int index = entry.key;
                              DateTime date = entry.value;
                              bool isToday = index == 29;
                              
                              return SizedBox(
                                width: barAreaWidth,
                                child: Center(
                                  // ✨ v3.3 關鍵修復：簡化標籤，只顯示日期數字
                                  // 「今天」改用顏色區分，不用額外標籤
                                  child: Text(
                                    isToday ? '今天' : '${date.day}',
                                    style: TextStyle(
                                      fontSize: isToday ? 9 : 10,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                      color: isToday ? AppColors.primary : AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _getTappedBarIndex(Offset localPosition, double totalWidth, int count) {
    double barWidth = totalWidth / count;
    return (localPosition.dx / barWidth).floor();
  }

  void _showInstantTooltip(Offset globalPosition, DateTime date, double calories) {
    _removeTooltip();
    
    final overlay = Overlay.of(context);
    
    double tooltipX = globalPosition.dx - 60;
    double tooltipY = globalPosition.dy - 80;
    
    final screenWidth = MediaQuery.of(context).size.width;
    if (tooltipX < 10) tooltipX = 10;
    if (tooltipX > screenWidth - 130) tooltipX = screenWidth - 130;
    if (tooltipY < 60) tooltipY = globalPosition.dy + 20;
    
    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: tooltipX,
        top: tooltipY,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.calories, AppColors.calories.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.calories.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('M月d日').format(date),
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                      ),
                      Text(
                        '${calories.toInt()} 大卡',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_tooltipOverlay!);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (_tooltipOverlay != null) {
        _removeTooltip();
      }
    });
  }

  Widget _buildNutrientsPieChart(Map<String, Map<String, dynamic>> dailyData) {
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
                child: const Icon(Icons.pie_chart, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('營養素分佈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          if (total == 0)
            _buildNoDataPieChart()
          else
            Row(
              children: [
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
                            titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: totalProtein,
                            color: AppColors.protein,
                            title: '${(totalProtein / total * 100).toInt()}%',
                            radius: 45,
                            titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: totalFat,
                            color: AppColors.fat,
                            title: '${(totalFat / total * 100).toInt()}%',
                            radius: 45,
                            titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        Text('${value.toStringAsFixed(1)} g', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.timeline, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('時間軸記錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item) {
    String mealType = item['mealType'];
    DateTime? createdAt;
    
    if (item['createdAt'] != null) {
      createdAt = (item['createdAt'] as Timestamp).toDate();
    }

    bool isFromCombo = item['isFromCombo'] ?? false;
    String comboName = item['comboName'] ?? '';
    
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                createdAt != null ? DateFormat('M/d').format(createdAt) : '--',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                createdAt != null ? DateFormat('HH:mm').format(createdAt) : '--:--',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.getMealLightColor(mealType), borderRadius: BorderRadius.circular(6)),
                child: Text(AppColors.getMealEmoji(mealType), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          Container(
            width: 2,
            height: 60,
            decoration: BoxDecoration(color: AppColors.getMealColor(mealType).withOpacity(0.3), borderRadius: BorderRadius.circular(1)),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['foodName'],
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFromCombo) ...[
                      const SizedBox(width: 8),
                      _buildComboTag(comboName),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 14, color: AppColors.calories),
                    const SizedBox(width: 4),
                    Text('${item['calories'].toInt()} 大卡', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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

  Widget _buildComboTag(String comboName) {
    String displayName = comboName.length > 6 ? '${comboName.substring(0, 6)}...' : comboName;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF4FACFE).withOpacity(0.15), const Color(0xFF00F2FE).withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4FACFE).withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu, size: 10, color: Color(0xFF4FACFE)),
          const SizedBox(width: 4),
          Text(displayName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF4FACFE))),
        ],
      ),
    );
  }

  Widget _buildMiniNutrient(String label, double value, Color color) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 2),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildNoDataChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: AppColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('暫無數據', style: TextStyle(fontSize: 14, color: AppColors.textTertiary.withOpacity(0.6))),
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
            Icon(Icons.pie_chart_outline, size: 48, color: AppColors.textTertiary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('暫無數據', style: TextStyle(fontSize: 14, color: AppColors.textTertiary.withOpacity(0.6))),
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
              boxShadow: [BoxShadow(color: AppColors.shadowLight, offset: const Offset(0, 4), blurRadius: 12)],
            ),
            child: const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
          ),
          const SizedBox(height: 20),
          const Text('載入中...', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
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
              const Text('載入失敗', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                  colors: [AppColors.primary.withOpacity(0.1), AppColors.primaryLight.withOpacity(0.05)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics_outlined, size: 80, color: AppColors.primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 24),
            const Text('暫無分析數據', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            const Text('開始記錄飲食後\n即可查看詳細分析', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter 精準繪製柱狀圖 + 水平輔助線
class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final double yMax;
  final List<double> yTicks;
  final Color barColor;
  final int todayIndex;
  final Color todayColor;
  
  _BarChartPainter({
    required this.values,
    required this.yMax,
    required this.yTicks,
    required this.barColor,
    required this.todayIndex,
    required this.todayColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final int count = values.length;
    final double barAreaWidth = size.width / count;
    final double barWidth = barAreaWidth * 0.55;
    final double barSpacing = (barAreaWidth - barWidth) / 2;
    
    // 繪製水平輔助線（虛線）
    final gridPaint = Paint()
      ..color = AppColors.divider.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (double tick in yTicks) {
      if (tick == 0) continue;
      double y = size.height * (1 - tick / yMax);
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // 繪製柱狀條
    for (int i = 0; i < count; i++) {
      double value = values[i];
      double heightRatio = yMax > 0 ? value / yMax : 0;
      double barHeight = size.height * heightRatio;
      
      if (barHeight < 4 && value > 0) barHeight = 4;
      
      double left = i * barAreaWidth + barSpacing;
      double top = size.height - barHeight;
      
      Rect barRect = Rect.fromLTWH(left, top, barWidth, barHeight);
      RRect roundedBar = RRect.fromRectAndRadius(barRect, const Radius.circular(6));
      
      bool isToday = i == todayIndex;
      Color startColor = isToday ? todayColor.withOpacity(0.6) : barColor.withOpacity(0.5);
      Color endColor = isToday ? todayColor : barColor;
      
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [startColor, endColor],
      );
      
      final barPaint = Paint()
        ..shader = gradient.createShader(barRect);
      
      canvas.drawRRect(roundedBar, barPaint);
      
      if (isToday) {
        final shadowPaint = Paint()
          ..color = todayColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(roundedBar.shift(const Offset(0, 2)), shadowPaint);
        canvas.drawRRect(roundedBar, barPaint);
      }
    }
  }
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 5;
    const double dashSpace = 3;
    double distance = (end - start).distance;
    double dx = (end.dx - start.dx) / distance;
    double dy = (end.dy - start.dy) / distance;
    
    double currentDistance = 0;
    while (currentDistance < distance) {
      double dashEndDistance = currentDistance + dashWidth;
      if (dashEndDistance > distance) dashEndDistance = distance;
      
      canvas.drawLine(
        Offset(start.dx + dx * currentDistance, start.dy + dy * currentDistance),
        Offset(start.dx + dx * dashEndDistance, start.dy + dy * dashEndDistance),
        paint,
      );
      
      currentDistance += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values || 
           oldDelegate.yMax != yMax ||
           oldDelegate.todayIndex != todayIndex;
  }
}