// lib/pages/workout/workout_single_execution_page.dart
// 🎯 單個運動執行頁面 - 用於從運動選擇頁面啟動的訓練
// ✅ 支援單個動作的完整訓練流程

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/wger_api_service.dart';
import '../../services/unified_workout_service.dart';

class WorkoutSingleExecutionPage extends StatefulWidget {
  final Exercise exercise;
  final bool isCoach;
  final String? traineeId;
  final String? planId;

  const WorkoutSingleExecutionPage({
    super.key,
    required this.exercise,
    required this.isCoach,
    this.traineeId,
    this.planId,
  });

  @override
  State<WorkoutSingleExecutionPage> createState() =>
      _WorkoutSingleExecutionPageState();
}

class _WorkoutSingleExecutionPageState
    extends State<WorkoutSingleExecutionPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();

  // 計時器相關
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;

  // 休息計時器
  Timer? _restTimer;
  int _restSeconds = 60;
  bool _isResting = false;

  // 組數記錄
  final List<ExerciseSetRecord> _setRecords = [];

  // 輸入控制器
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('🎯 開始單個運動訓練:');
      debugPrint('   運動: ${widget.exercise.nameZhTw}');
      if (widget.planId != null) {
        debugPrint('   計劃ID: ${widget.planId}');
      }
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
  }

  /// 跳過休息
  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  /// 添加一組記錄
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
      _setRecords.add(ExerciseSetRecord(
        setNumber: _setRecords.length + 1,
        reps: reps,
        weight: weight,
      ));
      _repsController.clear();
      _weightController.clear();
    });

    _showSnackBar('已新增第 ${_setRecords.length} 組');

    // 自動開始休息
    if (_setRecords.length < 5) {
      // 假設最多5組
      _startRest(seconds: 60);
    }
  }

  /// 刪除某組記錄
  void _removeSet(int index) {
    setState(() {
      _setRecords.removeAt(index);
      // 重新編號
      for (int i = 0; i < _setRecords.length; i++) {
        _setRecords[i] = _setRecords[i].copyWith(setNumber: i + 1);
      }
    });
    _showSnackBar('已刪除組數');
  }

  /// 完成訓練
  Future<void> _completeWorkout() async {
    // 檢查是否有記錄
    if (_setRecords.isEmpty && _seconds == 0) {
      _showSnackBar('請至少完成一組或使用計時器');
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
              '確定要完成「${widget.exercise.nameZhTw}」的訓練嗎？',
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
                  Text('✅ 完成 ${_setRecords.length} 組'),
                  Text('⏱️ 訓練時長：${_formatDuration(_seconds)}'),
                  if (widget.planId != null)
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
      // 計算平均值
      double? avgWeight;
      int totalReps = 0;

      if (_setRecords.isNotEmpty) {
        final weights =
            _setRecords.where((s) => s.weight != null).map((s) => s.weight!).toList();
        if (weights.isNotEmpty) {
          avgWeight = weights.reduce((a, b) => a + b) / weights.length;
        }
        totalReps = _setRecords.map((s) => s.reps).reduce((a, b) => a + b);
      }

      final avgReps =
          _setRecords.isNotEmpty ? (totalReps / _setRecords.length).round() : 0;

      // 使用實際時長，如果沒有計時則估算（每組1分鐘）
      int duration = _seconds > 0 ? (_seconds / 60).ceil() : _setRecords.length;

      // 保存記錄
      await _workoutService.addWorkoutLog(
        type: _mapCategoryToType(widget.exercise.category),
        name: widget.exercise.nameZhTw,
        duration: duration,
        sets: _setRecords.length,
        reps: avgReps,
        weight: avgWeight,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        planId: widget.planId, // ✅ 傳入 planId（如果有）
      );

      if (!mounted) return;

      _showSnackBar('訓練記錄已保存');
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

  /// 映射分類到類型
  String _mapCategoryToType(String category) {
    switch (category.toLowerCase()) {
      case '有氧':
        return 'cardio';
      case '瑜伽':
        return 'yoga';
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
            if (_setRecords.isNotEmpty || _seconds > 0) {
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
              widget.exercise.nameZhTw,
              style: const TextStyle(
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
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 運動資訊卡片
                  _buildExerciseInfoCard(),

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

                  // 備註
                  _buildNotesCard(),

                  const SizedBox(height: 80), // 留空間給底部按鈕
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildExerciseInfoCard() {
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
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 圖示
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getCategoryIcon(widget.exercise.category),
              size: 48,
              color: _getCategoryColor(widget.exercise.category),
            ),
          ),
          const SizedBox(height: 16),

          // 運動名稱
          Text(
            widget.exercise.nameZhTw,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 分類標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.exercise.category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 肌肉群
          if (widget.exercise.muscles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: widget.exercise.muscles.take(3).map((muscle) {
                return Chip(
                  label: Text(
                    muscle,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
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
            color: Colors.blue.withOpacity(0.3),
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
                  '共 ${_setRecords.length} 組',
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
          if (_setRecords.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _setRecords.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final set = _setRecords[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
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
                          hintText: '例：10',
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

  Widget _buildNotesCard() {
    return Container(
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
    bool canComplete = _setRecords.isNotEmpty || _seconds > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
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
                  '取消',
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
                      canComplete ? '完成訓練' : '請至少完成一組',
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
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '胸部':
        return Icons.fitness_center;
      case '背部':
        return Icons.beach_access;
      case '腿部':
        return Icons.directions_run;
      case '肩膀':
        return Icons.accessibility_new;
      case '手臂':
        return Icons.front_hand;
      case '腹肌':
        return Icons.boy;
      case '有氧':
        return Icons.directions_bike;
      default:
        return Icons.sports_gymnastics;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部':
        return Colors.red;
      case '背部':
        return Colors.blue;
      case '腿部':
        return Colors.orange;
      case '肩膀':
        return Colors.purple;
      case '手臂':
        return Colors.green;
      case '腹肌':
        return Colors.teal;
      case '有氧':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}

/// 組數記錄模型
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