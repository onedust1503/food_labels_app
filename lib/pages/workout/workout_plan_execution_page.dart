// lib/pages/workout/workout_plan_execution_page.dart
// 🎯 訓練計畫執行頁面 - 整合版
// ✅ 支援計畫訓練的完整執行流程

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/workout_model.dart';
import '../../services/unified_workout_service.dart';

class WorkoutPlanExecutionPage extends StatefulWidget {
  final WorkoutPlanModel plan;
  final WorkoutPlanDay selectedDay;

  const WorkoutPlanExecutionPage({
    super.key,
    required this.plan,
    required this.selectedDay,
  });

  @override
  State<WorkoutPlanExecutionPage> createState() =>
      _WorkoutPlanExecutionPageState();
}

class _WorkoutPlanExecutionPageState extends State<WorkoutPlanExecutionPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();

  // 當前執行的動作索引
  int _currentExerciseIndex = 0;

  // 計時器相關
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  // 休息計時器
  Timer? _restTimer;
  int _restSeconds = 60;
  bool _isResting = false;

  // 每個動作的完成記錄
  Map<int, List<ExerciseSetRecord>> _exerciseRecords = {};

  // 當前動作的組數輸入
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // 總備註
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 初始化每個動作的記錄
    for (int i = 0; i < widget.selectedDay.exercises.length; i++) {
      _exerciseRecords[i] = [];
    }

    if (kDebugMode) {
      debugPrint('📋 開始計畫訓練:');
      debugPrint('   計畫: ${widget.plan.planName}');
      debugPrint('   日期: ${widget.selectedDay.dayOfWeek}');
      debugPrint('   動作數: ${widget.selectedDay.exercises.length}');
      debugPrint('   planId: ${widget.plan.id}');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  PlannedExercise get _currentExercise =>
      widget.selectedDay.exercises[_currentExerciseIndex];

  List<ExerciseSetRecord> get _currentRecords =>
      _exerciseRecords[_currentExerciseIndex] ?? [];

  int get _completedExercisesCount =>
      _exerciseRecords.values.where((records) => records.isNotEmpty).length;

  /// 開始/暫停總計時器
  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
      setState(() => _isRunning = true);
    }
  }

  /// 重置總計時器
  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 0;
      _isRunning = false;
    });
  }

  /// 開始休息計時
  void _startRest({int seconds = 60}) {
    setState(() {
      _isResting = true;
      _restSeconds = seconds;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() => _restSeconds--);
      } else {
        _completeRest();
      }
    });
  }

  /// 增加休息時間
  void _addRestTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
    });
  }

  /// 完成休息
  void _completeRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
    // 可以添加音效提示
  }

  /// 跳過休息
  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  /// 添加當前動作的一組記錄
  void _addSet() {
    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      _showSnackBar('請輸入有效的次數');
      return;
    }

    final weight = _weightController.text.isNotEmpty
        ? double.tryParse(_weightController.text)
        : null;

    setState(() {
      _currentRecords.add(ExerciseSetRecord(
        setNumber: _currentRecords.length + 1,
        reps: reps,
        weight: weight,
      ));
      _repsController.clear();
      _weightController.clear();
    });

    _showSnackBar('已新增第 ${_currentRecords.length} 組');

    // 如果還有組數要做,開始休息
    final targetSets = _currentExercise.sets ?? 3;
    if (_currentRecords.length < targetSets) {
      _startRest(seconds: 60);
    }
  }

  /// 刪除某組記錄
  void _removeSet(int index) {
    setState(() {
      _currentRecords.removeAt(index);
      // 重新編號
      for (int i = 0; i < _currentRecords.length; i++) {
        _currentRecords[i] = _currentRecords[i].copyWith(setNumber: i + 1);
      }
    });
    _showSnackBar('已刪除組數');
  }

  /// 切換到下一個動作
  void _nextExercise() {
    if (_currentExerciseIndex < widget.selectedDay.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
      _showSnackBar('切換到: ${_currentExercise.name}');
    } else {
      _showSnackBar('已經是最後一個動作');
    }
  }

  /// 切換到上一個動作
  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
      });
      _showSnackBar('返回到: ${_currentExercise.name}');
    }
  }

  /// 完成整個訓練
  Future<void> _completeWorkout() async {
    // 檢查是否有記錄
    if (_completedExercisesCount == 0 && _seconds == 0) {
      _showSnackBar('請至少完成一個動作或使用計時器');
      return;
    }

    // 確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('完成訓練'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '確定要完成「${widget.selectedDay.dayOfWeek}」的訓練嗎？',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ 已完成 $_completedExercisesCount/${widget.selectedDay.exercises.length} 個動作'),
                  Text('⏱️ 訓練時長：${_formatDuration(_seconds)}'),
                  const Text(
                    '📋 此訓練將計入計畫進度',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            ),
            child: const Text('確定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      // 保存每個已完成的動作
      for (int i = 0; i < widget.selectedDay.exercises.length; i++) {
        final records = _exerciseRecords[i] ?? [];
        if (records.isEmpty) continue;

        final exercise = widget.selectedDay.exercises[i];
        
        // 計算平均重量和總次數
        double? avgWeight;
        int totalReps = 0;

        if (records.isNotEmpty) {
          final weights =
              records.where((s) => s.weight != null).map((s) => s.weight!).toList();
          if (weights.isNotEmpty) {
            avgWeight = weights.reduce((a, b) => a + b) / weights.length;
          }
          totalReps = records.map((s) => s.reps).reduce((a, b) => a + b);
        }

        final avgReps = records.isNotEmpty 
            ? (totalReps / records.length).round() 
            : 0;

        // 保存記錄,帶上 planId
        await _workoutService.addWorkoutLog(
          type: _mapCategoryToType(exercise.type),
          name: exercise.name,
          duration: (_seconds / widget.selectedDay.exercises.length / 60).ceil(), // 平均分配時間
          sets: records.length,
          reps: avgReps,
          weight: avgWeight,
          notes: _notesController.text.trim().isNotEmpty
              ? '${exercise.name}: ${_notesController.text.trim()}'
              : null,
          planId: widget.plan.id, // ✅ 關鍵：傳入 planId
        );

        if (kDebugMode) {
          debugPrint('✅ 已保存: ${exercise.name} (${records.length}組)');
        }
      }

      if (!mounted) return;

      _showSnackBar('訓練記錄已保存並計入計畫進度');
      Navigator.pop(context, true); // 返回並標記完成
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 保存訓練失敗: $e');
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackBar('保存失敗，請重試');
    }
  }

  /// 映射類型
  String _mapCategoryToType(String type) {
    switch (type.toLowerCase()) {
      case 'cardio':
      case '有氧':
        return 'cardio';
      case 'yoga':
      case '瑜伽':
        return 'yoga';
      case 'stretching':
      case '伸展':
        return 'stretching';
      default:
        return 'weight_training';
    }
  }

  /// 格式化時長
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (_completedExercisesCount > 0 || _seconds > 0) {
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認離開'),
                  content: const Text('你有未保存的訓練記錄，確定要離開嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('離開'),
                    ),
                  ],
                ),
              );

              if (!mounted) return;
              if (shouldExit == true) {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan.planName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '📋 計畫訓練',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : Column(
              children: [
                // 進度條
                _buildProgressBar(),

                // 主要內容
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 當前動作卡片
                        _buildCurrentExerciseCard(),

                        const SizedBox(height: 16),

                        // 休息計時器
                        if (_isResting) _buildRestTimer(),

                        const SizedBox(height: 16),

                        // 總計時器
                        _buildTotalTimer(),

                        const SizedBox(height: 16),

                        // 組數記錄
                        _buildSetsCard(),

                        const SizedBox(height: 16),

                        // 動作導航
                        _buildExerciseNavigation(),

                        const SizedBox(height: 16),

                        // 備註
                        _buildNotesCard(),
                      ],
                    ),
                  ),
                ),

                // 底部按鈕
                _buildBottomButtons(),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    double progress = widget.selectedDay.exercises.isEmpty
        ? 0
        : _completedExercisesCount / widget.selectedDay.exercises.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '訓練進度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_completedExercisesCount/${widget.selectedDay.exercises.length} 完成',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentExerciseCard() {
    IconData icon;
    Color iconColor;

    switch (_currentExercise.type.toLowerCase()) {
      case 'weight_training':
      case '重量訓練':
        icon = Icons.fitness_center;
        iconColor = Colors.red;
        break;
      case 'cardio':
      case '有氧':
        icon = Icons.directions_run;
        iconColor = Colors.blue;
        break;
      case 'yoga':
      case '瑜伽':
        icon = Icons.self_improvement;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.sports;
        iconColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '動作 ${_currentExerciseIndex + 1}/${widget.selectedDay.exercises.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              if (_currentRecords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentRecords.length}組完成',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            _currentExercise.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              if (_currentExercise.sets != null)
                _buildDetailChip('${_currentExercise.sets} 組', Icons.repeat),
              if (_currentExercise.reps != null)
                _buildDetailChip('${_currentExercise.reps} 次', Icons.loop),
              if (_currentExercise.duration != null)
                _buildDetailChip('${_currentExercise.duration} 分', Icons.timer),
            ],
          ),
          if (_currentExercise.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentExercise.notes!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    int minutes = _restSeconds ~/ 60;
    int seconds = _restSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[200]!, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, color: Colors.blue[700], size: 28),
              const SizedBox(width: 12),
              const Text(
                '休息時間',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeButton('+10秒', 10),
              const SizedBox(width: 12),
              _buildTimeButton('+30秒', 30),
              const SizedBox(width: 12),
              _buildTimeButton('跳過', 0, isSkip: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, int seconds, {bool isSkip = false}) {
    return ElevatedButton(
      onPressed: () {
        if (isSkip) {
          _skipRest();
        } else {
          _addRestTime(seconds);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSkip ? Colors.orange : Colors.blue[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTotalTimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                '總訓練時間',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? '暫停' : '開始'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetsCard() {
    return Container(
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
                Icon(Icons.format_list_numbered,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '組數記錄',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${_currentRecords.length} 組',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 組數列表
          if (_currentRecords.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentRecords.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final set = _currentRecords[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: Text(
                      '${set.setNumber}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${set.reps} 次${set.weight != null ? ' @ ${set.weight}kg' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeSet(index),
                  ),
                );
              },
            ),
            const Divider(height: 1),
          ],

          // 新增組數表單
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '次數 *',
                          hintText: _currentExercise.reps != null
                              ? '建議：${_currentExercise.reps}'
                              : '例：10',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '重量 (kg)',
                          hintText: '例：20',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add),
                    label: const Text('新增組數'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildExerciseNavigation() {
    return Container(
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
          Text(
            '動作導航',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentExerciseIndex > 0 ? _previousExercise : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('上一個'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentExerciseIndex <
                          widget.selectedDay.exercises.length - 1
                      ? _nextExercise
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('下一個'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
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
              Icon(Icons.note_alt, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '訓練備註',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '記錄今日訓練的感受或特殊情況...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    bool canComplete = _completedExercisesCount > 0 || _seconds > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.grey, width: 2),
              ),
              child: const Text(
                '暫停訓練',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canComplete ? _completeWorkout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: canComplete ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    canComplete ? '完成訓練' : '請完成至少一個動作',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 動作組數記錄模型
class ExerciseSetRecord {
  final int setNumber;
  final int reps;
  final double? weight;

  ExerciseSetRecord({
    required this.setNumber,
    required this.reps,
    this.weight,
  });

  ExerciseSetRecord copyWith({
    int? setNumber,
    int? reps,
    double? weight,
  }) {
    return ExerciseSetRecord(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
    );
  }
}