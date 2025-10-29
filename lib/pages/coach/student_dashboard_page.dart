// lib/pages/coach/student_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/enhanced_charts.dart';

/// 學員進度儀表板 - 教練端查看學員詳細數據
class StudentDashboardPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentDashboardPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  
  bool _isLoading = true;
  Map<String, dynamic> _studentStats = {};
  List<WorkoutHistoryData> _workoutHistory = [];
  Map<String, List<ExercisePR>> _personalRecords = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: 從 Firebase 載入學員數據
      // 1. 訓練統計
      // 2. 訓練歷史
      // 3. 個人紀錄
      // 4. 課表完成度
      
      // 模擬數據
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _studentStats = {
          'totalWorkouts': 42,
          'weeklyWorkouts': 5,
          'completionRate': 85,
          'totalDuration': 2400, // 分鐘
          'avgDuration': 57,
        };
        
        // 模擬最近7天訓練歷史
        _workoutHistory = List.generate(7, (index) {
          DateTime date = DateTime.now().subtract(Duration(days: 6 - index));
          return WorkoutHistoryData(
            date: date,
            duration: 45 + (index * 5),
            exercises: 8 + index,
            volume: 2500 + (index * 200),
          );
        });
        
        // 模擬個人紀錄
        _personalRecords = {
          '深蹲': [
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 30)), weight: 80, reps: 8),
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 20)), weight: 85, reps: 8),
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 10)), weight: 90, reps: 8),
            ExercisePR(date: DateTime.now(), weight: 95, reps: 8),
          ],
          '臥推': [
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 30)), weight: 60, reps: 10),
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 20)), weight: 65, reps: 10),
            ExercisePR(date: DateTime.now().subtract(const Duration(days: 10)), weight: 67.5, reps: 10),
            ExercisePR(date: DateTime.now(), weight: 70, reps: 10),
          ],
        };
        
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
        title: Text(widget.studentName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '總覽'),
            Tab(text: '訓練記錄'),
            Tab(text: '成長曲線'),
            Tab(text: '課表進度'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildProgressTab(),
                _buildScheduleTab(),
              ],
            ),
    );
  }

  // ========== Tab 1: 總覽 ==========
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadStudentData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 統計卡片
            _buildStatsCards(),
            const SizedBox(height: 24),
            
            // 最近7天訓練時長
            EnhancedLineChart(
              title: '最近7天訓練時長',
              dataPoints: _workoutHistory.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.duration.toDouble());
              }).toList(),
              lineColor: Colors.orange,
              maxY: 80,
              bottomTitles: _workoutHistory.map((data) {
                return DateFormat('E', 'zh_TW').format(data.date).substring(1);
              }).toList(),
              yAxisUnit: '分',
            ),
            const SizedBox(height: 24),
            
            // 訓練量趨勢
            EnhancedBarChart(
              title: '最近7天訓練量 (kg)',
              barGroups: _workoutHistory.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.volume.toDouble(),
                      color: Colors.blue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade300,
                          Colors.blue.shade600,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ],
                );
              }).toList(),
              barColor: Colors.blue,
              maxY: 4000,
              bottomTitles: _workoutHistory.map((data) {
                return DateFormat('E', 'zh_TW').format(data.date).substring(1);
              }).toList(),
              yAxisUnit: '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: '本週訓練',
          value: '${_studentStats['weeklyWorkouts']}次',
          icon: Icons.fitness_center,
          color: Colors.orange,
          trend: '+20%',
          isTrendPositive: true,
        ),
        StatCard(
          title: '完成率',
          value: '${_studentStats['completionRate']}%',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        StatCard(
          title: '累計訓練',
          value: '${_studentStats['totalWorkouts']}次',
          icon: Icons.event_available,
          color: Colors.blue,
        ),
        StatCard(
          title: '平均時長',
          value: '${_studentStats['avgDuration']}分',
          icon: Icons.timer,
          color: Colors.purple,
        ),
      ],
    );
  }

  // ========== Tab 2: 訓練記錄 ==========
  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadStudentData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workoutHistory.length,
        itemBuilder: (context, index) {
          WorkoutHistoryData data = _workoutHistory[index];
          return _buildHistoryCard(data);
        },
      ),
    );
  }

  Widget _buildHistoryCard(WorkoutHistoryData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('M月d日 (E)', 'zh_TW').format(data.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已完成',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem(
                  Icons.timer,
                  '${data.duration}分鐘',
                  Colors.orange,
                ),
                const SizedBox(width: 20),
                _buildStatItem(
                  Icons.fitness_center,
                  '${data.exercises}個動作',
                  Colors.blue,
                ),
                const SizedBox(width: 20),
                _buildStatItem(
                  Icons.monitor_weight,
                  '${data.volume}kg',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // ========== Tab 3: 成長曲線 ==========
  Widget _buildProgressTab() {
    return RefreshIndicator(
      onRefresh: _loadStudentData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '個人紀錄 (PR) 成長追蹤',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '追蹤學員在重點動作上的進步狀況',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          // 為每個追蹤的動作生成成長曲線
          ..._personalRecords.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildPRChart(entry.key, entry.value),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPRChart(String exerciseName, List<ExercisePR> records) {
    double maxWeight = records.map((r) => r.weight).reduce((a, b) => a > b ? a : b);
    double minWeight = records.map((r) => r.weight).reduce((a, b) => a < b ? a : b);
    
    return EnhancedLineChart(
      title: exerciseName,
      dataPoints: records.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), entry.value.weight);
      }).toList(),
      lineColor: Colors.green,
      maxY: maxWeight * 1.1,
      minY: minWeight * 0.9,
      bottomTitles: records.map((pr) {
        return DateFormat('M/d').format(pr.date);
      }).toList(),
      yAxisUnit: 'kg',
    );
  }

  // ========== Tab 4: 課表進度 ==========
  Widget _buildScheduleTab() {
    // TODO: 實作課表完成度追蹤
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '功能開發中',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            '即將推出課表完成度追蹤功能',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ========== 數據模型 ==========

class WorkoutHistoryData {
  final DateTime date;
  final int duration; // 分鐘
  final int exercises; // 動作數
  final int volume; // 訓練量 (kg)

  WorkoutHistoryData({
    required this.date,
    required this.duration,
    required this.exercises,
    required this.volume,
  });
}

class ExercisePR {
  final DateTime date;
  final double weight;
  final int reps;

  ExercisePR({
    required this.date,
    required this.weight,
    required this.reps,
  });
}