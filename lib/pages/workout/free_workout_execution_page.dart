// lib/pages/workout/free_workout_execution_page.dart
// 🔥 自由訓練執行頁面 - 完全符合 PDF 規範
// 核心原則：一個焦點、狀態機驅動、自動流轉

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/workout_service.dart';

class FreeWorkoutExecutionPage extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;

  const FreeWorkoutExecutionPage({
    super.key,
    required this.exercises,
  });

  @override
  State<FreeWorkoutExecutionPage> createState() =>
      _FreeWorkoutExecutionPageState();
}

class _FreeWorkoutExecutionPageState extends State<FreeWorkoutExecutionPage> {
  final _service = WorkoutService();
  late String _sessionId;
  
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0; // 🔥 當前焦點組
  
  bool _loading = true;
  bool _isResting = false;
  int _remainingRestTime = 0;
  Timer? _restTimer;
  
  // 用於記錄當前組的數據
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  
  // 追蹤各組狀態 (exerciseIndex -> setIndex -> status)
  Map<int, Map<int, String>> _setStatuses = {};
  
  @override
  void initState() {
    super.initState();
    _initializeStatuses();
    _boot();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // 初始化所有組狀態為 pending
  void _initializeStatuses() {
    for (int i = 0; i < widget.exercises.length; i++) {
      _setStatuses[i] = {};
      final sets = widget.exercises[i]['plannedSets'] ?? 1;
      for (int s = 0; s < sets; s++) {
        _setStatuses[i]![s] = 'pending';
      }
    }
  }

  Future<void> _boot() async {
    try {
      _sessionId = await _service.startAdHocSession(
        exercises: widget.exercises,
      );
      setState(() => _loading = false);
    } catch (e) {
      _showSnackBar('啟動訓練失敗：$e', Colors.red);
      Navigator.pop(context);
    }
  }

  Map<String, dynamic> get currentExercise => 
      widget.exercises[_currentExerciseIndex];
  
  String get currentExerciseDocId => 'ex$_currentExerciseIndex';
  
  int get totalSets => currentExercise['plannedSets'] ?? 1;
  
  String get currentSetStatus => 
      _setStatuses[_currentExerciseIndex]?[_currentSetIndex] ?? 'pending';

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  // 🔥 開始當前組
  Future<void> _startCurrentSet() async {
    try {
      await _service.adHocStartSet(
        _sessionId,
        currentExerciseDocId,
        _currentSetIndex,
      );
      
      setState(() {
        _setStatuses[_currentExerciseIndex]![_currentSetIndex] = 'active';
      });
      
      HapticFeedback.lightImpact();
      _showSnackBar('開始第 ${_currentSetIndex + 1} 組', Colors.blue);
    } catch (e) {
      _showSnackBar('開始失敗：$e', Colors.red);
    }
  }

  // 🔥 完成當前組 → 立刻進入休息
  Future<void> _completeCurrentSet() async {
    try {
      final reps = int.tryParse(_repsController.text);
      final weight = double.tryParse(_weightController.text);

      // 立刻寫入 Firestore
      await _service.adHocCompleteSet(
        sessionId: _sessionId,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        reps: reps ?? currentExercise['plannedReps'],
        weight: weight,
      );

      setState(() {
        _setStatuses[_currentExerciseIndex]![_currentSetIndex] = 'resting';
      });

      _repsController.clear();
      _weightController.clear();
      
      HapticFeedback.mediumImpact();

      // 🔥 立刻開始休息計時
      _startRestTimer(currentExercise['restSec'] ?? 90);
      
    } catch (e) {
      _showSnackBar('完成失敗：$e', Colors.red);
    }
  }

  // 🔥 開始休息計時
  void _startRestTimer(int restSec) {
    setState(() {
      _isResting = true;
      _remainingRestTime = restSec;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingRestTime <= 0) {
        _endRest();
      } else {
        setState(() => _remainingRestTime -= 1);
      }
    });
  }

  // 🔥 結束休息 → 自動聚焦下一組或下一動作
  Future<void> _endRest() async {
    _restTimer?.cancel();
    
    try {
      final plannedRestSec = currentExercise['restSec'] ?? 90;
      final takenRestSec = plannedRestSec - _remainingRestTime;

      await _service.adHocEndRest(
        sessionId: _sessionId,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        restTakenSec: takenRestSec > 0 ? takenRestSec : plannedRestSec,
      );

      setState(() {
        _setStatuses[_currentExerciseIndex]![_currentSetIndex] = 'completed';
        _isResting = false;
      });

      HapticFeedback.mediumImpact();

      // 🔥 自動跳轉邏輯
      if (_currentSetIndex + 1 < totalSets) {
        // 還有下一組 → 聚焦下一組
        setState(() {
          _currentSetIndex += 1;
        });
        _showSnackBar('進入第 ${_currentSetIndex + 1} 組', Colors.green);
      } else {
        // 這個動作完成了
        if (_currentExerciseIndex + 1 < widget.exercises.length) {
          // 還有下一個動作 → 聚焦下一個動作的第 1 組
          setState(() {
            _currentExerciseIndex += 1;
            _currentSetIndex = 0;
          });
          _showSnackBar(
            '✅ 動作完成！進入下一個動作',
            Colors.green,
          );
        } else {
          // 🎉 所有動作完成
          _showFinishDialog();
        }
      }
    } catch (e) {
      _showSnackBar('休息結束失敗：$e', Colors.red);
      setState(() => _isResting = false);
    }
  }

