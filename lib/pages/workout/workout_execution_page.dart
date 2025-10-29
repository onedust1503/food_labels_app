// lib/pages/workout/workout_execution_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';

/// 訓練執行頁面 - 互動式訓練模式
/// 提供即時記錄、組間計時、自動日誌生成
class WorkoutExecutionPage extends StatefulWidget {
  final WorkoutPlanModel workoutPlan;
  final WorkoutPlanDay selectedDay;

  const WorkoutExecutionPage({
    super.key,
    required this.workoutPlan,
    required this.selectedDay,
  });

  @override
  State<WorkoutExecutionPage> createState() => _WorkoutExecutionPageState();
}

class _WorkoutExecutionPageState extends State<WorkoutExecutionPage> {
  final WorkoutService _workoutService = WorkoutService();
  final PageController _pageController = PageController();
  
  int _currentExerciseIndex = 0;
  bool _isWorkoutStarted = false;
  bool _isRestMode = false;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;
  
  // 記錄每個動作的完成數據
  late List<ExerciseProgress> _exerciseProgressList;
  
  DateTime? _workoutStartTime;
  DateTime? _workoutEndTime;

  @override
  void initState() {
    super.initState();
    _initializeProgressTracking();
  }

  void _initializeProgressTracking() {
    _exerciseProgressList = widget.selectedDay.exercises.map((exercise) {
      int totalSets = exercise.sets ?? 3;
      return ExerciseProgress(
        exercise: exercise,
        completedSets: List.generate(totalSets, (index) => SetData()),
      );
    }).toList();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startWorkout() {
    setState(() {
      _isWorkoutStarted = true;
      _workoutStartTime = DateTime.now();
    });
  }

  void _finishWorkout() async {
    setState(() {
      _workoutEndTime = DateTime.now();
    });

    // 顯示總結並儲存
    await _showWorkoutSummary();
  }

  Future<void> _showWorkoutSummary() async {
    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0;

    for (var progress in _exerciseProgressList) {
      for (var set in progress.completedSets) {
        if (set.isCompleted) {
          totalSets++;
          totalReps += set.reps ?? 0;
          totalVolume += (set.weight ?? 0) * (set.reps ?? 0);
        }
      }
    }

    int durationMinutes = _workoutEndTime!.difference(_workoutStartTime!).inMinutes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🎉 訓練完成！',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('訓練時長', '$durationMinutes 分鐘'),
            _buildSummaryRow('完成組數', '$totalSets 組'),
            _buildSummaryRow('總次數', '$totalReps 次'),
            _buildSummaryRow('總訓練量', '${totalVolume.toStringAsFixed(1)} kg'),
            const SizedBox(height: 16),
            const Text(
              '繼續保持，你做得很棒！💪',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // TODO: 儲存訓練記錄到 Firebase
              await _saveWorkoutLog();
              if (mounted) {
                Navigator.of(context).pop(); // 關閉對話框
                Navigator.of(context).pop(); // 返回上一頁
              }
            },
            child: const Text('完成', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkoutLog() async {
    // TODO: 實作儲存到 Firebase
    // 將 _exerciseProgressList 的數據儲存到 workoutLogs collection
  }

  void _startRestTimer(int seconds) {
    setState(() {
      _isRestMode = true;
      _restSecondsRemaining = seconds;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSecondsRemaining > 0) {
          _restSecondsRemaining--;
        } else {
          _isRestMode = false;
          timer.cancel();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isRestMode = false;
      _restSecondsRemaining = 0;
    });
  }

  void _moveToNextExercise() {
    if (_currentExerciseIndex < widget.selectedDay.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _pageController.animateToPage(
          _currentExerciseIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    } else {
      _finishWorkout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWorkoutStarted) {
      return _buildPreWorkoutScreen();
    }

    if (_isRestMode) {
      return _buildRestScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_currentExerciseIndex + 1}/${widget.selectedDay.exercises.length}',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('結束訓練？'),
                  content: const Text('確定要結束今天的訓練嗎？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('繼續訓練'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('結束'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.selectedDay.exercises.length,
        onPageChanged: (index) {
          setState(() {
            _currentExerciseIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _buildExerciseCard(_exerciseProgressList[index]);
        },
      ),
    );
  }

  Widget _buildPreWorkoutScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutPlan.planName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日訓練',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${widget.selectedDay.exercises.length} 個動作',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: widget.selectedDay.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = widget.selectedDay.exercises[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        exercise.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${exercise.sets} 組 × ${exercise.reps} 次',
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _startWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '開始訓練',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestScreen() {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '休息時間',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$_restSecondsRemaining',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _skipRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text(
                '跳過休息',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseProgress progress) {
    PlannedExercise exercise = progress.exercise;
    int currentSet = progress.currentSetIndex();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 動作名稱
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exercise.type,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (exercise.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.notes!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),

          // 組數進度
          const Text(
            '完成進度',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 組數列表
          ...List.generate(progress.completedSets.length, (setIndex) {
            return _buildSetRow(
              progress,
              setIndex,
              currentSet == setIndex,
            );
          }),

          const SizedBox(height: 32),

          // 完成按鈕
          if (currentSet < progress.completedSets.length)
            _buildActionButton(progress, currentSet)
          else
            _buildNextExerciseButton(),
        ],
      ),
    );
  }

  Widget _buildSetRow(ExerciseProgress progress, int setIndex, bool isCurrent) {
    SetData setData = progress.completedSets[setIndex];
    bool isCompleted = setData.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.shade50
            : (isCurrent ? Colors.orange.shade50 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green
              : (isCurrent ? Colors.orange : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // 組數標記
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted ? Colors.green : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${setIndex + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // 重量輸入
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '重量 (kg)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (!isCompleted && isCurrent)
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      setData.weight = double.tryParse(value);
                    },
                  )
                else
                  Text(
                    setData.weight?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 次數輸入
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '次數',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (!isCompleted && isCurrent)
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      setData.reps = int.tryParse(value);
                    },
                  )
                else
                  Text(
                    setData.reps?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ExerciseProgress progress, int currentSet) {
    SetData currentSetData = progress.completedSets[currentSet];

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          if (currentSetData.weight == null || currentSetData.reps == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請輸入重量和次數')),
            );
            return;
          }

          setState(() {
            currentSetData.isCompleted = true;
          });

          // 如果還有下一組，開始休息計時
          if (currentSet < progress.completedSets.length - 1) {
            _startRestTimer(90); // 預設休息 90 秒
          } else {
            // 本動作已完成所有組數
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('本動作已完成！'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          currentSet < progress.completedSets.length - 1
              ? '完成第 ${currentSet + 1} 組'
              : '完成動作',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNextExerciseButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _moveToNextExercise,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _currentExerciseIndex == widget.selectedDay.exercises.length - 1
              ? '完成訓練'
              : '下一個動作',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ========== 數據模型 ==========

class ExerciseProgress {
  final PlannedExercise exercise;
  final List<SetData> completedSets;

  ExerciseProgress({
    required this.exercise,
    required this.completedSets,
  });

  int currentSetIndex() {
    for (int i = 0; i < completedSets.length; i++) {
      if (!completedSets[i].isCompleted) {
        return i;
      }
    }
    return completedSets.length; // 全部完成
  }

  bool isFullyCompleted() {
    return completedSets.every((set) => set.isCompleted);
  }
}

class SetData {
  double? weight;
  int? reps;
  bool isCompleted;

  SetData({
    this.weight,
    this.reps,
    this.isCompleted = false,
  });
}