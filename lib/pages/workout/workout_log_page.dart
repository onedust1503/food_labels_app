// lib/pages/workout/workout_log_page.dart
// 🔥 完整整合版：保留原有功能 + 整合顯示自由訓練和教練計畫
// ✅ 統一使用 UnifiedWorkoutService
// ✅ 標籤區分「自由」和「計畫」訓練
// ✅ 修正詳情頁面導航，確保資料正確傳遞
// ✅ 保留所有原有功能
// ✅ Soft UI 風格統一

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/unified_workout_service.dart';
import 'free_workout_execution_page.dart';
import 'workout_summary_page.dart';
import 'workout_session_detail_page.dart';

class WorkoutLogPage extends StatefulWidget {
  const WorkoutLogPage({super.key});

  @override
  State<WorkoutLogPage> createState() => _WorkoutLogPageState();
}

class _WorkoutLogPageState extends State<WorkoutLogPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _todayWorkouts = [];
  Map<String, dynamic> _todaySummary = {};
  bool _isLoading = true;

  // ===== 淡雅 Soft UI 配色（類似飲食記錄風格）=====
  static const Color _primaryColor = Color(0xFF66BB6A);      // 薄荷綠
  static const Color _primaryLight = Color(0xFFE8F5E9);      // 極淡綠
  static const Color _backgroundColor = Color(0xFFF0F4F3);   // 淡綠灰背景
  static const Color _cardColor = Color(0xFFFFFFFF);         // 純白卡片
  static const Color _textPrimary = Color(0xFF2D3436);       // 深灰文字
  static const Color _textSecondary = Color(0xFF636E72);     // 中灰文字
  
  // 來源顏色（柔和色）
  static const Color _selfColor = Color(0xFF81C784);         // 自由訓練 - 薄荷綠
  static const Color _planColor = Color(0xFFFFB74D);         // 計畫訓練 - 柔和橘
  static const Color _manualColor = Color(0xFF90A4AE);       // 手動記錄 - 柔和灰

  @override
  void initState() {
    super.initState();
    _loadTodayWorkouts();
  }

  Future<void> _loadTodayWorkouts() async {
    setState(() => _isLoading = true);
    try {
      // ✅ 使用整合方法，同時讀取自由訓練和計畫訓練
      final workouts = await _loadTodayWorkoutsUnified();
      final summary = await _workoutService.getTodayStats();

      setState(() {
        _todayWorkouts = workouts;
        _todaySummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  /// 🔥 整合讀取今日所有訓練（自由訓練 + 教練計畫）
  Future<List<Map<String, dynamic>>> _loadTodayWorkoutsUnified() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];
    
    List<Map<String, dynamic>> allWorkouts = [];

    try {
      // 1️⃣ 從 workoutLogs 讀取（包含手動記錄、自由訓練、計畫訓練）
      final logsSnapshot = await _firestore
          .collection('workoutLogs')
          .where('userId', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in logsSnapshot.docs) {
        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? '未命名訓練',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'] ?? data['sets'],
          'totalExercises': data['totalExercises'],
          'sets': data['sets'],
          'reps': data['reps'],
          'weight': data['weight'],
          'intensity': data['intensity'],
          'notes': data['notes'],
          'sessionId': data['sessionId'],
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['createdAt'],
          'timestamp': data['timestamp'],
          // 🔥 判斷來源
          'source': _determineSource(data),
        });
      }

      // 2️⃣ 檢查 workoutSessions 是否有額外的記錄（避免重複）
      final existingSessionIds = allWorkouts
          .where((w) => w['sessionId'] != null)
          .map((w) => w['sessionId'] as String)
          .toSet();

      final sessionsSnapshot = await _firestore
          .collection('workoutSessions')
          .where('userId', isEqualTo: uid)
          .where('date', isEqualTo: dateStr)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        // 避免重複
        if (existingSessionIds.contains(doc.id)) continue;

        final data = doc.data();
        allWorkouts.add({
          'id': doc.id,
          'name': data['name'] ?? data['planName'] ?? '訓練記錄',
          'type': data['type'] ?? 'weight_training',
          'duration': data['duration'] ?? 0,
          'caloriesBurned': (data['totalCalories'] ?? data['caloriesBurned'] ?? 0).toDouble(),
          'totalSets': data['totalSets'],
          'totalExercises': data['totalExercises'],
          'sessionId': doc.id,
          'planId': data['planId'],
          'planName': data['planName'],
          'createdAt': data['completedAt'] ?? data['endedAt'],
          'timestamp': data['timestamp'] is Timestamp 
              ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch 
              : data['timestamp'],
          'source': data['planId'] != null ? 'plan' : 'self',
        });
      }

      // 3️⃣ 按時間排序（最新的在前）
      allWorkouts.sort((a, b) {
        int aTime = 0;
        int bTime = 0;
        
        if (a['timestamp'] != null) {
          aTime = a['timestamp'] is int ? a['timestamp'] : 0;
        } else if (a['createdAt'] != null && a['createdAt'] is Timestamp) {
          aTime = (a['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        
        if (b['timestamp'] != null) {
          bTime = b['timestamp'] is int ? b['timestamp'] : 0;
        } else if (b['createdAt'] != null && b['createdAt'] is Timestamp) {
          bTime = (b['createdAt'] as Timestamp).millisecondsSinceEpoch;
        }
        
        return bTime.compareTo(aTime);
      });

      return allWorkouts;
    } catch (e) {
      debugPrint('❌ _loadTodayWorkoutsUnified 錯誤: $e');
      // 如果整合方法失敗，回退到原始方法
      return await _workoutService.getTodayWorkouts();
    }
  }

  /// 🔥 判斷訓練來源
  String _determineSource(Map<String, dynamic> data) {
    if (data['planId'] != null) {
      return 'plan';  // 教練計畫
    } else if (data['sessionId'] != null) {
      return 'self';  // 自由訓練
    } else {
      return 'manual';  // 手動記錄
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
                  color: Colors.black.withOpacity(0.05),
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.refresh_rounded, color: _textPrimary, size: 20),
              ),
              onPressed: _loadTodayWorkouts,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              onRefresh: _loadTodayWorkouts,
              color: _primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySummaryCard(),
                    const SizedBox(height: 16),
                    _buildWeekSummaryCard(),
                    const SizedBox(height: 16),
                    _buildWorkoutList(),
                    const SizedBox(height: 20),
                    _buildCompletedSessionsSection(),
                    const SizedBox(height: 80), // 給 FAB 留空間
                  ],
                ),
              ),
            ),
      floatingActionButton: _buildStartWorkoutFAB(),
    );
  }

  Widget _buildStartWorkoutFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showSelectExercisesDialog,
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
    );
  }

  void _showSelectExercisesDialog() {
    showDialog(
      context: context,
      builder: (context) => SelectExercisesDialog(
        onConfirm: (exercises) {
          Navigator.pop(context);
          _startWorkout(exercises);
        },
      ),
    );
  }

  Future<void> _startWorkout(List<Map<String, dynamic>> exercises) async {
    if (exercises.isEmpty) {
      _showSnackBar('請至少選擇一個動作', Colors.orange);
      return;
    }

    final sessionId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FreeWorkoutExecutionPage(exercises: exercises),
      ),
    );

    if (!mounted) return;

    if (sessionId != null && sessionId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
        ),
      );

      if (!mounted) return;

      await _loadTodayWorkouts();
      _showSnackBar('訓練記錄已保存！', _primaryColor);
    }
  }

  Widget _buildTodaySummaryCard() {
    int totalDuration = _todaySummary['totalDuration'] ?? 0;
    double totalCalories = (_todaySummary['totalCalories'] ?? 0).toDouble();
    int workoutCount = _todaySummary['workoutCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
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
                child: Icon(Icons.calendar_today_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '今日訓練 ${DateFormat('M月d日 (E)', 'zh_TW').format(DateTime.now())}',
                style: TextStyle(
                  color: _textPrimary,
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
              _buildStatItem(Icons.fitness_center_rounded, '$workoutCount', '次訓練', _primaryColor),
              _buildStatItem(Icons.timer_rounded, '$totalDuration', '分鐘', const Color(0xFFFFB74D)),
              _buildStatItem(Icons.local_fire_department_rounded, '${totalCalories.toInt()}', '卡路里', const Color(0xFFEF5350)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSummaryCard() {
    // 使用已載入的今日數據作為本週統計的一部分
    int trainDays = (_todaySummary['workoutCount'] ?? 0) > 0 ? 1 : 0;
    int totalDuration = _todaySummary['totalDuration'] ?? 0;
    double totalCalories = (_todaySummary['totalCalories'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                child: Icon(Icons.date_range_rounded, color: _primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '本週統計',
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
                  '過去7天',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeekStatItem(
                Icons.check_circle_outline_rounded,
                '$trainDays',
                '天訓練',
                _primaryColor,
              ),
              _buildWeekStatItem(
                Icons.timer_outlined,
                '$totalDuration',
                '總分鐘',
                const Color(0xFFFFB74D),
              ),
              _buildWeekStatItem(
                Icons.local_fire_department_outlined,
                '${totalCalories.toInt()}',
                '總卡路里',
                const Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
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
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutList() {
    if (_todayWorkouts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
                  '今日訓練記錄',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.fitness_center_rounded, size: 48, color: _primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              '今天還沒有運動記錄',
              style: TextStyle(fontSize: 15, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              '點擊右下角按鈕開始訓練',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    // 🔥 統計不同來源的訓練數量
    int selfCount = _todayWorkouts.where((w) => w['source'] == 'self').length;
    int planCount = _todayWorkouts.where((w) => w['source'] == 'plan').length;
    int manualCount = _todayWorkouts.where((w) => w['source'] == 'manual').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    '今日訓練記錄',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (selfCount > 0)
                    _buildCountChip('自由', selfCount, _selfColor),
                  if (planCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildCountChip('計畫', planCount, _planColor),
                  ],
                  if (manualCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildCountChip('手動', manualCount, _manualColor),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._todayWorkouts.map((workout) => _buildWorkoutCard(workout)),
        ],
      ),
    );
  }

  /// 🔥 來源統計小標籤
  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final type = workout['type'] ?? 'other';
    final name = workout['name'] ?? '訓練記錄';
    final planName = workout['planName'] as String?;
    final duration = workout['duration'] ?? 0;
    final caloriesBurned = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final totalSets = workout['totalSets'];
    final totalExercises = workout['totalExercises'];
    final sessionId = workout['sessionId'];
    final source = workout['source'] as String? ?? 'manual';
    
    // 🔥 根據來源設定顏色和標籤
    Color sourceColor;
    String sourceLabel;
    IconData sourceIcon;

    switch (source) {
      case 'plan':
        sourceColor = _planColor;
        sourceLabel = '計畫';
        sourceIcon = Icons.event_note_rounded;
        break;
      case 'self':
        sourceColor = _selfColor;
        sourceLabel = '自由';
        sourceIcon = Icons.fitness_center_rounded;
        break;
      default:
        sourceColor = _manualColor;
        sourceLabel = '手動';
        sourceIcon = Icons.edit_rounded;
    }

    // 🔥 格式化時間顯示
    String timeStr = '';
    final createdAt = workout['createdAt'];
    final timestamp = workout['timestamp'];
    
    if (createdAt != null) {
      try {
        final dateTime = createdAt is Timestamp 
            ? createdAt.toDate() 
            : DateTime.fromMillisecondsSinceEpoch(createdAt);
        timeStr = DateFormat('HH:mm:ss').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    } else if (timestamp != null) {
      try {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        timeStr = DateFormat('HH:mm:ss').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    }

    // 🔥 顯示名稱（計畫訓練優先顯示計畫名稱）
    final displayName = planName ?? name;

    return GestureDetector(
      onTap: () => _navigateToDetail(workout),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primaryLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 🔥 使用來源顏色而不是類型顏色
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(sourceIcon, color: sourceColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 🔥 來源標籤
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sourceColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          sourceLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: sourceColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (timeStr.isNotEmpty) ...[
                        Icon(Icons.access_time_rounded, size: 13, color: _textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.timer_outlined, size: 13, color: _textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '$duration 分鐘',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                      if (caloriesBurned > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.local_fire_department_rounded, size: 13, color: const Color(0xFFEF5350)),
                        const SizedBox(width: 3),
                        Text(
                          '${caloriesBurned.toInt()} 卡',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFEF5350)),
                        ),
                      ],
                    ],
                  ),
                  // 🔥 顯示總組數和動作數
                  if (totalSets != null || totalExercises != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (totalExercises != null) ...[
                          Text(
                            '$totalExercises 個動作',
                            style: TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                        ],
                        if (totalSets != null && totalExercises != null)
                          Text(' · ', style: TextStyle(color: _textSecondary)),
                        if (totalSets != null)
                          Text(
                            '$totalSets 組',
                            style: TextStyle(fontSize: 12, color: _textSecondary),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 刪除按鈕
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: const Color(0xFFEF5350).withOpacity(0.7), size: 20),
              onPressed: () => _deleteWorkout(workout),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Icon(Icons.chevron_right_rounded, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  /// 🔥 導航到詳情頁面 - 關鍵修正
  Future<void> _navigateToDetail(Map<String, dynamic> workout) async {
    final sessionId = workout['sessionId'] as String?;
    
    if (sessionId != null && sessionId.isNotEmpty) {
      // 🔥 有 sessionId - 從 workoutSessions 獲取完整詳情
      try {
        final details = await _workoutService.getWorkoutSessionDetails(sessionId);
        
        if (details != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutSessionDetailPage(
                workoutSession: details,
              ),
            ),
          );
        } else {
          // 如果詳情不存在，顯示簡單對話框
          _showSimpleWorkoutDetail(workout);
        }
      } catch (e) {
        _showSnackBar('載入詳情失敗：$e', Colors.red);
      }
    } else {
      // 沒有 sessionId - 顯示簡單對話框
      _showSimpleWorkoutDetail(workout);
    }
  }

  void _showSimpleWorkoutDetail(Map<String, dynamic> workout) {
    final name = workout['name'] ?? '訓練記錄';
    final planName = workout['planName'] as String?;
    final date = workout['date'] ?? '';
    final duration = workout['duration'] ?? 0;
    final sets = workout['sets'];
    final reps = workout['reps'];
    final weight = workout['weight'];
    final caloriesBurned = (workout['caloriesBurned'] ?? 0.0).toDouble();
    final intensity = workout['intensity'];
    final notes = workout['notes'];
    final source = workout['source'] as String? ?? 'manual';
    
    String timeStr = '';
    final createdAt = workout['createdAt'];
    if (createdAt != null) {
      try {
        final dateTime = createdAt is Timestamp 
            ? createdAt.toDate() 
            : DateTime.fromMillisecondsSinceEpoch(createdAt);
        timeStr = DateFormat('HH:mm:ss').format(dateTime);
      } catch (e) {
        // 忽略解析錯誤
      }
    }

    // 來源標籤
    String sourceText;
    Color sourceColor;
    switch (source) {
      case 'plan':
        sourceText = '教練計畫';
        sourceColor = _planColor;
        break;
      case 'self':
        sourceText = '自由訓練';
        sourceColor = _selfColor;
        break;
      default:
        sourceText = '手動記錄';
        sourceColor = _manualColor;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(child: Text(planName ?? name)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sourceText,
                style: TextStyle(fontSize: 12, color: sourceColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (date.isNotEmpty) _buildDetailRow('日期', date),
              if (timeStr.isNotEmpty) _buildDetailRow('時間', timeStr),
              _buildDetailRow('時長', '$duration 分鐘'),
              if (sets != null) _buildDetailRow('組數', '$sets 組'),
              if (reps != null) _buildDetailRow('次數', '$reps 次'),
              if (weight != null) _buildDetailRow('重量', '$weight kg'),
              if (caloriesBurned > 0) _buildDetailRow('卡路里', '${caloriesBurned.toInt()} 大卡'),
              if (intensity != null) _buildDetailRow('強度', _getIntensityText(intensity)),
              if (notes != null && notes.isNotEmpty) _buildDetailRow('備註', notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWorkout(workout);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 🔥 刪除訓練記錄
  Future<void> _deleteWorkout(Map<String, dynamic> workout) async {
    final workoutId = workout['id'] as String?;
    if (workoutId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這筆訓練記錄嗎？'),
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

    if (confirmed == true) {
      try {
        await _workoutService.deleteWorkout(workoutId);
        _showSnackBar('已刪除訓練記錄', _primaryColor);
        _loadTodayWorkouts();
      } catch (e) {
        _showSnackBar('刪除失敗：$e', Colors.red);
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label：',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityText(String intensity) {
    switch (intensity) {
      case 'low':
        return '低強度';
      case 'medium':
        return '中強度';
      case 'high':
        return '高強度';
      default:
        return intensity;
    }
  }

  Widget _buildCompletedSessionsSection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .where('endedAt', isNotEqualTo: null)
          .orderBy('endedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: _primaryColor)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final sessions = snapshot.data!.docs;
        final today = DateTime.now().toIso8601String().split('T')[0];
        final historySessions = sessions.where((doc) {
          final startTs = doc.data()['startedAt'] as Timestamp?;
          if (startTs == null) return false;
          final date = startTs.toDate().toIso8601String().split('T')[0];
          return date != today;
        }).toList();

        if (historySessions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.history_rounded, color: _primaryColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '歷史訓練記錄',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${historySessions.length} 筆',
                      style: TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historySessions.length,
                itemBuilder: (context, index) {
                  final doc = historySessions[index];
                  final data = doc.data();
                  final startTs = data['startedAt'] as Timestamp?;
                  final endTs = data['endedAt'] as Timestamp?;
                  final start = startTs?.toDate();
                  final end = endTs?.toDate();
                  final planId = data['planId'];
                  final planName = data['planName'] as String?;
                  final source = planId != null ? 'plan' : 'self';

                  String dateText = '未記錄時間';
                  String durationText = '—';
                  
                  if (start != null) {
                    dateText = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(start);
                    
                    if (end != null) {
                      final diff = end.difference(start);
                      final minutes = diff.inMinutes;
                      final seconds = diff.inSeconds % 60;
                      durationText = '$minutes分$seconds秒';
                    }
                  }

                  // 來源標籤
                  Color sourceColor = source == 'plan' ? _planColor : _selfColor;
                  String sourceLabel = source == 'plan' ? '計畫' : '自由';

                  return FutureBuilder<QuerySnapshot>(
                    future: _firestore
                        .collection('workoutLogs')
                        .where('sessionId', isEqualTo: doc.id)
                        .limit(1)
                        .get(),
                    builder: (context, logSnapshot) {
                      int exercises = 0;
                      int totalSets = 0;
                      double calories = 0;

                      if (logSnapshot.hasData && logSnapshot.data!.docs.isNotEmpty) {
                        final logData = logSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        exercises = logData['totalExercises'] ?? 0;
                        totalSets = logData['totalSets'] ?? 0;
                        calories = (logData['caloriesBurned'] ?? 0).toDouble();
                      }

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutSummaryPage(sessionId: doc.id),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _primaryLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: sourceColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  source == 'plan' ? Icons.event_note_rounded : Icons.history_rounded,
                                  color: sourceColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            planName ?? dateText,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: _textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // 來源標籤
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sourceColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            sourceLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: sourceColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (planName != null)
                                      Text(
                                        dateText,
                                        style: TextStyle(fontSize: 12, color: _textSecondary),
                                      ),
                                    Text(
                                      '時長：$durationText · 動作：$exercises · 組數：$totalSets',
                                      style: TextStyle(fontSize: 12, color: _textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (calories > 0)
                                Column(
                                  children: [
                                    Icon(Icons.local_fire_department_rounded, color: const Color(0xFFEF5350), size: 20),
                                    Text(
                                      '${calories.toInt()}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEF5350),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: _textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddWorkoutDialog(
        onSave: (data) async {
          await _workoutService.addWorkoutLog(
            type: data['type'],
            name: data['name'],
            duration: data['duration'],
            caloriesBurned: data['calories'],
            sets: data['sets'],
            reps: data['reps'],
            intensity: data['intensity'],
            notes: data['notes'],
          );
          _loadTodayWorkouts();
          _showSnackBar('運動記錄成功！', _primaryColor);
        },
      ),
    );
  }
}

// ========== 選擇動作對話框 ==========

class SelectExercisesDialog extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onConfirm;

  const SelectExercisesDialog({super.key, required this.onConfirm});

  @override
  State<SelectExercisesDialog> createState() => _SelectExercisesDialogState();
}

class _SelectExercisesDialogState extends State<SelectExercisesDialog> {
  final List<Map<String, dynamic>> _selectedExercises = [];

  // Soft UI 配色
  static const Color _primaryColor = Color(0xFF4CAF50);
  static const Color _primaryLight = Color(0xFFE8F5E9);

  final List<Map<String, dynamic>> _exerciseLibrary = [
    {'name': '臥推', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 8, 'restSec': 120, 'category': '胸部'},
    {'name': '深蹲', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 8, 'restSec': 120, 'category': '腿部'},
    {'name': '硬舉', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 5, 'restSec': 180, 'category': '背部'},
    {'name': '肩推', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 10, 'restSec': 90, 'category': '肩膀'},
    {'name': '引體向上', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 8, 'restSec': 90, 'category': '背部'},
    {'name': '二頭彎舉', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60, 'category': '手臂'},
    {'name': '三頭下壓', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60, 'category': '手臂'},
    {'name': '啞鈴飛鳥', 'type': 'reps', 'defaultSets': 3, 'defaultReps': 12, 'restSec': 60, 'category': '胸部'},
    {'name': '腿推', 'type': 'reps', 'defaultSets': 4, 'defaultReps': 10, 'restSec': 90, 'category': '腿部'},
    {'name': '跑步', 'type': 'duration', 'defaultDuration': 30, 'restSec': 0, 'category': '有氧'},
    {'name': '棒式', 'type': 'duration', 'defaultDuration': 60, 'defaultSets': 3, 'restSec': 60, 'category': '腹肌'},
  ];

  void _addExercise(Map<String, dynamic> exercise) {
    setState(() {
      _selectedExercises.add({
        'name': exercise['name'],
        'type': exercise['type'],
        'category': exercise['category'],
        'plannedSets': exercise['defaultSets'] ?? 3,
        'plannedReps': exercise['defaultReps'],
        'plannedDurationSec': exercise['defaultDuration'] != null 
            ? exercise['defaultDuration'] * 60 
            : null,
        'restSec': exercise['restSec'] ?? 90,
      });
    });
  }

  void _removeExercise(int index) {
    setState(() => _selectedExercises.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '選擇訓練動作',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),

            if (_selectedExercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已選擇：',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedExercises.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ex = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}. ${ex['name']}',
                          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeExercise(index),
                          child: Icon(Icons.close_rounded, size: 16, color: _primaryColor),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(),
            ],

            Expanded(
              child: ListView.builder(
                itemCount: _exerciseLibrary.length,
                itemBuilder: (context, index) {
                  final ex = _exerciseLibrary[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.fitness_center_rounded, color: _primaryColor, size: 20),
                      ),
                      title: Text(ex['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        ex['type'] == 'reps'
                            ? '${ex['category']} · ${ex['defaultSets']} 組 × ${ex['defaultReps']} 次'
                            : '${ex['category']} · ${ex['defaultDuration']} 分鐘',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: _primaryColor, size: 28),
                        onPressed: () => _addExercise(ex),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedExercises.isEmpty
                    ? null
                    : () => widget.onConfirm(_selectedExercises),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  '開始訓練（${_selectedExercises.length} 個動作）',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 事後記錄對話框 ========== 

class AddWorkoutDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AddWorkoutDialog({super.key, required this.onSave});

  @override
  State<AddWorkoutDialog> createState() => _AddWorkoutDialogState();
}

class _AddWorkoutDialogState extends State<AddWorkoutDialog> {
  String _selectedType = 'weight_training';
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  String _selectedIntensity = 'medium';

  static const Color _primaryColor = Color(0xFF4CAF50);

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
        left: 16,
        right: 16,
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
            const SizedBox(height: 16),
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
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '運動名稱',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: '時長（分鐘）',
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
              const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isEmpty || _durationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('請填寫必填欄位'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  widget.onSave({
                    'type': _selectedType,
                    'name': _nameController.text,
                    'duration': int.parse(_durationController.text),
                    'calories': _caloriesController.text.isNotEmpty
                        ? double.parse(_caloriesController.text)
                        : null,
                    'sets': _setsController.text.isNotEmpty
                        ? int.parse(_setsController.text)
                        : null,
                    'reps': _repsController.text.isNotEmpty
                        ? int.parse(_repsController.text)
                        : null,
                    'intensity': _selectedIntensity,
                    'notes': null,
                  });

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
