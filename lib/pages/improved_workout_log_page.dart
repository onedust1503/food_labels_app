// lib/pages/improved_workout_log_page.dart
// ✨ 改進的訓練記錄頁面 - 生產版本（無調試信息）

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../services/unified_workout_service.dart';
import 'exercise_selection_page.dart';

class ImprovedWorkoutLogPage extends StatefulWidget {
  final bool isCoach;
  final String? traineeId;

  const ImprovedWorkoutLogPage({
    super.key,
    required this.isCoach,
    this.traineeId,
  });

  @override
  State<ImprovedWorkoutLogPage> createState() => _ImprovedWorkoutLogPageState();
}

class _ImprovedWorkoutLogPageState extends State<ImprovedWorkoutLogPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _todayWorkouts = [];
  Map<String, dynamic> _todayStats = {
    'totalDuration': 0,
    'totalCalories': 0.0,
    'workoutCount': 0,
  };
  Map<String, dynamic> _weeklyStats = {
    'workoutDays': 0,
    'totalDuration': 0,
    'totalCalories': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 載入所有數據
  Future<void> _loadData() async {
    if (kDebugMode) {
      debugPrint('🔄 開始載入訓練數據...');
    }

    setState(() => _isLoading = true);

    try {
      // 並行載入三個數據源
      final results = await Future.wait([
        _workoutService.getTodayWorkouts(),
        _workoutService.getTodayStats(),
        _workoutService.getWeeklyStats(),
      ]);

      final workouts = results[0] as List<Map<String, dynamic>>;
      final todayStats = results[1] as Map<String, dynamic>;
      final weeklyStats = results[2] as Map<String, dynamic>;

      if (kDebugMode) {
        debugPrint('✅ 載入成功:');
        debugPrint('   今日訓練: ${workouts.length} 筆');
        debugPrint('   今日統計: $todayStats');
        debugPrint('   本週統計: $weeklyStats');
      }

      if (mounted) {
        setState(() {
          _todayWorkouts = workouts;
          _todayStats = todayStats;
          _weeklyStats = weeklyStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入訓練數據失敗: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入數據失敗');
      }
    }
  }

  /// 刪除運動記錄
  Future<void> _deleteWorkout(String workoutId) async {
    if (kDebugMode) {
      debugPrint('🗑️ 刪除訓練記錄: $workoutId');
    }

    try {
      await _workoutService.deleteWorkout(workoutId);
      _showSnackBar('已刪除運動記錄');
      await _loadData(); // 重新載入數據
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 刪除失敗: $e');
      }
      _showSnackBar('刪除失敗，請重試');
    }
  }

  /// 顯示刪除確認對話框
  Future<void> _confirmDelete(String workoutId, String workoutName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$workoutName」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteWorkout(workoutId);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        title: const Text(
          '訓練記錄',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 今日統計卡片
                    _buildTodayStatsCard(),

                    // 本週統計卡片
                    _buildWeeklyStatsCard(),

                    // 今日訓練列表
                    _buildTodayWorkoutsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseSelectionPage(
                isCoach: widget.isCoach,
                traineeId: widget.traineeId,
              ),
            ),
          );

          if (result == true) {
            _loadData(); // 新增訓練後重新載入
          }
        },
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '新增訓練',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 今日統計卡片
  Widget _buildTodayStatsCard() {
    final duration = _todayStats['totalDuration'] ?? 0;
    final calories = (_todayStats['totalCalories'] ?? 0.0).toDouble();
    final count = _todayStats['workoutCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '今日訓練 ${DateFormat('M月d日').format(DateTime.now())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.fitness_center,
                value: '$count',
                label: '次訓練',
              ),
              _buildStatItem(
                icon: Icons.timer,
                value: '$duration',
                label: '分鐘',
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                value: calories.toStringAsFixed(0),
                label: '卡路里',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 統計項目
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 本週統計卡片
  Widget _buildWeeklyStatsCard() {
    final workoutDays = _weeklyStats['workoutDays'] ?? 0;
    final duration = _weeklyStats['totalDuration'] ?? 0;
    final calories = (_weeklyStats['totalCalories'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '本週統計（過去7天）',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeeklyStatItem(
                icon: Icons.event_available,
                value: '$workoutDays',
                label: '天訓練',
                color: Colors.blue,
              ),
              _buildWeeklyStatItem(
                icon: Icons.timer,
                value: '$duration',
                label: '總分鐘',
                color: Colors.orange,
              ),
              _buildWeeklyStatItem(
                icon: Icons.local_fire_department,
                value: calories.toStringAsFixed(0),
                label: '總卡路里',
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 本週統計項目
  Widget _buildWeeklyStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 今日訓練列表
  Widget _buildTodayWorkoutsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '今日訓練記錄',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_todayWorkouts.length} 筆',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          _todayWorkouts.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _todayWorkouts.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final workout = _todayWorkouts[index];
                    return _buildWorkoutItem(workout);
                  },
                ),
        ],
      ),
    );
  }

  /// 訓練項目
  Widget _buildWorkoutItem(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '未知運動';
    final duration = workout['duration'] ?? 0;
    final calories = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final sets = workout['sets'];
    final reps = workout['reps'];
    final weight = workout['weight'];
    final workoutId = workout['id'] ?? '';

    return Dismissible(
      key: Key(workoutId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認刪除'),
            content: Text('確定要刪除「$name」嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('刪除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await _deleteWorkout(workoutId);
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.fitness_center,
            color: Colors.green,
            size: 24,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$duration 分鐘',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.local_fire_department,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${calories.toStringAsFixed(0)} 卡',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (sets != null && reps != null) ...[
              const SizedBox(height: 4),
              Text(
                '$sets 組 × $reps 次${weight != null ? ' @ ${weight}kg' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(workoutId, name),
        ),
      ),
    );
  }

  /// 空狀態
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有訓練記錄',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊下方按鈕開始記錄訓練',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}