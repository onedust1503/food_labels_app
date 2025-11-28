// lib/pages/improved_workout_log_page.dart
// ✅ 整合版 v2 - 支援顯示「計畫/自由」標籤
// ✅ 正確讀取 planId 和 planName
// ✅ 修正詳情顯示問題

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'workout/workout_session_detail_page.dart';
import 'exercise_selection_page.dart';

class ImprovedWorkoutLogPage extends StatefulWidget {
  final bool isCoach;
  final String? traineeId;
  final String? planId;

  const ImprovedWorkoutLogPage({
    super.key,
    required this.isCoach,
    this.traineeId,
    this.planId,
  });

  @override
  State<ImprovedWorkoutLogPage> createState() => _ImprovedWorkoutLogPageState();
}

class _ImprovedWorkoutLogPageState extends State<ImprovedWorkoutLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // 🆕 來源統計
  int _planCount = 0;
  int _freeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (kDebugMode && widget.planId != null) {
      debugPrint('📋 訓練計畫模式: planId = ${widget.planId}');
    }
  }

  String get _currentUserId {
    return widget.traineeId ?? _auth.currentUser?.uid ?? '';
  }

  /// 🔄 載入今日訓練數據
  Future<void> _loadData() async {
    if (kDebugMode) {
      debugPrint('🔄 開始載入訓練數據...');
    }

    setState(() => _isLoading = true);

    try {
      final userId = _currentUserId;
      if (userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 取得今日日期範圍
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // 🔥 從 workoutLogs 讀取（簡化查詢，避免複合索引）
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)  // 限制數量提高效能
          .get();

      // 🔥 也從 users/{uid}/workouts 讀取（備用）
      final userWorkoutsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      // 合併去重（以 id 為準）
      final Map<String, Map<String, dynamic>> mergedMap = {};

      // 先加入 workoutLogs（在本地過濾今日資料）
      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // 🆕 本地過濾：只保留今日的記錄
        if (createdAt == null || createdAt.isBefore(todayStart) || createdAt.isAfter(todayEnd)) {
          continue;
        }
        
        mergedMap[doc.id] = {
          'id': doc.id,
          'name': data['name'] ?? '未知運動',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['caloriesBurned'] ?? 0.0).toDouble(),
          'sessionId': data['sessionId'],
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          // 🆕 關鍵：讀取 planId 和 planName
          'planId': data['planId'],
          'planName': data['planName'],
          'notes': data['notes'],
          'source': 'workoutLogs',
        };
      }

      // 再加入 users/workouts（如果不重複，本地過濾今日資料）
      for (var doc in userWorkoutsSnapshot.docs) {
        if (mergedMap.containsKey(doc.id)) continue;
        
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // 🆕 本地過濾：只保留今日的記錄
        if (createdAt == null || createdAt.isBefore(todayStart) || createdAt.isAfter(todayEnd)) {
          continue;
        }
        
        mergedMap[doc.id] = {
            'id': doc.id,
            'name': data['name'] ?? '未知運動',
            'duration': data['duration'] ?? 0,
            'caloriesBurned': (data['caloriesBurned'] ?? 0.0).toDouble(),
            'sessionId': data['sessionId'],
            'totalSets': data['totalSets'] ?? data['sets'],
            'totalExercises': data['totalExercises'],
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'planId': data['planId'],
            'planName': data['planName'],
            'notes': data['notes'],
            'source': 'userWorkouts',
          };
        }

      // 轉換為列表並排序
      final workouts = mergedMap.values.toList();
      workouts.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      // 🆕 計算來源統計
      int planCount = 0;
      int freeCount = 0;
      int totalDuration = 0;
      double totalCalories = 0.0;

      for (var workout in workouts) {
        if (workout['planId'] != null && (workout['planId'] as String).isNotEmpty) {
          planCount++;
        } else {
          freeCount++;
        }
        totalDuration += (workout['duration'] ?? 0) as int;
        totalCalories += (workout['caloriesBurned'] ?? 0.0) as double;
      }

      // 載入週統計
      final weeklyStats = await _loadWeeklyStats(userId);

      if (kDebugMode) {
        debugPrint('✅ 載入成功:');
        debugPrint('   今日訓練: ${workouts.length} 筆');
        debugPrint('   計畫訓練: $planCount 筆');
        debugPrint('   自由訓練: $freeCount 筆');
      }

      if (mounted) {
        setState(() {
          _todayWorkouts = workouts;
          _planCount = planCount;
          _freeCount = freeCount;
          _todayStats = {
            'totalDuration': totalDuration,
            'totalCalories': totalCalories,
            'workoutCount': workouts.length,
          };
          _weeklyStats = weeklyStats;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 載入訓練數據失敗: $e');
        debugPrint('堆疊追蹤: $stackTrace');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入數據失敗: $e');
      }
    }
  }

  /// 載入週統計
  Future<Map<String, dynamic>> _loadWeeklyStats(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      // 🆕 簡化查詢，避免複合索引
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      int totalDuration = 0;
      double totalCalories = 0.0;
      Set<String> workoutDays = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // 🆕 本地過濾：只計算本週的記錄
        if (createdAt == null || createdAt.isBefore(weekStartDate)) {
          continue;
        }
        
        totalDuration += (data['duration'] ?? 0) as int;
        totalCalories += (data['caloriesBurned'] ?? 0.0).toDouble();
        workoutDays.add('${createdAt.year}-${createdAt.month}-${createdAt.day}');
      }

      return {
        'workoutDays': workoutDays.length,
        'totalDuration': totalDuration,
        'totalCalories': totalCalories,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入週統計失敗: $e');
      }
      return {
        'workoutDays': 0,
        'totalDuration': 0,
        'totalCalories': 0.0,
      };
    }
  }

  Future<void> _deleteWorkout(String workoutId) async {
    if (kDebugMode) {
      debugPrint('🗑️ 刪除訓練記錄: $workoutId');
    }

    try {
      // 從 workoutLogs 刪除
      await _firestore.collection('workoutLogs').doc(workoutId).delete();
      
      // 也嘗試從 users/workouts 刪除
      final userId = _currentUserId;
      if (userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('workouts')
            .doc(workoutId)
            .delete()
            .catchError((_) {}); // 忽略錯誤（可能不存在）
      }

      _showSnackBar('已刪除運動記錄');
      await _loadData();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 刪除失敗: $e');
      }
      _showSnackBar('刪除失敗,請重試');
    }
  }

  Future<void> _confirmDelete(String workoutId, String workoutName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$workoutName」嗎?'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '訓練記錄',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (widget.planId != null)
              Text(
                '📋 計畫訓練',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
          ],
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
                    if (widget.planId != null) _buildPlanModeInfoCard(),
                    _buildTodayStatsCard(),
                    _buildWeeklyStatsCard(),
                    _buildTodayWorkoutsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewWorkout,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '開始訓練',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 開始新訓練
  Future<void> _startNewWorkout() async {
    if (kDebugMode) {
      debugPrint('🏋️ 導航到運動選擇頁面...');
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionPage(
          isCoach: widget.isCoach,
          traineeId: widget.traineeId,
          planId: widget.planId,
        ),
      ),
    );

    if (result == true && mounted) {
      if (kDebugMode) {
        debugPrint('✅ 訓練完成，重新載入數據...');
      }
      await _loadData();
      _showSnackBar('✅ 訓練已記錄！');
    }
  }

  Widget _buildPlanModeInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_note,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '訓練計畫模式',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '此次訓練將計入計畫進度',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }

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
            color: Colors.green.withOpacity(0.3),
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
                '今日訓練 ${DateFormat('M月d日 (E)', 'zh_TW').format(DateTime.now())}',
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

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
            color: Colors.grey.withOpacity(0.1),
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
                '本週統計(過去7天)',
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
            color: color.withOpacity(0.1),
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

  Widget _buildTodayWorkoutsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                // 🆕 顯示來源統計標籤
                if (_planCount > 0) ...[
                  _buildSourceTag('計畫', _planCount, Colors.orange),
                  const SizedBox(width: 6),
                ],
                if (_freeCount > 0) ...[
                  _buildSourceTag('自由', _freeCount, Colors.blue),
                ],
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

  /// 🆕 來源標籤
  Widget _buildSourceTag(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWorkoutItem(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '未知運動';
    final duration = workout['duration'] ?? 0;
    final calories = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final workoutId = workout['id'] ?? '';

    // 🆕 判斷來源
    final planId = workout['planId'] as String?;
    final isPlanWorkout = planId != null && planId.isNotEmpty;

    final createdAt = workout['createdAt'];
    DateTime dateTime;

    if (createdAt is DateTime) {
      dateTime = createdAt;
    } else {
      dateTime = DateTime.now();
    }

    final totalSets = workout['totalSets'] ?? 0;
    final totalExercises = workout['totalExercises'] ?? 0;

    return Dismissible(
      key: Key(workoutId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認刪除'),
            content: Text('確定要刪除「$name」嗎?'),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showWorkoutDetail(workout),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 🆕 根據來源顯示不同顏色的圖示
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPlanWorkout
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPlanWorkout ? Icons.event_note : Icons.fitness_center,
                    color: isPlanWorkout ? Colors.orange : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🆕 標題行：名稱 + 來源標籤
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 🆕 來源標籤
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPlanWorkout
                                  ? Colors.orange.withOpacity(0.15)
                                  : Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPlanWorkout
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isPlanWorkout ? '計畫' : '自由',
                              style: TextStyle(
                                fontSize: 10,
                                color: isPlanWorkout ? Colors.orange : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 時間
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm:ss').format(dateTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 統計資訊
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

                      // 動作和組數
                      if (totalExercises > 0 || totalSets > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${totalExercises > 0 ? '$totalExercises 個動作' : ''}${totalExercises > 0 && totalSets > 0 ? ' • ' : ''}${totalSets > 0 ? '$totalSets 組' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),

                // 右側操作按鈕
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(workoutId, name),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🆕 顯示訓練詳情
  Future<void> _showWorkoutDetail(Map<String, dynamic> workout) async {
    final sessionId = workout['sessionId'] as String?;
    final notes = workout['notes'] as String?;
    final planId = workout['planId'] as String?;
    final planName = workout['planName'] as String?;
    final isPlanWorkout = planId != null && planId.isNotEmpty;

    // 如果有 sessionId，嘗試載入 session 詳情
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        final sessionDoc = await _firestore
            .collection('workoutSessions')
            .doc(sessionId)
            .get();

        if (sessionDoc.exists && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkoutSessionDetailPage(
                workoutSession: sessionDoc.data()!,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('載入 session 詳情失敗: $e');
        }
      }
    }

    // 如果沒有 sessionId 或載入失敗，顯示簡單的詳情對話框
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isPlanWorkout ? Icons.event_note : Icons.fitness_center,
                color: isPlanWorkout ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  workout['name'] ?? '訓練詳情',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 來源標籤
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPlanWorkout
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlanWorkout ? Icons.calendar_today : Icons.sports_gymnastics,
                        size: 16,
                        color: isPlanWorkout ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPlanWorkout ? '計畫訓練' : '自由訓練',
                        style: TextStyle(
                          color: isPlanWorkout ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (isPlanWorkout && planName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '計畫名稱：$planName',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // 統計資訊
                _buildDetailRow(Icons.timer, '訓練時長', '${workout['duration']} 分鐘'),
                _buildDetailRow(Icons.local_fire_department, '消耗熱量', '${(workout['caloriesBurned'] ?? 0.0).toStringAsFixed(0)} 卡'),
                
                if ((workout['totalExercises'] ?? 0) > 0)
                  _buildDetailRow(Icons.fitness_center, '動作數', '${workout['totalExercises']} 個'),
                
                if ((workout['totalSets'] ?? 0) > 0)
                  _buildDetailRow(Icons.repeat, '總組數', '${workout['totalSets']} 組'),

                // 備註
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '訓練備註',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

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