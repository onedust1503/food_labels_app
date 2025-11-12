// lib/pages/workout/workout_log_page.dart
// 🔥 完整修正版：添加日期時間顯示 + 可點擊查看詳情

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/workout_service.dart';
import '../../models/workout_model.dart';
import 'free_workout_execution_page.dart';
import 'workout_summary_page.dart';
import 'workout_detail_page.dart'; // 🔥 關鍵：加入這行 import

class WorkoutLogPage extends StatefulWidget {
  const WorkoutLogPage({super.key});

  @override
  State<WorkoutLogPage> createState() => _WorkoutLogPageState();
}

class _WorkoutLogPageState extends State<WorkoutLogPage> {
  final WorkoutService _workoutService = WorkoutService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WorkoutModel> _todayWorkouts = [];
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
      final workouts = await _workoutService.getTodayWorkouts();
      final summary = await _workoutService.getTodayWorkoutSummary();

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
            Text(
              '${_todayWorkouts.length} 筆記錄',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._todayWorkouts.map((workout) => _buildWorkoutCard(workout)),
      ],
    );
  }

  Widget _buildWorkoutCard(WorkoutModel workout) {
    IconData typeIcon;
    Color typeColor;

    switch (workout.type) {
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

    // 🔥 格式化時間顯示（精確到秒）
    final timeStr = DateFormat('HH:mm:ss').format(workout.createdAt);

    // 🔥 時長顯示（精確到秒）
    String durationText = '${workout.duration} 分鐘';
    
    return GestureDetector(
      onTap: () {
        // 🔥 關鍵修正：根據是否有 sessionId 決定顯示方式
        final sid = workout.sessionId;
        if (sid != null && sid.isNotEmpty) {
          // 有 sessionId - 跳轉到詳情頁面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutDetailPage(workout: workout),
            ),
          );
        } else {
          // 沒有 sessionId - 顯示簡單對話框
          _showSimpleWorkoutDetail(workout);
        }
      },
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
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, color: typeColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          workout.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 🔥 顯示時間（精確到秒）
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    durationText,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  // 🔥 顯示總組數和動作數
                  if (workout.totalSets != null && workout.totalExercises != null)
                    Text(
                      '${workout.totalExercises} 個動作 · ${workout.totalSets} 組',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                if (workout.caloriesBurned != null) ...[
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  Text(
                    '${workout.caloriesBurned!.toInt()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showSimpleWorkoutDetail(WorkoutModel workout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workout.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('日期', workout.date),
              _buildDetailRow('時間', DateFormat('HH:mm:ss').format(workout.createdAt)),
              _buildDetailRow('時長', '${workout.duration} 分鐘'),
              if (workout.sets != null)
                _buildDetailRow('組數', '${workout.sets} 組'),
              if (workout.reps != null)
                _buildDetailRow('次數', '${workout.reps} 次'),
              if (workout.weight != null)
                _buildDetailRow('重量', '${workout.weight} kg'),
              if (workout.caloriesBurned != null)
                _buildDetailRow('卡路里', '${workout.caloriesBurned!.toInt()} 大卡'),
              if (workout.intensity != null)
                _buildDetailRow('強度', _getIntensityText(workout.intensity!)),
              if (workout.notes != null && workout.notes!.isNotEmpty)
                _buildDetailRow('備註', workout.notes!),
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
                                color: const Color(0xFF6C63FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.history, color: Color(0xFF6C63FF), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (start != null)
                                        Text(
                                          DateFormat('HH:mm').format(start),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
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