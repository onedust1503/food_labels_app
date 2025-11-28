// lib/pages/workout/workout_log_page.dart
// 🔥 完整整合版：保留原有功能 + 整合顯示自由訓練和教練計畫
// ✅ 統一使用 UnifiedWorkoutService
// ✅ 標籤區分「自由」和「計畫」訓練
// ✅ 修正詳情頁面導航，確保資料正確傳遞
// ✅ 保留所有原有功能

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/unified_workout_service.dart';
import '../../models/workout_model.dart';
import 'free_workout_execution_page.dart';
import 'workout_summary_page.dart';
import 'workout_session_detail_page.dart';

class WorkoutLogPage extends StatefulWidget {
  const WorkoutLogPage({super.key});

  @override
  State<WorkoutLogPage> createState() => _WorkoutLogPageState();
}

class _WorkoutLogPageState extends State<WorkoutLogPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _todayWorkouts = [];
  Map<String, dynamic> _todaySummary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayWorkouts();
  }

  Future<void> _loadTodayWorkouts() async {
    setState(() => _isLoading = true);
    try {
      // ✅ 使用整合方法，同時讀取自由訓練和計畫訓練
      final workouts = await _loadTodayWorkoutsUnified();
      final summary = await _workoutService.getTodayStats();

      setState(() {
        _todayWorkouts = workouts;
        _todaySummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  /// 🔥 整合讀取今日所有訓練（自由訓練 + 教練計畫）
  Future<List<Map<String, dynamic>>> _loadTodayWorkoutsUnified() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];
    
    List<Map<String, dynamic>> allWorkouts = [];

    try {
      // 1️⃣ 從 workoutLogs 讀取（包含手動記錄、自由訓練、計畫訓練）
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名訓練',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'sets': data['sets'],
          'reps': data['reps'],
          'weight': data['weight'],
          'intensity': data['intensity'],
          'notes': data['notes'],
          'sessionId': data['sessionId'],
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['createdAt'],
          'timestamp': data['timestamp'],
          // 🔥 判斷來源
          'source': _determineSource(data),
        });
      }

      // 2️⃣ 檢查 workoutSessions 是否有額外的記錄（避免重複）
      final existingSessionIds = allWorkouts
          .where((w) => w['sessionId'] != null)
          .map((w) => w['sessionId'] as String)
          .toSet();

      final sessionsSnapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        // 避免重複
        if (existingSessionIds.contains(doc.id)) continue;

        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? data['planName'] ?? '訓練記錄',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['totalCalories'] ?? data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'],
          'totalExercises': data['totalExercises'],
          'sessionId': doc.id,
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['completedAt'] ?? data['endedAt'],
          'timestamp': data['timestamp'] is Timestamp 
              ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch 
              : data['timestamp'],
          'source': data['planId'] != null ? 'plan' : 'self',
        });
      }

      // 3️⃣ 按時間排序（最新的在前）
      allWorkouts.sort((a, b) {
        int aTime = 0;
        int bTime = 0;
        
        if (a['timestamp'] != null) {
          aTime = a['timestamp'] is int ? a['timestamp'] : 0;
        } else if (a['createdAt'] != null && a['createdAt'] is Timestamp) {
          aTime = (a['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        
        if (b['timestamp'] != null) {
          bTime = b['timestamp'] is int ? b['timestamp'] : 0;
        } else if (b['createdAt'] != null && b['createdAt'] is Timestamp) {
          bTime = (b['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        
        return bTime.compareTo(aTime);
      });

      return allWorkouts;
    } catch (e) {
      debugPrint('❌ _loadTodayWorkoutsUnified 錯誤: $e');
      // 如果整合方法失敗，回退到原始方法
      return await _workoutService.getTodayWorkouts();
    }
  }

  /// 🔥 判斷訓練來源
  String _determineSource(Map<String, dynamic> data) {
    if (data['planId'] != null) {
      return 'plan';  // 教練計畫
    } else if (data['sessionId'] != null) {
      return 'self';  // 自由訓練
    } else {
      return 'manual';  // 手動記錄
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('運動記錄'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWorkoutDialog(),
            tooltip: '事後記錄',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayWorkouts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySummaryCard(),
                    const SizedBox(height: 20),
                    _buildStartWorkoutButton(),
                    const SizedBox(height: 20),
                    _buildWorkoutList(),
                    const SizedBox(height: 20),
                    _buildCompletedSessionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStartWorkoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showSelectExercisesDialog,
        icon: const Icon(Icons.fitness_center, size: 28),
        label: const Text(
          '開始訓練',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  void _showSelectExercisesDialog() {
    showDialog(
      context: context,
      builder: (context) => SelectExercisesDialog(
        onConfirm: (exercises) {
          Navigator.pop(context);
          _startWorkout(exercises);
        },
      ),
    );
  }

  Future<void> _startWorkout(List<Map<String, dynamic>> exercises) async {
    if (exercises.isEmpty) {
      _showSnackBar('請至少選擇一個動作', Colors.orange);
      return;
    }

    final sessionId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FreeWorkoutExecutionPage(exercises: exercises),
      ),
    );

    if (!mounted) return;

    if (sessionId != null && sessionId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
        ),
      );

      if (!mounted) return;

      await _loadTodayWorkouts();
      _showSnackBar('✅ 訓練記錄已保存！', Colors.green);
    }
  }

  Widget _buildTodaySummaryCard() {
    int totalDuration = _todaySummary['totalDuration'] ?? 0;
    double totalCalories = (_todaySummary['totalCalories'] ?? 0).toDouble();
    int workoutCount = _todaySummary['workoutCount'] ?? 0;

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
              const Text(
                '今日運動',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.timer, '$totalDuration', '分鐘'),
              _buildStatItem(Icons.local_fire_department, '${totalCalories.toInt()}', '大卡'),
              _buildStatItem(Icons.fitness_center, '$workoutCount', '次'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
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

  Widget _buildWorkoutList() {
    if (_todayWorkouts.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.fitness_center, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '今天還沒有運動記錄',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showSelectExercisesDialog,
              icon: const Icon(Icons.add),
              label: const Text('開始訓練'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 🔥 統計不同來源的訓練數量
    int selfCount = _todayWorkouts.where((w) => w['source'] == 'self').length;
    int planCount = _todayWorkouts.where((w) => w['source'] == 'plan').length;
    int manualCount = _todayWorkouts.where((w) => w['source'] == 'manual').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '今日訓練',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                if (selfCount > 0)
                  _buildCountChip('自由', selfCount, Colors.blue),
                if (planCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildCountChip('計畫', planCount, Colors.orange),
                ],
                if (manualCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildCountChip('手動', manualCount, Colors.grey),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._todayWorkouts.map((workout) => _buildWorkoutCard(workout)),
      ],
    );
  }

  /// 🔥 來源統計小標籤
  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
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

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final type = workout['type'] ?? 'other';
    final name = workout['name'] ?? '訓練記錄';
    final planName = workout['planName'] as String?;
    final duration = workout['duration'] ?? 0;
    final caloriesBurned = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final totalSets = workout['totalSets'];
    final totalExercises = workout['totalExercises'];
    final sessionId = workout['sessionId'];
    final source = workout['source'] as String? ?? 'manual';
    
    // 🔥 根據來源設定顏色和標籤
    Color sourceColor;
    String sourceLabel;
    IconData sourceIcon;

    switch (source) {
      case 'plan':
        sourceColor = Colors.orange;
        sourceLabel = '計畫';
        sourceIcon = Icons.event_note;
        break;
      case 'self':
        sourceColor = Colors.blue;
        sourceLabel = '自由';
        sourceIcon = Icons.self_improvement;
        break;
      default:
        sourceColor = Colors.grey;
        sourceLabel = '手動';
        sourceIcon = Icons.edit;
    }
    
    IconData typeIcon;
    Color typeColor;

    switch (type) {
      case 'weight_training':
        typeIcon = Icons.fitness_center;
        typeColor = Colors.red;
        break;
      case 'cardio':
        typeIcon = Icons.directions_run;
        typeColor = Colors.blue;
        break;
      case 'yoga':
        typeIcon = Icons.self_improvement;
        typeColor = Colors.purple;
        break;
      case 'self_workout':
        typeIcon = Icons.sports;
        typeColor = Colors.green;
        break;
      default:
        typeIcon = Icons.sports;
        typeColor = Colors.orange;
    }

    // 🔥 格式化時間顯示
    String timeStr = '';
    final createdAt = workout['createdAt'];
    final timestamp = workout['timestamp'];
    
    if (createdAt != null) {
      try {
        final dateTime = createdAt is Timestamp 
            ? createdAt.toDate() 
            : DateTime.fromMillisecondsSinceEpoch(createdAt);
        timeStr = DateFormat('HH:mm').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    } else if (timestamp != null) {
      try {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        timeStr = DateFormat('HH:mm').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    }

    // 🔥 顯示名稱（計畫訓練優先顯示計畫名稱）
    final displayName = planName ?? name;

    return GestureDetector(
      onTap: () => _navigateToDetail(workout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔥 使用來源顏色而不是類型顏色
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(sourceIcon, color: sourceColor, size: 28),
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
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 🔥 來源標籤
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sourceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sourceColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: sourceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (timeStr.isNotEmpty) ...[
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.timer, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '$duration 分鐘',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  // 🔥 顯示總組數和動作數
                  if (totalSets != null || totalExercises != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (totalExercises != null) ...[
                          Text(
                            '$totalExercises 個動作',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                        if (totalSets != null && totalExercises != null)
                          Text(' · ', style: TextStyle(color: Colors.grey[400])),
                        if (totalSets != null)
                          Text(
                            '$totalSets 組',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (caloriesBurned > 0) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        '${caloriesBurned.toInt()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '卡',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// 🔥 導航到詳情頁面 - 關鍵修正
  Future<void> _navigateToDetail(Map<String, dynamic> workout) async {
    final sessionId = workout['sessionId'] as String?;
    
    if (sessionId != null && sessionId.isNotEmpty) {
      // 🔥 有 sessionId - 從 workoutSessions 獲取完整詳情
      try {
        final details = await _workoutService.getWorkoutSessionDetails(sessionId);
        
        if (details != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutSessionDetailPage(
                workoutSession: details,
              ),
            ),
          );
        } else {
          // 如果詳情不存在，顯示簡單對話框
          _showSimpleWorkoutDetail(workout);
        }
      } catch (e) {
        _showSnackBar('載入詳情失敗：$e', Colors.red);
      }
    } else {
      // 沒有 sessionId - 顯示簡單對話框
      _showSimpleWorkoutDetail(workout);
    }
  }

  void _showSimpleWorkoutDetail(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '訓練記錄';
    final planName = workout['planName'] as String?;
    final date = workout['date'] ?? '';
    final duration = workout['duration'] ?? 0;
    final sets = workout['sets'];
    final reps = workout['reps'];
    final weight = workout['weight'];
    final caloriesBurned = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final intensity = workout['intensity'];
    final notes = workout['notes'];
    final source = workout['source'] as String? ?? 'manual';
    
    String timeStr = '';
    final createdAt = workout['createdAt'];
    if (createdAt != null) {
      try {
        final dateTime = createdAt is Timestamp 
            ? createdAt.toDate() 
            : DateTime.fromMillisecondsSinceEpoch(createdAt);
        timeStr = DateFormat('HH:mm:ss').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    }

    // 來源標籤
    String sourceText;
    Color sourceColor;
    switch (source) {
      case 'plan':
        sourceText = '教練計畫';
        sourceColor = Colors.orange;
        break;
      case 'self':
        sourceText = '自由訓練';
        sourceColor = Colors.blue;
        break;
      default:
        sourceText = '手動記錄';
        sourceColor = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Expanded(child: Text(planName ?? name)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sourceText,
                style: TextStyle(fontSize: 12, color: sourceColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (date.isNotEmpty) _buildDetailRow('日期', date),
              if (timeStr.isNotEmpty) _buildDetailRow('時間', timeStr),
              _buildDetailRow('時長', '$duration 分鐘'),
              if (sets != null) _buildDetailRow('組數', '$sets 組'),
              if (reps != null) _buildDetailRow('次數', '$reps 次'),
              if (weight != null) _buildDetailRow('重量', '$weight kg'),
              if (caloriesBurned > 0) _buildDetailRow('卡路里', '${caloriesBurned.toInt()} 大卡'),
              if (intensity != null) _buildDetailRow('強度', _getIntensityText(intensity)),
              if (notes != null && notes.isNotEmpty) _buildDetailRow('備註', notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWorkout(workout);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 🔥 刪除訓練記錄
  Future<void> _deleteWorkout(Map<String, dynamic> workout) async {
    final workoutId = workout['id'] as String?;
    if (workoutId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這筆訓練記錄嗎？'),
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
      try {
        await _workoutService.deleteWorkout(workoutId);
        _showSnackBar('已刪除訓練記錄', Colors.green);
        _loadTodayWorkouts();
      } catch (e) {
        _showSnackBar('刪除失敗：$e', Colors.red);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label：',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityText(String intensity) {
    switch (intensity) {
      case 'low':
        return '低強度';
      case 'medium':
        return '中強度';
      case 'high':
        return '高強度';
      default:
        return intensity;
    }
  }

  Widget _buildCompletedSessionsSection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .where('endedAt', isNotEqualTo: null)
          .orderBy('endedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final sessions = snapshot.data!.docs;
        final today = DateTime.now().toIso8601String().split('T')[0];
        final historySessions = sessions.where((doc) {
          final startTs = doc.data()['startedAt'] as Timestamp?;
          if (startTs == null) return false;
          final date = startTs.toDate().toIso8601String().split('T')[0];
          return date != today;
        }).toList();

        if (historySessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '歷史訓練記錄',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${historySessions.length} 筆',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: historySessions.length,
              itemBuilder: (context, index) {
                final doc = historySessions[index];
                final data = doc.data();
                final startTs = data['startedAt'] as Timestamp?;
                final endTs = data['endedAt'] as Timestamp?;
                final start = startTs?.toDate();
                final end = endTs?.toDate();
                final planId = data['planId'];
                final planName = data['planName'] as String?;
                final source = planId != null ? 'plan' : 'self';

                String dateText = '未記錄時間';
                String durationText = '—';
                
                if (start != null) {
                  dateText = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(start);
                  
                  if (end != null) {
                    final diff = end.difference(start);
                    final minutes = diff.inMinutes;
                    final seconds = diff.inSeconds % 60;
                    durationText = '$minutes分$seconds秒';
                  }
                }

                // 來源標籤
                Color sourceColor = source == 'plan' ? Colors.orange : Colors.blue;
                String sourceLabel = source == 'plan' ? '計畫' : '自由';

                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('workoutLogs')
                      .where('sessionId', isEqualTo: doc.id)
                      .limit(1)
                      .get(),
                  builder: (context, logSnapshot) {
                    int exercises = 0;
                    int totalSets = 0;
                    double calories = 0;

                    if (logSnapshot.hasData && logSnapshot.data!.docs.isNotEmpty) {
                      final logData = logSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      exercises = logData['totalExercises'] ?? 0;
                      totalSets = logData['totalSets'] ?? 0;
                      calories = (logData['caloriesBurned'] ?? 0).toDouble();
                    }

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutSummaryPage(sessionId: doc.id),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sourceColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                source == 'plan' ? Icons.event_note : Icons.history,
                                color: sourceColor,
                                size: 28,
                              ),
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
                                          planName ?? dateText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // 來源標籤
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: sourceColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sourceLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: sourceColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (planName != null)
                                    Text(
                                      dateText,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  Text(
                                    '時長：$durationText · 動作：$exercises · 組數：$totalSets',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (calories > 0)
                              Column(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                  Text(
                                    '${calories.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddWorkoutDialog(
        onSave: (data) async {
          await _workoutService.addWorkoutLog(
            type: data['type'],
            name: data['name'],
            duration: data['duration'],
            caloriesBurned: data['calories'],
            sets: data['sets'],
            reps: data['reps'],
            intensity: data['intensity'],
            notes: data['notes'],
          );
          _loadTodayWorkouts();
          _showSnackBar('運動記錄成功！', Colors.green);
        },
      ),
    );
  }
}

// ========== 選擇動作對話框 ==========

class SelectExercisesDialog extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onConfirm;

  const SelectExercisesDialog({super.key, required this.onConfirm});

  @override
  State<SelectExercisesDialog> createState() => _SelectExercisesDialogState();
}

class _SelectExercisesDialogState extends State<SelectExercisesDialog> {
  final List<Map<String, dynamic>> _selectedExercises = [];

  final List<Map<String, dynamic>> _exerciseLibrary = [
    {'name': '臥推', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 8, 'restSec': 120},
    {'name': '深蹲', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 8, 'restSec': 120},
    {'name': '硬舉', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 5, 'restSec': 180},
    {'name': '肩推', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 10, 'restSec': 90},
    {'name': '引體向上', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 8, 'restSec': 90},
    {'name': '二頭彎舉', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60},
    {'name': '三頭下壓', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60},
    {'name': '啞鈴飛鳥', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60},
    {'name': '腿推', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 10, 'restSec': 90},
    {'name': '跑步', 'type': 'duration', 'defaultDuration': 30, 'restSec': 0},
    {'name': '棒式', 'type': 'duration', 'defaultDuration': 60, 'defaultSets': 3, 'restSec': 60},
  ];

  void _addExercise(Map<String, dynamic> exercise) {
    setState(() {
      _selectedExercises.add({
        'name': exercise['name'],
        'type': exercise['type'],
        'plannedSets': exercise['defaultSets'] ?? 3,
        'plannedReps': exercise['defaultReps'],
        'plannedDurationSec': exercise['defaultDuration'] != null 
            ? exercise['defaultDuration'] * 60 
            : null,
        'restSec': exercise['restSec'] ?? 90,
      });
    });
  }

  void _removeExercise(int index) {
    setState(() => _selectedExercises.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '選擇訓練動作',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),

          if (_selectedExercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '已選擇：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedExercises.asMap().entries.map((entry) {
                final index = entry.key;
                final ex = entry.value;
                return Chip(
                  label: Text('${index + 1}. ${ex['name']}'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => _removeExercise(index),
                  backgroundColor: Colors.orange[100],
                );
              }).toList(),
            ),
            const Divider(),
          ],

          Expanded(
            child: ListView.builder(
              itemCount: _exerciseLibrary.length,
              itemBuilder: (context, index) {
                final ex = _exerciseLibrary[index];
                return ListTile(
                  leading: const Icon(Icons.fitness_center, color: Colors.orange),
                  title: Text(ex['name']),
                  subtitle: Text(
                    ex['type'] == 'reps'
                        ? '${ex['defaultSets']} 組 × ${ex['defaultReps']} 次'
                        : '${ex['defaultDuration']} 分鐘',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => _addExercise(ex),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedExercises.isEmpty
                  ? null
                  : () => widget.onConfirm(_selectedExercises),
              icon: const Icon(Icons.check),
              label: Text('確認（${_selectedExercises.length} 個動作）'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 事後記錄對話框 ========== 

class AddWorkoutDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AddWorkoutDialog({super.key, required this.onSave});

  @override
  State<AddWorkoutDialog> createState() => _AddWorkoutDialogState();
}

class _AddWorkoutDialogState extends State<AddWorkoutDialog> {
  String _selectedType = 'weight_training';
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  String _selectedIntensity = 'medium';

  final Map<String, String> _workoutTypes = {
    'weight_training': '重量訓練',
    'cardio': '有氧運動',
    'yoga': '瑜伽',
    'stretching': '伸展',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '事後記錄運動',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '運動類型',
                border: OutlineInputBorder(),
              ),
              items: _workoutTypes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '運動名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: '時長（分鐘）',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: '消耗卡路里',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_selectedType == 'weight_training') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setsController,
                      decoration: const InputDecoration(
                        labelText: '組數',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      decoration: const InputDecoration(
                        labelText: '次數',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isEmpty || _durationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填寫必填欄位')),
                    );
                    return;
                  }

                  widget.onSave({
                    'type': _selectedType,
                    'name': _nameController.text,
                    'duration': int.parse(_durationController.text),
                    'calories': _caloriesController.text.isNotEmpty
                        ? double.parse(_caloriesController.text)
                        : null,
                    'sets': _setsController.text.isNotEmpty
                        ? int.parse(_setsController.text)
                        : null,
                    'reps': _repsController.text.isNotEmpty
                        ? int.parse(_repsController.text)
                        : null,
                    'intensity': _selectedIntensity,
                    'notes': null,
                  });

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}