  // 🔥 跳過休息
  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  // 🔥 延長休息
  void _addRestTime(int seconds) {
    setState(() {
      _remainingRestTime += seconds;
    });
  }

  // 🔥 完成訓練確認對話框
  Future<void> _showFinishDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 訓練完成'),
        content: const Text('所有動作已完成！要結束訓練嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('繼續'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('完成'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _finishWorkout();
    }
  }

  // 🔥 完成訓練
  Future<void> _finishWorkout() async {
    try {
      await _service.finishAdHocSession(sessionId: _sessionId);
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('完成失敗：$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('自由訓練'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔥 頂部：進度條
          _buildProgressHeader(),
          
          // 🔥 主體：當前焦點區域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 動作資訊
                  _buildExerciseInfo(),
                  
                  const SizedBox(height: 24),
                  
                  // 🔥 當前焦點組操作區（大按鈕）
                  if (!_isResting) _buildCurrentSetActionArea(),
                  
                  // 🔥 休息計時器（全屏顯示）
                  if (_isResting) _buildRestTimer(),
                  
                  const SizedBox(height: 24),
                  
                  // 所有組狀態列表（只顯示，不能操作）
                  _buildAllSetsStatus(),
                  
                  const SizedBox(height: 100), // 底部留白
                ],
              ),
            ),
          ),
          
          // 🔥 底部：完成訓練按鈕
          _buildBottomBar(),
        ],
      ),
    );
  }

  // 🔥 頂部進度
  Widget _buildProgressHeader() {
    final completedSets = _setStatuses[_currentExerciseIndex]!
        .values
        .where((s) => s == 'completed')
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 動作進度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 ${_currentExerciseIndex + 1} / ${widget.exercises.length} 個動作',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '第 ${_currentSetIndex + 1} / $totalSets 組',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalSets > 0 ? completedSets / totalSets : 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 動作資訊卡片
  Widget _buildExerciseInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
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
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 40,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          
          // 動作名稱
          Text(
            currentExercise['name'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // 目標
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '目標：${currentExercise['plannedReps']} 次 × $totalSets 組',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 當前焦點組操作區（大按鈕）
  Widget _buildCurrentSetActionArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 當前組標題
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_currentSetIndex + 1}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '當前組',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 輸入欄位
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _repsController,
                  decoration: InputDecoration(
                    labelText: '實際次數',
                    hintText: '${currentExercise['plannedReps']}',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: '重量 (kg)',
                    hintText: '選填',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 🔥 主要操作按鈕（大按鈕）
          if (currentSetStatus == 'pending')
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _startCurrentSet,
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text(
                  '開始這組',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          
          if (currentSetStatus == 'active')
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _completeCurrentSet,
                icon: const Icon(Icons.check_circle, size: 28),
                label: const Text(
                  '完成這組',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 休息計時器（全屏顯示）
  Widget _buildRestTimer() {
    final minutes = _remainingRestTime ~/ 60;
    final seconds = _remainingRestTime % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue, width: 3),
      ),
      child: Column(
        children: [
          const Icon(Icons.timer, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            '休息中',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 24),
          
          // 大大的倒數計時
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              height: 1,
            ),
          ),
          const SizedBox(height: 32),
          
          // 操作按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _addRestTime(30),
                icon: const Icon(Icons.add),
                label: const Text('+30秒'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _skipRest,
                icon: const Icon(Icons.skip_next),
                label: const Text('跳過'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 所有組狀態列表（只顯示標籤）
  Widget _buildAllSetsStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '組數進度',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(totalSets, (index) {
              final status = _setStatuses[_currentExerciseIndex]![index] ?? 'pending';
              final isCurrent = index == _currentSetIndex;
              
              Color color;
              IconData icon;
              
              switch (status) {
                case 'completed':
                  color = Colors.green;
                  icon = Icons.check_circle;
                  break;
                case 'active':
                  color = Colors.blue;
                  icon = Icons.play_circle;
                  break;
                case 'resting':
                  color = Colors.orange;
                  icon = Icons.timer;
                  break;
                default:
                  color = Colors.grey.shade300;
                  icon = Icons.radio_button_unchecked;
              }
              
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isCurrent ? color : color.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: isCurrent 
                      ? Border.all(color: color, width: 3)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isCurrent ? Colors.white : color,
                      size: isCurrent ? 24 : 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 🔥 底部按鈕
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 離開按鈕
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('確認離開'),
                      content: const Text('訓練尚未完成，確定要離開嗎？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('離開'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    Navigator.pop(context);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
                child: const Text('離開'),
              ),
            ),
            const SizedBox(width: 16),
            
            // 完成訓練按鈕
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _showFinishDialog,
                icon: const Icon(Icons.check_circle),
                label: const Text('完成訓練'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}