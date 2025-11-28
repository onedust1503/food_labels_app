// lib/pages/stats/workout_stats_page.dart
// 🔥 完整優化版 - Soft UI 風格、運動目標、連續天數、對比上週
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  List<DailyWorkoutStats> _weeklyStats = [];
  List<DailyWorkoutStats> _lastWeekStats = [];
  Map<String, int> _typeDistribution = {};
  MonthlyOverview? _monthlyOverview;
  
  // 🔥 新增：運動目標與連續天數
  int _weeklyGoal = 3;
  int _monthlyGoal = 12;
  int _consecutiveDays = 0;
  int _longestStreak = 0;
  int _monthlyActiveDays = 0; // 🔥 新增：本月實際運動天數

  late TabController _tabController;

  // 🔥 運動類型翻譯對照表
  final Map<String, String> _workoutTypeNames = {
    'weight_training': '重量訓練',
    'strength': '重訓',
    'cardio': '有氧運動',
    'running': '跑步',
    'cycling': '騎車',
    'swimming': '游泳',
    'yoga': '瑜伽',
    'pilates': '皮拉提斯',
    'hiit': 'HIIT',
    'flexibility': '柔軟度',
    'stretching': '伸展',
    'sports': '球類運動',
    'basketball': '籃球',
    'tennis': '網球',
    'badminton': '羽毛球',
    'walking': '走路',
    'hiking': '健行',
    'dance': '舞蹈',
    'martial_arts': '武術',
    'boxing': '拳擊',
    'crossfit': 'CrossFit',
    'plan_workout': '計畫訓練',
    'chest': '胸部',
    'back': '背部',
    'legs': '腿部',
    'shoulders': '肩部',
    'arms': '手臂',
    'core': '核心',
    'full_body': '全身',
    'upper_body': '上半身',
    'lower_body': '下半身',
    'other': '其他',
  };

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
      // 🔥 並行載入所有數據
      final results = await Future.wait([
        _statsService.getWeeklyWorkoutStats(),
        _statsService.getWorkoutTypeDistribution(),
        _statsService.getMonthlyOverview(),
        _loadLastWeekStats(),
        _loadWorkoutGoals(),
        _calculateStreaks(),
        _calculateMonthlyActiveDays(), // 🔥 新增
      ]);

      setState(() {
        _weeklyStats = results[0] as List<DailyWorkoutStats>;
        _typeDistribution = results[1] as Map<String, int>;
        _monthlyOverview = results[2] as MonthlyOverview;
        _lastWeekStats = results[3] as List<DailyWorkoutStats>;
        
        final goals = results[4] as Map<String, int>;
        _weeklyGoal = goals['weekly'] ?? 3;
        _monthlyGoal = goals['monthly'] ?? 12;
        
        final streaks = results[5] as Map<String, int>;
        _consecutiveDays = streaks['current'] ?? 0;
        _longestStreak = streaks['longest'] ?? 0;
        
        _monthlyActiveDays = results[6] as int; // 🔥 新增
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  // 🔥 載入上週數據（用於對比）- 優化版：範圍查詢
  Future<List<DailyWorkoutStats>> _loadLastWeekStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];
      
      final now = DateTime.now();
      // 🔥 修正：正確計算上週的起始和結束日期
      // 週一 = 1, 週日 = 7
      // 上週一 = 今天 - (今天是週幾 - 1) - 7
      final thisWeekMonday = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekMonday = thisWeekMonday.subtract(const Duration(days: 7));
      final lastWeekSunday = lastWeekMonday.add(const Duration(days: 6));
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(lastWeekMonday);
      final endDateStr = DateFormat('yyyy-MM-dd').format(lastWeekSunday);
      
      // 🔥 優化：一次查詢整週數據
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();
      
      // 按日期分組
      Map<String, List<Map<String, dynamic>>> byDate = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String? ?? '';
        if (dateStr.isNotEmpty) {
          byDate.putIfAbsent(dateStr, () => []);
          byDate[dateStr]!.add(data);
        }
      }
      
      // 建立每天的統計
      List<DailyWorkoutStats> stats = [];
      for (int i = 0; i < 7; i++) {
        final date = lastWeekMonday.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final dayData = byDate[dateStr] ?? [];
        
        int totalDuration = 0;
        double totalCalories = 0;
        
        for (var data in dayData) {
          totalDuration += (data['duration'] ?? 0) as int;
          totalCalories += ((data['caloriesBurned'] ?? 0) as num).toDouble();
        }
        
        stats.add(DailyWorkoutStats(
          date: date,
          duration: totalDuration,
          calories: totalCalories,
          workoutCount: dayData.length,
        ));
      }
      return stats;
    } catch (e) {
      return [];
    }
  }

  // 🔥 載入運動目標
  Future<Map<String, int>> _loadWorkoutGoals() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'weekly': 3, 'monthly': 12};
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final goals = data['workoutGoals'] as Map<String, dynamic>?;
        if (goals != null) {
          return {
            'weekly': (goals['weekly'] ?? 3) as int,
            'monthly': (goals['monthly'] ?? 12) as int,
          };
        }
      }
      return {'weekly': 3, 'monthly': 12};
    } catch (e) {
      return {'weekly': 3, 'monthly': 12};
    }
  }

  // 🔥 新增：計算本月實際運動天數（不是訓練次數）
  Future<int> _calculateMonthlyActiveDays() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 0;
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startDateStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: todayStr)
          .get();
      
      // 🔥 關鍵：用 Set 去重，計算不重複的天數
      Set<String> uniqueDays = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          uniqueDays.add(dateStr);
        }
      }
      
      return uniqueDays.length;
    } catch (e) {
      return 0;
    }
  }

  // 🔥 計算連續運動天數 - 修正版
  Future<Map<String, int>> _calculateStreaks() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'current': 0, 'longest': 0};
      
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final startDate = now.subtract(const Duration(days: 90)); // 查詢 90 天
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .get();
      
      // 收集有運動的日期（用 Set 去重）
      Set<String> workoutDates = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          workoutDates.add(dateStr);
        }
      }
      
      // 🔥 計算當前連續天數
      // 邏輯：從今天或昨天開始往回算
      int currentStreak = 0;
      bool startedCounting = false;
      
      for (int i = 0; i <= 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        if (workoutDates.contains(dateStr)) {
          currentStreak++;
          startedCounting = true;
        } else {
          // 如果是今天且還沒運動，跳過繼續看昨天
          if (i == 0 && !startedCounting) {
            continue;
          }
          // 已經開始計算了，遇到沒運動的日子就停止
          if (startedCounting) {
            break;
          }
        }
      }
      
      // 🔥 計算最長連續天數
      int longestStreak = 0;
      int tempStreak = 0;
      
      // 從 90 天前開始往今天算
      for (int i = 90; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        if (workoutDates.contains(dateStr)) {
          tempStreak++;
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
        } else {
          tempStreak = 0;
        }
      }
      
      return {'current': currentStreak, 'longest': longestStreak};
    } catch (e) {
      return {'current': 0, 'longest': 0};
    }
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

  String _translateWorkoutType(String type) {
    return _workoutTypeNames[type.toLowerCase()] ?? 
           _workoutTypeNames[type] ?? 
           type;
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
                    _buildMonthlyOverview(isSmallScreen),
                    const SizedBox(height: 16),
                    _buildGoalProgress(isSmallScreen),
                    const SizedBox(height: 16),
                    _buildStreakAndComparison(isSmallScreen),
                    const SizedBox(height: 16),
                    _buildWeeklySummaryCards(isSmallScreen),
                    const SizedBox(height: 20),
                    _buildChartSection(isSmallScreen),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🏋️ 運動類型分佈'),
                    const SizedBox(height: 12),
                    _buildTypePieChart(isSmallScreen),
                    const SizedBox(height: 20),
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
          Text('載入統計資料中...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildMonthlyOverview(bool isSmallScreen) {
    if (_monthlyOverview == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent1, AppColors.accent1.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent1.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_month, color: Colors.white, size: isSmallScreen ? 18 : 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '本月運動總覽',
                    style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  DateFormat('yyyy年M月').format(DateTime.now()),
                  style: TextStyle(color: AppColors.accent1, fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewItem('${_monthlyOverview!.totalWorkouts}', '次訓練', Icons.fitness_center, isSmallScreen),
              _buildOverviewItem('${_monthlyOverview!.totalDuration}', '分鐘', Icons.timer, isSmallScreen),
              _buildOverviewItem('${_monthlyOverview!.totalCalories.toInt()}', '大卡', Icons.local_fire_department, isSmallScreen),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: isSmallScreen ? 24 : 28),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 22 : 26, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isSmallScreen ? 11 : 12)),
      ],
    );
  }

  Widget _buildGoalProgress(bool isSmallScreen) {
    int activeDays = _weeklyStats.where((s) => s.workoutCount > 0).length;
    
    // 🔥 修正：使用正確計算的本月運動天數
    double weeklyProgress = (_weeklyGoal > 0) ? (activeDays / _weeklyGoal).clamp(0.0, 1.0) : 0;
    double monthlyProgress = (_monthlyGoal > 0) ? (_monthlyActiveDays / _monthlyGoal).clamp(0.0, 1.0) : 0;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: AppColors.accent1, size: 20),
              const SizedBox(width: 8),
              Text('運動目標', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              InkWell(
                onTap: _showGoalSettingDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text('設定', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(label: '本週', current: activeDays, goal: _weeklyGoal, progress: weeklyProgress, color: AppColors.accent2, isSmallScreen: isSmallScreen),
          const SizedBox(height: 12),
          _buildProgressBar(label: '本月', current: _monthlyActiveDays, goal: _monthlyGoal, progress: monthlyProgress, color: AppColors.accent1, isSmallScreen: isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildProgressBar({required String label, required int current, required int goal, required double progress, required Color color, required bool isSmallScreen}) {
    bool isCompleted = current >= goal;
    int remaining = (goal - current).clamp(0, goal);
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: isSmallScreen ? 12 : 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted ? '🎉 達成！' : '還差 $remaining 天',
                    style: TextStyle(color: isCompleted ? AppColors.success : color, fontSize: isSmallScreen ? 10 : 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Text('$current / $goal 天', style: TextStyle(color: AppColors.textPrimary, fontSize: isSmallScreen ? 13 : 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? AppColors.success : color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakAndComparison(bool isSmallScreen) {
    int thisWeekWorkouts = _weeklyStats.fold(0, (sum, s) => sum + s.workoutCount);
    int lastWeekWorkouts = _lastWeekStats.fold(0, (sum, s) => sum + s.workoutCount);
    int thisWeekDuration = _weeklyStats.fold(0, (sum, s) => sum + s.duration);
    int lastWeekDuration = _lastWeekStats.fold(0, (sum, s) => sum + s.duration);
    
    int workoutDiff = thisWeekWorkouts - lastWeekWorkouts;
    int durationDiff = thisWeekDuration - lastWeekDuration;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🔥', style: TextStyle(fontSize: isSmallScreen ? 18 : 22)),
                    const SizedBox(width: 6),
                    Text('連續運動', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: isSmallScreen ? 11 : 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_consecutiveDays', style: TextStyle(color: Colors.white, fontSize: isSmallScreen ? 28 : 32, fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text('天', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: isSmallScreen ? 12 : 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('最長紀錄 $_longestStreak 天', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: isSmallScreen ? 10 : 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.compare_arrows, color: AppColors.info, size: isSmallScreen ? 18 : 20),
                    const SizedBox(width: 6),
                    Text('對比上週', style: TextStyle(color: AppColors.textSecondary, fontSize: isSmallScreen ? 11 : 12)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildComparisonItem('訓練次數', workoutDiff, '次', isSmallScreen),
                const SizedBox(height: 6),
                _buildComparisonItem('運動時長', durationDiff, '分', isSmallScreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonItem(String label, int diff, String unit, bool isSmallScreen) {
    Color color;
    String prefix;
    IconData icon;
    
    if (diff > 0) {
      color = AppColors.success;
      prefix = '+';
      icon = Icons.trending_up;
    } else if (diff < 0) {
      color = AppColors.error;
      prefix = '';
      icon = Icons.trending_down;
    } else {
      color = AppColors.textTertiary;
      prefix = '';
      icon = Icons.trending_flat;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 10 : 11)),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
            Text('$prefix$diff $unit', style: TextStyle(color: color, fontSize: isSmallScreen ? 12 : 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklySummaryCards(bool isSmallScreen) {
    int activeDays = _weeklyStats.where((s) => s.workoutCount > 0).length;
    int totalDuration = _weeklyStats.fold(0, (sum, s) => sum + s.duration);
    double totalCalories = _weeklyStats.fold(0.0, (sum, s) => sum + s.calories);

    return Row(
      children: [
        Expanded(child: _buildMiniCard(icon: Icons.calendar_today, color: AppColors.accent2, title: '訓練天數', value: '$activeDays', unit: '/ 7 天', isSmallScreen: isSmallScreen)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniCard(icon: Icons.timer_outlined, color: AppColors.info, title: '本週時長', value: '$totalDuration', unit: '分鐘', isSmallScreen: isSmallScreen)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniCard(icon: Icons.local_fire_department, color: AppColors.accent1, title: '本週消耗', value: '${totalCalories.toInt()}', unit: '大卡', isSmallScreen: isSmallScreen)),
      ],
    );
  }

  Widget _buildMiniCard({required IconData icon, required Color color, required String title, required String value, required String unit, required bool isSmallScreen}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: isSmallScreen ? 18 : 22),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 10 : 11)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontSize: isSmallScreen ? 18 : 20, fontWeight: FontWeight.bold))),
          Text(unit, style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 9 : 10)),
        ],
      ),
    );
  }

  Widget _buildChartSection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(color: AppColors.accent1, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 13, fontWeight: FontWeight.bold),
              tabs: const [Tab(text: '運動時長'), Tab(text: '卡路里消耗')],
            ),
          ),
          SizedBox(
            height: isSmallScreen ? 220 : 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildDurationChart(isSmallScreen)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _buildCaloriesChart(isSmallScreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChart(bool isSmallScreen) {
    if (_weeklyStats.isEmpty || _weeklyStats.every((s) => s.duration == 0)) {
      return _buildEmptyChartContent('本週還沒有運動記錄');
    }

    double maxDuration = _weeklyStats.map((e) => e.duration.toDouble()).reduce((a, b) => a > b ? a : b);
    double yMax = maxDuration > 0 ? ((maxDuration * 1.3) / 10).ceil() * 10.0 : 60;
    if (yMax < 10) yMax = 10;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isSmallScreen ? 32 : 38,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(right: 4), child: Text('${value.toInt()}', style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 9 : 10)));
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
                return Padding(padding: const EdgeInsets.only(top: 8), child: Text('週${weekdays[weekdayIndex]}', style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 9 : 10)));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_weeklyStats.length, (i) => FlSpot(i.toDouble(), _weeklyStats[i].duration.toDouble())),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.accent1,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 5, color: AppColors.accent1, strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(colors: [AppColors.accent1.withValues(alpha: 0.3), AppColors.accent1.withValues(alpha: 0.05)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem('${spot.y.toInt()} 分鐘', const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCaloriesChart(bool isSmallScreen) {
    if (_weeklyStats.isEmpty || _weeklyStats.every((s) => s.calories == 0)) {
      return _buildEmptyChartContent('本週還沒有運動記錄');
    }

    double maxCalories = _weeklyStats.map((e) => e.calories).reduce((a, b) => a > b ? a : b);
    double yMax = maxCalories > 0 ? ((maxCalories * 1.3) / 50).ceil() * 50.0 : 300;
    if (yMax < 50) yMax = 50;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: isSmallScreen ? 32 : 38,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == yMax) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(right: 4), child: Text('${value.toInt()}', style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 9 : 10)));
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
                return Padding(padding: const EdgeInsets.only(top: 8), child: Text('週${weekdays[weekdayIndex]}', style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 9 : 10)));
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
                gradient: LinearGradient(colors: [AppColors.accent1, AppColors.accent1.withValues(alpha: 0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                width: isSmallScreen ? 16 : 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${rod.toY.toInt()} 大卡', const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildTypePieChart(bool isSmallScreen) {
    if (_typeDistribution.isEmpty) {
      return _buildEmptyCard('本月還沒有運動記錄');
    }

    final colors = [AppColors.accent1, AppColors.accent2, AppColors.accent3, AppColors.info, AppColors.primary, Colors.purple.shade300, Colors.teal.shade300, Colors.pink.shade300];

    int total = _typeDistribution.values.fold(0, (a, b) => a + b);
    int colorIndex = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legends = [];

    var sortedEntries = _typeDistribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries) {
      Color color = colors[colorIndex % colors.length];
      double percentage = (entry.value / total * 100);
      
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: percentage >= 8 ? '${percentage.toInt()}%' : '',
          color: color,
          radius: isSmallScreen ? 55 : 65,
          titleStyle: TextStyle(fontSize: isSmallScreen ? 10 : 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );

      legends.add(_buildLegendItem(_translateWorkoutType(entry.key), entry.value, color, isSmallScreen));
      colorIndex++;
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: isSmallScreen ? 150 : 170,
              child: PieChart(PieChartData(sections: sections, centerSpaceRadius: isSmallScreen ? 28 : 35, sectionsSpace: 2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: legends.take(5).toList()),
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
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: isSmallScreen ? 11 : 12), overflow: TextOverflow.ellipsis)),
          Text('$count次', style: TextStyle(color: AppColors.textPrimary, fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDailyList(bool isSmallScreen) {
    if (_weeklyStats.isEmpty) return _buildEmptyCard('本週還沒有數據');

    final weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: List.generate(_weeklyStats.length, (i) {
          final day = _weeklyStats[i];
          final dateStr = DateFormat('yyyy-MM-dd').format(day.date);
          final isToday = dateStr == today;
          final hasWorkout = day.workoutCount > 0;

          return Container(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14 : 18, vertical: isSmallScreen ? 12 : 14),
            decoration: BoxDecoration(
              color: isToday ? AppColors.accent1.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(20) : Radius.zero,
                bottom: i == _weeklyStats.length - 1 ? const Radius.circular(20) : Radius.zero,
              ),
              border: i < _weeklyStats.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isSmallScreen ? 50 : 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(weekdays[day.date.weekday - 1], style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.w500, color: isToday ? AppColors.accent1 : AppColors.textPrimary, fontSize: isSmallScreen ? 13 : 14)),
                      Text(DateFormat('MM/dd').format(day.date), style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 10 : 11)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: hasWorkout ? AppColors.success.withValues(alpha: 0.15) : Colors.grey.shade100, shape: BoxShape.circle),
                  child: Icon(hasWorkout ? Icons.check_rounded : Icons.remove, size: 18, color: hasWorkout ? AppColors.success : Colors.grey.shade400),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: hasWorkout
                      ? Row(
                          children: [
                            Expanded(child: _buildDayStatItem(Icons.fitness_center, '${day.workoutCount}次', AppColors.accent1, isSmallScreen)),
                            Expanded(child: _buildDayStatItem(Icons.timer_outlined, '${day.duration}分', AppColors.info, isSmallScreen)),
                            Expanded(child: _buildDayStatItem(Icons.local_fire_department, '${day.calories.toInt()}卡', AppColors.accent1, isSmallScreen)),
                          ],
                        )
                      : Text('休息日', style: TextStyle(color: AppColors.textTertiary, fontSize: isSmallScreen ? 12 : 13, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayStatItem(IconData icon, String value, Color color, bool isSmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
        const SizedBox(width: 3),
        Flexible(child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _showGoalSettingDialog() {
    final weeklyController = TextEditingController(text: _weeklyGoal.toString());
    final monthlyController = TextEditingController(text: _monthlyGoal.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.flag, color: AppColors.accent1), const SizedBox(width: 12), const Text('設定運動目標')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weeklyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '每週運動目標',
                suffixText: '天',
                hintText: '建議 3-5 天',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent1, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: monthlyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '每月運動目標',
                suffixText: '天',
                hintText: '建議 12-20 天',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent1, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final weekly = int.tryParse(weeklyController.text) ?? 3;
              final monthly = int.tryParse(monthlyController.text) ?? 12;
              
              setState(() {
                _weeklyGoal = weekly.clamp(1, 7);
                _monthlyGoal = monthly.clamp(1, 31);
              });
              
              final userId = _auth.currentUser?.uid;
              if (userId != null) {
                await _firestore.collection('users').doc(userId).set({'workoutGoals': {'weekly': _weeklyGoal, 'monthly': _monthlyGoal}}, SetOptions(merge: true));
              }
              
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('運動目標已更新'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Center(child: Column(children: [Icon(Icons.fitness_center, size: 48, color: AppColors.textTertiary), const SizedBox(height: 12), Text(message, style: TextStyle(color: AppColors.textTertiary, fontSize: 14))])),
    );
  }

  Widget _buildEmptyChartContent(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bar_chart_outlined, size: 40, color: AppColors.textTertiary), const SizedBox(height: 12), Text(message, style: TextStyle(color: AppColors.textTertiary, fontSize: 13))]));
  }
}