import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';  // 🔥 v5.12 新增：語音播報
import '../../theme/workout_colors.dart';
import '../../components/workout/soft_workout_card.dart';
import '../../services/unified_workout_service.dart';
import '../../services/user_service.dart';
// 🔥 移除：不再依賴外部 import，改用內建離線資料
// import '../../services/wger_api_service.dart';
import '../../utils/exercise_calorie_calculator.dart';
import 'workout_summary_page.dart';

/// 自由訓練執行頁面 - v5.12 手勢操作 + 即時統計 + 休息優化版
/// 
/// 🔥 v5.12 新增功能：
/// - 手勢操作：上滑完成/下滑略過
/// - 休息時間優化：漸進式震動 + 語音倒數播報 + 下一組預覽
/// 
/// 核心功能：
/// 1. 🔥 上一組紀錄提示 + 一鍵複製功能（第 2 組及之後顯示）
/// 2. 🔥 修復：easeOutBack 曲線導致 opacity 超出範圍的錯誤
/// 3. 🔥 新增動作時可從資料庫選擇或手動新增
/// 4. 🔥 支援搜尋、分類瀏覽、最近使用
/// 5. 極簡流程 - 完成動作後提示自動消失，不彈對話框
/// 6. 隨時休息 - 懸浮休息按鈕，任何時候都能休息
/// 7. 全螢幕慶祝 - 全部完成時顯示慶祝畫面
/// 8. 滑動切換 - 左右滑動切換動作
/// 9. 中途新增 - 訓練中可新增動作
/// 10. 計時保留 - 切換組數時暫停計時，回來可繼續
class FreeWorkoutExecutionPage extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final String workoutName;

  const FreeWorkoutExecutionPage({
    super.key,
    required this.exercises,
    this.workoutName = '自由訓練',
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

  // 訓練名稱
  late String _workoutName;

  // 用戶體重（用於卡路里計算）
  double _userBodyWeight = 65.0;

  // 可修改的動作列表（支援中途新增）
  late List<Map<String, dynamic>> _exercises;

  // PageController 用於滑動切換
  late PageController _pageController;

  // 動態組數資料：exerciseIndex -> List<SetData>
  final Map<int, List<SetData>> _exerciseSets = {};

  // 🔥 v5.10 新增：動作預設值記憶（從 Firebase 讀取）
  // 格式：exerciseName -> {reps: 12, weight: 40.0}
  final Map<String, Map<String, dynamic>> _exerciseDefaults = {};

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

  // 🔥 v5.12 新增：手勢操作狀態
  double _cardSwipeOffset = 0;
  bool _isCardSwiping = false;

  // 🔥 v5.12 新增：語音播報
  late FlutterTts _flutterTts;
  bool _ttsInitialized = false;

  @override
  void initState() {
    super.initState();
    _workoutName = widget.workoutName;
    
    _exercises = List<Map<String, dynamic>>.from(
      widget.exercises.map((e) => Map<String, dynamic>.from(e))
    );
    _pageController = PageController(initialPage: 0);
    _initializeAnimations();
    _initTts();  // 🔥 v5.12 新增：初始化語音播報
    _loadUserBodyWeight();
    _loadExerciseDefaults();  // 🔥 v5.10 新增：載入動作預設值
    _initializeSession();
  }

  // 🔥 v5.12 新增：初始化語音播報
  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      // 設定中文語音
      await _flutterTts.setLanguage('zh-TW');
      await _flutterTts.setSpeechRate(0.5);  // 語速
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[TTS] 初始化失敗: $e');
      _ttsInitialized = false;
    }
  }

  // 🔥 v5.12 新增：語音播報
  Future<void> _speak(String text) async {
    if (!_ttsInitialized) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TTS] 播報失敗: $e');
    }
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

  // ============================================================
  // 🔥 v5.10 新增：動作預設值記憶功能
  // ============================================================

  /// 從 Firebase 載入用戶的動作預設值
  Future<void> _loadExerciseDefaults() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
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
      
      // 🔥 v5.11 簡化：只載入不自動套用，保留數據供未來使用
    } catch (e) {
      debugPrint('[警告] 載入動作預設值失敗: $e');
    }
  }

  /// 保存動作的預設值到 Firebase（保留供未來使用）
  Future<void> _saveExerciseDefault(String exerciseName, int reps, double weight) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // 更新本地緩存
      _exerciseDefaults[exerciseName] = {
        'reps': reps,
        'weight': weight,
      };

      // 保存到 Firebase
      await FirebaseFirestore.instance
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

  /// 獲取動作的預設值
  Map<String, dynamic> _getExerciseDefault(String exerciseName) {
    return _exerciseDefaults[exerciseName] ?? {'reps': 12, 'weight': 0.0};
  }

  Future<void> _initializeSession() async {
    try {
      _sessionId = await _service.startAdHocSession(
        exercises: _exercises,
        workoutName: _workoutName,
      );

      for (int i = 0; i < _exercises.length; i++) {
        _exerciseSets[i] = [];
      }

      setState(() => _isInitialized = true);
      _startTotalTimer();
      
      debugPrint('[初始化] 訓練名稱: $_workoutName, SessionId: $_sessionId');
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
    _flutterTts.stop();  // 🔥 v5.12 新增：停止語音播報
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
        
        // 🔥 v5.12 新增：漸進式震動 + 語音播報
        if (_remainingRestTime <= 10 && _remainingRestTime > 0) {
          if (_remainingRestTime <= 3) {
            // 最後 3 秒：重震動 + 語音倒數
            HapticFeedback.heavyImpact();
            _speak('$_remainingRestTime');
          } else if (_remainingRestTime <= 5) {
            // 5-4 秒：中震動
            HapticFeedback.mediumImpact();
          } else {
            // 10-6 秒：輕震動
            HapticFeedback.lightImpact();
          }
        }
      } else {
        _speak('開始');  // 🔥 v5.12 新增：休息結束語音提示
        _onRestComplete();
      }
    });
  }

  Future<void> _onRestComplete() async {
    _restTimer?.cancel();
    HapticFeedback.heavyImpact();
    
    final restTakenSec = _restStartTime;
    
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
    if (currentSet?.status == 'active') {
      _stopSetTimer();
      setState(() {
        currentSet!.status = 'paused';
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
  // 🔥 新增動作 - 完整選擇器版本
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
      'addedDuringSession': true,  // 🔥 標記為訓練中新增
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
  // 組數操作
  // ============================================================

  Future<void> _addSet() async {
    final sets = _exerciseSets[_currentExerciseIndex]!;
    final exerciseName = currentExercise['name'] as String? ?? '';
    
    int defaultReps = 12;
    double defaultWeight = 0;
    
    if (sets.isNotEmpty) {
      // 優先使用本次訓練的上一組數據
      final lastSet = sets.last;
      defaultReps = lastSet.reps;
      defaultWeight = lastSet.weight;
    } else {
      // 🔥 v5.10 新增：使用 Firebase 記憶的預設值
      final savedDefault = _getExerciseDefault(exerciseName);
      defaultReps = savedDefault['reps'] as int? ?? 12;
      defaultWeight = (savedDefault['weight'] as num?)?.toDouble() ?? 0.0;
      
      // 🔥 v5.10.1 修復：檢查是否有記錄（不再只檢查重量）
      if (_exerciseDefaults.containsKey(exerciseName)) {
        debugPrint('[預設值] $exerciseName 使用記憶值：$defaultWeight kg × $defaultReps 下');
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

    // 🔥 v5.10 新增：保存當前重量和次數作為預設值
    // 🔥 v5.10.1 修復：不再限制重量必須 > 0，允許徒手訓練
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

      setState(() {
        currentSet!.status = 'completed';
      });

      HapticFeedback.heavyImpact();
      _onExerciseCompleted();
      
    } else {
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
    
    if (index == _currentSetIndex) return;
    
    if (currentSetData?.status == 'active') {
      _stopSetTimer();
      setState(() => currentSetData!.status = 'paused');
    }
    
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

  // 🔥 獲取分類對應的圖標（用於訓練卡片，優化版）
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
              
              const Text(
                '太棒了！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_workoutName 完成',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
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
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
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
        // 🔥 v5.12 移除：即時訓練統計（太佔空間）
        // _buildQuickStats(),
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
                if (currentTotalSets > 0) ...[
                  _buildSwipeHint(),  // 🔥 v5.12 新增：手勢提示
                  _buildCurrentSetCard(),
                ]
                else
                  _buildEmptySetPrompt(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 🔥 v5.12 新增：即時訓練統計
  // ============================================================

  Widget _buildQuickStats() {
    final totalVolume = _calculateTotalVolume();
    final completedSets = _totalCompletedSets;
    final calories = _calculateTotalCalories();
    
    // 如果還沒開始，不顯示
    if (completedSets == 0) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WorkoutColors.primary.withOpacity(0.1),
            WorkoutColors.active.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
            icon: Icons.fitness_center,
            value: totalVolume >= 1000 
                ? '${(totalVolume / 1000).toStringAsFixed(1)}t'
                : '${totalVolume.toInt()}kg',
            label: '總重量',
            color: WorkoutColors.primary,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withOpacity(0.2),
          ),
          _buildQuickStatItem(
            icon: Icons.check_circle,
            value: '$completedSets',
            label: '完成組數',
            color: WorkoutColors.success,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withOpacity(0.2),
          ),
          _buildQuickStatItem(
            icon: Icons.local_fire_department,
            value: '${calories.toInt()}',
            label: '卡路里',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 計算總訓練量（重量 × 次數）
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
                colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
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
  // 滑動卡片 - 🔥 修改新增按鈕
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
              // 🔥 改用新的選擇器
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
                Row(
                  children: [
                    // 🔥 顯示「新增」標籤
                    if (isAddedDuringSession)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
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
                _buildNextSetPreview(),  // 🔥 v5.12 增強：下一組預覽
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
  // 🔥 v5.12 新增：下一組預覽（增強版）
  // ============================================================

  Widget _buildNextSetPreview() {
    final sets = _exerciseSets[_currentExerciseIndex];
    final nextSetIndex = _currentSetIndex + 1;
    final hasNextSet = sets != null && nextSetIndex < sets.length;
    
    // 建議設定（基於上一組）
    final suggestedReps = currentSet?.reps ?? 12;
    final suggestedWeight = currentSet?.weight ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: _remainingRestTime <= 3 
            ? Border.all(color: Colors.white.withOpacity(0.5), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // 倒數提示（最後 3 秒）
          if (_remainingRestTime <= 3 && _remainingRestTime > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '準備開始！',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          Text(
            currentExercise['name'] ?? '下一組',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            hasNextSet ? '第 ${nextSetIndex + 1} 組' : '最後一組',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 建議設定
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  children: [
                    Text(
                      '建議次數',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$suggestedReps 下',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    Text(
                      '建議重量',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${suggestedWeight.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                Text(
                  _workoutName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          final setStatus = _setStatuses[index];
                          
                          // 🔥 優化：自定義帶數字的進度指示器
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
                                boxShadow: isCurrent ? [
                                  BoxShadow(
                                    color: bgColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ] : null,
                                border: isCurrent ? Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ) : null,
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

    final allSetsCompleted = _exerciseSets[_currentExerciseIndex]?.every(
      (s) => s.status == 'completed' || s.status == 'skipped'
    ) ?? false;

    // 🔥 v5.12 新增：手勢操作支援
    final canSwipe = isActive && !allSetsCompleted;
    
    return GestureDetector(
      onVerticalDragStart: canSwipe ? (_) {
        setState(() => _isCardSwiping = true);
      } : null,
      onVerticalDragUpdate: canSwipe ? (details) {
        setState(() {
          _cardSwipeOffset += details.delta.dy;
          // 限制滑動範圍
          _cardSwipeOffset = _cardSwipeOffset.clamp(-100.0, 100.0);
        });
      } : null,
      onVerticalDragEnd: canSwipe ? (details) {
        if (_cardSwipeOffset < -50) {
          // 上滑超過 50 → 完成當前組
          _completeCurrentSet();
          HapticFeedback.heavyImpact();
        } else if (_cardSwipeOffset > 50) {
          // 下滑超過 50 → 略過當前組
          _skipCurrentSet();
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _cardSwipeOffset = 0;
          _isCardSwiping = false;
        });
      } : null,
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
            // 滑動提示背景
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
            // 主卡片
            Container(
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
          if (allSetsCompleted) ...[
            // 🔥 優化：添加淡入 + 縮放動畫
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                // 🔥 修復：easeOutBack 曲線會超過 1.0，需要 clamp
                final safeOpacity = value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: safeOpacity,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),  // scale 可以超過 1.0，產生彈性效果
                    child: child,
                  ),
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
                ],
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

            // 🔥 v5.11 簡化：只保留「上一組」提示（第 2 組及之後）
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
    ),  // 關閉主卡片 Container
          ],
        ),
      ),  // 關閉 AnimatedContainer
    );  // 關閉 GestureDetector
  }

  // 🔥 v5.12 新增：手勢提示
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
          Text(
            '上滑完成 · 下滑略過',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 v5.9 新增：上一組紀錄提示
  // ============================================================

  Widget _buildPreviousSetHint() {
    final sets = _exerciseSets[_currentExerciseIndex];
    if (sets == null || _currentSetIndex <= 0) return const SizedBox();
    
    final previousSet = sets[_currentSetIndex - 1];
    final currentSetData = currentSet;
    if (currentSetData == null) return const SizedBox();
    
    // 檢查當前值是否與上一組相同
    final isSameAsPrevious = currentSetData.reps == previousSet.reps && 
                              currentSetData.weight == previousSet.weight;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          // 上一組圖標
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.history,
              size: 16,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 10),
          
          // 上一組數據
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上一組',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${previousSet.weight.toStringAsFixed(previousSet.weight % 1 == 0 ? 0 : 1)} kg × ${previousSet.reps} 下',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          // 複製按鈕
          if (!isSameAsPrevious)
            GestureDetector(
              onTap: () => _copyFromPreviousSet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '複製',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '已套用',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
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

  // 🔥 v5.9 新增：從上一組複製數據
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
    
    // 顯示輕量提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('已複製：${previousSet.weight.toStringAsFixed(0)} kg × ${previousSet.reps} 下'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
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
                _showAddExerciseSheet();  // 🔥 改用新方法
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
                      _showAddExerciseSheet();  // 🔥 改用新方法
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
                    title: Row(
                      children: [
                        Text(
                          exercise['name'] ?? '動作 ${index + 1}',
                          style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                        ),
                        if (isAddedDuringSession) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '新增',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
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

// ============================================================
// 🔥 動作選擇器底部彈出視窗
// ============================================================

class _ExercisePickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onExerciseSelected;

  const _ExercisePickerSheet({required this.onExerciseSelected});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedCategory = '胸部';
  String? _expandedCategory;
  
  // 資料
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _recentExercises = [];
  List<Map<String, dynamic>> _customExercises = [];  // 🔥 新增：單獨追蹤自訂動作
  bool _isLoading = true;
  
  // 分類 - 匹配 WgerApiService 的分類
  final List<String> _categories = ['胸部', '背部', '肩部', '手臂', '腿部', '核心', '有氧', '其他'];
  
  // 分類圖標（優化版）
  final Map<String, IconData> _categoryIcons = {
    '胸部': Icons.fitness_center,
    '背部': Icons.sports_kabaddi,       // 🔥 優化：更像背部訓練
    '肩部': Icons.sports_gymnastics,
    '肩膀': Icons.sports_gymnastics,
    '手臂': Icons.front_hand,            // 🔥 優化：手臂圖標
    '腿部': Icons.airline_seat_legroom_extra,  // 🔥 優化：腿部圖標
    '核心': Icons.self_improvement,
    '腹肌': Icons.self_improvement,
    '有氧': Icons.directions_run,
    '其他': Icons.sports,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // 🔥 1. 使用內建離線動作資料庫（50個動作）
      final systemExercises = _getOfflineExercises();
      debugPrint('[動作選擇器] 載入 ${systemExercises.length} 個系統動作');

      // 2. 載入用戶自訂動作（Firebase）
      List<Map<String, dynamic>> userExercises = [];
      if (uid != null) {
        try {
          final userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('customExercises')
              .get();
          
          userExercises = userSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'category': data['category'] ?? '其他',
              'isSystem': false,
            };
          }).toList();
          
          debugPrint('[動作選擇器] 載入 ${userExercises.length} 個自訂動作');
        } catch (e) {
          debugPrint('[動作選擇器] 載入自訂動作失敗: $e');
        }
      }

      // 3. 載入最近使用的動作（從最近的訓練記錄）
      final Set<String> recentNames = {};
      if (uid != null) {
        try {
          final recentSnapshot = await FirebaseFirestore.instance
              .collection('workoutSessions')
              .where('userId', isEqualTo: uid)
              .orderBy('startTime', descending: true)
              .limit(5)
              .get();
          
          for (var doc in recentSnapshot.docs) {
            final exercises = doc.data()['exercises'] as List<dynamic>? ?? [];
            for (var ex in exercises) {
              if (ex is Map) {
                final name = ex['name'] ?? ex['exerciseName'];
                if (name != null) recentNames.add(name.toString());
              }
            }
            if (recentNames.length >= 10) break;
          }
        } catch (e) {
          debugPrint('[動作選擇器] 載入最近動作失敗: $e');
        }
      }

      // 合併所有動作（自訂動作在前面）
      final allExercises = [...userExercises, ...systemExercises];
      
      // 從全部動作中找出最近使用的
      final recentExercises = allExercises
          .where((e) => recentNames.contains(e['name']))
          .toList();

      setState(() {
        _allExercises = allExercises;
        _recentExercises = recentExercises;
        _customExercises = userExercises;  // 🔥 新增：保存自訂動作列表
        _isLoading = false;
      });
      
      debugPrint('[動作選擇器] 總共 ${allExercises.length} 個動作可選擇');
    } catch (e) {
      debugPrint('[錯誤] 載入動作失敗: $e');
      // 🔥 即使出錯也載入離線資料
      setState(() {
        _allExercises = _getOfflineExercises();
        _recentExercises = [];
        _isLoading = false;
      });
    }
  }

  // 🔥 內建離線動作資料庫（50個動作）
  List<Map<String, dynamic>> _getOfflineExercises() {
    return [
      // ========== 胸部 (8個) ==========
      {'id': '1', 'name': '臥推', 'category': '胸部', 'isSystem': true},
      {'id': '2', 'name': '伏地挺身', 'category': '胸部', 'isSystem': true},
      {'id': '3', 'name': '上斜臥推', 'category': '胸部', 'isSystem': true},
      {'id': '4', 'name': '下斜臥推', 'category': '胸部', 'isSystem': true},
      {'id': '5', 'name': '啞鈴飛鳥', 'category': '胸部', 'isSystem': true},
      {'id': '6', 'name': '繩索飛鳥', 'category': '胸部', 'isSystem': true},
      {'id': '7', 'name': '胸部撐體', 'category': '胸部', 'isSystem': true},
      {'id': '8', 'name': '胸推機', 'category': '胸部', 'isSystem': true},
      
      // ========== 背部 (8個) ==========
      {'id': '9', 'name': '引體向上', 'category': '背部', 'isSystem': true},
      {'id': '10', 'name': '硬舉', 'category': '背部', 'isSystem': true},
      {'id': '11', 'name': '槓鈴划船', 'category': '背部', 'isSystem': true},
      {'id': '12', 'name': '滑輪下拉', 'category': '背部', 'isSystem': true},
      {'id': '13', 'name': '啞鈴划船', 'category': '背部', 'isSystem': true},
      {'id': '14', 'name': 'T槓划船', 'category': '背部', 'isSystem': true},
      {'id': '15', 'name': '坐姿划船', 'category': '背部', 'isSystem': true},
      {'id': '16', 'name': '面拉', 'category': '背部', 'isSystem': true},
      
      // ========== 腿部 (10個) ==========
      {'id': '17', 'name': '深蹲', 'category': '腿部', 'isSystem': true},
      {'id': '18', 'name': '前蹲', 'category': '腿部', 'isSystem': true},
      {'id': '19', 'name': '腿推', 'category': '腿部', 'isSystem': true},
      {'id': '20', 'name': '弓箭步', 'category': '腿部', 'isSystem': true},
      {'id': '21', 'name': '腿伸展', 'category': '腿部', 'isSystem': true},
      {'id': '22', 'name': '腿彎舉', 'category': '腿部', 'isSystem': true},
      {'id': '23', 'name': '保加利亞分腿蹲', 'category': '腿部', 'isSystem': true},
      {'id': '24', 'name': '羅馬尼亞硬舉', 'category': '腿部', 'isSystem': true},
      {'id': '25', 'name': '提踵', 'category': '腿部', 'isSystem': true},
      {'id': '26', 'name': '腿內收', 'category': '腿部', 'isSystem': true},
      
      // ========== 肩部 (6個) ==========
      {'id': '27', 'name': '肩推', 'category': '肩部', 'isSystem': true},
      {'id': '28', 'name': '側平舉', 'category': '肩部', 'isSystem': true},
      {'id': '29', 'name': '前平舉', 'category': '肩部', 'isSystem': true},
      {'id': '30', 'name': '後三角飛鳥', 'category': '肩部', 'isSystem': true},
      {'id': '31', 'name': '直立划船', 'category': '肩部', 'isSystem': true},
      {'id': '32', 'name': '阿諾推舉', 'category': '肩部', 'isSystem': true},
      
      // ========== 手臂 (8個) ==========
      {'id': '33', 'name': '二頭彎舉', 'category': '手臂', 'isSystem': true},
      {'id': '34', 'name': '錘式彎舉', 'category': '手臂', 'isSystem': true},
      {'id': '35', 'name': '牧師椅彎舉', 'category': '手臂', 'isSystem': true},
      {'id': '36', 'name': '繩索彎舉', 'category': '手臂', 'isSystem': true},
      {'id': '37', 'name': '三頭伸展', 'category': '手臂', 'isSystem': true},
      {'id': '38', 'name': '三頭撐體', 'category': '手臂', 'isSystem': true},
      {'id': '39', 'name': '仰臥三頭伸展', 'category': '手臂', 'isSystem': true},
      {'id': '40', 'name': '窄握臥推', 'category': '手臂', 'isSystem': true},
      
      // ========== 核心 (6個) ==========
      {'id': '41', 'name': '捲腹', 'category': '核心', 'isSystem': true},
      {'id': '42', 'name': '棒式', 'category': '核心', 'isSystem': true},
      {'id': '43', 'name': '抬腿', 'category': '核心', 'isSystem': true},
      {'id': '44', 'name': '俄羅斯轉體', 'category': '核心', 'isSystem': true},
      {'id': '45', 'name': '登山者', 'category': '核心', 'isSystem': true},
      {'id': '46', 'name': '單車捲腹', 'category': '核心', 'isSystem': true},
      
      // ========== 有氧 (4個) ==========
      {'id': '47', 'name': '跑步', 'category': '有氧', 'isSystem': true},
      {'id': '48', 'name': '騎自行車', 'category': '有氧', 'isSystem': true},
      {'id': '49', 'name': '游泳', 'category': '有氧', 'isSystem': true},
      {'id': '50', 'name': '跳繩', 'category': '有氧', 'isSystem': true},
    ];
  }

  List<Map<String, dynamic>> get _filteredExercises {
    if (_searchQuery.isEmpty) return _allExercises;
    final query = _searchQuery.toLowerCase();
    return _allExercises.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final category = (e['category'] ?? '').toString().toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _exercisesByCategory {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var category in _categories) {
      grouped[category] = _filteredExercises
          .where((e) {
            final exerciseCategory = e['category'] ?? '';
            // 🔥 處理分類別名
            if (category == '肩部' && exerciseCategory == '肩膀') return true;
            if (category == '核心' && exerciseCategory == '腹肌') return true;
            return exerciseCategory == category;
          })
          .toList();
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 拖曳指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 標題
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    '新增動作',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // Tab 切換
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: WorkoutColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 18),
                      SizedBox(width: 6),
                      Text('選擇動作'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 6),
                      Text('自訂動作'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tab 內容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSelectTab(),
                _buildCustomTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 選擇動作 Tab
  // ============================================================

  Widget _buildSelectTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 搜尋框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: '搜尋動作...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 動作列表
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildSearchResults()
              : _buildCategoryList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredExercises;
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '找不到「$_searchQuery」',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _customNameController.text = _searchQuery;
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.add),
              label: const Text('新增為自訂動作'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) => _buildExerciseItem(results[index]),
    );
  }

  Widget _buildCategoryList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 🔥 我的自訂動作（最前面顯示）
        if (_customExercises.isNotEmpty) ...[
          _buildSectionHeader(
            '我的自訂動作',
            _customExercises.length,
            icon: Icons.star,
            iconColor: Colors.amber,
            onTap: () {
              setState(() {
                _expandedCategory = _expandedCategory == '自訂' ? null : '自訂';
              });
            },
            isExpanded: _expandedCategory == '自訂',
          ),
          if (_expandedCategory == '自訂')
            ...(_customExercises.map((e) => _buildExerciseItem(e))),
          const SizedBox(height: 16),
        ],
        
        // 最近使用
        if (_recentExercises.isNotEmpty) ...[
          _buildSectionHeader(
            '最近使用', 
            null,
            icon: Icons.history,
            iconColor: Colors.blueGrey,
          ),
          ...(_recentExercises.take(5).map((e) => _buildExerciseItem(e))),
          const SizedBox(height: 16),
        ],
        
        // 按分類顯示
        ..._categories.map((category) {
          final exercises = _exercisesByCategory[category] ?? [];
          if (exercises.isEmpty) return const SizedBox.shrink();
          
          final isExpanded = _expandedCategory == category;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                category,
                exercises.length,
                icon: _getCategoryIconData(category),
                iconColor: _getCategoryColor(category),
                onTap: () {
                  setState(() {
                    _expandedCategory = isExpanded ? null : category;
                  });
                },
                isExpanded: isExpanded,
              ),
              if (isExpanded)
                ...exercises.map((e) => _buildExerciseItem(e)),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int? count, {
    VoidCallback? onTap, 
    bool isExpanded = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? Colors.grey),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
            const Spacer(),
            if (onTap != null)
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? '未命名';
    final category = exercise['category'] ?? '其他';
    final isSystem = exercise['isSystem'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: WorkoutColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _categoryIcons[category] ?? Icons.fitness_center,
            color: WorkoutColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(
              category,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (!isSystem) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '自訂',
                  style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          onPressed: () => _selectExercise(exercise),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: WorkoutColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
        onTap: () => _selectExercise(exercise),
      ),
    );
  }

  void _selectExercise(Map<String, dynamic> exercise) {
    Navigator.pop(context);
    widget.onExerciseSelected(exercise);
  }

  // 🔥 返回分類的 IconData（優化版）
  IconData _getCategoryIconData(String category) {
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

  // 🔥 返回分類的顏色
  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return Colors.red;
      case '背部': return Colors.blue;
      case '肩部': 
      case '肩膀': return Colors.orange;
      case '手臂': return Colors.purple;
      case '腿部': return Colors.green;
      case '核心': 
      case '腹肌': return Colors.teal;
      case '有氧': return Colors.pink;
      case '其他': return Colors.grey;
      default: return Colors.orange;
    }
  }

  // ============================================================
  // 自訂動作 Tab
  // ============================================================

  Widget _buildCustomTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ========== 新增自訂動作區塊 ==========
        Container(
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
                  Icon(Icons.add_circle, color: WorkoutColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '新增自訂動作',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 動作名稱
              TextField(
                controller: _customNameController,
                decoration: InputDecoration(
                  hintText: '輸入動作名稱，例：啞鈴飛鳥',
                  prefixIcon: const Icon(Icons.fitness_center),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              
              const SizedBox(height: 16),
              
              // 分類選擇
              const Text(
                '選擇分類',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  final iconData = _getCategoryIconData(category);
                  final iconColor = _getCategoryColor(category);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? iconColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? iconColor : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            iconData,
                            size: 16,
                            color: isSelected ? Colors.white : iconColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // 新增按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _customNameController.text.trim().isEmpty
                      ? null
                      : () => _addCustomExercise(),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('新增並加入訓練'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorkoutColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
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
        
        const SizedBox(height: 24),
        
        // ========== 我的自訂動作列表 ==========
        Row(
          children: [
            Icon(Icons.folder_special, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            Text(
              '我的自訂動作',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_customExercises.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        if (_customExercises.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  '還沒有自訂動作',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '在上方新增你的第一個自訂動作吧！',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...(_customExercises.map((exercise) => _buildCustomExerciseItem(exercise))),
        
        const SizedBox(height: 16),
        
        // 提示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '自訂動作會出現在「選擇動作」Tab 的對應分類中',
                  style: TextStyle(fontSize: 13, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔥 新增：自訂動作項目（帶管理功能）
  Widget _buildCustomExerciseItem(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? '未命名';
    final category = exercise['category'] ?? '其他';
    final id = exercise['id'];
    final iconData = _getCategoryIconData(category);
    final iconColor = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(iconData, size: 22, color: iconColor),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '自訂',
                style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 選擇按鈕
            IconButton(
              onPressed: () {
                final exerciseData = {
                  'name': name,
                  'category': category,
                  'restSec': 90,
                };
                Navigator.pop(context);
                widget.onExerciseSelected(exerciseData);
              },
              icon: Icon(Icons.add_circle, color: WorkoutColors.primary, size: 28),
              tooltip: '加入訓練',
            ),
            // 刪除按鈕
            IconButton(
              onPressed: () => _deleteCustomExercise(id, name),
              icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 24),
              tooltip: '刪除',
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 新增：刪除自訂動作
  Future<void> _deleteCustomExercise(String? id, String name) async {
    if (id == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('刪除動作'),
        content: Text('確定要刪除「$name」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('customExercises')
            .doc(id)
            .delete();
        
        // 更新本地狀態
        setState(() {
          _customExercises.removeWhere((e) => e['id'] == id);
          _allExercises.removeWhere((e) => e['id'] == id && e['isSystem'] == false);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已刪除「$name」'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[錯誤] 刪除自訂動作失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCustomExercise() async {
    final name = _customNameController.text.trim();
    if (name.isEmpty) return;

    final exercise = {
      'name': name,
      'category': _selectedCategory,
      'restSec': 90,
    };

    // 儲存到用戶自訂動作
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('customExercises')
            .add({
          'name': name,
          'category': _selectedCategory,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // 🔥 更新本地列表
        final newExercise = {
          'id': docRef.id,
          'name': name,
          'category': _selectedCategory,
          'isSystem': false,
        };
        setState(() {
          _customExercises.insert(0, newExercise);
          _allExercises.insert(0, newExercise);
        });
        
        debugPrint('[動作選擇器] 已新增自訂動作: $name');
      }
    } catch (e) {
      debugPrint('[警告] 儲存自訂動作失敗: $e');
    }

    // 清空輸入
    _customNameController.clear();
    
    Navigator.pop(context);
    widget.onExerciseSelected(exercise);
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