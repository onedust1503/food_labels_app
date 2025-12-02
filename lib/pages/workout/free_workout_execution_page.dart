import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/workout_colors.dart';
import '../../components/workout/soft_workout_card.dart';
import '../../services/unified_workout_service.dart';
import '../../services/user_service.dart';
import '../../utils/exercise_calorie_calculator.dart';
import 'workout_summary_page.dart';

/// 自由訓練執行頁面 - v5.0 極簡流程版
/// 
/// 核心改進：
/// 1. 🚀 極簡流程 - 完成動作後 Toast 3秒自動跳下一個，不彈對話框
/// 2. 💤 隨時休息 - 新增「需要休息？」按鈕，任何時候都能休息
/// 3. 🎉 全螢幕慶祝 - 全部完成時顯示慶祝畫面
/// 4. 🔀 滑動切換 - 左右滑動切換動作
/// 5. ➕ 中途新增 - 訓練中可新增動作
/// 
/// 設計理念：減少打斷，讓用戶「無腦跟著做」
class FreeWorkoutExecutionPage extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;

  const FreeWorkoutExecutionPage({
    super.key,
    required this.exercises,
  });

  @override
  State<FreeWorkoutExecutionPage> createState() => _FreeWorkoutExecutionPageState();
}

class _FreeWorkoutExecutionPageState extends State<FreeWorkoutExecutionPage>
    with TickerProviderStateMixin {
  final UnifiedWorkoutService _service = UnifiedWorkoutService();
  final UserService _userService = UserService();

  // === 狀態管理 ===
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  String? _sessionId;
  bool _isInitialized = false;

  // 用戶體重（用於卡路里計算）
  double _userBodyWeight = 65.0;

  // 可修改的動作列表（支援中途新增）
  late List<Map<String, dynamic>> _exercises;

  // PageController 用於滑動切換
  late PageController _pageController;

  // 動態組數資料：exerciseIndex -> List<SetData>
  final Map<int, List<SetData>> _exerciseSets = {};

  // === 計時器 ===
  Timer? _totalTimer;
  Timer? _setTimer;
  Timer? _restTimer;
  Timer? _toastTimer; // 🆕 Toast 自動跳轉計時器
  int _totalElapsedSeconds = 0;
  int _setElapsedSeconds = 0;
  int _remainingRestTime = 0;
  int _totalRestTime = 90;
  int _toastCountdown = 3; // 🆕 Toast 倒數秒數

  // 記錄休息開始時間
  int _restStartTime = 0;

  // === 動畫 ===
  late AnimationController _pulseController;
  late AnimationController _restPulseController;
  late AnimationController _celebrationController; // 🆕 慶祝動畫

  // === UI 狀態 ===
  bool _showToast = false; // 🆕 是否顯示 Toast
  String _toastTitle = '';
  String _toastSubtitle = '';
  int? _nextExerciseIndex; // 🆕 Toast 跳轉目標
  bool _showCelebration = false; // 🆕 是否顯示慶祝畫面
  bool _isManualResting = false; // 🆕 是否為手動休息

  @override
  void initState() {
    super.initState();
    _exercises = List<Map<String, dynamic>>.from(
      widget.exercises.map((e) => Map<String, dynamic>.from(e))
    );
    _pageController = PageController(initialPage: 0);
    _initializeAnimations();
    _loadUserBodyWeight();
    _initializeSession();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _restPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  Future<void> _loadUserBodyWeight() async {
    try {
      final weight = await _userService.getBodyWeightForCalories();
      setState(() {
        _userBodyWeight = weight;
      });
      debugPrint('✅ 載入用戶體重: $_userBodyWeight kg');
    } catch (e) {
      debugPrint('⚠️ 載入體重失敗: $e');
    }
  }

  Future<void> _initializeSession() async {
    try {
      _sessionId = await _service.startAdHocSession(
        exercises: _exercises,
      );

      for (int i = 0; i < _exercises.length; i++) {
        _exerciseSets[i] = [];
      }

      setState(() => _isInitialized = true);
      _startTotalTimer();
    } catch (e) {
      debugPrint('❌ 初始化失敗: $e');
    }
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _setTimer?.cancel();
    _restTimer?.cancel();
    _toastTimer?.cancel();
    _pulseController.dispose();
    _restPulseController.dispose();
    _celebrationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // 計時器邏輯
  // ============================================================

  void _startTotalTimer() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _totalElapsedSeconds++);
    });
  }

  void _startSetTimer() {
    _setTimer?.cancel();
    _setElapsedSeconds = 0;
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _setElapsedSeconds++);
    });
  }

  void _stopSetTimer() {
    _setTimer?.cancel();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _remainingRestTime = seconds;
    _totalRestTime = seconds;
    _restStartTime = _totalRestTime;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingRestTime > 0) {
        setState(() => _remainingRestTime--);
        if (_remainingRestTime <= 10 && _remainingRestTime > 0) {
          HapticFeedback.lightImpact();
        }
      } else {
        _onRestComplete();
      }
    });
  }

  Future<void> _onRestComplete() async {
    _restTimer?.cancel();
    HapticFeedback.heavyImpact();
    
    final restTakenSec = _restStartTime;
    
    // 🆕 如果是手動休息，不更新 Firebase，直接返回訓練
    if (_isManualResting) {
      setState(() {
        _isManualResting = false;
      });
      return;
    }
    
    try {
      await _service.adHocEndRest(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        restTakenSec: restTakenSec,
      );
    } catch (e) {
      debugPrint('❌ 休息結束同步失敗: $e');
    }
    
    _moveToNextSet();
  }

  // ============================================================
  // 🆕 Toast 通知系統（取代對話框）
  // ============================================================

  void _showExerciseCompletedToast(int? nextIndex) {
    _toastTimer?.cancel();
    
    final currentName = currentExercise['name'] ?? '動作';
    final nextName = nextIndex != null ? _exercises[nextIndex]['name'] : null;

    setState(() {
      _showToast = true;
      _toastTitle = '✅ $currentName 完成！';
      _toastSubtitle = nextName != null ? '即將進入：$nextName' : '所有動作已完成';
      _toastCountdown = 3;
      _nextExerciseIndex = nextIndex;
    });

    HapticFeedback.mediumImpact();

    // 開始倒數
    _toastTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_toastCountdown > 1) {
        setState(() => _toastCountdown--);
      } else {
        timer.cancel();
        _onToastComplete();
      }
    });
  }

  void _onToastComplete() {
    if (!_showToast) return;
    
    setState(() {
      _showToast = false;
    });

    if (_nextExerciseIndex != null) {
      // 跳到下一個動作
      _switchToExercise(_nextExerciseIndex!);
    } else {
      // 全部完成，顯示慶祝畫面
      _showAllCompletedCelebration();
    }
  }

  void _cancelToastAndDoAction(VoidCallback action) {
    _toastTimer?.cancel();
    setState(() {
      _showToast = false;
    });
    action();
  }

  // ============================================================
  // 🆕 全螢幕慶祝畫面
  // ============================================================

  void _showAllCompletedCelebration() {
    setState(() {
      _showCelebration = true;
    });
    _celebrationController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _hideCelebrationAndContinue() {
    setState(() {
      _showCelebration = false;
    });
  }

  // ============================================================
  // 🆕 手動休息功能
  // ============================================================

  void _startManualRest() {
    // 如果正在訓練中，先停止計時
    if (currentSet?.status == 'active') {
      _stopSetTimer();
      setState(() {
        currentSet!.status = 'pending';
      });
    }

    setState(() {
      _isManualResting = true;
    });

    final restTime = currentExercise['restSec'] ?? 90;
    _startRestTimer(restTime);
    HapticFeedback.mediumImpact();
  }

  void _cancelManualRest() {
    _restTimer?.cancel();
    setState(() {
      _isManualResting = false;
    });
  }

  // ============================================================
  // Getters
  // ============================================================

  SetData? get currentSet {
    final sets = _exerciseSets[_currentExerciseIndex];
    if (sets == null || sets.isEmpty || _currentSetIndex >= sets.length) {
      return null;
    }
    return sets[_currentSetIndex];
  }

  int get currentTotalSets => _exerciseSets[_currentExerciseIndex]?.length ?? 0;
  Map<String, dynamic> get currentExercise => _exercises[_currentExerciseIndex];
  String get currentExerciseDocId => 'ex$_currentExerciseIndex';
  bool get _isLastSet => _currentSetIndex >= currentTotalSets - 1;

  // 🆕 檢查所有動作是否都有完成至少一組
  bool get _allExercisesHaveProgress {
    for (int i = 0; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty || !sets.any((s) => s.status == 'completed')) {
        return false;
      }
    }
    return true;
  }

  // 🆕 取得下一個未完成的動作索引
  int? get _nextIncompleteExerciseIndex {
    // 先從當前動作之後找
    for (int i = _currentExerciseIndex + 1; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty || !sets.any((s) => s.status == 'completed')) {
        return i;
      }
    }
    // 再從頭找
    for (int i = 0; i < _currentExerciseIndex; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty || !sets.any((s) => s.status == 'completed')) {
        return i;
      }
    }
    return null;
  }

  // ============================================================
  // 滑動切換動作
  // ============================================================

  void _onPageChanged(int index) {
    if (index == _currentExerciseIndex) return;

    // 取消 Toast
    if (_showToast) {
      _toastTimer?.cancel();
      setState(() => _showToast = false);
    }

    // 處理當前狀態
    if (currentSet?.status == 'resting') {
      _restTimer?.cancel();
      setState(() => currentSet!.status = 'completed');
    }
    if (currentSet?.status == 'active') {
      _stopSetTimer();
      setState(() => currentSet!.status = 'pending');
    }

    setState(() {
      _currentExerciseIndex = index;
      _currentSetIndex = 0;
      
      final sets = _exerciseSets[index] ?? [];
      if (sets.isNotEmpty) {
        final lastCompletedIndex = sets.lastIndexWhere((s) => s.status == 'completed');
        if (lastCompletedIndex >= 0 && lastCompletedIndex < sets.length - 1) {
          _currentSetIndex = lastCompletedIndex + 1;
        } else if (lastCompletedIndex == sets.length - 1) {
          _currentSetIndex = sets.length - 1;
        }
      }
    });

    HapticFeedback.selectionClick();
  }

  void _switchToExercise(int index) {
    if (index < 0 || index >= _exercises.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ============================================================
  // 新增動作
  // ============================================================

  void _showQuickAddExerciseDialog() {
    final nameController = TextEditingController();
    String selectedCategory = '胸部';
    final categories = ['胸部', '背部', '肩部', '手臂', '腿部', '核心', '有氧', '其他'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: WorkoutColors.primary),
              SizedBox(width: 8),
              Text('新增動作'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '動作名稱',
                  hintText: '例：啞鈴飛鳥',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.fitness_center),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: '分類',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setDialogState(() => selectedCategory = value ?? '胸部'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final newExercise = {
                  'name': name,
                  'category': selectedCategory,
                  'restSec': 90,
                };

                setState(() {
                  _exercises.add(newExercise);
                  _exerciseSets[_exercises.length - 1] = [];
                });

                _service.adHocAddExercise(
                  sessionId: _sessionId!,
                  exercise: newExercise,
                ).catchError((e) => debugPrint('❌ 新增動作同步失敗: $e'));

                Navigator.pop(context);
                
                Future.delayed(const Duration(milliseconds: 200), () {
                  _switchToExercise(_exercises.length - 1);
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('新增'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WorkoutColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 組數操作
  // ============================================================

  Future<void> _addSet() async {
    final sets = _exerciseSets[_currentExerciseIndex]!;
    
    int defaultReps = 12;
    double defaultWeight = 0;
    
    if (sets.isNotEmpty) {
      final lastSet = sets.last;
      defaultReps = lastSet.reps;
      defaultWeight = lastSet.weight;
    }

    final newSet = SetData(
      reps: defaultReps,
      weight: defaultWeight,
      status: 'pending',
    );

    setState(() {
      sets.add(newSet);
      _currentSetIndex = sets.length - 1;
    });

    try {
      await _service.adHocAddSet(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        targetReps: defaultReps,
      );
    } catch (e) {
      debugPrint('❌ 新增組數失敗: $e');
    }
  }

  void _startCurrentSet() {
    if (currentSet == null) return;

    setState(() {
      currentSet!.status = 'active';
    });
    
    _service.adHocStartSet(
      _sessionId!,
      currentExerciseDocId,
      _currentSetIndex,
    );
    
    _startSetTimer();
    HapticFeedback.mediumImpact();
  }

  Future<void> _completeCurrentSet() async {
    if (currentSet == null) return;

    _stopSetTimer();
    final setDuration = _setElapsedSeconds;
    currentSet!.durationSec = setDuration;

    try {
      await _service.adHocCompleteSet(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        reps: currentSet!.reps,
        weight: currentSet!.weight,
        durationSec: setDuration,
      );
    } catch (e) {
      debugPrint('❌ 完成組數同步失敗: $e');
    }

    // 🆕 新流程：判斷是否最後一組
    if (_isLastSet) {
      // 最後一組，標記為完成
      try {
        await _service.adHocEndRest(
          sessionId: _sessionId!,
          exerciseDocId: currentExerciseDocId,
          setIndex: _currentSetIndex,
          restTakenSec: 0,
        );
      } catch (e) {
        debugPrint('❌ 更新狀態失敗: $e');
      }

      setState(() {
        currentSet!.status = 'completed';
      });

      HapticFeedback.heavyImpact();

      // 🆕 顯示 Toast，3秒後自動跳轉
      final nextIndex = _nextIncompleteExerciseIndex;
      _showExerciseCompletedToast(nextIndex);
      
    } else {
      // 不是最後一組，進入組間休息
      setState(() {
        currentSet!.status = 'resting';
      });

      final restTime = currentExercise['restSec'] ?? 90;
      _startRestTimer(restTime);
    }
  }

  Future<void> _skipRest() async {
    _restTimer?.cancel();
    
    // 🆕 如果是手動休息，直接取消
    if (_isManualResting) {
      setState(() => _isManualResting = false);
      return;
    }
    
    final restTakenSec = _restStartTime - _remainingRestTime;
    
    try {
      await _service.adHocEndRest(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
        restTakenSec: restTakenSec,
      );
    } catch (e) {
      debugPrint('❌ 跳過休息同步失敗: $e');
    }
    
    _moveToNextSet();
  }

  Future<void> _skipCurrentSet() async {
    if (currentSet == null) return;

    setState(() {
      currentSet!.status = 'skipped';
    });

    try {
      await _service.adHocSkipSet(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        setIndex: _currentSetIndex,
      );
    } catch (e) {
      debugPrint('❌ 略過同步失敗: $e');
    }

    if (_isLastSet) {
      final nextIndex = _nextIncompleteExerciseIndex;
      _showExerciseCompletedToast(nextIndex);
    } else {
      _moveToNextSet();
    }
  }

  void _moveToNextSet() {
    if (currentSet?.status == 'resting') {
      setState(() => currentSet!.status = 'completed');
    }

    if (_currentSetIndex < currentTotalSets - 1) {
      setState(() => _currentSetIndex++);
    }
  }

  void _onSetTapped(int index) {
    final set = _exerciseSets[_currentExerciseIndex]![index];
    if (set.status == 'pending' || set.status == 'completed') {
      setState(() => _currentSetIndex = index);
    }
  }

  // ============================================================
  // 卡路里計算
  // ============================================================

  double _calculateTotalCalories() {
    double totalCalories = 0;

    _exerciseSets.forEach((exerciseIndex, sets) {
      if (exerciseIndex >= _exercises.length) return;
      
      final exercise = _exercises[exerciseIndex];
      final exerciseName = exercise['name'] as String? ?? '';
      final category = exercise['category'] as String? ?? '';

      for (var set in sets) {
        if (set.status != 'completed') continue;

        totalCalories += ExerciseCalorieCalculator.calculateSetCalories(
          exerciseName: exerciseName,
          category: category,
          reps: set.reps,
          weight: set.weight,
          durationSeconds: set.durationSec ?? 30,
          bodyWeight: _userBodyWeight,
        );
      }
    });

    return totalCalories;
  }

  int get _totalCompletedSets {
    int count = 0;
    _exerciseSets.forEach((_, sets) {
      count += sets.where((s) => s.status == 'completed').length;
    });
    return count;
  }

  // ============================================================
  // 完成訓練
  // ============================================================

  void _finishWorkout() async {
    _totalTimer?.cancel();
    _restTimer?.cancel();
    _toastTimer?.cancel();

    final sessionId = _sessionId!;

    try {
      await _service.finishAdHocSession(
        sessionId: sessionId,
        userBodyWeight: _userBodyWeight,
      );
      debugPrint('✅ Firebase session 已完成');
    } catch (e) {
      debugPrint('❌ Firebase session 完成失敗: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
      ),
      (route) => route.isFirst,
    );
  }

  // ============================================================
  // 工具方法
  // ============================================================

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<SetStatus> get _setStatuses {
    if (currentTotalSets == 0) return [];
    return List.generate(currentTotalSets, (index) {
      final set = _exerciseSets[_currentExerciseIndex]![index];
      switch (set.status) {
        case 'completed': return SetStatus.completed;
        case 'active': return SetStatus.active;
        case 'resting': return SetStatus.resting;
        case 'skipped': return SetStatus.skipped;
        default: return SetStatus.pending;
      }
    });
  }

  // ============================================================
  // UI 建構
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🆕 判斷顯示哪個畫面
    final isResting = currentSet?.status == 'resting' || _isManualResting;

    return Scaffold(
      backgroundColor: isResting ? WorkoutColors.rest : WorkoutColors.background,
      body: Stack(
        children: [
          // 主要內容
          SafeArea(
            child: isResting ? _buildRestingView() : _buildTrainingView(),
          ),

          // 🆕 Toast 通知覆蓋層
          if (_showToast) _buildToastOverlay(),

          // 🆕 慶祝畫面覆蓋層
          if (_showCelebration) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ============================================================
  // 🆕 Toast 通知 UI
  // ============================================================

  Widget _buildToastOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 標題
                Text(
                  _toastTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // 副標題 + 倒數
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _toastSubtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: WorkoutColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_toastCountdown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: WorkoutColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 按鈕
                Row(
                  children: [
                    // 直接開始（跳過倒數）
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelToastAndDoAction(_onToastComplete),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _nextExerciseIndex != null ? '直接開始' : '查看總結',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 先休息一下
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _cancelToastAndDoAction(_startManualRest),
                        icon: const Icon(Icons.bedtime, size: 20),
                        label: const Text('先休息', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WorkoutColors.rest,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 🆕 慶祝畫面 UI
  // ============================================================

  Widget _buildCelebrationOverlay() {
    final totalCalories = _calculateTotalCalories();
    
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              WorkoutColors.success,
              WorkoutColors.success.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 慶祝 emoji
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  final scale = 1.0 + (_celebrationController.value * 0.2);
                  return Transform.scale(
                    scale: scale,
                    child: const Text(
                      '🎉',
                      style: TextStyle(fontSize: 80),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // 標題
              const Text(
                '太棒了！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '所有動作都完成了',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              
              // 統計卡片
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildCelebrationStat(
                      icon: Icons.timer_outlined,
                      label: '訓練時長',
                      value: _formatDuration(_totalElapsedSeconds),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    _buildCelebrationStat(
                      icon: Icons.local_fire_department,
                      label: '消耗卡路里',
                      value: '${totalCalories.toInt()} kcal',
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    _buildCelebrationStat(
                      icon: Icons.fitness_center,
                      label: '完成組數',
                      value: '$_totalCompletedSets 組',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // 按鈕
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    // 繼續加練
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hideCelebrationAndContinue,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          '繼續加練',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // 結束訓練
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _finishWorkout,
                        icon: const Icon(Icons.flag),
                        label: const Text('結束訓練', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: WorkoutColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 訓練視圖
  // ============================================================

  Widget _buildTrainingView() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSwipeableExerciseCard(),
                const SizedBox(height: 16),
                _buildSetsProgressCard(),
                const SizedBox(height: 16),
                if (currentTotalSets > 0) _buildCurrentSetCard(),
                // 🆕 手動休息按鈕
                if (currentTotalSets > 0 && currentSet?.status != 'active')
                  _buildManualRestButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🆕 手動休息按鈕
  Widget _buildManualRestButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: _startManualRest,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: WorkoutColors.rest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WorkoutColors.rest.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bedtime_outlined, color: WorkoutColors.rest.withOpacity(0.8), size: 22),
              const SizedBox(width: 8),
              Text(
                '需要休息一下？',
                style: TextStyle(
                  color: WorkoutColors.rest.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 滑動卡片
  // ============================================================

  Widget _buildSwipeableExerciseCard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text('左右滑動切換動作', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showQuickAddExerciseDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: WorkoutColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: WorkoutColors.primary),
                      SizedBox(width: 2),
                      Text('新增', style: TextStyle(fontSize: 12, color: WorkoutColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _exercises.length,
            itemBuilder: (context, index) => _buildExerciseCardItem(index),
          ),
        ),
        
        const SizedBox(height: 12),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildExerciseCardItem(int index) {
    final exercise = _exercises[index];
    final sets = _exerciseSets[index] ?? [];
    final completedSets = sets.where((s) => s.status == 'completed').length;
    final totalSets = sets.length;
    final hasProgress = sets.any((s) => s.status == 'completed');
    final isFullyCompleted = totalSets > 0 && completedSets == totalSets;

    return GestureDetector(
      onTap: () => _showExerciseList(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFullyCompleted 
                ? [WorkoutColors.success, WorkoutColors.success.withOpacity(0.8)]
                : (hasProgress 
                    ? [WorkoutColors.active, WorkoutColors.active.withOpacity(0.8)]
                    : [WorkoutColors.primary, WorkoutColors.primary.withOpacity(0.8)]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isFullyCompleted ? WorkoutColors.success : WorkoutColors.primary).withOpacity(0.3),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '第 ${index + 1} / ${_exercises.length} 個動作',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    exercise['category'] ?? '重量訓練',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Spacer(),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFullyCompleted ? Icons.check : Icons.fitness_center,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise['name'] ?? '未命名動作',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalSets > 0 
                            ? (isFullyCompleted ? '✓ 已完成 $completedSets 組' : '已完成 $completedSets / $totalSets 組')
                            : '尚未開始',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (totalSets > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completedSets / totalSets,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_exercises.length, (index) {
        final isActive = index == _currentExerciseIndex;
        final sets = _exerciseSets[index] ?? [];
        final hasProgress = sets.any((s) => s.status == 'completed');
        final isCompleted = sets.isNotEmpty && sets.every((s) => s.status == 'completed');

        return GestureDetector(
          onTap: () => _switchToExercise(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive 
                  ? WorkoutColors.primary 
                  : (isCompleted 
                      ? WorkoutColors.success 
                      : (hasProgress ? WorkoutColors.active : Colors.grey[300])),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  // ============================================================
  // 休息視圖
  // ============================================================

  Widget _buildRestingView() {
    final progress = _totalRestTime > 0 
        ? (_totalRestTime - _remainingRestTime) / _totalRestTime 
        : 0.0;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // 🆕 手動休息時顯示「取消」按鈕
                IconButton(
                  onPressed: _isManualResting ? _cancelManualRest : () => _skipRest(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  '總計 ${_formatDuration(_totalElapsedSeconds)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isManualResting ? '休息中 💤' : '組間休息',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              AnimatedBuilder(
                animation: _restPulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_restPulseController.value * 0.03);
                  return Transform.scale(
                    scale: scale,
                    child: Text(
                      _formatDuration(_remainingRestTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 🆕 顯示不同的提示
              if (!_isManualResting)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        currentExercise['name'] ?? '下一組',
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '第 ${_currentSetIndex + 2} 組',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currentSet != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '上一組：${currentSet!.reps} 次 × ${currentSet!.weight.toStringAsFixed(0)} kg',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _remainingRestTime += 30;
                        _totalRestTime += 30;
                      });
                      HapticFeedback.lightImpact();
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('+30s', style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isManualResting ? _cancelManualRest : _skipRest,
                    icon: Icon(_isManualResting ? Icons.play_arrow : Icons.skip_next),
                    label: Text(
                      _isManualResting ? '繼續訓練' : '跳過休息',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: WorkoutColors.rest,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AppBar
  // ============================================================

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitDialog(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: WorkoutColors.softShadowSmall,
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),

          Expanded(
            child: Column(
              children: [
                const Text(
                  '自由訓練',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDuration(_totalElapsedSeconds),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () => _showOptionsMenu(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: WorkoutColors.softShadowSmall,
              ),
              child: const Icon(Icons.more_vert, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 組數進度卡片
  // ============================================================

  Widget _buildSetsProgressCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '組數進度',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_exerciseSets[_currentExerciseIndex]?.where((s) => s.status == 'completed').length ?? 0} / $currentTotalSets 組',
                style: const TextStyle(
                  color: WorkoutColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: currentTotalSets == 0
                    ? const Text('點擊 + 新增組數', style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(currentTotalSets, (index) {
                          final isCurrent = index == _currentSetIndex;
                          return GestureDetector(
                            onTap: () => _onSetTapped(index),
                            child: Container(
                              decoration: isCurrent ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: WorkoutColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ) : null,
                              child: SetStatusIndicator(
                                setNumber: index + 1,
                                status: _setStatuses[index],
                              ),
                            ),
                          );
                        }),
                      ),
              ),

              GestureDetector(
                onTap: _addSet,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: WorkoutColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.add, color: WorkoutColors.primary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('待做', Colors.grey[300]!),
              _buildLegendItem('進行', WorkoutColors.active),
              _buildLegendItem('休息', WorkoutColors.rest),
              _buildLegendItem('完成', WorkoutColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ============================================================
  // 當前組數卡片
  // ============================================================

  Widget _buildCurrentSetCard() {
    final set = currentSet;
    if (set == null) return const SizedBox();

    final isActive = set.status == 'active';
    final isPending = set.status == 'pending';
    final isCompleted = set.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? WorkoutColors.success : WorkoutColors.primary.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? WorkoutColors.success : WorkoutColors.primary).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '第 ${_currentSetIndex + 1} 組',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (isActive) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: WorkoutColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 16, color: WorkoutColors.success),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_setElapsedSeconds),
                        style: const TextStyle(
                          color: WorkoutColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 4),
          Text(
            isActive ? '訓練中' : (isCompleted ? '已完成' : '準備開始'),
            style: TextStyle(
              color: isActive ? WorkoutColors.success : Colors.grey,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildNumberInput(
                  label: '次數',
                  value: set.reps,
                  unit: '下',
                  icon: Icons.repeat,
                  color: WorkoutColors.primary,
                  onChanged: (val) => setState(() => set.reps = val),
                  step: 1,
                  enabled: !isCompleted,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: _buildNumberInput(
                  label: '重量',
                  value: set.weight.toInt(),
                  unit: 'kg',
                  icon: Icons.fitness_center,
                  color: WorkoutColors.active,
                  onChanged: (val) => setState(() => set.weight = val.toDouble()),
                  step: 5,
                  enabled: !isCompleted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (isPending)
            _buildPrimaryButton(
              label: '開始這組',
              icon: Icons.play_arrow,
              color: WorkoutColors.primary,
              onPressed: _startCurrentSet,
            )
          else if (isActive)
            _buildPrimaryButton(
              label: '✓ 完成這組',
              icon: Icons.check,
              color: WorkoutColors.success,
              onPressed: _completeCurrentSet,
            )
          else if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: WorkoutColors.success),
                  SizedBox(width: 8),
                  Text(
                    '已完成',
                    style: TextStyle(
                      color: WorkoutColors.success,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (!isCompleted) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _skipCurrentSet,
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('略過本組'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required String unit,
    required IconData icon,
    required Color color,
    required Function(int) onChanged,
    required int step,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (enabled)
                GestureDetector(
                  onTap: () {
                    if (value > step) {
                      onChanged(value - step);
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: WorkoutColors.softShadowSmall,
                    ),
                    child: Icon(Icons.remove, size: 18, color: color),
                  ),
                ),

              Expanded(
                child: GestureDetector(
                  onTap: enabled ? () => _showNumberPicker(label, value, onChanged) : null,
                  child: Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: enabled ? color : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              if (enabled)
                GestureDetector(
                  onTap: () {
                    onChanged(value + step);
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: WorkoutColors.softShadowSmall,
                    ),
                    child: Icon(Icons.add, size: 18, color: color),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),
          Text(unit, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  void _showNumberPicker(String label, int currentValue, Function(int) onChanged) {
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('輸入$label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? currentValue;
              onChanged(newValue);
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  // ============================================================
  // 對話框
  // ============================================================

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確定要離開嗎？'),
        content: const Text('訓練進度將會保存'),
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
            child: const Text('離開'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle, color: WorkoutColors.primary),
              title: const Text('新增動作'),
              onTap: () {
                Navigator.pop(context);
                _showQuickAddExerciseDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime, color: WorkoutColors.rest),
              title: const Text('休息一下'),
              onTap: () {
                Navigator.pop(context);
                _startManualRest();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('調整休息時間'),
              onTap: () {
                Navigator.pop(context);
                _showRestTimeSelector();
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('查看所有動作'),
              onTap: () {
                Navigator.pop(context);
                _showExerciseList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined, color: Colors.red),
              title: const Text('結束訓練', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _finishWorkout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRestTimeSelector() {
    final options = [30, 60, 90, 120, 180];
    final currentRest = currentExercise['restSec'] ?? 90;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('選擇休息時間', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...options.map((seconds) => ListTile(
              leading: Icon(
                seconds == currentRest ? Icons.check_circle : Icons.circle_outlined,
                color: seconds == currentRest ? WorkoutColors.success : Colors.grey,
              ),
              title: Text('${seconds}秒'),
              onTap: () {
                setState(() {
                  _exercises[_currentExerciseIndex]['restSec'] = seconds;
                });
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showExerciseList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('動作列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showQuickAddExerciseDialog();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新增'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  final isCurrent = index == _currentExerciseIndex;
                  final sets = _exerciseSets[index] ?? [];
                  final completedSets = sets.where((s) => s.status == 'completed').length;
                  final totalSets = sets.length;
                  final hasProgress = sets.any((s) => s.status == 'completed');
                  final isCompleted = totalSets > 0 && completedSets == totalSets;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent 
                          ? WorkoutColors.primary 
                          : (isCompleted 
                              ? WorkoutColors.success.withOpacity(0.2) 
                              : (hasProgress ? WorkoutColors.active.withOpacity(0.2) : Colors.grey[200])),
                      child: isCompleted 
                          ? const Icon(Icons.check, color: WorkoutColors.success, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(
                      exercise['name'] ?? '動作 ${index + 1}',
                      style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      totalSets > 0 
                          ? (isCompleted ? '✓ 已完成' : '$completedSets / $totalSets 組')
                          : '尚未開始',
                      style: TextStyle(
                        color: isCompleted ? WorkoutColors.success : (hasProgress ? WorkoutColors.active : Colors.grey),
                      ),
                    ),
                    trailing: isCurrent ? const Icon(Icons.play_arrow, color: WorkoutColors.primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _switchToExercise(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 組數資料模型
class SetData {
  int reps;
  double weight;
  String status;
  int? durationSec;

  SetData({
    required this.reps,
    required this.weight,
    required this.status,
    this.durationSec,
  });
}