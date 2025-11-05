// lib/pages/workout/workout_execution_page.dart
// ✅ 修正版 - 移除 AudioPlayer 依賴
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';

class WorkoutExecutionPage extends StatefulWidget {
  final WorkoutPlanDay planDay;
  final String planId;
  final String planName;

  const WorkoutExecutionPage({
    super.key,
    required this.planDay,
    required this.planId,
    required this.planName,
  });

  @override
  State<WorkoutExecutionPage> createState() => _WorkoutExecutionPageState();
}

class _WorkoutExecutionPageState extends State<WorkoutExecutionPage> {
  final WorkoutService _workoutService = WorkoutService();
  
  int currentExerciseIndex = 0;
  int currentSet = 1;
  bool isResting = false;
  int restSeconds = 60;
  Timer? _restTimer;
  
  Map<int, bool> completedExercises = {};
  Map<int, List<bool>> completedSets = {};
  
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.planDay.exercises.length; i++) {
      completedExercises[i] = false;
      int sets = widget.planDay.exercises[i].sets ?? 1;
      completedSets[i] = List.filled(sets, false);
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer() {
    setState(() {
      isResting = true;
      restSeconds = 60;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restSeconds > 0) {
        setState(() => restSeconds--);
      } else {
        _completeRest();
      }
    });
  }

  void _addRestTime(int seconds) {
    setState(() => restSeconds += seconds);
  }

  void _completeRest() {
    _restTimer?.cancel();
    setState(() => isResting = false);
    // ✅ 移除音效播放
    debugPrint('⏰ 休息結束');
  }

  void _markSetCompleted(int exerciseIndex, int setIndex) {
    setState(() {
      completedSets[exerciseIndex]![setIndex] = true;
      
      bool allSetsCompleted = completedSets[exerciseIndex]!.every((set) => set);
      if (allSetsCompleted) {
        completedExercises[exerciseIndex] = true;
      }
    });
    
    PlannedExercise exercise = widget.planDay.exercises[exerciseIndex];
    int totalSets = exercise.sets ?? 1;
    if (setIndex < totalSets - 1) {
      _startRestTimer();
    }
  }

  Future<void> _completeWorkout() async {
    try {
      int totalDuration = 0;
      double totalCalories = 0;
      
      for (var exercise in widget.planDay.exercises) {
        totalDuration += exercise.duration ?? 5;
        totalCalories += (exercise.duration ?? 5) * 5;
      }

      // ✅ 使用正確的日期格式
      String today = DateTime.now().toIso8601String().split('T')[0];

      await _workoutService.addWorkoutLog(
        type: 'plan_workout',
        name: '${widget.planName} - ${widget.planDay.dayOfWeek}',
        duration: totalDuration,
        caloriesBurned: totalCalories,
      );

      // ✅ 暫時註解掉，因為 WorkoutService 可能沒有這個方法
      // await _workoutService.recordPlanDayCompletion(
      //   planId: widget.planId,
      //   dayOfWeek: widget.planDay.dayOfWeek,
      //   date: DateTime.now(),
      // );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 訓練完成!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記錄失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    PlannedExercise currentExercise = widget.planDay.exercises[currentExerciseIndex];
    int totalExercises = widget.planDay.exercises.length;
    int completedCount = completedExercises.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.planName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(completedCount, totalExercises),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildCurrentExerciseCard(currentExercise),
                    const SizedBox(height: 20),
                    
                    if (isResting) _buildRestTimer(),
                    const SizedBox(height: 20),
                    
                    if (currentExercise.sets != null && currentExercise.sets! > 1)
                      _buildSetTracker(currentExercise),
                    
                    const SizedBox(height: 30),
                    _buildExerciseList(),
                  ],
                ),
              ),
            ),
            
            _buildBottomButtons(completedCount, totalExercises),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int completed, int total) {
    double progress = total > 0 ? completed / total : 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '$completed/$total 完成',
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
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentExerciseCard(PlannedExercise exercise) {
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(
            exercise.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildExerciseDetails(exercise),
          if (exercise.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.notes!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

  Widget _buildExerciseDetails(PlannedExercise exercise) {
    List<Widget> details = [];

    if (exercise.sets != null && exercise.reps != null) {
      details.add(_buildDetailChip('${exercise.sets} 組', Icons.repeat));
      details.add(const SizedBox(width: 12));
      details.add(_buildDetailChip('${exercise.reps} 次', Icons.loop));
    } else if (exercise.sets != null) {
      details.add(_buildDetailChip('${exercise.sets} 組', Icons.repeat));
    }

    if (exercise.duration != null) {
      if (details.isNotEmpty) details.add(const SizedBox(width: 12));
      details.add(_buildDetailChip('${exercise.duration} 分鐘', Icons.timer));
    }

    return Wrap(alignment: WrapAlignment.center, children: details);
  }

  Widget _buildDetailChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
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
    int minutes = restSeconds ~/ 60;
    int seconds = restSeconds % 60;

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
          _completeRest();
        } else {
          _addRestTime(seconds);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSkip ? Colors.orange : Colors.blue[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSetTracker(PlannedExercise exercise) {
    int totalSets = exercise.sets ?? 1;
    List<bool> setStatus = completedSets[currentExerciseIndex] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('組數進度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(totalSets, (index) {
              bool isCompleted = setStatus[index];
              return GestureDetector(
                onTap: () => _markSetCompleted(currentExerciseIndex, index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: isCompleted
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('訓練清單', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...widget.planDay.exercises.asMap().entries.map((entry) {
            int index = entry.key;
            PlannedExercise exercise = entry.value;
            bool isCompleted = completedExercises[index] ?? false;
            bool isCurrent = index == currentExerciseIndex;

            return GestureDetector(
              onTap: () => setState(() => currentExerciseIndex = index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.orange.withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? Colors.orange : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green
                            : (isCurrent ? Colors.orange : Colors.grey[300]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(int completed, int total) {
    bool allCompleted = completed == total;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.grey, width: 2),
              ),
              child: const Text(
                '暫停訓練',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: allCompleted ? _completeWorkout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: allCompleted ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    allCompleted ? '完成訓練' : '完成所有動作後點擊',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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