// lib/pages/workout/workout_plan_execution_page.dart
// 🔥 v5.1 整合版 - 保留 v5.0 所有功能 + v7.0 修復
//
// v7.0 修復：
// 1. 使用 WorkoutDateHelper 正規化星期格式
// 2. startPlanSession 不建立 sets（由執行頁面用 adHocAddSet 建立）
//
// 保留功能：
// - TTS 語音播報
// - 動畫效果（脈動、慶祝）
// - 滑動切換動作（PageView）
// - 手動休息功能
// - 上滑完成/下滑略過手勢
// - 複製上一組數據
// - 動作預設值記憶
// - 訓練中新增動作
// - 導航到 WorkoutSummaryPage

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../theme/workout_colors.dart';
import '../../components/workout/soft_workout_card.dart';
import '../../services/unified_workout_service.dart';
import '../../services/user_service.dart';
import '../../utils/exercise_calorie_calculator.dart';
import '../../utils/workout_date_helper.dart';  // 🔥 v7.0 新增
import 'workout_summary_page.dart';

/// 計畫訓練執行頁面 - v5.1 整合版
class WorkoutPlanExecutionPage extends StatefulWidget {
  final String planId;
  final String planName;
  final String dayOfWeek;
  final List<Map<String, dynamic>> exercises;

  const WorkoutPlanExecutionPage({
    super.key,
    required this.planId,
    required this.planName,
    required this.dayOfWeek,
    required this.exercises,
  });

  @override
  State<WorkoutPlanExecutionPage> createState() => _WorkoutPlanExecutionPageState();
}

