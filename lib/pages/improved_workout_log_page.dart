// lib/pages/improved_workout_log_page.dart
// ✅ 整合版 v8 - 可摺疊日期分組
// ✅ 🔥 新增：日期分組可摺疊（今天展開，其他摺疊）
// ✅ 🔥 新增：摺疊時顯示統計摘要（幾筆、總時長、總卡路里）
// ✅ 🔥 新增：精確時間顯示（分鐘+秒數）
// ✅ 編輯訓練名稱功能
// ✅ 按日期分組顯示（今天/昨天/具體日期）
// ✅ 分頁設計（記錄/分析）

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'workout/workout_session_detail_page.dart';
import 'workout/workout_summary_page.dart';
import 'exercise_selection_page.dart';

class ImprovedWorkoutLogPage extends StatefulWidget {
  final bool isCoach;
  final String? traineeId;
  final String? planId;

  const ImprovedWorkoutLogPage({
    super.key,
    required this.isCoach,
    this.traineeId,
    this.planId,
  });

  @override
  State<ImprovedWorkoutLogPage> createState() => _ImprovedWorkoutLogPageState();
}

class _ImprovedWorkoutLogPageState extends State<ImprovedWorkoutLogPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===== Soft UI 淡綠色配色（統一風格）=====
  static const Color _primaryColor = Color(0xFF66BB6A);
  static const Color _primaryDark = Color(0xFF4CAF50);
  static const Color _primaryLight = Color(0xFFE8F5E9);
  static const Color _backgroundColor = Color(0xFFF0F4F3);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  
  static const Color _planColor = Color(0xFFFFB74D);
  static const Color _freeColor = Color(0xFF81C784);
  static const Color _manualColor = Color(0xFF90A4AE);

  static const Color _chartColor = Color(0xFF66BB6A);
  static const Color _chartColorLight = Color(0xFFA5D6A7);

  late TabController _tabController;
  bool _isLoading = true;
  
  // 🔥 記錄頁數據 - 按日期分組
  Map<String, List<Map<String, dynamic>>> _workoutsByDate = {};
  
  // 🔥 v8 新增：追蹤展開的日期
  Set<String> _expandedDates = {};
  
  Map<String, dynamic> _todayStats = {
    'totalDuration': 0,
    'totalCalories': 0.0,
    'workoutCount': 0,
  };
  int _planCount = 0;
  int _freeCount = 0;

  // 分析頁數據
  int _analysisDays = 7;
  Map<String, dynamic> _analysisStats = {};
  List<Map<String, dynamic>> _dailyData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        if (_tabController.index == 1) {
          _loadAnalysisData();
        }
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUserId {
    return widget.traineeId ?? _auth.currentUser?.uid ?? '';
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else {
      if (date.year == now.year) {
        return DateFormat('M月d日 (E)', 'zh_TW').format(date);
      } else {
        return DateFormat('yyyy年M月d日 (E)', 'zh_TW').format(date);
      }
    }
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // ===== 載入記錄頁數據 =====
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _currentUserId;
      if (userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final endDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final userWorkoutsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final Map<String, Map<String, dynamic>> mergedMap = {};

      for (var doc in logsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        if (createdAt == null || createdAt.isBefore(startDate) || createdAt.isAfter(endDate)) {
          continue;
        }
        
        mergedMap[doc.id] = {
          'id': doc.id,
          'name': data['name'] ?? '未知運動',
          'duration': data['duration'] ?? 0,
          'totalDurationSeconds': data['totalDurationSeconds'],
          'caloriesBurned': (data['caloriesBurned'] ?? 0.0).toDouble(),
          'sessionId': data['sessionId'],
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'createdAt': createdAt,
          'planId': data['planId'],
          'planName': data['planName'],
          'notes': data['notes'],
          'source': data['planId'] != null ? 'plan' : (data['sessionId'] != null ? 'self' : 'manual'),
        };
      }

      for (var doc in userWorkoutsSnapshot.docs) {
        if (mergedMap.containsKey(doc.id)) continue;
        
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        if (createdAt == null || createdAt.isBefore(startDate) || createdAt.isAfter(endDate)) {
          continue;
        }
        
        mergedMap[doc.id] = {
          'id': doc.id,
          'name': data['name'] ?? '未知運動',
          'duration': data['duration'] ?? 0,
          'totalDurationSeconds': data['totalDurationSeconds'],
          'caloriesBurned': (data['caloriesBurned'] ?? 0.0).toDouble(),
          'sessionId': data['sessionId'],
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'createdAt': createdAt,
          'planId': data['planId'],
          'planName': data['planName'],
          'notes': data['notes'],
          'source': data['planId'] != null ? 'plan' : (data['sessionId'] != null ? 'self' : 'manual'),
        };
      }

      final workouts = mergedMap.values.toList();
      workouts.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      final Map<String, List<Map<String, dynamic>>> groupedWorkouts = {};
      
      int planCount = 0;
      int freeCount = 0;
      int todayDuration = 0;
      double todayCalories = 0.0;
      int todayCount = 0;

      final todayKey = _getDateKey(now);

      for (var workout in workouts) {
        final createdAt = workout['createdAt'] as DateTime;
        final dateKey = _getDateKey(createdAt);
        
        if (!groupedWorkouts.containsKey(dateKey)) {
          groupedWorkouts[dateKey] = [];
        }
        groupedWorkouts[dateKey]!.add(workout);

        final source = workout['source'] as String?;
        if (source == 'plan') {
          planCount++;
        } else {
          freeCount++;
        }

        if (dateKey == todayKey) {
          todayDuration += (workout['duration'] ?? 0) as int;
          todayCalories += (workout['caloriesBurned'] ?? 0.0) as double;
          todayCount++;
        }
      }

      if (mounted) {
        setState(() {
          _workoutsByDate = groupedWorkouts;
          _planCount = planCount;
          _freeCount = freeCount;
          _todayStats = {
            'totalDuration': todayDuration,
            'totalCalories': todayCalories,
            'workoutCount': todayCount,
          };
          _isLoading = false;
          
          // 🔥 v8：預設展開今天
          _expandedDates = {todayKey};
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 載入失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入數據失敗');
      }
    }
  }

  // ===== 載入分析頁數據 =====
  Future<void> _loadAnalysisData() async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return;

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _analysisDays - 1));

      final snapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final Map<String, Map<String, dynamic>> dailyMap = {};

      for (int i = 0; i < _analysisDays; i++) {
        final date = startDate.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        dailyMap[key] = {
          'date': date,
          'duration': 0,
          'calories': 0.0,
          'count': 0,
        };
      }

      int totalDuration = 0;
      double totalCalories = 0.0;
      Set<String> workoutDays = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        if (createdAt == null || createdAt.isBefore(startDate)) continue;
        
        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        final duration = (data['duration'] ?? 0) as int;
        final calories = (data['caloriesBurned'] ?? 0.0).toDouble();

        if (dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey]!['duration'] = (dailyMap[dateKey]!['duration'] as int) + duration;
          dailyMap[dateKey]!['calories'] = (dailyMap[dateKey]!['calories'] as double) + calories;
          dailyMap[dateKey]!['count'] = (dailyMap[dateKey]!['count'] as int) + 1;
        }

        totalDuration += duration;
        totalCalories += calories;
        workoutDays.add(dateKey);
      }

      final dailyList = dailyMap.values.toList();
      dailyList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      if (mounted) {
        setState(() {
          _dailyData = dailyList;
          _analysisStats = {
            'workoutDays': workoutDays.length,
            'totalDuration': totalDuration,
            'totalCalories': totalCalories,
            'avgDuration': workoutDays.isNotEmpty ? (totalDuration / workoutDays.length).round() : 0,
            'avgCalories': workoutDays.isNotEmpty ? (totalCalories / workoutDays.length).round() : 0,
          };
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 載入分析數據失敗: $e');
    }
  }

  // 🔥 編輯訓練名稱
  Future<void> _showEditNameDialog(Map<String, dynamic> workout) async {
    final currentName = workout['name'] as String? ?? '自由訓練';
    final workoutId = workout['id'] as String?;
    final sessionId = workout['sessionId'] as String?;
    
    if (workoutId == null) {
      _showSnackBar('無法編輯此記錄');
      return;
    }

    final TextEditingController controller = TextEditingController(text: currentName);
    String? selectedQuickName;

    final List<String> quickNames = [
      '胸部訓練', '背部訓練', '腿部訓練', '肩部訓練',
      '手臂訓練', '核心訓練', '全身訓練', '有氧運動',
      '上半身', '下半身', '推力日', '拉力日',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit_rounded, color: _primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('編輯訓練名稱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '輸入訓練名稱',
                    filled: true,
                    fillColor: _primaryLight.withAlpha(128),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: _textSecondary, size: 20),
                            onPressed: () {
                              controller.clear();
                              setDialogState(() => selectedQuickName = null);
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      if (quickNames.contains(value)) {
                        selectedQuickName = value;
                      } else {
                        selectedQuickName = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                Text(
                  '快速選擇',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickNames.map((name) {
                    final isSelected = selectedQuickName == name || controller.text == name;
                    return GestureDetector(
                      onTap: () {
                        controller.text = name;
                        setDialogState(() => selectedQuickName = name);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _primaryColor : _primaryColor.withAlpha(128),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : _primaryColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, newName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != currentName) {
      await _updateWorkoutName(workoutId, sessionId, result);
    }
  }

  Future<void> _updateWorkoutName(String workoutId, String? sessionId, String newName) async {
    try {
      final batch = _firestore.batch();

      final logRef = _firestore.collection('workoutLogs').doc(workoutId);
      batch.update(logRef, {'name': newName});

      final userId = _currentUserId;
      if (userId.isNotEmpty) {
        final userWorkoutRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('workouts')
            .doc(workoutId);
        batch.update(userWorkoutRef, {'name': newName});
      }

      if (sessionId != null && sessionId.isNotEmpty) {
        final sessionRef = _firestore.collection('workoutSessions').doc(sessionId);
        batch.update(sessionRef, {'name': newName});

        if (userId.isNotEmpty) {
          final userSessionRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('workoutSessions')
              .doc(sessionId);
          batch.update(userSessionRef, {'name': newName});
        }
      }

      await batch.commit();

      _showSnackBar('✅ 名稱已更新');
      await _loadData();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 更新名稱失敗: $e');
      _showSnackBar('更新失敗');
    }
  }

  Future<void> _deleteWorkout(String workoutId) async {
    try {
      await _firestore.collection('workoutLogs').doc(workoutId).delete();
      
      final userId = _currentUserId;
      if (userId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('workouts')
            .doc(workoutId)
            .delete()
            .catchError((_) {});
      }

      _showSnackBar('已刪除運動記錄');
      await _loadData();
    } catch (e) {
      _showSnackBar('刪除失敗');
    }
  }

  Future<void> _confirmDelete(String workoutId, String workoutName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$workoutName」嗎?'),
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

    if (confirmed == true) await _deleteWorkout(workoutId);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          '訓練記錄',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.refresh_rounded, color: _textPrimary, size: 20),
              ),
              onPressed: () {
                _loadData();
                if (_tabController.index == 1) _loadAnalysisData();
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildTabBar(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecordTab(),
                _buildAnalysisTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0 ? _buildFAB() : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt_rounded, size: 18),
                SizedBox(width: 6),
                Text('記錄'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_rounded, size: 18),
                SizedBox(width: 6),
                Text('分析'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.planId != null) _buildPlanModeInfoCard(),
            _buildTodayStatsCard(),
            const SizedBox(height: 16),
            _buildWorkoutsListByDate(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalysisData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDaySelector(),
            const SizedBox(height: 16),
            _buildDurationTrendCard(),
            const SizedBox(height: 16),
            _buildAnalysisStatsCard(),
            const SizedBox(height: 16),
            _buildHistoryList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildDayOption(7)),
          Expanded(child: _buildDayOption(30)),
        ],
      ),
    );
  }

  Widget _buildDayOption(int days) {
    final isSelected = _analysisDays == days;
    return GestureDetector(
      onTap: () {
        if (_analysisDays != days) {
          setState(() => _analysisDays = days);
          _loadAnalysisData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '$days 天',
            style: TextStyle(
              color: isSelected ? Colors.white : _textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationTrendCard() {
    final avgDuration = _analysisStats['avgDuration'] ?? 0;

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
                child: Icon(Icons.timer_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '訓練時長趨勢',
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
                child: Row(
                  children: [
                    Text(
                      '平均 ',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    Text(
                      '$avgDuration',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' 分鐘',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_dailyData.isEmpty) {
      return Center(
        child: Text('暫無數據', style: TextStyle(color: _textSecondary)),
      );
    }

    double maxDuration = 0;
    for (var item in _dailyData) {
      final d = (item['duration'] as int).toDouble();
      if (d > maxDuration) maxDuration = d;
    }
    final double maxY = maxDuration > 0 ? (maxDuration * 1.2).ceilToDouble() : 60.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final data = _dailyData[groupIndex];
              final date = data['date'] as DateTime;
              return BarTooltipItem(
                '${DateFormat('M/d').format(date)}\n${rod.toY.toInt()} 分鐘',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _dailyData.length) return const Text('');
                
                final date = _dailyData[index]['date'] as DateTime;
                final isToday = DateFormat('yyyy-MM-dd').format(date) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
                
                if (_analysisDays == 30 && index % 5 != 0 && !isToday) {
                  return const Text('');
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(date),
                    style: TextStyle(
                      color: isToday ? _primaryColor : _textSecondary,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('');
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(color: _textSecondary, fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: _textSecondary.withAlpha(26),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: _dailyData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final duration = (data['duration'] as int).toDouble();
          final hasData = duration > 0;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: duration,
                color: hasData ? _chartColor : _chartColorLight.withAlpha(77),
                width: _analysisDays == 7 ? 28 : 8,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalysisStatsCard() {
    final workoutDays = _analysisStats['workoutDays'] ?? 0;
    final totalDuration = _analysisStats['totalDuration'] ?? 0;
    final totalCalories = (_analysisStats['totalCalories'] ?? 0.0).toDouble();

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
                '統計總覽',
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
                  '過去 $_analysisDays 天',
                  style: TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnalysisStatItem(Icons.check_circle_outline_rounded, '$workoutDays', '訓練天數', _primaryColor),
              _buildAnalysisStatItem(Icons.timer_outlined, '$totalDuration', '總分鐘', const Color(0xFFFFB74D)),
              _buildAnalysisStatItem(Icons.local_fire_department_outlined, '${totalCalories.toInt()}', '總卡路里', const Color(0xFFEF5350)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    final uid = _currentUserId;
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .where('endedAt', isNotEqualTo: null)
          .orderBy('endedAt', descending: true)
          .limit(_analysisDays == 7 ? 10 : 30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyHistoryState();
        }

        final sessions = snapshot.data!.docs;

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
                    child: Icon(Icons.history_rounded, color: _primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '歷史訓練',
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
                      '${sessions.length} 筆',
                      style: TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...sessions.map((doc) => _buildHistoryItem(doc)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistoryState() {
    return Container(
      padding: const EdgeInsets.all(40),
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
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.history_rounded, size: 40, color: _primaryColor.withAlpha(128)),
            ),
            const SizedBox(height: 16),
            Text(
              '暫無歷史訓練記錄',
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final startTs = data['startedAt'] as Timestamp?;
    final endTs = data['endedAt'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();
    final workoutName = data['name'] as String? ?? data['planName'] as String? ?? '自由訓練';
    final isPlan = data['planId'] != null;

    String dateText = '未記錄時間';
    String durationText = '—';
    
    if (start != null) {
      dateText = DateFormat('MM/dd (E)', 'zh_TW').format(start);
      if (end != null) {
        final minutes = end.difference(start).inMinutes;
        durationText = '$minutes分鐘';
      }
    }

    final sourceColor = isPlan ? _planColor : _freeColor;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WorkoutSummaryPage(sessionId: doc.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primaryLight.withAlpha(128),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sourceColor.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPlan ? Icons.event_note_rounded : Icons.fitness_center_rounded,
                color: sourceColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateText · $durationText',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ===== 以下是記錄頁的元件 =====

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _manualColor.withAlpha(77),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FloatingActionButton.small(
            heroTag: 'manual',
            onPressed: _showAddWorkoutDialog,
            backgroundColor: _cardColor,
            elevation: 0,
            child: Icon(Icons.edit_note_rounded, color: _manualColor),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withAlpha(77),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'start',
            onPressed: _startNewWorkout,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '開始訓練',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ],
    );
  }

  Future<void> _startNewWorkout() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionPage(
          isCoach: widget.isCoach,
          traineeId: widget.traineeId,
          planId: widget.planId,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadData();
      _showSnackBar('✅ 訓練已記錄！');
    }
  }

  Widget _buildPlanModeInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _planColor.withAlpha(38),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.event_note_rounded, color: _planColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '訓練計畫模式',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '此次訓練將計入計畫進度',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_rounded, color: _primaryColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatsCard() {
    final duration = _todayStats['totalDuration'] ?? 0;
    final calories = (_todayStats['totalCalories'] ?? 0.0).toDouble();
    final count = _todayStats['workoutCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '今日訓練 ${DateFormat('M月d日 (E)', 'zh_TW').format(DateTime.now())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTodayStatItem(Icons.fitness_center_rounded, '$count', '次訓練'),
              _buildTodayStatItem(Icons.timer_rounded, '$duration', '分鐘'),
              _buildTodayStatItem(Icons.local_fire_department_rounded, '${calories.toInt()}', '卡路里'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(217),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // 🔥 v8：可摺疊的日期分組訓練列表
  Widget _buildWorkoutsListByDate() {
    if (_workoutsByDate.isEmpty) {
      return _buildEmptyWorkoutsCard();
    }

    final sortedDates = _workoutsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final todayKey = _getDateKey(DateTime.now());

    return Column(
      children: sortedDates.map((dateKey) {
        final workouts = _workoutsByDate[dateKey]!;
        final date = workouts.first['createdAt'] as DateTime;
        final dateLabel = _getDateLabel(date);
        final isToday = dateKey == todayKey;
        final isExpanded = _expandedDates.contains(dateKey);

        // 🔥 計算該日統計
        int totalDuration = 0;
        double totalCalories = 0;
        for (var w in workouts) {
          totalDuration += (w['duration'] ?? 0) as int;
          totalCalories += (w['caloriesBurned'] ?? 0.0) as double;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              // 🔥 可點擊的日期標題
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedDates.remove(dateKey);
                    } else {
                      _expandedDates.add(dateKey);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      // 日期圖標
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isToday ? _primaryColor : _primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                          color: isToday ? Colors.white : _primaryColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // 日期標籤
                      Text(
                        dateLabel,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // 筆數徽章
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${workouts.length} 筆',
                          style: TextStyle(
                            fontSize: 11,
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // 🔥 摺疊時顯示統計摘要
                      if (!isExpanded) ...[
                        Text(
                          '$totalDuration分',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: const Color(0xFFEF5350),
                        ),
                        Text(
                          '${totalCalories.toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF5350),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      // 展開/摺疊圖標
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
              
              // 🔥 可展開的訓練列表
              AnimatedCrossFade(
                firstChild: const SizedBox(height: 0),
                secondChild: Column(
                  children: [
                    Divider(height: 1, color: _primaryLight),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: workouts.map((w) => _buildWorkoutItem(w)).toList(),
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyWorkoutsCard() {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.list_alt_rounded, color: _primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '最近訓練記錄',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '未知運動';
    final totalSeconds = workout['totalDurationSeconds'] as int? ?? 
        ((workout['duration'] ?? 0) as int) * 60;
    final durationMin = totalSeconds ~/ 60;
    final durationSec = totalSeconds % 60;
    final calories = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final workoutId = workout['id'] ?? '';
    final source = workout['source'] as String? ?? 'self';

    final isPlan = source == 'plan';
    final isManual = source == 'manual';
    final sourceColor = isPlan ? _planColor : (isManual ? _manualColor : _freeColor);
    final sourceLabel = isPlan ? '計畫' : (isManual ? '手動' : '自由');
    final sourceIcon = isPlan ? Icons.event_note_rounded : (isManual ? Icons.edit_rounded : Icons.fitness_center_rounded);

    final createdAt = workout['createdAt'] as DateTime?;
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '';
    final totalSets = workout['totalSets'] ?? 0;
    final totalExercises = workout['totalExercises'] ?? 0;

    return GestureDetector(
      onTap: () => _showWorkoutDetail(workout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primaryLight.withAlpha(128),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sourceColor.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(sourceIcon, color: sourceColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sourceColor.withAlpha(38),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sourceLabel,
                          style: TextStyle(fontSize: 10, color: sourceColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (timeStr.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: _textSecondary),
                            const SizedBox(width: 2),
                            Text(timeStr, style: TextStyle(fontSize: 11, color: _textSecondary)),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: _textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            durationSec > 0 ? '$durationMin分$durationSec秒' : '$durationMin分',
                            style: TextStyle(fontSize: 11, color: _textSecondary),
                          ),
                        ],
                      ),
                      if (calories > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFEF5350)),
                            const SizedBox(width: 2),
                            Text('${calories.toInt()}卡', style: const TextStyle(fontSize: 11, color: Color(0xFFEF5350))),
                          ],
                        ),
                    ],
                  ),
                  if (totalExercises > 0 || totalSets > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${totalExercises > 0 ? '$totalExercises個動作' : ''}${totalExercises > 0 && totalSets > 0 ? ' · ' : ''}${totalSets > 0 ? '$totalSets組' : ''}',
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: _primaryColor.withAlpha(179), size: 18),
              onPressed: () => _showEditNameDialog(workout),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '編輯名稱',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: const Color(0xFFEF5350).withAlpha(179), size: 18),
              onPressed: () => _confirmDelete(workoutId, name),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showWorkoutDetail(Map<String, dynamic> workout) async {
    final sessionId = workout['sessionId'] as String?;

    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        final sessionDoc = await _firestore
            .collection('workoutSessions')
            .doc(sessionId)
            .get();

        if (sessionDoc.exists && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkoutSessionDetailPage(workoutSession: sessionDoc.data()!),
            ),
          );
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('載入詳情失敗: $e');
      }
    }

    if (mounted) {
      _showSimpleDetailDialog(workout);
    }
  }

  void _showSimpleDetailDialog(Map<String, dynamic> workout) {
    final source = workout['source'] as String? ?? 'self';
    final isPlan = source == 'plan';
    final sourceColor = isPlan ? _planColor : _freeColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sourceColor.withAlpha(38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPlan ? Icons.event_note_rounded : Icons.fitness_center_rounded,
                color: sourceColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(workout['name'] ?? '訓練詳情', style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(Icons.timer_rounded, '時長', '${workout['duration']} 分鐘'),
            _buildDetailRow(Icons.local_fire_department_rounded, '熱量', '${(workout['caloriesBurned'] ?? 0.0).toInt()} 卡'),
            if ((workout['totalExercises'] ?? 0) > 0)
              _buildDetailRow(Icons.fitness_center_rounded, '動作', '${workout['totalExercises']} 個'),
            if ((workout['totalSets'] ?? 0) > 0)
              _buildDetailRow(Icons.repeat_rounded, '組數', '${workout['totalSets']} 組'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('關閉', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: _textSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.fitness_center_rounded, size: 48, color: _primaryColor.withAlpha(128)),
            ),
            const SizedBox(height: 20),
            Text('最近沒有訓練記錄', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 6),
            Text('點擊下方按鈕開始記錄訓練', style: TextStyle(fontSize: 13, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showAddWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddWorkoutSheet(
        onSave: (data) async {
          try {
            final userId = _currentUserId;
            if (userId.isEmpty) return;

            await _firestore.collection('workoutLogs').add({
              'userId': userId,
              'name': data['name'],
              'type': data['type'],
              'duration': data['duration'],
              'caloriesBurned': data['calories'] ?? 0.0,
              'sets': data['sets'],
              'reps': data['reps'],
              'intensity': data['intensity'],
              'notes': data['notes'],
              'date': DateTime.now().toIso8601String().split('T')[0],
              'createdAt': FieldValue.serverTimestamp(),
            });

            _showSnackBar('✅ 運動記錄成功！');
            await _loadData();
          } catch (e) {
            _showSnackBar('記錄失敗');
          }
        },
      ),
    );
  }
}

// ===== 事後記錄表單 =====
class _AddWorkoutSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const _AddWorkoutSheet({required this.onSave});

  @override
  State<_AddWorkoutSheet> createState() => _AddWorkoutSheetState();
}

class _AddWorkoutSheetState extends State<_AddWorkoutSheet> {
  String _selectedType = 'weight_training';
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _notesController = TextEditingController();

  static const Color _primaryColor = Color(0xFF66BB6A);

  final Map<String, String> _workoutTypes = {
    'weight_training': '重量訓練',
    'cardio': '有氧運動',
    'yoga': '瑜伽',
    'stretching': '伸展',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '事後記錄運動',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: '運動類型',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _workoutTypes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 14),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '運動名稱 *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: '時長（分鐘）*',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    decoration: InputDecoration(
                      labelText: '消耗卡路里',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            
            if (_selectedType == 'weight_training') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setsController,
                      decoration: InputDecoration(
                        labelText: '組數',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      decoration: InputDecoration(
                        labelText: '次數',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '備註',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isEmpty || _durationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填寫必填欄位')),
                    );
                    return;
                  }

                  widget.onSave({
                    'type': _selectedType,
                    'name': _nameController.text,
                    'duration': int.tryParse(_durationController.text) ?? 0,
                    'calories': double.tryParse(_caloriesController.text),
                    'sets': int.tryParse(_setsController.text),
                    'reps': int.tryParse(_repsController.text),
                    'intensity': 'medium',
                    'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
                  });

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('保存記錄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}