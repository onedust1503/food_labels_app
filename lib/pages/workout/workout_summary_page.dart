// lib/pages/workout/workout_summary_page.dart
// ✅ 完全匹配 UnifiedWorkoutService 數據結構
// ✅ 支援計畫訓練 (source: 'plan') 和自由訓練 (source: 'self')
// ✅ 添加 share_plus 分享功能
// 🔥 v2 新增：顯示訓練名稱（而非固定文字）
// 🔥 v3 新增：時長顯示「X 分 Y 秒」格式
// 🔥 v3 新增：動作數量顯示「+N 新增」標註
// 🔥 v4 新增：本次訓練亮點卡片（最大重量、最多次數、總訓練量）
// 🔥 v5 新增：分享給教練功能（橋樑整合）
//    - 通知教練
//    - 分享到聊天室
//    - 訓練感受輸入（RPE、心情、疲勞度）
// ⚠️ 需要在 pubspec.yaml 添加: share_plus: ^7.2.1

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
// 🔥 v5 修正：明確指定 import 避免衝突
import '../../services/workout_share_service.dart' 
    show WorkoutShareService, WorkoutShareCard, WorkoutFeedback, WorkoutSource, FreeWorkoutType;
import '../../components/workout_feedback_sheet.dart' 
    show WorkoutFeedbackSheet, WorkoutFeedbackResult;