class _WorkoutPlanExecutionPageState extends State<WorkoutPlanExecutionPage>
    with TickerProviderStateMixin {
  final UnifiedWorkoutService _service = UnifiedWorkoutService();
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // 動作預設值記憶
  final Map<String, Map<String, dynamic>> _exerciseDefaults = {};

  // === 計時器 ===
  Timer? _totalTimer;
  Timer? _setTimer;
  Timer? _restTimer;
  Timer? _messageTimer;
  int _totalElapsedSeconds = 0;
  int _remainingRestTime = 0;
  int _totalRestTime = 90;
  int _restStartTime = 0;

  // === 動畫 ===
  late AnimationController _pulseController;
  late AnimationController _restPulseController;
  late AnimationController _celebrationController;

  // === UI 狀態 ===
  bool _showCelebration = false;
  bool _isManualResting = false;
  String? _completionMessage;
  Offset? _floatingButtonPosition;
  bool _isDragging = false;
  double _cardSwipeOffset = 0;
  bool _isCardSwiping = false;

  // === TTS 語音 ===
  late FlutterTts _flutterTts;
  bool _ttsInitialized = false;

  @override
  void initState() {
    super.initState();
    _exercises = List<Map<String, dynamic>>.from(
      widget.exercises.map((e) => Map<String, dynamic>.from(e))
    );
    _pageController = PageController(initialPage: 0);
    _initializeAnimations();
    _initTts();
    _loadUserBodyWeight();
    _loadExerciseDefaults();
    _initializeSession();
  }

  // ============================================================
  // 初始化
  // ============================================================

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

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage('zh-TW');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[TTS] 初始化失敗: $e');
      _ttsInitialized = false;
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsInitialized) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] 播報失敗: $e');
    }
  }

  Future<void> _loadUserBodyWeight() async {
    try {
      final weight = await _userService.getBodyWeightForCalories();
      setState(() => _userBodyWeight = weight);
      debugPrint('[載入] 用戶體重: $_userBodyWeight kg');
    } catch (e) {
      debugPrint('[警告] 載入體重失敗: $e');
    }
  }

  Future<void> _loadExerciseDefaults() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('exerciseDefaults')
          .get();

      for (var doc in snapshot.docs) {
        _exerciseDefaults[doc.id] = {
          'reps': doc.data()['reps'] ?? 12,
          'weight': (doc.data()['weight'] ?? 0.0).toDouble(),
        };
      }

      debugPrint('[載入] 動作預設值：${_exerciseDefaults.length} 個動作');
    } catch (e) {
      debugPrint('[警告] 載入動作預設值失敗: $e');
    }
  }

  Future<void> _saveExerciseDefault(String exerciseName, int reps, double weight) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      _exerciseDefaults[exerciseName] = {'reps': reps, 'weight': weight};

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('exerciseDefaults')
          .doc(exerciseName)
          .set({
        'reps': reps,
        'weight': weight,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[保存] 動作預設值：$exerciseName -> $weight kg × $reps 下');
    } catch (e) {
      debugPrint('[警告] 保存動作預設值失敗: $e');
    }
  }

  Map<String, dynamic> _getExerciseDefault(String exerciseName) {
    return _exerciseDefaults[exerciseName] ?? {'reps': 12, 'weight': 0.0};
  }

  /// 🔥 v7.0 修復：使用 WorkoutDateHelper + startPlanSession 不建立 sets
  Future<void> _initializeSession() async {
    try {
      // 🔥 v7.0：正規化星期格式
      final normalizedDayOfWeek = WorkoutDateHelper.normalizeToChinese(widget.dayOfWeek);
      final workoutName = '${widget.planName} - $normalizedDayOfWeek';

      // 🔥 v7.0：使用 startPlanSession（createSets 預設為 false）
      // Service 只建立 exercises，不建立 sets
      _sessionId = await _service.startPlanSession(
        planId: widget.planId,
        planName: widget.planName,
        dayOfWeek: widget.dayOfWeek,
        exercises: _exercises,
        workoutName: workoutName,
        // createSets: false,  // 預設值，由執行頁面建立 sets
      );

      // 初始化每個動作的組數列表
      for (int i = 0; i < _exercises.length; i++) {
        _exerciseSets[i] = [];
        
        final exerciseName = _exercises[i]['name'] as String? ?? '';
        final plannedSets = _exercises[i]['sets'] as int? ?? 0;
        final plannedReps = _exercises[i]['reps'] as int? ?? 12;
        
        // 獲取用戶的預設值
        final defaults = _getExerciseDefault(exerciseName);
        final defaultWeight = (defaults['weight'] as num?)?.toDouble() ?? 0.0;
        
        // 🔥 v7.0：由執行頁面建立 sets（避免與 Service 重複）
        if (plannedSets > 0) {
          for (int j = 0; j < plannedSets; j++) {
            _exerciseSets[i]!.add(SetData(
              reps: plannedReps,
              weight: defaultWeight,
              status: 'pending',
            ));
            
            // 同步到 Firebase
            await _service.adHocAddSet(
              sessionId: _sessionId!,
              exerciseDocId: 'ex$i',
              targetReps: plannedReps,
            );
          }
        }
      }

      setState(() => _isInitialized = true);
      _startTotalTimer();

      debugPrint('[初始化] 計畫訓練 Session 已創建 (v7.0)');
      debugPrint('  - 計畫: ${widget.planName}');
      debugPrint('  - 日期: $normalizedDayOfWeek');
      debugPrint('  - SessionId: $_sessionId');
      debugPrint('  - 動作數: ${_exercises.length}');
      for (int i = 0; i < _exercises.length; i++) {
        debugPrint('  - 動作 $i: ${_exercises[i]['name']} - ${_exerciseSets[i]?.length ?? 0} 組');
      }
    } catch (e) {
      debugPrint('[錯誤] 初始化失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失敗: $e'), backgroundColor: Colors.red),
        );
      }
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
    _flutterTts.stop();
    super.dispose();
  }

  // ============================================================
  // 計時器
  // ============================================================

  void _startTotalTimer() {
    _totalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _totalElapsedSeconds++);
    });
  }

  void _startSetTimer() {
    _setTimer?.cancel();
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

        // 漸進式震動 + 語音播報
        if (_remainingRestTime <= 10 && _remainingRestTime > 0) {
          if (_remainingRestTime <= 3) {
            HapticFeedback.heavyImpact();
            _speak('$_remainingRestTime');
          } else if (_remainingRestTime <= 5) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.lightImpact();
          }
        }
      } else {
        _speak('開始');
        _onRestComplete();
      }
    });
  }

  Future<void> _onRestComplete() async {
    _restTimer?.cancel();
    HapticFeedback.heavyImpact();

    final restTakenSec = _restStartTime;

    if (_isManualResting) {
      setState(() => _isManualResting = false);
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

  int? get _nextIncompleteExerciseIndex {
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
    for (int i = _currentExerciseIndex + 1; i < _exercises.length; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty) return i;
    }
    for (int i = 0; i < _currentExerciseIndex; i++) {
      final sets = _exerciseSets[i] ?? [];
      if (sets.isEmpty) return i;
    }
    return null;
  }

  // ============================================================
  // 組數操作
  // ============================================================

  Future<void> _addSet() async {
    final sets = _exerciseSets[_currentExerciseIndex]!;
    final exerciseName = currentExercise['name'] as String? ?? '';

    int defaultReps = 12;
    double defaultWeight = 0;

    if (sets.isNotEmpty) {
      final lastSet = sets.last;
      defaultReps = lastSet.reps;
      defaultWeight = lastSet.weight;
    } else {
      // 使用計畫中的預設值
      final plannedReps = currentExercise['reps'] as int?;
      if (plannedReps != null && plannedReps > 0) {
        defaultReps = plannedReps;
      } else {
        // 使用歷史記錄
        final savedDefault = _getExerciseDefault(exerciseName);
        defaultReps = savedDefault['reps'] as int? ?? 12;
        defaultWeight = (savedDefault['weight'] as num?)?.toDouble() ?? 0.0;
      }
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

    setState(() => currentSet!.status = 'active');

    _service.adHocStartSet(
      _sessionId!,
      currentExerciseDocId,
      _currentSetIndex,
    );

    _startSetTimer();
    HapticFeedback.mediumImpact();
  }

  void _resumeCurrentSet() {
    if (currentSet == null || currentSet!.status != 'paused') return;

    setState(() => currentSet!.status = 'active');
    _startSetTimer();
    HapticFeedback.mediumImpact();
  }

  Future<void> _completeCurrentSet() async {
    if (currentSet == null) return;

    _stopSetTimer();
    final setDuration = currentSet!.elapsedSeconds;
    currentSet!.durationSec = setDuration;

    // 保存預設值
    final exerciseName = currentExercise['name'] as String? ?? '';
    if (exerciseName.isNotEmpty) {
      _saveExerciseDefault(exerciseName, currentSet!.reps, currentSet!.weight);
    }

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

      setState(() => currentSet!.status = 'completed');
      HapticFeedback.heavyImpact();
      _onExerciseCompleted();
    } else {
      setState(() => currentSet!.status = 'resting');
      final restTime = currentExercise['restSec'] ?? 90;
      _startRestTimer(restTime);
    }
  }

  Future<void> _skipRest() async {
    _restTimer?.cancel();

    if (_isManualResting) {
      setState(() => _isManualResting = false);
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

    setState(() => currentSet!.status = 'skipped');

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

    if (index == _currentSetIndex) return;

    final currentSetData = currentSet;
    if (currentSetData?.status == 'active') {
      _stopSetTimer();
      setState(() => currentSetData!.status = 'paused');
    }

    setState(() => _currentSetIndex = index);
    HapticFeedback.selectionClick();
  }

  // ============================================================
  // 動作切換
  // ============================================================

  void _onPageChanged(int index) {
    if (index == _currentExerciseIndex) return;

    _messageTimer?.cancel();
    setState(() => _completionMessage = null);

    final currentSetData = currentSet;
    if (currentSetData != null) {
      if (currentSetData.status == 'resting') {
        _restTimer?.cancel();
        setState(() => currentSetData.status = 'completed');
      } else if (currentSetData.status == 'active') {
        _stopSetTimer();
        setState(() => currentSetData.status = 'paused');
      }
    }

    if (_isManualResting) {
      _restTimer?.cancel();
      setState(() => _isManualResting = false);
    }

    final newSets = _exerciseSets[index] ?? [];
    int newSetIndex = 0;

    if (newSets.isNotEmpty) {
      final firstIncompleteIndex = newSets.indexWhere((s) =>
          s.status == 'pending' || s.status == 'active' || s.status == 'paused');

      if (firstIncompleteIndex >= 0) {
        newSetIndex = firstIncompleteIndex;
      } else {
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
  // 完成提示
  // ============================================================

  void _showCompletionMessage(String message) {
    _messageTimer?.cancel();

    setState(() => _completionMessage = message);
    HapticFeedback.mediumImpact();

    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _completionMessage = null);
      }
    });
  }

  void _onExerciseCompleted() {
    final nextIndex = _nextIncompleteExerciseIndex;

    if (nextIndex == null) {
      _showAllCompletedCelebration();
    } else {
      _showCompletionMessage('完成！滑動選擇下一個動作');
    }
  }

  void _showAllCompletedCelebration() {
    setState(() => _showCelebration = true);
    _celebrationController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _hideCelebrationAndContinue() {
    setState(() => _showCelebration = false);
  }

  // ============================================================
  // 手動休息
  // ============================================================

  void _startManualRest() {
    if (currentSet?.status == 'active') {
      _stopSetTimer();
      setState(() => currentSet!.status = 'paused');
    }

    setState(() => _isManualResting = true);

    final restTime = currentExercise['restSec'] ?? 90;
    _startRestTimer(restTime);
    HapticFeedback.mediumImpact();
  }

  void _cancelManualRest() {
    _restTimer?.cancel();
    setState(() {
      _isManualResting = false;
      if (currentSet?.status == 'paused') {
        currentSet!.status = 'active';
        _startSetTimer();
      }
    });
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

  double _calculateTotalVolume() {
    double total = 0;
    _exerciseSets.forEach((_, sets) {
      for (var set in sets) {
        if (set.status == 'completed') {
          total += set.weight * set.reps;
        }
      }
    });
    return total;
  }

  // ============================================================
  // 🔥 完成訓練 - 使用 finishPlanSession
  // ============================================================

  void _finishWorkout() async {
    _totalTimer?.cancel();
    _restTimer?.cancel();
    _messageTimer?.cancel();

    final sessionId = _sessionId!;

    try {
      // 🔥 使用 finishPlanSession 而非 finishAdHocSession
      await _service.finishPlanSession(
        sessionId: sessionId,
        planId: widget.planId,
        planName: widget.planName,
        dayOfWeek: widget.dayOfWeek,
        userBodyWeight: _userBodyWeight,
      );
      debugPrint('[完成] 計畫訓練 Session 已完成');
    } catch (e) {
      debugPrint('[錯誤] 計畫訓練完成失敗: $e');
    }

    if (!mounted) return;

    // 🔥 導航到摘要頁面
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
      ),
      (route) => route.isFirst,
    );
  }

  // ============================================================
  // 新增動作
  // ============================================================

  void _showAddExerciseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExercisePickerSheet(
        onExerciseSelected: (exercise) {
          _addExerciseToWorkout(exercise);
        },
      ),
    );
  }

  void _addExerciseToWorkout(Map<String, dynamic> exercise) {
    final newExercise = {
      'name': exercise['name'],
      'category': exercise['category'] ?? '其他',
      'restSec': exercise['restSec'] ?? 90,
      'addedDuringSession': true,
    };

    setState(() {
      _exercises.add(newExercise);
      _exerciseSets[_exercises.length - 1] = [];
    });

    _service.adHocAddExercise(
      sessionId: _sessionId!,
      exercise: newExercise,
    ).catchError((e) => debugPrint('[錯誤] 新增動作同步失敗: $e'));

    Future.delayed(const Duration(milliseconds: 200), () {
      _switchToExercise(_exercises.length - 1);
    });

    HapticFeedback.mediumImpact();
  }

  // ============================================================
  // 工具方法
  // ============================================================

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIconForCard(String category) {
    switch (category) {
      case '胸部': return Icons.fitness_center;
      case '背部': return Icons.sports_kabaddi;
      case '肩部':
      case '肩膀': return Icons.sports_gymnastics;
      case '手臂': return Icons.front_hand;
      case '腿部': return Icons.airline_seat_legroom_extra;
      case '核心':
      case '腹肌': return Icons.self_improvement;
      case '有氧': return Icons.directions_run;
      case '其他': return Icons.sports;
      default: return Icons.fitness_center;
    }
  }

  List<SetStatus> get _setStatuses {
    if (currentTotalSets == 0) return [];
    return List.generate(currentTotalSets, (index) {
      final set = _exerciseSets[_currentExerciseIndex]![index];
      switch (set.status) {
        case 'completed': return SetStatus.completed;
        case 'active': return SetStatus.active;
        case 'paused': return SetStatus.active;
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
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: WorkoutColors.primary),
              const SizedBox(height: 16),
              Text(
                '正在準備訓練...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final isResting = currentSet?.status == 'resting' || _isManualResting;
    const softBackground = Color(0xFFFAFBFC);

    return Scaffold(
      backgroundColor: isResting ? WorkoutColors.rest : softBackground,
      body: Stack(
        children: [
          SafeArea(
            child: isResting ? _buildRestingView() : _buildTrainingView(),
          ),
          if (!isResting && !_showCelebration && currentTotalSets > 0)
            _buildFloatingRestButton(),
          if (_completionMessage != null && !isResting && !_showCelebration)
            _buildCompletionMessage(),
          if (_showCelebration) _buildCelebrationOverlay(),
        ],
      ),
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
                _buildPlanInfoCard(),
                const SizedBox(height: 12),
                _buildSwipeableExerciseCard(),
                const SizedBox(height: 12),
                _buildSetsProgressCard(),
                const SizedBox(height: 12),
                if (currentTotalSets > 0) ...[
                  _buildSwipeHint(),
                  _buildCurrentSetCard(),
                ] else
                  _buildEmptySetPrompt(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.dayOfWeek,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '計畫訓練',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

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
                Text(
                  '${widget.planName} - ${widget.dayOfWeek}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
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
                onTap: _showAddExerciseSheet,
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
    final isAddedDuringSession = exercise['addedDuringSession'] == true;

    final plannedSets = exercise['sets'] as int? ?? 0;

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
                    : [Colors.orange, Colors.orange.withOpacity(0.8)]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isFullyCompleted ? WorkoutColors.success : Colors.orange).withOpacity(0.25),
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
                Row(
                  children: [
                    if (isAddedDuringSession)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '新增',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                    isFullyCompleted
                        ? Icons.check
                        : _getCategoryIconForCard(exercise['category'] ?? '其他'),
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
                            : (plannedSets > 0 ? '計畫 $plannedSets 組' : '尚未開始'),
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
                  ? Colors.orange
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
              const Text('組數進度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                '$completedCount / $currentTotalSets 組',
                style: TextStyle(
                  color: allSetsCompleted ? WorkoutColors.success : Colors.orange,
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
                          final setStatus = _setStatuses[index];

                          Color bgColor;
                          Color textColor;
                          IconData? icon;

                          switch (setStatus) {
                            case SetStatus.completed:
                              bgColor = WorkoutColors.success;
                              textColor = Colors.white;
                              icon = Icons.check;
                              break;
                            case SetStatus.active:
                              bgColor = WorkoutColors.active;
                              textColor = Colors.white;
                              break;
                            case SetStatus.resting:
                              bgColor = WorkoutColors.rest;
                              textColor = Colors.white;
                              break;
                            case SetStatus.skipped:
                              bgColor = Colors.grey[400]!;
                              textColor = Colors.white;
                              icon = Icons.close;
                              break;
                            default:
                              bgColor = Colors.grey[200]!;
                              textColor = Colors.grey[600]!;
                          }

                          return GestureDetector(
                            onTap: () => _onSetTapped(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: bgColor.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                                border: isCurrent
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: icon != null
                                    ? Icon(icon, color: textColor, size: 20)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
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
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.add, color: Colors.orange),
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
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSwipeHint() {
    final set = currentSet;
    if (set == null || set.status != 'active') return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_vertical, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text('上滑完成 · 下滑略過', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildCurrentSetCard() {
    final set = currentSet;
    if (set == null) return const SizedBox();

    final isActive = set.status == 'active';
    final isPaused = set.status == 'paused';
    final isPending = set.status == 'pending';
    final isCompleted = set.status == 'completed';
    final isSkipped = set.status == 'skipped';

    final allSetsCompleted = _exerciseSets[_currentExerciseIndex]?.every(
            (s) => s.status == 'completed' || s.status == 'skipped') ??
        false;

    final canSwipe = isActive && !allSetsCompleted;

    return GestureDetector(
      onVerticalDragStart: canSwipe ? (_) => setState(() => _isCardSwiping = true) : null,
      onVerticalDragUpdate: canSwipe
          ? (details) {
              setState(() {
                _cardSwipeOffset += details.delta.dy;
                _cardSwipeOffset = _cardSwipeOffset.clamp(-100.0, 100.0);
              });
            }
          : null,
      onVerticalDragEnd: canSwipe
          ? (details) {
              if (_cardSwipeOffset < -50) {
                _completeCurrentSet();
                HapticFeedback.heavyImpact();
              } else if (_cardSwipeOffset > 50) {
                _skipCurrentSet();
                HapticFeedback.mediumImpact();
              }
              setState(() {
                _cardSwipeOffset = 0;
                _isCardSwiping = false;
              });
            }
          : null,
      onVerticalDragCancel: () {
        setState(() {
          _cardSwipeOffset = 0;
          _isCardSwiping = false;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isCardSwiping ? 0 : 200),
        transform: Matrix4.translationValues(0, _cardSwipeOffset * 0.3, 0),
        child: Stack(
          children: [
            if (_isCardSwiping && _cardSwipeOffset.abs() > 20)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardSwipeOffset < 0
                        ? WorkoutColors.success.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _cardSwipeOffset < 0 ? Icons.check_circle : Icons.skip_next,
                          size: 32,
                          color: _cardSwipeOffset < 0
                              ? WorkoutColors.success.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cardSwipeOffset < 0 ? '放開完成' : '放開略過',
                          style: TextStyle(
                            fontSize: 12,
                            color: _cardSwipeOffset < 0
                                ? WorkoutColors.success.withOpacity(0.7)
                                : Colors.grey.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: allSetsCompleted
                      ? WorkoutColors.success
                      : isActive
                          ? WorkoutColors.success
                          : isPaused
                              ? WorkoutColors.active
                              : Colors.orange.withOpacity(0.2),
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
                  if (allSetsCompleted) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        final safeOpacity = value.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: safeOpacity,
                          child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: WorkoutColors.success.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle, color: WorkoutColors.success, size: 48),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '此動作已完成',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WorkoutColors.success),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '共完成 ${_exerciseSets[_currentExerciseIndex]?.where((s) => s.status == 'completed').length ?? 0} 組',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _addSet,
                      icon: const Icon(Icons.add),
                      label: const Text('加練一組'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('第 ${_currentSetIndex + 1} 組', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                      isActive
                          ? '訓練中'
                          : isPaused
                              ? '已暫停'
                              : isCompleted
                                  ? '已完成'
                                  : isSkipped
                                      ? '已略過'
                                      : '準備開始',
                      style: TextStyle(
                        color: isActive
                            ? WorkoutColors.success
                            : isPaused
                                ? WorkoutColors.active
                                : isCompleted
                                    ? WorkoutColors.success
                                    : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentSetIndex > 0 && !isCompleted && !isSkipped) ...[
                      _buildPreviousSetHint(),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactNumberInput(
                            label: '次數',
                            value: set.reps,
                            unit: '下',
                            color: Colors.orange,
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
                    if (isPending)
                      _buildCompactButton(
                        label: '開始這組',
                        icon: Icons.play_arrow,
                        color: Colors.orange,
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
                        child: Text('略過本組', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousSetHint() {
    final sets = _exerciseSets[_currentExerciseIndex];
    if (sets == null || _currentSetIndex <= 0) return const SizedBox();

    final previousSet = sets[_currentSetIndex - 1];
    final currentSetData = currentSet;
    if (currentSetData == null) return const SizedBox();

    final isSameAsPrevious =
        currentSetData.reps == previousSet.reps && currentSetData.weight == previousSet.weight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.history, size: 16, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('上一組', style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
                const SizedBox(height: 2),
                Text(
                  '${previousSet.weight.toStringAsFixed(previousSet.weight % 1 == 0 ? 0 : 1)} kg × ${previousSet.reps} 下',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          if (!isSameAsPrevious)
            GestureDetector(
              onTap: () => _copyFromPreviousSet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('複製', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text('已套用', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _copyFromPreviousSet() {
    final sets = _exerciseSets[_currentExerciseIndex];
    if (sets == null || _currentSetIndex <= 0) return;

    final previousSet = sets[_currentSetIndex - 1];
    final current = currentSet;
    if (current == null) return;

    setState(() {
      current.reps = previousSet.reps;
      current.weight = previousSet.weight;
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('已複製：${previousSet.weight.toStringAsFixed(0)} kg × ${previousSet.reps} 下'),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.all(16),
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
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: enabled ? color : Colors.grey),
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
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
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

  Widget _buildEmptySetPrompt() {
    final plannedSets = currentExercise['sets'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            plannedSets > 0 ? '計畫 $plannedSets 組，點擊 + 開始' : '點擊上方 + 新增組數',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingRestButton() {
    final screenSize = MediaQuery.of(context).size;

    _floatingButtonPosition ??= Offset(screenSize.width - 76, screenSize.height - 180);

    return Positioned(
      left: _floatingButtonPosition!.dx,
      top: _floatingButtonPosition!.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            final newX = (_floatingButtonPosition!.dx + details.delta.dx).clamp(0.0, screenSize.width - 60);
            final newY = (_floatingButtonPosition!.dy + details.delta.dy).clamp(100.0, screenSize.height - 120);
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
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(_isDragging ? 0.5 : 0.3),
                  blurRadius: _isDragging ? 16 : 12,
                  offset: const Offset(0, 4),
                  spreadRadius: _isDragging ? 2 : 0,
                ),
              ],
            ),
            child: const Icon(Icons.bedtime_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

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
              BoxShadow(color: WorkoutColors.success.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(_completionMessage!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 休息視圖
  // ============================================================

  Widget _buildRestingView() {
    final progress = _totalRestTime > 0 ? (_totalRestTime - _remainingRestTime) / _totalRestTime : 0.0;

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
                Text('總計 ${_formatDuration(_totalElapsedSeconds)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500),
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
                      style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w300, letterSpacing: 4),
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
              if (!_isManualResting) _buildNextSetPreview(),
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
                    label: Text(_isManualResting ? '繼續訓練' : '跳過休息', style: const TextStyle(fontSize: 16)),
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

  Widget _buildNextSetPreview() {
    final sets = _exerciseSets[_currentExerciseIndex];
    final nextSetIndex = _currentSetIndex + 1;
    final hasNextSet = sets != null && nextSetIndex < sets.length;

    final suggestedReps = currentSet?.reps ?? 12;
    final suggestedWeight = currentSet?.weight ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: _remainingRestTime <= 3 ? Border.all(color: Colors.white.withOpacity(0.5), width: 2) : null,
      ),
      child: Column(
        children: [
          if (_remainingRestTime <= 3 && _remainingRestTime > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('準備開始！', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Text(currentExercise['name'] ?? '下一組', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            hasNextSet ? '第 ${nextSetIndex + 1} 組' : '最後一組',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  children: [
                    Text('建議次數', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    const SizedBox(height: 2),
                    Text('$suggestedReps 下', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),
                Column(
                  children: [
                    Text('建議重量', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    const SizedBox(height: 2),
                    Text('${suggestedWeight.toStringAsFixed(0)} kg',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 慶祝畫面
  // ============================================================

  Widget _buildCelebrationOverlay() {
    final totalCalories = _calculateTotalCalories();

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade500, Colors.orange.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  final scale = 1.0 + (_celebrationController.value * 0.2);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.emoji_events, size: 56, color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('太棒了！', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${widget.planName} 完成', style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _buildCelebrationStat(icon: Icons.timer_outlined, label: '訓練時長', value: _formatDuration(_totalElapsedSeconds)),
                    const Divider(color: Colors.white24, height: 24),
                    _buildCelebrationStat(icon: Icons.local_fire_department, label: '消耗卡路里', value: '${totalCalories.toInt()} kcal'),
                    const Divider(color: Colors.white24, height: 24),
                    _buildCelebrationStat(icon: Icons.fitness_center, label: '完成組數', value: '$_totalCompletedSets 組'),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hideCelebrationAndContinue,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('繼續加練', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _finishWorkout,
                        icon: const Icon(Icons.flag),
                        label: const Text('結束訓練', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Widget _buildCelebrationStat({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('繼續訓練')),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.orange),
              title: const Text('新增動作'),
              onTap: () {
                Navigator.pop(context);
                _showAddExerciseSheet();
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    setState(() => _exercises[_currentExerciseIndex]['restSec'] = seconds);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
                      _showAddExerciseSheet();
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
                  final isAddedDuringSession = exercise['addedDuringSession'] == true;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? Colors.orange
                          : (isCompleted
                              ? WorkoutColors.success.withOpacity(0.2)
                              : (hasProgress ? WorkoutColors.active.withOpacity(0.2) : Colors.grey[200])),
                      child: isCompleted
                          ? const Icon(Icons.check, color: WorkoutColors.success, size: 20)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(color: isCurrent ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold),
                            ),
                    ),
                    title: Row(
                      children: [
                        Text(exercise['name'] ?? '動作 ${index + 1}',
                            style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                        if (isAddedDuringSession) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(8)),
                            child: const Text('新增', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      totalSets > 0 ? (isCompleted ? '已完成' : '$completedSets / $totalSets 組') : '尚未開始',
                      style: TextStyle(color: isCompleted ? WorkoutColors.success : (hasProgress ? WorkoutColors.active : Colors.grey)),
                    ),
                    trailing: isCurrent ? const Icon(Icons.play_arrow, color: Colors.orange) : null,
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

// ============================================================
// 動作選擇器
// ============================================================

class _ExercisePickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onExerciseSelected;

  const _ExercisePickerSheet({required this.onExerciseSelected});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<Map<String, dynamic>> _exercises = [
    {'name': '臥推', 'category': '胸部'},
    {'name': '伏地挺身', 'category': '胸部'},
    {'name': '上斜臥推', 'category': '胸部'},
    {'name': '啞鈴飛鳥', 'category': '胸部'},
    {'name': '引體向上', 'category': '背部'},
    {'name': '硬舉', 'category': '背部'},
    {'name': '槓鈴划船', 'category': '背部'},
    {'name': '滑輪下拉', 'category': '背部'},
    {'name': '深蹲', 'category': '腿部'},
    {'name': '腿推', 'category': '腿部'},
    {'name': '弓箭步', 'category': '腿部'},
    {'name': '腿伸展', 'category': '腿部'},
    {'name': '肩推', 'category': '肩部'},
    {'name': '側平舉', 'category': '肩部'},
    {'name': '二頭彎舉', 'category': '手臂'},
    {'name': '三頭伸展', 'category': '手臂'},
    {'name': '捲腹', 'category': '核心'},
    {'name': '棒式', 'category': '核心'},
    {'name': '跑步', 'category': '有氧'},
    {'name': '跳繩', 'category': '有氧'},
  ];

  List<Map<String, dynamic>> get _filteredExercises {
    if (_searchQuery.isEmpty) return _exercises;
    return _exercises.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                const Expanded(
                  child: Text('新增動作', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: '搜尋動作...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center, color: Colors.orange, size: 20),
                  ),
                  title: Text(exercise['name'] ?? ''),
                  subtitle: Text(exercise['category'] ?? ''),
                  trailing: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onExerciseSelected(exercise);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add, color: Colors.white, size: 18),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onExerciseSelected(exercise);
                  },
                );
              },
            ),
          ),
        ],
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
  int elapsedSeconds;

  SetData({
    required this.reps,
    required this.weight,
    required this.status,
    this.durationSec,
    this.elapsedSeconds = 0,
  });
}