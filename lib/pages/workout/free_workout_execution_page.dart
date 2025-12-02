import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/workout_colors.dart';
import '../../components/workout/soft_workout_card.dart';
import '../../services/unified_workout_service.dart';
import '../../services/user_service.dart';
import '../../utils/exercise_calorie_calculator.dart';
import 'workout_summary_page.dart';

/// 自由訓練執行頁面 - v5.1 精簡專業版
/// 
/// 核心改進：
/// 1. 極簡流程 - 完成動作後提示自動消失，不彈對話框
/// 2. 隨時休息 - 懸浮休息按鈕，任何時候都能休息
/// 3. 全螢幕慶祝 - 全部完成時顯示慶祝畫面
/// 4. 滑動切換 - 左右滑動切換動作
/// 5. 中途新增 - 訓練中可新增動作
/// 6. 計時保留 - 切換組數時暫停計時，回來可繼續
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
  Timer? _messageTimer;
  int _totalElapsedSeconds = 0;
  int _remainingRestTime = 0;
  int _totalRestTime = 90;

  // 記錄休息開始時間
  int _restStartTime = 0;

  // === 動畫 ===
  late AnimationController _pulseController;
  late AnimationController _restPulseController;
  late AnimationController _celebrationController;

  // === UI 狀態 ===
  bool _showCelebration = false;
  bool _isManualResting = false;
  String? _completionMessage;

  // 懸浮休息按鈕位置
  Offset? _floatingButtonPosition;
  bool _isDragging = false;

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
      debugPrint('[載入] 用戶體重: $_userBodyWeight kg');
    } catch (e) {
      debugPrint('[警告] 載入體重失敗: $e');
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
      debugPrint('[錯誤] 初始化失敗: $e');
    }
  }

  @override
  void dispose() {
    _totalTimer?.cancel();
    _setTimer?.cancel();
    _restTimer?.cancel();
    _messageTimer?.cancel();
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
    // 從已累積的時間繼續（支援暫停後繼續）
    _setTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (currentSet != null) {
          currentSet!.elapsedSeconds++;
        }
      });
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
    
    // 如果是手動休息，不更新 Firebase，直接返回訓練
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
      debugPrint('[錯誤] 休息結束同步失敗: $e');
    }
    
    _moveToNextSet();
  }

  // ============================================================
  // 輕量完成提示
  // ============================================================

  void _showCompletionMessage(String message) {
    _messageTimer?.cancel();
    
    setState(() {
      _completionMessage = message;
    });

    HapticFeedback.mediumImpact();

    // 2秒後自動消失
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _completionMessage = null);
      }
    });
  }

  void _onExerciseCompleted() {
    final nextIndex = _nextIncompleteExerciseIndex;
    
    if (nextIndex == null) {
      // 全部完成，顯示慶祝畫面
      _showAllCompletedCelebration();
    } else {
      // 還有其他動作，顯示提示
      _showCompletionMessage('完成！滑動選擇下一個動作');
    }
  }

  // ============================================================
  // 全螢幕慶祝畫面
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
  // 手動休息功能
  // ============================================================

  void _startManualRest() {
    // 如果正在訓練中，先停止計時（但保留已累積時間）
    if (currentSet?.status == 'active') {
      _stopSetTimer();
      setState(() {
        currentSet!.status = 'paused'; // 改用 paused 狀態
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
      // 如果之前是暫停狀態，恢復為 active 並繼續計時
      if (currentSet?.status == 'paused') {
        currentSet!.status = 'active';
        _startSetTimer();
      }
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

  // 檢查所有「有開始的動作」是否都完成了
  bool get _allStartedExercisesCompleted {
    bool hasAnyStarted = false;
    for (int i = 0; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isNotEmpty) {
        hasAnyStarted = true;
        if (!sets.every((s) => s.status == 'completed' || s.status == 'skipped')) {
          return false;
        }
      }
    }
    return hasAnyStarted;
  }

  // 取得下一個可以做的動作索引
  int? get _nextIncompleteExerciseIndex {
    // 1. 先找「有開始但還沒做完」的動作
    for (int i = _currentExerciseIndex + 1; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isNotEmpty && sets.any((s) => 
          s.status == 'pending' || s.status == 'active' || s.status == 'paused')) {
        return i;
      }
    }
    for (int i = 0; i < _currentExerciseIndex; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isNotEmpty && sets.any((s) => 
          s.status == 'pending' || s.status == 'active' || s.status == 'paused')) {
        return i;
      }
    }
    
    // 2. 再找「還沒開始」的動作
    for (int i = _currentExerciseIndex + 1; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty) {
        return i;
      }
    }
    for (int i = 0; i < _currentExerciseIndex; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty) {
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

    // 清除提示訊息
    _messageTimer?.cancel();
    setState(() => _completionMessage = null);

    // 處理當前狀態
    final currentSetData = currentSet;
    if (currentSetData != null) {
      if (currentSetData.status == 'resting') {
        // 組間休息中切換：標記為完成，回來直接下一組
        _restTimer?.cancel();
        setState(() => currentSetData.status = 'completed');
      } else if (currentSetData.status == 'active') {
        // 訓練中切換：暫停，保留計時
        _stopSetTimer();
        setState(() => currentSetData.status = 'paused');
      }
    }
    
    // 如果是手動休息中切換，取消休息
    if (_isManualResting) {
      _restTimer?.cancel();
      setState(() => _isManualResting = false);
    }

    // 切換到新動作
    final newSets = _exerciseSets[index] ?? [];
    int newSetIndex = 0;
    
    if (newSets.isNotEmpty) {
      // 找到第一個未完成的組（pending, active, paused）
      final firstIncompleteIndex = newSets.indexWhere((s) => 
          s.status == 'pending' || s.status == 'active' || s.status == 'paused');
      
      if (firstIncompleteIndex >= 0) {
        // 有未完成的組，跳到那一組
        newSetIndex = firstIncompleteIndex;
      } else {
        // 全部完成或跳過，顯示最後一組
        newSetIndex = newSets.length - 1;
      }
    }

    setState(() {
      _currentExerciseIndex = index;
      _currentSetIndex = newSetIndex;
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
                ).catchError((e) => debugPrint('[錯誤] 新增動作同步失敗: $e'));

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
      if (sets.length == 1) {
        _currentSetIndex = 0;
      }
    });

    try {
      await _service.adHocAddSet(
        sessionId: _sessionId!,
        exerciseDocId: currentExerciseDocId,
        targetReps: defaultReps,
      );
    } catch (e) {
      debugPrint('[錯誤] 新增組數失敗: $e');
    }
    
    HapticFeedback.lightImpact();
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

  // 繼續已暫停的組
  void _resumeCurrentSet() {
    if (currentSet == null || currentSet!.status != 'paused') return;

    setState(() {
      currentSet!.status = 'active';
    });
    
    _startSetTimer();
    HapticFeedback.mediumImpact();
  }

  Future<void> _completeCurrentSet() async {
    if (currentSet == null) return;

    _stopSetTimer();
    final setDuration = currentSet!.elapsedSeconds;
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
      debugPrint('[錯誤] 完成組數同步失敗: $e');
    }

    if (_isLastSet) {
      try {
        await _service.adHocEndRest(
          sessionId: _sessionId!,
          exerciseDocId: currentExerciseDocId,
          setIndex: _currentSetIndex,
          restTakenSec: 0,
        );
      } catch (e) {
        debugPrint('[錯誤] 更新狀態失敗: $e');
      }

      setState(() {
        currentSet!.status = 'completed';
      });

      HapticFeedback.heavyImpact();
      _onExerciseCompleted();
      
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
    
    if (_isManualResting) {
      setState(() => _isManualResting = false);
      // 如果之前是暫停狀態，恢復為 active
      if (currentSet?.status == 'paused') {
        currentSet!.status = 'active';
        _startSetTimer();
      }
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
      debugPrint('[錯誤] 跳過休息同步失敗: $e');
    }
    
    _moveToNextSet();
  }

  Future<void> _skipCurrentSet() async {
    if (currentSet == null) return;

    _stopSetTimer();
    
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
      debugPrint('[錯誤] 略過同步失敗: $e');
    }

    if (_isLastSet) {
      _onExerciseCompleted();
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
    final sets = _exerciseSets[_currentExerciseIndex]!;
    if (index >= sets.length) return;
    
    final currentSetData = currentSet;
    
    // 如果點擊的是當前組，不做任何事
    if (index == _currentSetIndex) return;
    
    // 如果當前組正在訓練中，暫停它（保留計時）
    if (currentSetData?.status == 'active') {
      _stopSetTimer();
      setState(() => currentSetData!.status = 'paused');
    }
    
    // 切換到目標組
    setState(() => _currentSetIndex = index);
    HapticFeedback.selectionClick();
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
          durationSeconds: set.durationSec ?? set.elapsedSeconds,
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
    _messageTimer?.cancel();

    final sessionId = _sessionId!;

    try {
      await _service.finishAdHocSession(
        sessionId: sessionId,
        userBodyWeight: _userBodyWeight,
      );
      debugPrint('[完成] Firebase session 已完成');
    } catch (e) {
      debugPrint('[錯誤] Firebase session 完成失敗: $e');
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
        case 'paused': return SetStatus.active; // paused 顯示為 active 狀態
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

    final isResting = currentSet?.status == 'resting' || _isManualResting;
    
    // 更白的背景色
    const softBackground = Color(0xFFFAFBFC);

    return Scaffold(
      backgroundColor: isResting ? WorkoutColors.rest : softBackground,
      body: Stack(
        children: [
          // 主要內容
          SafeArea(
            child: isResting ? _buildRestingView() : _buildTrainingView(),
          ),

          // 懸浮休息按鈕（只在訓練中顯示）
          if (!isResting && !_showCelebration && currentTotalSets > 0)
            _buildFloatingRestButton(),

          // 輕量完成提示（底部）
          if (_completionMessage != null && !isResting && !_showCelebration)
            _buildCompletionMessage(),

          // 慶祝畫面覆蓋層
          if (_showCelebration) _buildCelebrationOverlay(),
        ],
      ),
    );
  }

  // ============================================================
  // 輕量完成提示 UI
  // ============================================================

  Widget _buildCompletionMessage() {
    return Positioned(
      bottom: 100,
      left: 24,
      right: 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: WorkoutColors.success,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: WorkoutColors.success.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _completionMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 慶祝畫面 UI
  // ============================================================

  Widget _buildCelebrationOverlay() {
    final totalCalories = _calculateTotalCalories();
    
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF388E3C),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 慶祝圖示
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  final scale = 1.0 + (_celebrationController.value * 0.2);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 56,
                        color: Colors.white,
                      ),
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
                  borderRadius: BorderRadius.circular(24),
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
                            borderRadius: BorderRadius.circular(20),
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
                            borderRadius: BorderRadius.circular(20),
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSwipeableExerciseCard(),
                const SizedBox(height: 12),
                _buildSetsProgressCard(),
                const SizedBox(height: 12),
                if (currentTotalSets > 0) 
                  _buildCurrentSetCard()
                else
                  _buildEmptySetPrompt(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySetPrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '點擊上方 + 新增組數',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingRestButton() {
    final screenSize = MediaQuery.of(context).size;
    
    _floatingButtonPosition ??= Offset(
      screenSize.width - 76,
      screenSize.height - 180,
    );
    
    return Positioned(
      left: _floatingButtonPosition!.dx,
      top: _floatingButtonPosition!.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            final newX = (_floatingButtonPosition!.dx + details.delta.dx)
                .clamp(0.0, screenSize.width - 60);
            final newY = (_floatingButtonPosition!.dy + details.delta.dy)
                .clamp(100.0, screenSize.height - 120);
            _floatingButtonPosition = Offset(newX, newY);
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onTap: _startManualRest,
        child: Transform.scale(
          scale: _isDragging ? 1.15 : 1.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF81C784), Color(0xFF66BB6A)],  // 薄荷綠
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF66BB6A).withOpacity(_isDragging ? 0.5 : 0.3),
                  blurRadius: _isDragging ? 16 : 12,
                  offset: const Offset(0, 4),
                  spreadRadius: _isDragging ? 2 : 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: Colors.white,
              size: 26,
            ),
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
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isFullyCompleted ? WorkoutColors.success : WorkoutColors.primary).withOpacity(0.25),
              blurRadius: 16,
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
                            ? (isFullyCompleted ? '已完成 $completedSets 組' : '已完成 $completedSets / $totalSets 組')
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
                _isManualResting ? '休息中' : '組間休息',
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

              if (!_isManualResting)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final hasAnyProgress = _exerciseSets.values.any((sets) => 
      sets.any((s) => s.status == 'completed'));
    
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

          if (hasAnyProgress)
            GestureDetector(
              onTap: _finishWorkout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: WorkoutColors.success,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '結束',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
    final completedCount = _exerciseSets[_currentExerciseIndex]?.where((s) => s.status == 'completed').length ?? 0;
    final allSetsCompleted = currentTotalSets > 0 && 
        (_exerciseSets[_currentExerciseIndex]?.every((s) => s.status == 'completed' || s.status == 'skipped') ?? false);
    
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
                '$completedCount / $currentTotalSets 組',
                style: TextStyle(
                  color: allSetsCompleted ? WorkoutColors.success : WorkoutColors.primary,
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
    final isPaused = set.status == 'paused';
    final isPending = set.status == 'pending';
    final isCompleted = set.status == 'completed';
    final isSkipped = set.status == 'skipped';

    // 檢查是否整個動作都完成了
    final allSetsCompleted = _exerciseSets[_currentExerciseIndex]?.every(
      (s) => s.status == 'completed' || s.status == 'skipped'
    ) ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: allSetsCompleted ? WorkoutColors.success :
                 isActive ? WorkoutColors.success : 
                 isPaused ? WorkoutColors.active :
                 WorkoutColors.primary.withOpacity(0.2),
          width: (isActive || isPaused || allSetsCompleted) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 如果整個動作都完成了，顯示完成訊息
          if (allSetsCompleted) ...[
            const Icon(Icons.check_circle, color: WorkoutColors.success, size: 48),
            const SizedBox(height: 12),
            const Text(
              '此動作已完成',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WorkoutColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '共完成 ${_exerciseSets[_currentExerciseIndex]?.where((s) => s.status == 'completed').length ?? 0} 組',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: const Text('加練一組'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WorkoutColors.primary,
                side: const BorderSide(color: WorkoutColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ] else ...[
            // 標題行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '第 ${_currentSetIndex + 1} 組',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (isActive || isPaused) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaused ? WorkoutColors.active : WorkoutColors.success).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaused ? Icons.pause : Icons.timer, 
                          size: 14, 
                          color: isPaused ? WorkoutColors.active : WorkoutColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(set.elapsedSeconds),
                          style: TextStyle(
                            color: isPaused ? WorkoutColors.active : WorkoutColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 2),
            Text(
              isActive ? '訓練中' : 
              isPaused ? '已暫停' :
              isCompleted ? '已完成' : 
              isSkipped ? '已略過' : '準備開始',
              style: TextStyle(
                color: isActive ? WorkoutColors.success : 
                       isPaused ? WorkoutColors.active :
                       isCompleted ? WorkoutColors.success :
                       Colors.grey,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 12),

            // 次數和重量
            Row(
              children: [
                Expanded(
                  child: _buildCompactNumberInput(
                    label: '次數',
                    value: set.reps,
                    unit: '下',
                    color: WorkoutColors.primary,
                    onChanged: (val) => setState(() => set.reps = val),
                    step: 1,
                    enabled: !isCompleted && !isSkipped,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactNumberInput(
                    label: '重量',
                    value: set.weight.toInt(),
                    unit: 'kg',
                    color: WorkoutColors.active,
                    onChanged: (val) => setState(() => set.weight = val.toDouble()),
                    step: 5,
                    enabled: !isCompleted && !isSkipped,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 按鈕
            if (isPending)
              _buildCompactButton(
                label: '開始這組',
                icon: Icons.play_arrow,
                color: WorkoutColors.primary,
                onPressed: _startCurrentSet,
              )
            else if (isPaused)
              _buildCompactButton(
                label: '繼續這組',
                icon: Icons.play_arrow,
                color: WorkoutColors.active,
                onPressed: _resumeCurrentSet,
              )
            else if (isActive)
              _buildCompactButton(
                label: '完成這組',
                icon: Icons.check,
                color: WorkoutColors.success,
                onPressed: _completeCurrentSet,
              )
            else if (isCompleted || isSkipped)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.skip_next,
                      color: isCompleted ? WorkoutColors.success : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCompleted ? '已完成' : '已略過',
                      style: TextStyle(
                        color: isCompleted ? WorkoutColors.success : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            if (!isCompleted && !isSkipped)
              TextButton(
                onPressed: _skipCurrentSet,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  '略過本組',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactNumberInput({
    required String label,
    required int value,
    required String unit,
    required Color color,
    required Function(int) onChanged,
    required int step,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 4),
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: WorkoutColors.softShadowSmall,
                    ),
                    child: Icon(Icons.remove, size: 16, color: color),
                  ),
                ),
              Expanded(
                child: GestureDetector(
                  onTap: enabled ? () => _showNumberPicker(label, value, onChanged) : null,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: enabled ? color : Colors.grey,
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: WorkoutColors.softShadowSmall,
                    ),
                    child: Icon(Icons.add, size: 16, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(unit, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCompactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          ? (isCompleted ? '已完成' : '$completedSets / $totalSets 組')
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

/// 組數資料模型 - 新增 elapsedSeconds 保留計時進度
class SetData {
  int reps;
  double weight;
  String status; // pending, active, paused, resting, completed, skipped
  int? durationSec;
  int elapsedSeconds; // 已累積的秒數（支援暫停繼續）

  SetData({
    required this.reps,
    required this.weight,
    required this.status,
    this.durationSec,
    this.elapsedSeconds = 0,
  });
}