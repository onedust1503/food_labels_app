// lib/pages/workout/free_workout_execution_page_v3.dart
// 🔥 自由訓練執行頁 - 完全符合 FitFit 邏輯
// ✅ 修正版 - 新增組數時同步到 Firestore

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _FreeWorkoutExecutionPageState extends State<FreeWorkoutExecutionPage>
    with TickerProviderStateMixin {
  final _service = WorkoutService();
  late String _sessionId;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  bool _loading = true;
  bool _isResting = false;
  int _remainingRestTime = 0;
  Timer? _restTimer;

  // 🔥 總計時器
  DateTime? _sessionStartTime;
  int _totalElapsedSeconds = 0;
  Timer? _totalTimer;

  // 組內計時器 (TUT)
  bool _isSetActive = false;
  int _setElapsedTime = 0;
  Timer? _setTimer;

  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  // 🔥 不預設組數 - 動態結構
  // Map<exerciseIndex, List<SetData>>
  Map<int, List<SetData>> _exerciseSets = {};

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initializeEmptySets();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _boot();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _setTimer?.cancel();
    _totalTimer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // 🔥 初始化為空組數
  void _initializeEmptySets() {
    for (int i = 0; i < widget.exercises.length; i++) {
      _exerciseSets[i] = []; // 空的,沒有任何組
    }
  }

  Future<void> _boot() async {
    try {
      _sessionId = await _service.startAdHocSession(
        exercises: widget.exercises,
      );
      
      // 🔥 啟動總計時
      _sessionStartTime = DateTime.now();
      _startTotalTimer();
      
      setState(() => _loading = false);
    } catch (e) {
      _showSnackBar('啟動訓練失敗：$e', Colors.red);
      Navigator.pop(context);
    }
  }

  // 🔥 開始總計時
  void _startTotalTimer() {
    _totalTimer?.cancel();
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _sessionStartTime != null) {
        setState(() {
          _totalElapsedSeconds =
              DateTime.now().difference(_sessionStartTime!).inSeconds;
        });
      }
    });
  }

  Map<String, dynamic> get currentExercise =>
      widget.exercises[_currentExerciseIndex];

  String get currentExerciseDocId => 'ex$_currentExerciseIndex';

  // 🔥 當前動作的總組數(動態)
  int get currentTotalSets => _exerciseSets[_currentExerciseIndex]?.length ?? 0;

  SetData? get currentSet {
    if (currentTotalSets == 0) return null;
    if (_currentSetIndex >= currentTotalSets) return null;
    return _exerciseSets[_currentExerciseIndex]![_currentSetIndex];
  }

  String get currentSetStatus => currentSet?.status ?? 'none';

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // 🔥 新增一組(永遠加在最後) - ✅ 修正版:同步到 Firestore
  Future<void> _addNewSet() async {
    try {
      // 1. 先在前端新增
      final newIndex = currentTotalSets;
      
      setState(() {
        _exerciseSets[_currentExerciseIndex]!.add(SetData(
          index: newIndex,
          status: 'pending',
        ));
      });

      // 2. ✅ 同步到 Firestore
      await _service.adHocAddSet(
        sessionId: _sessionId,
        exerciseDocId: currentExerciseDocId,
        targetReps: 10,  // 預設 10 次,可以修改
      );

      // 3. 如果是第一組,自動聚焦
      if (currentTotalSets == 1) {
        setState(() {
          _currentSetIndex = 0;
        });
      }

      _showSnackBar('已新增第 $currentTotalSets 組', const Color(0xFF3B82F6));
      HapticFeedback.lightImpact();
    } catch (e) {
      _showSnackBar('新增失敗：$e', Colors.red);
      
      // 失敗時回滾前端狀態
      setState(() {
        if (_exerciseSets[_currentExerciseIndex]!.isNotEmpty) {
          _exerciseSets[_currentExerciseIndex]!.removeLast();
        }
      });
    }
  }

  // 🔥 開始當前組
  Future<void> _startCurrentSet() async {
    if (currentSet == null) return;

    try {
      await _service.adHocStartSet(
        _sessionId,
        currentExerciseDocId,
        _currentSetIndex,
      );

      setState(() {
        currentSet!.status = 'active';
        _isSetActive = true;
        _setElapsedTime = 0;
      });

      _startSetTimer();

      HapticFeedback.lightImpact();
      _showSnackBar(
          '開始第 ${_currentSetIndex + 1} 組', const Color(0xFF6C63FF));
    } catch (e) {
      _showSnackBar('開始失敗：$e', Colors.red);
    }
  }

  void _startSetTimer() {
    _setTimer?.cancel();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isSetActive) {
        setState(() => _setElapsedTime += 1);
      }
    });
  }

  // 🔥 完成當前組
  Future<void> _completeCurrentSet() async {
    if (currentSet == null) return;

    try {
      final reps = int.tryParse(_repsController.text);
      final weight = double.tryParse(_weightController.text);

      _setTimer?.cancel();
      setState(() => _isSetActive = false);

      await _service.adHocCompleteSet(
        sessionId: _sessionId,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        reps: reps ?? 10,
        weight: weight,
      );

      setState(() {
        currentSet!.status = 'resting';
        currentSet!.reps = reps;
        currentSet!.weight = weight;
      });

      _repsController.clear();
      _weightController.clear();

      HapticFeedback.mediumImpact();

      // 🔥 開始休息
      _startRestTimer(currentExercise['restSec'] ?? 90);
    } catch (e) {
      _showSnackBar('完成失敗：$e', Colors.red);
    }
  }

  // 🔥 略過當前組
  Future<void> _skipCurrentSet() async {
    if (currentSet == null) return;

    try {
      // ✅ 同步到 Firestore
      await _service.adHocSkipSet(
        sessionId: _sessionId,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
      );

      setState(() {
        currentSet!.status = 'skipped';
        _isSetActive = false;
      });

      _setTimer?.cancel();
      _repsController.clear();
      _weightController.clear();

      HapticFeedback.lightImpact();
      _moveToNextFocus();
    } catch (e) {
      _showSnackBar('略過失敗：$e', Colors.red);
    }
  }

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
        currentSet!.status = 'completed';
        _isResting = false;
      });

      HapticFeedback.mediumImpact();
      _moveToNextFocus();
    } catch (e) {
      _showSnackBar('休息結束失敗：$e', Colors.red);
      setState(() => _isResting = false);
    }
  }

  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  void _addRestTime(int seconds) {
    setState(() {
      _remainingRestTime += seconds;
    });
    HapticFeedback.selectionClick();
  }

  // 🔥 統一的跳轉邏輯
  void _moveToNextFocus() {
    // 找下一個 pending 組
    bool foundNext = false;

    // 先在當前動作找
    for (int i = _currentSetIndex + 1; i < currentTotalSets; i++) {
      if (_exerciseSets[_currentExerciseIndex]![i].status == 'pending') {
        setState(() {
          _currentSetIndex = i;
        });
        foundNext = true;
        break;
      }
    }

    if (!foundNext) {
      // 當前動作沒有 pending 組了 → 檢查是否有下一個動作
      if (_currentExerciseIndex + 1 < widget.exercises.length) {
        setState(() {
          _currentExerciseIndex += 1;
          _currentSetIndex = 0;
        });
        _showSnackBar('✅ 動作完成！進入下一個動作', const Color(0xFF22C55E));
      } else {
        // 🎉 所有動作完成
        _showFinishDialog();
      }
    }
  }

  // 🔥 完成訓練
  Future<void> _showFinishDialog() async {
    // 檢查是否有未完成的組
    int incompleteCount = 0;
    for (var sets in _exerciseSets.values) {
      incompleteCount +=
          sets.where((s) => s.status == 'pending' || s.status == 'active').length;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration, color: Color(0xFF22C55E)),
            ),
            const SizedBox(width: 12),
            const Text('訓練完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incompleteCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '還有 $incompleteCount 組未完成',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '總訓練時長: ${_formatDuration(_totalElapsedSeconds)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('確定要結束訓練嗎？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('繼續訓練'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  Future<void> _finishWorkout() async {
    try {
      // 標記所有未完成的為 skipped
      for (var sets in _exerciseSets.values) {
        for (var set in sets) {
          if (set.status == 'pending' || set.status == 'active') {
            set.status = 'skipped';
          }
        }
      }

      await _service.finishAdHocSession(sessionId: _sessionId);

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, _sessionId);
      }
    } catch (e) {
      _showSnackBar('完成失敗：$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                '準備訓練中...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 主內容區
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildExerciseInfo(),
                      const SizedBox(height: 16),
                      
                      // 🔥 組數區域(橫向滾動)
                      _buildSetsArea(),
                      
                      const SizedBox(height: 16),
                      
                      // 🔥 當前焦點組操作
                      if (!_isResting && currentTotalSets > 0)
                        _buildCurrentSetActionArea(),
                      
                      // 提示文字(如果沒有組)
                      if (currentTotalSets == 0) _buildEmptySetHint(),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 🔥 迷你休息條(固定底部)
          if (_isResting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildMiniRestBar(),
            ),
        ],
      ),
    );
  }

  // 🔥 AppBar - 顯示總計時
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        children: [
          const Text(
            '自由訓練',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            _formatDuration(_totalElapsedSeconds),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'finish') {
              _showFinishDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'finish',
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 12),
                  Text('完成訓練'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF2DC4EA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 32,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentExercise['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '第 ${_currentExerciseIndex + 1} / ${widget.exercises.length} 個動作',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '組數',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (currentTotalSets > 0)
                Text(
                  '(${_exerciseSets[_currentExerciseIndex]!.where((s) => s.status == 'completed').length}/$currentTotalSets)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 60,
            child: Row(
              children: [
                if (currentTotalSets > 0)
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentTotalSets,
                      itemBuilder: (context, index) {
                        final set = _exerciseSets[_currentExerciseIndex]![index];
                        return _buildSetChip(set, index);
                      },
                    ),
                  ),
                
                const SizedBox(width: 8),
                InkWell(
                  onTap: _addNewSet,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6C63FF),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF6C63FF),
                      size: 24,
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

  Widget _buildSetChip(SetData set, int index) {
    final isCurrent = index == _currentSetIndex;
    Color color;
    IconData icon;

    switch (set.status) {
      case 'completed':
        color = const Color(0xFF22C55E);
        icon = Icons.check_circle;
        break;
      case 'active':
        color = const Color(0xFF6C63FF);
        icon = Icons.play_circle_filled;
        break;
      case 'resting':
        color = const Color(0xFFF59E0B);
        icon = Icons.timer;
        break;
      case 'skipped':
        color = Colors.grey;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey.shade300;
        icon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isCurrent ? 56 : 44,
        height: isCurrent ? 56 : 44,
        decoration: BoxDecoration(
          color: isCurrent ? color : color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: isCurrent
              ? Border.all(color: color, width: 3)
              : Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isCurrent ? Colors.white : color,
              size: isCurrent ? 20 : 16,
            ),
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: isCurrent ? 11 : 10,
                fontWeight: FontWeight.bold,
                color: isCurrent ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySetHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '點擊上方 + 按鈕新增組數',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSetActionArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSetActive
              ? const Color(0xFF22C55E)
              : const Color(0xFF6C63FF),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (_isSetActive) ...[
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF22C55E), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_setElapsedTime),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _repsController,
                  decoration: InputDecoration(
                    labelText: '次數',
                    hintText: '10',
                    prefixIcon: const Icon(Icons.repeat, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: '重量',
                    hintText: 'kg',
                    prefixIcon: const Icon(Icons.fitness_center, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (currentSetStatus == 'pending')
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _startCurrentSet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '開始這組',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (currentSetStatus == 'active')
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _completeCurrentSet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '完成這組',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (currentSetStatus == 'pending' || currentSetStatus == 'active') ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _skipCurrentSet,
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('略過本組'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRestBar() {
    final minutes = _remainingRestTime ~/ 60;
    final seconds = _remainingRestTime % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
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
            const Icon(
              Icons.timer,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),

            OutlinedButton(
              onPressed: () => _addRestTime(30),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('+30s'),
            ),
            const SizedBox(width: 8),

            ElevatedButton(
              onPressed: _skipRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text('跳過'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class SetData {
  int index;
  String status;
  int? reps;
  double? weight;

  SetData({
    required this.index,
    required this.status,
    this.reps,
    this.weight,
  });
}
