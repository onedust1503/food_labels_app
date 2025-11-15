// lib/pages/water/water_log_page.dart
// 🎨 響應式莫蘭迪風格 - 飲水記錄頁面
// ✨ 修復版:自訂水杯對話框 + 平滑更新動畫

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/water_service.dart';
import '../../theme/app_theme.dart';

class WaterLogPage extends StatefulWidget {
  const WaterLogPage({super.key});

  @override
  State<WaterLogPage> createState() => _WaterLogPageState();
}

class _WaterLogPageState extends State<WaterLogPage> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {  // 🔧 加入 AutomaticKeepAliveClientMixin
  final WaterService _waterService = WaterService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  int userDefaultTarget = 2000;
  
  List<int> customCups = [100, 200, 300, 500];
  bool _isLoadingCups = true;

  // 🔧 保持狀態,避免重建時閃爍
  @override
  bool get wantKeepAlive => true;

  String get _todayTaiwan {
    DateTime tw = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${tw.year}-${tw.month.toString().padLeft(2, '0')}-${tw.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserDefaultTarget();
    _loadCustomCups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDefaultTarget() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data.containsKey('waterTargetDefault')) {
            setState(() {
              userDefaultTarget = data['waterTargetDefault'] ?? 2000;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('載入用戶預設目標失敗: $e');
    }
  }

  Future<void> _loadCustomCups() async {
    try {
      final cups = await _waterService.getCustomCups();
      if (mounted) {
        setState(() {
          customCups = cups;
          _isLoadingCups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCups = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // 🔧 必須調用,用於 AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('喝水記錄'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showCustomCupsDialog,
            tooltip: '自訂水杯',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '今日記錄'),
            Tab(text: '本週統計'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWaterDialog,
        backgroundColor: AppColors.primary,
        elevation: 8,
        icon: const Icon(Icons.add),
        label: const Text(
          '喝水',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _waterService.getTodayWaterStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  '載入失敗',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};
        final totalWater = data['totalWater'] ?? 0;
        final targetWater = data['targetWater'] ?? userDefaultTarget;
        final logs = List.from(data['logs'] ?? []);
        final percentage = targetWater > 0 ? (totalWater / targetWater).clamp(0.0, 1.0) : 0.0;

        return Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProgressCard(totalWater, targetWater, percentage),
                const SizedBox(height: 24),
                _buildQuickAddButtons(),
                const SizedBox(height: 24),
                _buildLogsList(logs),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(int totalWater, int targetWater, double percentage) {
    final isCompleted = percentage >= 1.0;
    final displayPercentage = (percentage * 100).toInt();
    
    final cardGradient = LinearGradient(
      colors: isCompleted 
          ? [const Color(0xFF7DD3C0), const Color(0xFF58C9B9)]
          : [const Color(0xFF87CEEB), const Color(0xFF6CB4DD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final circleSize = (screenWidth * 0.32).clamp(100.0, 125.0);
        final iconSize = circleSize * 0.16;
        final mainFontSize = circleSize * 0.16;
        final subFontSize = circleSize * 0.085;
        final strokeWidth = circleSize * 0.075;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.02,
            horizontal: screenWidth * 0.02,
          ),
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: circleSize,
                height: circleSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: strokeWidth,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child: TweenAnimationBuilder<double>(
                        duration: AppAnimations.slow,
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: percentage),
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: strokeWidth,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          );
                        },
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(iconSize * 0.28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.water_drop,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: circleSize * 0.03),
                        TweenAnimationBuilder<int>(
                          duration: AppAnimations.slow,
                          curve: Curves.easeOutCubic,
                          tween: IntTween(begin: 0, end: totalWater),
                          builder: (context, value, child) {
                            return Text(
                              '$value ml',
                              style: TextStyle(
                                fontSize: mainFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0,
                                shadows: const [
                                  Shadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(height: circleSize * 0.01),
                        Text(
                          '/ $targetWater ml',
                          style: TextStyle(
                            fontSize: subFontSize,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: circleSize * 0.015),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: subFontSize * 0.7,
                            vertical: subFontSize * 0.15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$displayPercentage%',
                            style: TextStyle(
                              fontSize: subFontSize * 1.15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenWidth * 0.018),
              
              InkWell(
                onTap: _showTargetSettingDialog,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.025,
                    vertical: screenWidth * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: subFontSize * 1.05, color: Colors.white),
                      SizedBox(width: screenWidth * 0.008),
                      Text(
                        '調整今日目標',
                        style: TextStyle(
                          fontSize: subFontSize * 0.95,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAddButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '快速記錄',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showCustomCupsDialog,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('自訂'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingCups)
          const Center(child: CircularProgressIndicator())
        else
          // 🔧 使用 AnimatedSwitcher 實現平滑過渡
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey(customCups.toString()),  // 🔧 使用 ValueKey 觸發動畫
              children: customCups.map((amount) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: customCups.indexOf(amount) < customCups.length - 1 ? 12 : 0,
                    ),
                    child: _buildQuickButton(amount),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickButton(int amount) {
    return InkWell(
      onTap: () => _addWater(amount),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.small,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.water_drop, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              '${amount}ml',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(List logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.small,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.water_drop_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '今日尚未記錄喝水',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊下方按鈕開始記錄',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今日記錄',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '共 ${logs.length} 次',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 🔧 使用 AnimatedList 實現平滑的列表更新
        ...logs.asMap().entries.map((entry) {
          int index = entry.key;
          var log = entry.value;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildLogItem(log, index),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log, int index) {
    final amount = log['amount'] ?? 0;
    final note = log['note'] ?? '';
    
    String timeStr;
    if (log['displayTime'] != null && log['displayTime'].toString().isNotEmpty) {
      timeStr = log['displayTime'];
    } else if (log['timestamp'] != null) {
      final timestamp = (log['timestamp'] as dynamic).toDate();
      timeStr = DateFormat('HH:mm').format(timestamp);
    } else {
      timeStr = '--:--';
    }

    return Dismissible(
      key: Key('water_$index\_${DateTime.now().millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) => _confirmDeleteSwipe(index),
      child: InkWell(
        onTap: () => _showEditLogDialog(log, index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.small,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.water_drop, color: AppColors.primary, size: 24),
            ),
            title: Row(
              children: [
                Text(
                  '${amount}ml',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      note,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeStr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            trailing: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _waterService.getRecentWaterLogs(days: 7),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '載入失敗: ${snapshot.error}',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final weekData = snapshot.data ?? [];

        return FutureBuilder<Map<String, dynamic>>(
          future: _waterService.getWeeklyStats(),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? {};

            return Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeeklyStatsCard(stats),
                    const SizedBox(height: 24),
                    _buildWeeklyChart(weekData),
                    const SizedBox(height: 24),
                    Text(
                      '最近 7 天',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...weekData.map((dayData) => _buildDayCard(dayData)).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7DD3C0), Color(0xFF58C9B9)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.emphasized,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '本週統計',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      '藍綠=達標',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildStatItem('總攝取', '${stats['totalWater'] ?? 0}ml')),
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
              Expanded(child: _buildStatItem('日均', '${stats['avgDaily'] ?? 0}ml')),
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
              Expanded(child: _buildStatItem('達標', '${stats['daysCompleted'] ?? 0}/7')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(List<Map<String, dynamic>> weekData) {
    if (weekData.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth * 0.6;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本週趨勢',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: chartHeight.clamp(180.0, 260.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 3000,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => AppColors.primary,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final dayData = weekData.reversed.toList()[group.x.toInt()];
                          final totalWater = dayData['totalWater'] ?? 0;
                          return BarTooltipItem(
                            '${totalWater}ml',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < weekData.length) {
                              final dayData = weekData.reversed.toList()[value.toInt()];
                              final date = DateTime.parse(dayData['date']);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getWeekdayShort(date.weekday),
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('M/d').format(date),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 500,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.textTertiary.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weekData.reversed.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final dayData = entry.value;
                      final totalWater = (dayData['totalWater'] ?? 0).toDouble();
                      final targetWater = (dayData['targetWater'] ?? 2000).toDouble();
                      final isCompleted = totalWater >= targetWater;
                      
                      final barColor = isCompleted 
                          ? const Color(0xFF7DD3C0)
                          : const Color(0xFF87CEEB);
                      
                      final barColorDark = isCompleted
                          ? const Color(0xFF58C9B9)
                          : const Color(0xFF6CB4DD);
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: totalWater,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            gradient: LinearGradient(
                              colors: [barColor, barColorDark],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCard(Map<String, dynamic> dayData) {
    final date = DateTime.parse(dayData['date']);
    final totalWater = dayData['totalWater'] ?? 0;
    final targetWater = dayData['targetWater'] ?? userDefaultTarget;
    final percentage = targetWater > 0 ? (totalWater / targetWater).clamp(0.0, 1.0) : 0.0;
    final isCompleted = totalWater >= targetWater;

    final borderColor = isCompleted 
        ? const Color(0xFF7DD3C0)
        : AppColors.textTertiary.withValues(alpha: 0.2);
    
    final progressColor = isCompleted
        ? const Color(0xFF7DD3C0)
        : const Color(0xFF87CEEB);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCompleted ? 2 : 1),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 65,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat('M/d').format(date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getWeekdayName(date.weekday),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${totalWater}ml / ${targetWater}ml',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Icon(Icons.check_circle, color: progressColor, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.textTertiary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }

  String _getWeekdayShort(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }

  // ==================== 對話框 ====================

  void _showAddWaterDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.water_drop, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('記錄喝水'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '水量(毫升)',
                hintText: '例如:200',
                suffixText: 'ml',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: '備註(選填)',
                hintText: '例如:早餐後',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _addWater(amount, note: noteController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showEditLogDialog(Map<String, dynamic> log, int index) {
    final amountController = TextEditingController(
      text: (log['amount'] ?? 0).toString(),
    );
    final noteController = TextEditingController(
      text: log['note'] ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('編輯記錄'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '水量(毫升)',
                suffixText: 'ml',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: '備註',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                try {
                  await _waterService.editWaterLog(
                    date: _todayTaiwan,
                    logIndex: index,
                    newAmount: amount,
                    newNote: noteController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('記錄已更新'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('更新失敗: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  // 🔧 修復:自訂水杯對話框 - 使用 SingleChildScrollView 避免溢出
  void _showCustomCupsDialog() {
    final controllers = customCups.map((amount) {
      return TextEditingController(text: amount.toString());
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_drink, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('自訂水杯容量'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,  // 🔧 設定寬度
          child: SingleChildScrollView(  // 🔧 包裝 ScrollView 避免溢出
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),  // 🔧 增加間距
                  child: TextField(
                    controller: controllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '水杯 ${index + 1}',
                      suffixText: 'ml',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(  // 🔧 調整內邊距
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCups = controllers
                  .map((c) => int.tryParse(c.text) ?? 100)
                  .where((amount) => amount > 0)
                  .toList();
              
              if (newCups.length == 4) {
                Navigator.pop(context);
                try {
                  await _waterService.updateCustomCups(newCups);
                  if (mounted) {
                    setState(() {
                      customCups = newCups;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('水杯設定已更新'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('更新失敗: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  void _showTargetSettingDialog() {
    final TextEditingController controller = TextEditingController(
      text: userDefaultTarget.toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.tune, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('設定每日目標'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '建議每日攝取量:2000-2500ml',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '目標水量(毫升)',
                hintText: '例如:2000',
                suffixText: 'ml',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = int.tryParse(controller.text);
              if (target != null && target > 0) {
                Navigator.pop(context);
                try {
                  await _waterService.updateWaterTarget(target);
                  setState(() {
                    userDefaultTarget = target;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('目標已更新'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('更新失敗: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWater(int amount, {String? note}) async {
    try {
      await _waterService.addWaterLog(amount: amount, note: note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('已記錄 ${amount}ml'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記錄失敗: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDeleteSwipe(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text('確認刪除'),
          ],
        ),
        content: const Text('確定要刪除這筆記錄嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _waterService.deleteWaterLog(date: _todayTaiwan, logIndex: index);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('已刪除記錄'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('刪除失敗: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }
}