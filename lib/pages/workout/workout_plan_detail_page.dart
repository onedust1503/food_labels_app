// lib/pages/workout/workout_plan_detail_page.dart
// ✅ 更新版 - 啟用進度追蹤功能，保留所有原有功能
import 'package:flutter/material.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';
import '../../services/workout_progress_service.dart'; // 🆕 導入進度服務
import 'workout_execution_page.dart';

class WorkoutPlanDetailPage extends StatefulWidget {
  final WorkoutPlanModel plan;

  const WorkoutPlanDetailPage({super.key, required this.plan});

  @override
  State<WorkoutPlanDetailPage> createState() => _WorkoutPlanDetailPageState();
}

class _WorkoutPlanDetailPageState extends State<WorkoutPlanDetailPage> {
  final WorkoutService _workoutService = WorkoutService();
  final WorkoutProgressService _progressService = WorkoutProgressService(); // 🆕 進度服務
  
  // ✅ 啟用進度功能
  Map<String, int> _completions = {};
  bool _isLoadingProgress = true;

  final Map<String, String> _dayNames = {
    'monday': '星期一',
    'tuesday': '星期二',
    'wednesday': '星期三',
    'thursday': '星期四',
    'friday': '星期五',
    'saturday': '星期六',
    'sunday': '星期日',
  };

  @override
  void initState() {
    super.initState();
    _loadProgress(); // ✅ 載入進度
  }

  // ✅ 啟用進度載入
  Future<void> _loadProgress() async {
    if (widget.plan.id != null) {
      try {
        final progress = await _progressService.getWeeklyCompletion(widget.plan.id!);
        setState(() {
          _completions = progress;
          _isLoadingProgress = false;
        });
      } catch (e) {
        setState(() => _isLoadingProgress = false);
      }
    } else {
      setState(() => _isLoadingProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.plan.planName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.plan.status == 'active')
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('標記為完成'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'complete') {
                  _markAsCompleted();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlanHeader(),
            const SizedBox(height: 16),
            // ✅ 檢查載入狀態
            _isLoadingProgress
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _buildWeeklySchedule(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHeader() {
    // ✅ 計算完成次數
    int totalCompletions = _completions.values.fold(0, (sum, count) => sum + count);
    int totalDays = widget.plan.days.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.plan.description != null) ...[
            Text(
              widget.plan.description!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(widget.plan.startDate)} - ${widget.plan.endDate != null ? _formatDate(widget.plan.endDate!) : "持續進行"}',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.fitness_center, size: 16, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                '每週 $totalDays 天訓練',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ✅ 顯示實際完成次數
                _buildStatItem('已完成', '$totalCompletions 次', Icons.check_circle),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                _buildStatItem('本週目標', '$totalDays 天', Icons.fitness_center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWeeklySchedule() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每週訓練計畫',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...widget.plan.days.asMap().entries.map((entry) {
            int index = entry.key;
            WorkoutPlanDay day = entry.value;
            return _buildDayCard(day, index);
          }),
        ],
      ),
    );
  }

  Widget _buildDayCard(WorkoutPlanDay day, int index) {
    // ✅ 顯示完成次數
    int completionCount = _completions[day.dayOfWeek] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dayNames[day.dayOfWeek] ?? day.dayOfWeek,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${day.exercises.length} 個動作',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                // ✅ 顯示完成次數
                const Spacer(),
                if (completionCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '完成 $completionCount 次',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...day.exercises.asMap().entries.map((entry) {
                  int exIndex = entry.key;
                  PlannedExercise exercise = entry.value;
                  return _buildExerciseItem(exercise, exIndex + 1);
                }),
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startWorkout(day),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.play_circle_filled, size: 22),
                    label: const Text(
                      '開始訓練',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(PlannedExercise exercise, int index) {
    IconData icon;
    Color iconColor;

    switch (exercise.type) {
      case 'weight_training':
        icon = Icons.fitness_center;
        iconColor = Colors.red;
        break;
      case 'cardio':
        icon = Icons.directions_run;
        iconColor = Colors.blue;
        break;
      case 'yoga':
        icon = Icons.self_improvement;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.sports;
        iconColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  _getExerciseDetails(exercise),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (exercise.notes != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          exercise.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getExerciseDetails(PlannedExercise exercise) {
    List<String> details = [];

    if (exercise.sets != null && exercise.reps != null) {
      details.add('${exercise.sets} 組 × ${exercise.reps} 次');
    } else if (exercise.sets != null) {
      details.add('${exercise.sets} 組');
    }

    if (exercise.duration != null) {
      details.add('${exercise.duration} 分鐘');
    }

    return details.isEmpty ? '自訂訓練' : details.join(' • ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _startWorkout(WorkoutPlanDay day) async {
    if (widget.plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('計畫 ID 不存在'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutExecutionPage(
          planDay: day,
          planId: widget.plan.id!,
          planName: widget.plan.planName,
        ),
      ),
    );

    // ✅ 重新載入進度
    if (result == true) {
      _loadProgress();
    }
  }

  Future<void> _markAsCompleted() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('確認完成'),
          content: const Text('確定要將此訓練計畫標記為已完成嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('確定'),
            ),
          ],
        ),
      );

      if (confirmed == true && widget.plan.id != null) {
        await _workoutService.markPlanAsCompleted(widget.plan.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已標記為完成!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}