class WorkoutSummaryPage extends StatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? sessionData;

  const WorkoutSummaryPage({
    super.key,
    required this.sessionId,
    this.sessionData,
  });

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage>
    with TickerProviderStateMixin {
  
  // ===== Soft UI 淡綠色配色 =====
  static const Color _primaryColor = Color(0xFF66BB6A);
  static const Color _primaryDark = Color(0xFF4CAF50);
  static const Color _primaryLight = Color(0xFFE8F5E9);
  static const Color _backgroundColor = Color(0xFFF0F4F3);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _accentOrange = Color(0xFFFFB74D);
  static const Color _accentRed = Color(0xFFEF5350);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _accentPurple = Color(0xFFBA68C8);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WorkoutShareService _shareService = WorkoutShareService();  // 🔥 v5 新增

  Map<String, dynamic> _sessionData = {};
  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic> _avgStats = {};
  bool _isLoading = true;
  Set<int> _expandedExercises = {0};

  // 🔥 v4 新增：訓練亮點數據
  Map<String, dynamic> _highlights = {};
  
  // 🔥 v5 新增：是否已分享給教練
  bool _hasSharedToCoach = false;

  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    try {
      if (kDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('🔍 WorkoutSummaryPage 開始載入');
        debugPrint('   SessionId: ${widget.sessionId}');
      }

      // 1. 優先使用傳入的 sessionData
      if (widget.sessionData != null && widget.sessionData!.isNotEmpty) {
        _sessionData = Map<String, dynamic>.from(widget.sessionData!);
        
        if (kDebugMode) {
          debugPrint('📦 使用傳入的 sessionData');
          debugPrint('   Keys: ${_sessionData.keys.toList()}');
          debugPrint('   source: ${_sessionData['source']}');
          debugPrint('   planName: ${_sessionData['planName']}');
          debugPrint('   name: ${_sessionData['name']}');
          debugPrint('   duration: ${_sessionData['duration']}');
          debugPrint('   totalDurationSeconds: ${_sessionData['totalDurationSeconds']}');
          debugPrint('   totalCalories: ${_sessionData['totalCalories']}');
          debugPrint('   totalSets: ${_sessionData['totalSets']}');
          debugPrint('   totalExercises: ${_sessionData['totalExercises']}');
          debugPrint('   addedExercisesCount: ${_sessionData['addedExercisesCount']}');
        }
        
        // 提取 exercises
        _extractExercises();
      }

      // 2. 如果沒有數據或 exercises 為空，從 Firestore 讀取
      if (_sessionData.isEmpty || _exercises.isEmpty) {
        await _loadFromFirestore();
      }

      // 3. 載入歷史平均數據（用於對比）
      await _loadAverageStats();

      // 🔥 v4 新增：計算訓練亮點
      _calculateHighlights();
      
      // 🔥 v5 新增：檢查是否已分享給教練
      _hasSharedToCoach = _sessionData['feedback'] != null;

      if (mounted) {
        setState(() => _isLoading = false);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _celebrationController.forward();
        });
      }

      if (kDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('✅ 載入完成:');
        debugPrint('   訓練類型: ${_isPlanWorkout ? "計畫訓練" : "自由訓練"}');
        debugPrint('   🔥 訓練名稱: $_workoutName');
        debugPrint('   計畫名稱: $_planName');
        debugPrint('   訓練時長: $_durationDisplay');
        debugPrint('   動作數量: $_totalExercises (新增: $_addedExercisesCount)');
        debugPrint('   總組數: $_totalSets');
        debugPrint('   完成組數: $_completedSets');
        debugPrint('   消耗卡路里: $_calories');
        debugPrint('   🏆 訓練亮點: $_highlights');
        debugPrint('   📤 已分享給教練: $_hasSharedToCoach');
        debugPrint('═══════════════════════════════════════════');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ 載入失敗: $e');
        debugPrint('$stack');
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 從 sessionData 提取 exercises
  void _extractExercises() {
    if (!_sessionData.containsKey('exercises') || _sessionData['exercises'] == null) {
      if (kDebugMode) debugPrint('⚠️ sessionData 中沒有 exercises');
      return;
    }

    final exercisesData = _sessionData['exercises'];
    if (exercisesData is! List) {
      if (kDebugMode) debugPrint('⚠️ exercises 不是 List 類型');
      return;
    }

    _exercises = exercisesData.map((e) {
      if (e is Map) {
        return Map<String, dynamic>.from(e);
      }
      return <String, dynamic>{};
    }).where((e) => e.isNotEmpty).toList();

    if (kDebugMode) {
      debugPrint('📋 提取到 ${_exercises.length} 個動作:');
      for (int i = 0; i < _exercises.length; i++) {
        final ex = _exercises[i];
        final name = ex['name'] ?? ex['exerciseName'] ?? '未命名';
        final completedSets = ex['completedSets'] ?? 0;
        final sets = ex['sets'] as List? ?? [];
        final isAdded = ex['addedDuringSession'] == true;
        debugPrint('   ${i + 1}. $name - completedSets: $completedSets, sets.length: ${sets.length}${isAdded ? ' [新增]' : ''}');
        
        // 檢查 sets 結構
        if (sets.isNotEmpty) {
          final firstSet = sets[0];
          debugPrint('      首組結構: ${firstSet.keys}');
          debugPrint('      reps: ${firstSet['reps']}, weight: ${firstSet['weight']}, status: ${firstSet['status']}');
        }
      }
    }
  }

  Future<void> _loadFromFirestore() async {
    if (kDebugMode) debugPrint('🔄 從 Firestore 載入數據...');

    // 嘗試從 workoutSessions 頂層集合讀取
    final doc = await _firestore
        .collection('workoutSessions')
        .doc(widget.sessionId)
        .get();

    if (doc.exists) {
      _sessionData = Map<String, dynamic>.from(doc.data()!);
      if (kDebugMode) {
        debugPrint('✅ 從 workoutSessions 讀取成功');
        debugPrint('   source: ${_sessionData['source']}');
        debugPrint('   planName: ${_sessionData['planName']}');
        debugPrint('   🔥 name: ${_sessionData['name']}');
      }
      _extractExercises();
      return;
    }

    // 嘗試從 users/{uid}/workoutSessions 讀取
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workoutSessions')
          .doc(widget.sessionId)
          .get();

      if (userDoc.exists) {
        _sessionData = Map<String, dynamic>.from(userDoc.data()!);
        if (kDebugMode) debugPrint('✅ 從 users/workoutSessions 讀取成功');

        // 如果 exercises 為空，嘗試讀取子集合
        if (!_sessionData.containsKey('exercises') || 
            (_sessionData['exercises'] as List?)?.isEmpty == true) {
          await _loadExercisesFromSubcollection(userDoc.reference);
        } else {
          _extractExercises();
        }
      }
    }
  }

  /// 從子集合讀取 exercises（備用方案）
  Future<void> _loadExercisesFromSubcollection(DocumentReference sessionRef) async {
    if (kDebugMode) debugPrint('📂 從子集合讀取 exercises...');
    
    final exercisesSnap = await sessionRef.collection('exercises').get();
    if (exercisesSnap.docs.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ 子集合中沒有 exercises');
      return;
    }

    _exercises = [];
    for (final exDoc in exercisesSnap.docs) {
      final exData = Map<String, dynamic>.from(exDoc.data());
      
      // 讀取 sets 子集合
      final setsSnap = await exDoc.reference.collection('sets').orderBy('index').get();
      final sets = setsSnap.docs.map((s) {
        final setData = Map<String, dynamic>.from(s.data());
        // 轉換欄位名稱以匹配 UnifiedWorkoutService 的輸出格式
        return {
          'setIndex': setData['index'],
          'reps': setData['actualReps'] ?? setData['targetReps'],
          'weight': setData['weight'],
          'status': setData['status'],
          'durationSec': setData['actualDurationSec'],
        };
      }).toList();
      
      // 計算完成組數
      final completedSets = sets.where((s) => 
        s['status'] == 'completed' || s['status'] == 'resting'
      ).length;
      
      exData['name'] = exData['exerciseName'] ?? exData['name'] ?? '未命名';
      exData['sets'] = sets;
      exData['completedSets'] = completedSets;
      
      _exercises.add(exData);
    }
    
    if (kDebugMode) debugPrint('✅ 從子集合讀取到 ${_exercises.length} 個動作');
  }

  Future<void> _loadAverageStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      int totalDuration = 0;
      double totalCalories = 0;
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isAfter(thirtyDaysAgo)) {
          totalDuration += (data['duration'] ?? 0) as int;
          totalCalories += (data['caloriesBurned'] ?? 0.0).toDouble();
          count++;
        }
      }

      if (count > 0) {
        _avgStats = {
          'avgDuration': (totalDuration / count).round(),
          'avgCalories': (totalCalories / count).round(),
          'totalSessions': count,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 載入平均數據失敗: $e');
    }
  }

  // 🔥 v4 新增：計算本次訓練亮點
  void _calculateHighlights() {
    if (_exercises.isEmpty) return;

    double maxWeight = 0;
    String maxWeightExercise = '';
    int maxReps = 0;
    String maxRepsExercise = '';
    double totalVolume = 0;
    int longestSet = 0;
    String longestSetExercise = '';
    
    for (var exercise in _exercises) {
      final name = exercise['name'] ?? exercise['exerciseName'] ?? '未知動作';
      final sets = exercise['sets'] as List? ?? [];
      
      for (var set in sets) {
        if (set is! Map) continue;
        final status = set['status'] as String? ?? '';
        if (status != 'completed' && status != 'resting') continue;
        
        final weight = (set['weight'] as num?)?.toDouble() ?? 0;
        final reps = (set['reps'] as num?)?.toInt() ?? 0;
        final duration = (set['durationSec'] as num?)?.toInt() ?? 0;
        
        // 最大重量
        if (weight > maxWeight) {
          maxWeight = weight;
          maxWeightExercise = name;
        }
        
        // 最多次數
        if (reps > maxReps) {
          maxReps = reps;
          maxRepsExercise = name;
        }
        
        // 總訓練量（重量 × 次數）
        totalVolume += weight * reps;
        
        // 最長單組時間
        if (duration > longestSet) {
          longestSet = duration;
          longestSetExercise = name;
        }
      }
    }
    
    _highlights = {
      'maxWeight': maxWeight,
      'maxWeightExercise': maxWeightExercise,
      'maxReps': maxReps,
      'maxRepsExercise': maxRepsExercise,
      'totalVolume': totalVolume,
      'longestSet': longestSet,
      'longestSetExercise': longestSetExercise,
    };
  }

  // 🔥 v4 新增：是否有亮點數據可顯示
  bool get _hasHighlights {
    return (_highlights['maxWeight'] as double? ?? 0) > 0 ||
           (_highlights['maxReps'] as int? ?? 0) > 0;
  }

  // ===== 數據計算（完全匹配 UnifiedWorkoutService 格式）=====
  
  /// 是否為計畫訓練
  bool get _isPlanWorkout {
    return _sessionData['source'] == 'plan' || 
           _sessionData['planId'] != null ||
           _sessionData['planName'] != null;
  }

  /// 🔥 訓練名稱（用於顯示）
  String get _workoutName {
    // 優先使用 name 欄位（訓練命名功能存儲的值）
    if (_sessionData['name'] != null && 
        (_sessionData['name'] as String).isNotEmpty &&
        _sessionData['name'] != '自由訓練') {
      return _sessionData['name'] as String;
    }
    
    // 計畫訓練使用 planName
    if (_isPlanWorkout) {
      return _sessionData['planName'] ?? '計畫訓練';
    }
    
    // 預設
    return _sessionData['name'] ?? '自由訓練';
  }

  /// 計畫名稱（僅計畫訓練有）
  String? get _planName => _sessionData['planName'] as String?;
  
  /// 計畫ID
  String? get _planId => _sessionData['planId'] as String?;
  
  /// 星期幾（僅計畫訓練有）
  String? get _dayOfWeek => _sessionData['dayOfWeek'] as String?;

  /// 🔥 訓練時長（總秒數）
  int get _totalDurationSeconds {
    // 優先使用 totalDurationSeconds
    if (_sessionData['totalDurationSeconds'] != null) {
      return (_sessionData['totalDurationSeconds'] as num).toInt();
    }
    // 從時間戳計算
    final start = _parseTimestamp(_sessionData['startedAt']);
    final end = _parseTimestamp(_sessionData['endedAt'] ?? _sessionData['completedAt']);
    if (start != null && end != null) {
      return end.difference(start).inSeconds.clamp(1, 99999);
    }
    // 備用：從 duration (分鐘) 轉換
    if (_sessionData['duration'] != null) {
      return ((_sessionData['duration'] as num).toInt() * 60);
    }
    return 0;
  }

  /// 訓練時長（分鐘）- 保留向後相容
  int get _duration {
    return (_totalDurationSeconds / 60).ceil().clamp(1, 999);
  }

  /// 🔥 時長顯示字串（X 分 Y 秒）
  String get _durationDisplay {
    final totalSec = _totalDurationSeconds;
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    
    if (minutes > 0 && seconds > 0) {
      return '$minutes 分 $seconds 秒';
    } else if (minutes > 0) {
      return '$minutes 分鐘';
    } else {
      return '$seconds 秒';
    }
  }

  /// 動作數量
  int get _totalExercises {
    // 優先使用 exercises 列表長度
    if (_exercises.isNotEmpty) return _exercises.length;
    // 備用：從 sessionData 讀取
    return (_sessionData['totalExercises'] ?? 0) as int;
  }

  /// 🔥 新增動作數量
  int get _addedExercisesCount {
    // 優先從 sessionData 讀取（UnifiedWorkoutService 計算好的值）
    if (_sessionData['addedExercisesCount'] != null) {
      return (_sessionData['addedExercisesCount'] as num).toInt();
    }
    // 備用：從 exercises 計算
    int count = 0;
    for (var ex in _exercises) {
      if (ex['addedDuringSession'] == true) {
        count++;
      }
    }
    return count;
  }
  
  /// 總組數
  int get _totalSets {
    // 優先從 sessionData 讀取（UnifiedWorkoutService 計算好的值）
    if (_sessionData['totalSets'] != null && (_sessionData['totalSets'] as num).toInt() > 0) {
      return (_sessionData['totalSets'] as num).toInt();
    }
    // 備用：從 exercises 計算
    int total = 0;
    for (var ex in _exercises) {
      // 使用 completedSets（UnifiedWorkoutService 計算好的）
      if (ex['completedSets'] != null && (ex['completedSets'] as num).toInt() > 0) {
        total += (ex['completedSets'] as num).toInt();
      } else {
        // 從 sets 計算
        final sets = ex['sets'] as List? ?? [];
        total += sets.where((s) {
          if (s is! Map) return false;
          final status = s['status'] as String?;
          return status == 'completed' || status == 'resting';
        }).length;
      }
    }
    return total;
  }

  /// 完成組數
  int get _completedSets {
    // 與 totalSets 相同，因為 UnifiedWorkoutService 只記錄已完成的組
    return _totalSets;
  }

  /// 消耗卡路里
  double get _calories {
    // UnifiedWorkoutService 同時寫入 totalCalories 和 caloriesBurned
    if (_sessionData['totalCalories'] != null) {
      return (_sessionData['totalCalories'] as num).toDouble();
    }
    if (_sessionData['caloriesBurned'] != null) {
      return (_sessionData['caloriesBurned'] as num).toDouble();
    }
    return 0.0;
  }

  /// 時間範圍字串
  String get _timeRange {
    final start = _parseTimestamp(_sessionData['startedAt'] ?? _sessionData['timestamp']);
    final end = _parseTimestamp(_sessionData['endedAt'] ?? _sessionData['completedAt']);
    if (start != null && end != null) {
      return '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    }
    if (start != null) {
      return DateFormat('HH:mm').format(start);
    }
    return '--:--';
  }

  /// 日期字串
  String get _dateString {
    // 優先使用 date 欄位
    if (_sessionData['date'] != null) {
      try {
        final date = DateTime.parse(_sessionData['date'] as String);
        return DateFormat('yyyy年M月d日 (E)', 'zh_TW').format(date);
      } catch (_) {}
    }
    // 備用：從時間戳解析
    final start = _parseTimestamp(_sessionData['startedAt'] ?? _sessionData['timestamp'] ?? _sessionData['createdAt']);
    if (start != null) {
      return DateFormat('yyyy年M月d日 (E)', 'zh_TW').format(start);
    }
    return DateFormat('yyyy年M月d日 (E)', 'zh_TW').format(DateTime.now());
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  // ===== 🔥 分享內容生成（更新：包含訓練名稱和亮點）=====
  String _generateShareText() {
    final buffer = StringBuffer();
    
    // 🔥 使用訓練名稱
    buffer.writeln('🏋️ $_workoutName 完成！');
    buffer.writeln();
    
    // 計畫訓練額外資訊
    if (_isPlanWorkout && _planName != null && _planName != _workoutName) {
      buffer.writeln('📋 $_planName');
      if (_dayOfWeek != null) {
        buffer.writeln('📆 $_dayOfWeek');
      }
    }
    
    buffer.writeln('📅 $_dateString');
    buffer.writeln('⏱️ 時長：$_durationDisplay');
    buffer.writeln('🔥 消耗：${_calories.toInt()} 大卡');
    buffer.writeln('💪 動作：$_totalExercises 個${_addedExercisesCount > 0 ? '（+$_addedExercisesCount 新增）' : ''}');
    buffer.writeln('✅ 組數：$_completedSets/$_totalSets');
    buffer.writeln();
    
    // 🔥 v4 新增：添加訓練亮點
    if (_hasHighlights) {
      buffer.writeln('🏆 本次亮點：');
      final maxWeight = _highlights['maxWeight'] as double? ?? 0;
      final maxReps = _highlights['maxReps'] as int? ?? 0;
      final totalVolume = _highlights['totalVolume'] as double? ?? 0;
      
      if (maxWeight > 0) {
        buffer.writeln('  • 最大重量：${maxWeight.toStringAsFixed(1)} kg（${_highlights['maxWeightExercise']}）');
      }
      if (maxReps > 0) {
        buffer.writeln('  • 最多次數：$maxReps 下（${_highlights['maxRepsExercise']}）');
      }
      if (totalVolume > 0) {
        buffer.writeln('  • 總訓練量：${(totalVolume / 1000).toStringAsFixed(1)} 噸');
      }
      buffer.writeln();
    }
    
    // 添加動作摘要
    if (_exercises.isNotEmpty) {
      buffer.writeln('📝 訓練內容：');
      for (int i = 0; i < _exercises.length && i < 5; i++) {
        final ex = _exercises[i];
        final name = ex['name'] ?? ex['exerciseName'] ?? '動作${i + 1}';
        final completedSets = ex['completedSets'] ?? 0;
        final isAdded = ex['addedDuringSession'] == true;
        buffer.writeln('  • $name ($completedSets 組)${isAdded ? ' [新增]' : ''}');
      }
      if (_exercises.length > 5) {
        buffer.writeln('  ... 還有 ${_exercises.length - 5} 個動作');
      }
      buffer.writeln();
    }
    
    buffer.writeln('#健身 #訓練記錄 #FitDiet');
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryColor),
              const SizedBox(height: 16),
              Text('載入訓練數據...', style: TextStyle(color: _textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSuccessHeader(),
                  const SizedBox(height: 20),
                  _buildStatsCard(),
                  // 🔥 v4 新增：訓練亮點卡片
                  if (_hasHighlights) ...[
                    const SizedBox(height: 16),
                    _buildHighlightsCard(),
                  ],
                  // 🔥 v5 新增：分享給教練卡片
                  const SizedBox(height: 16),
                  _buildShareToCoachCard(),
                  if (_avgStats.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildComparisonCard(),
                  ],
                  if (_exercises.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildExercisesList(),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: _backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8),
            ],
          ),
          child: Icon(Icons.close_rounded, color: _textPrimary, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '訓練總結',
        style: TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 8),
                ],
              ),
              child: Icon(Icons.share_rounded, color: _textPrimary, size: 20),
            ),
            onPressed: _showShareOptions,
          ),
        ),
      ],
    );
  }

  // 🔥 修改：顯示訓練名稱
  Widget _buildSuccessHeader() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha(77),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // 成功圖標
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            
            // 🔥 訓練名稱（主標題）
            Text(
              _workoutName,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 26, 
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            
            // 🔥 「完成」標籤
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51), 
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded, 
                    color: Colors.white.withAlpha(230), 
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '訓練完成',
                    style: TextStyle(
                      color: Colors.white.withAlpha(230), 
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // 計畫名稱（僅計畫訓練且名稱不同時顯示）
            if (_isPlanWorkout && _planName != null && _planName != _workoutName) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38), 
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_rounded, 
                      color: Colors.white.withAlpha(200), 
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _planName!, 
                      style: TextStyle(
                        color: Colors.white.withAlpha(200), 
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // 星期幾（僅計畫訓練顯示）
            if (_isPlanWorkout && _dayOfWeek != null) ...[
              const SizedBox(height: 6),
              Text(
                _dayOfWeek!,
                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 日期
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38), 
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded, 
                    color: Colors.white.withAlpha(217), 
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dateString, 
                    style: TextStyle(
                      color: Colors.white.withAlpha(230), 
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 修改：時長顯示「X 分 Y 秒」格式，動作數量顯示「+N 新增」
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '訓練數據',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _timeRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // 🔥 時長：顯示「X 分 Y 秒」格式
              Expanded(
                child: _buildStatBoxWithString(
                  icon: Icons.timer_rounded, 
                  value: _durationDisplay, 
                  label: '訓練時長', 
                  color: _accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              // 🔥 動作數量：顯示「+N 新增」
              Expanded(
                child: _buildStatBoxWithSubtext(
                  icon: Icons.fitness_center_rounded, 
                  value: '$_totalExercises', 
                  subtext: _addedExercisesCount > 0 ? '+$_addedExercisesCount 新增' : null,
                  unit: '個', 
                  label: '動作數量', 
                  color: _accentPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  icon: Icons.repeat_rounded,
                  value: '$_completedSets/$_totalSets',
                  unit: '',
                  label: '完成組數',
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.local_fire_department_rounded,
                  value: '${_calories.toInt()}',
                  unit: '大卡',
                  label: '消耗熱量',
                  color: _accentRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 🔥 新增：顯示字串格式的統計框（用於時長）
  Widget _buildStatBoxWithString({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 🔥 新增：帶有副標題的統計框（用於動作數量 +N 新增）
  Widget _buildStatBoxWithSubtext({
    required IconData icon, 
    required String value, 
    String? subtext,
    required String unit, 
    required String label, 
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          // 🔥 新增動作標註
          if (subtext != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentOrange.withAlpha(38),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtext, 
                style: TextStyle(
                  color: _accentOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // 🔥 v4 新增：訓練亮點卡片
  Widget _buildHighlightsCard() {
    final maxWeight = _highlights['maxWeight'] as double? ?? 0;
    final maxReps = _highlights['maxReps'] as int? ?? 0;
    final totalVolume = _highlights['totalVolume'] as double? ?? 0;
    final longestSet = _highlights['longestSet'] as int? ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(77),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '本次訓練亮點',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.star_rounded, color: Colors.white, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            
            // 亮點項目
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (maxWeight > 0)
                  _buildHighlightItem(
                    icon: Icons.fitness_center_rounded,
                    label: '最大重量',
                    value: '${maxWeight.toStringAsFixed(1)} kg',
                    subtitle: _highlights['maxWeightExercise'] as String? ?? '',
                  ),
                if (maxReps > 0)
                  _buildHighlightItem(
                    icon: Icons.repeat_rounded,
                    label: '最多次數',
                    value: '$maxReps 下',
                    subtitle: _highlights['maxRepsExercise'] as String? ?? '',
                  ),
                if (totalVolume > 0)
                  _buildHighlightItem(
                    icon: Icons.show_chart_rounded,
                    label: '總訓練量',
                    value: '${(totalVolume / 1000).toStringAsFixed(1)} 噸',
                    subtitle: '重量 × 次數',
                  ),
                if (longestSet > 30)  // 只顯示超過30秒的
                  _buildHighlightItem(
                    icon: Icons.timer_rounded,
                    label: '最長單組',
                    value: '$longestSet 秒',
                    subtitle: _highlights['longestSetExercise'] as String? ?? '',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightItem({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final itemWidth = (MediaQuery.of(context).size.width - 72) / 2 - 5;
    
    return Container(
      width: itemWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 v5 新增：分享給教練卡片
  // ═══════════════════════════════════════════════════════════════
  Widget _buildShareToCoachCard() {
    final themeColor = _isPlanWorkout ? Colors.orange : Colors.blue;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hasSharedToCoach 
              ? _primaryColor.withAlpha(100) 
              : themeColor.withAlpha(100),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasSharedToCoach 
                      ? _primaryLight 
                      : themeColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _hasSharedToCoach 
                      ? Icons.check_circle_rounded 
                      : Icons.send_rounded,
                  color: _hasSharedToCoach ? _primaryColor : themeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasSharedToCoach ? '已分享給教練' : '分享給教練',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasSharedToCoach 
                          ? '教練可以在聊天室查看你的訓練記錄'
                          : '讓教練了解你的訓練狀況，獲得專業回饋',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 分享按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _hasSharedToCoach ? null : _shareToCoach,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasSharedToCoach 
                    ? Colors.grey[300] 
                    : themeColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[200],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                _hasSharedToCoach 
                    ? Icons.check_rounded 
                    : Icons.chat_bubble_outline_rounded,
                size: 20,
              ),
              label: Text(
                _hasSharedToCoach ? '已分享' : '記錄感受並分享',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          
          // 提示文字
          if (!_hasSharedToCoach) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, 
                    color: _textSecondary.withAlpha(150), size: 14),
                const SizedBox(width: 6),
                Text(
                  '記錄 RPE、心情、疲勞度等訓練感受',
                  style: TextStyle(
                    color: _textSecondary.withAlpha(150),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 v5 新增：分享給教練的邏輯
  Future<void> _shareToCoach() async {
    // 顯示訓練感受輸入彈窗
    final result = _isPlanWorkout
        ? await WorkoutFeedbackSheet.showForPlan(
            context,
            workoutName: _workoutName,
            planName: _planName ?? _workoutName,
            durationMinutes: _duration,
            caloriesBurned: _calories,
          )
        : await WorkoutFeedbackSheet.showForFree(
            context,
            workoutName: _workoutName,
            freeWorkoutType: _sessionData['workoutType'] ?? 'weight_training',
            freeWorkoutCategory: _sessionData['category'],
            durationMinutes: _duration,
            caloriesBurned: _calories,
          );

    if (result == null || !mounted) return;

    // 顯示載入中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: _isPlanWorkout ? Colors.orange : Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text('正在分享給教練...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 創建分享卡片
      final shareCard = _isPlanWorkout
          ? WorkoutShareCard.fromPlan(
              sessionId: widget.sessionId,
              workoutName: _workoutName,
              planName: _planName ?? _workoutName,
              planDayOfWeek: _dayOfWeek ?? '',
              durationMinutes: _duration,
              caloriesBurned: _calories,
              exerciseCount: _totalExercises,
              totalSets: _totalSets,
              isOnSchedule: true,
              statusLabel: '準時',
              feedback: result.feedback,
              completedAt: DateTime.now(),
              highlights: _highlights,
            )
          : WorkoutShareCard.fromFree(
              sessionId: widget.sessionId,
              workoutName: _workoutName,
              freeWorkoutType: _sessionData['workoutType'] ?? 'weight_training',
              freeWorkoutCategory: _sessionData['category'],
              durationMinutes: _duration,
              caloriesBurned: _calories,
              exerciseCount: _totalExercises,
              totalSets: _totalSets,
              feedback: result.feedback,
              completedAt: DateTime.now(),
              highlights: _highlights,
            );

      // 執行分享流程
      await _shareService.completeWorkoutWithFeedback(
        shareCard: shareCard,
        feedback: result.feedback,
        notifyCoach: result.shareToCoach,
        autoShareToChat: result.shareToChat,
      );

      if (mounted) {
        Navigator.pop(context); // 關閉載入對話框
        
        setState(() {
          _hasSharedToCoach = true;
        });

        // 顯示成功訊息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(result.shareToChat 
                    ? '已分享到聊天室！' 
                    : '已通知教練！'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: _primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 關閉載入對話框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('分享失敗：$e'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildComparisonCard() {
    final avgDuration = (_avgStats['avgDuration'] ?? 0) as int;
    final avgCalories = (_avgStats['avgCalories'] ?? 0) as int;
    final int durationDiff = _duration - avgDuration;
    final int caloriesDiff = _calories.toInt() - avgCalories;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentOrange.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: _accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '與近30天平均對比',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildComparisonItem(
                  label: '訓練時長',
                  current: '$_duration 分鐘',
                  diff: durationDiff,
                  unit: '分鐘',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: _textSecondary.withAlpha(38),
              ),
              Expanded(
                child: _buildComparisonItem(
                  label: '消耗熱量',
                  current: '${_calories.toInt()} 大卡',
                  diff: caloriesDiff,
                  unit: '大卡',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem({
    required String label,
    required String current,
    required int diff,
    required String unit,
  }) {
    final isPositive = diff >= 0;
    final diffColor = isPositive ? _primaryColor : _accentRed;
    final diffIcon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Column(
      children: [
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          current,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: diffColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(diffIcon, color: diffColor, size: 14),
              const SizedBox(width: 2),
              Text(
                '${diff.abs()} $unit',
                style: TextStyle(
                  color: diffColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.list_alt_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '動作詳情',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 🔥 修改：顯示新增動作數量
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_exercises.length} 個動作',
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_addedExercisesCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _accentOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$_addedExercisesCount',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            _exercises.length,
            (index) => _buildExerciseItem(index, _exercises[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(int index, Map<String, dynamic> exercise) {
    // 支援 UnifiedWorkoutService 的欄位名稱
    final name = exercise['name'] ?? exercise['exerciseName'] ?? '未知動作';
    final category = exercise['category'] as String?;
    final allSets = exercise['sets'] as List? ?? [];
    final isAddedDuringSession = exercise['addedDuringSession'] == true;
    
    // UnifiedWorkoutService 已經過濾，所以 sets 都是有效的
    final completedSetsCount = (exercise['completedSets'] as num?)?.toInt() ?? allSets.length;
    final isExpanded = _expandedExercises.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _primaryLight.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedExercises.remove(index);
              } else {
                _expandedExercises.add(index);
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // 🔥 新增：新增動作標籤
                            if (isAddedDuringSession) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '新增',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '完成 $completedSetsCount 組',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            if (category != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentPurple.withAlpha(26),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: _accentPurple,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (allSets.isNotEmpty)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textSecondary,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded && allSets.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: List.generate(allSets.length, (setIndex) {
                  final set = allSets[setIndex];
                  if (set is! Map) return const SizedBox.shrink();
                  
                  // UnifiedWorkoutService 的 sets 結構
                  // { setIndex, reps, weight, durationSec, calories, rpe, note, status }
                  final status = set['status'] as String? ?? 'completed';
                  final reps = set['reps'] ?? set['actualReps'] ?? 0;
                  final weight = (set['weight'] as num?)?.toDouble() ?? 0.0;
                  final setCalories = (set['calories'] as num?)?.toDouble();

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: setIndex < allSets.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: _textSecondary.withAlpha(26),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        // 組數編號
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primaryColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${setIndex + 1}',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 狀態圖標
                        Icon(
                          status == 'completed'
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline,
                          color: status == 'completed'
                              ? _primaryColor
                              : _textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == 'completed' ? '完成' : '略過',
                          style: TextStyle(
                            color: status == 'completed'
                                ? _primaryColor
                                : _textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        // 次數
                        if (reps != null && reps > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentBlue.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$reps 次',
                              style: TextStyle(
                                color: _accentBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // 重量
                        if (weight > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentOrange.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1)} kg',
                              style: TextStyle(
                                color: _accentOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        // 卡路里（如果有）
                        if (setCalories != null && setCalories > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentRed.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${setCalories.toInt()}卡',
                              style: TextStyle(
                                color: _accentRed,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _repeatWorkout,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text(
                '再來一次',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                '完成',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _repeatWorkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('功能開發中...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ===== 🔥 分享功能（一般社群分享）=====
  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '分享訓練成果',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.share_rounded,
                  label: '分享',
                  color: _primaryColor,
                  onTap: _shareToApps,
                ),
                _buildShareOption(
                  icon: Icons.copy_rounded,
                  label: '複製',
                  color: _accentBlue,
                  onTap: _copyToClipboard,
                ),
                _buildShareOption(
                  icon: Icons.message_rounded,
                  label: 'LINE',
                  color: const Color(0xFF00B900),
                  onTap: _shareToApps,
                ),
                _buildShareOption(
                  icon: Icons.facebook_rounded,
                  label: 'FB',
                  color: const Color(0xFF1877F2),
                  onTap: _shareToApps,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(color: _textSecondary, fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToApps() async {
    final text = _generateShareText();
    try {
      await Share.share(text, subject: '我的訓練成果');
    } catch (e) {
      if (kDebugMode) debugPrint('分享失敗: $e');
      _copyToClipboard();
    }
  }

  void _copyToClipboard() {
    final text = _generateShareText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('已複製到剪貼簿'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}