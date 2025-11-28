// lib/pages/workout/workout_summary_page.dart
// 🔥 完整修正版：使用 UnifiedWorkoutService 統一服務
// ✅ 統一使用 UnifiedWorkoutService
// ✅ 優化資料讀取和顯示邏輯

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/unified_workout_service.dart'; // ✅ 改用統一服務

class WorkoutSummaryPage extends StatefulWidget {
  final String sessionId;

  const WorkoutSummaryPage({
    super.key,
    required this.sessionId,
  });

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage>
    with SingleTickerProviderStateMixin {
  final UnifiedWorkoutService _service = UnifiedWorkoutService(); // ✅ 改用統一服務
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadSessionData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    try {
      debugPrint('📊 [WorkoutSummary] 載入 sessionId: ${widget.sessionId}');

      // ✅ 使用統一服務獲取詳情
      final details = await _service.getWorkoutSessionDetails(widget.sessionId);

      if (details != null) {
        debugPrint('📊 [WorkoutSummary] 成功從統一服務獲取資料');
        setState(() {
          _sessionData = details;
          _exercises = List<Map<String, dynamic>>.from(details['exercises'] ?? []);
          _isLoading = false;
        });
        _animationController.forward();
        return;
      }

      // 🔄 降級方案：嘗試從用戶子集合讀取
      debugPrint('📊 [WorkoutSummary] 統一服務無資料，嘗試用戶子集合');
      await _loadFromUserSubcollection();
    } catch (e) {
      debugPrint('❌ [WorkoutSummary] 載入失敗: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '載入失敗: $e';
      });
    }
  }

  Future<void> _loadFromUserSubcollection() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '用戶未登入';
      });
      return;
    }

    try {
      // 從用戶子集合讀取 session
      final sessionDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .doc(widget.sessionId)
          .get();

      if (!sessionDoc.exists) {
        debugPrint('📊 [WorkoutSummary] 用戶子集合也無資料');
        setState(() {
          _isLoading = false;
          _errorMessage = '找不到訓練記錄';
        });
        return;
      }

      final data = sessionDoc.data()!;
      debugPrint('📊 [WorkoutSummary] 從用戶子集合獲取資料: ${data.keys}');

      // 讀取 exercises 子集合
      final exercisesSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .doc(widget.sessionId)
          .collection('exercises')
          .orderBy('index')
          .get();

      List<Map<String, dynamic>> exercises = [];

      for (var exDoc in exercisesSnap.docs) {
        final exData = exDoc.data();

        // 讀取每個動作的組數
        final setsSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('workoutSessions')
            .doc(widget.sessionId)
            .collection('exercises')
            .doc(exDoc.id)
            .collection('sets')
            .orderBy('index')
            .get();

        final sets = setsSnap.docs.map((s) => s.data()).toList();

        exercises.add({
          ...exData,
          'sets': sets,
          'docId': exDoc.id,
        });
      }

      setState(() {
        _sessionData = {
          ...data,
          'sessionId': widget.sessionId,
        };
        _exercises = exercises;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      debugPrint('❌ [WorkoutSummary] 用戶子集合讀取失敗: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '載入失敗: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('訓練總結'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能開發中')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text('載入訓練資料...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCongratulationsCard(),
                  const SizedBox(height: 20),
                  _buildStatsOverview(),
                  const SizedBox(height: 20),
                  _buildExercisesList(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCongratulationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 48,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '🎉 太棒了！',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '你完成了今天的訓練',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    // 計算統計數據
    final startedAt = _sessionData?['startedAt'];
    final endedAt = _sessionData?['endedAt'];

    int durationMinutes = 0;
    String startTimeStr = '';
    String endTimeStr = '';

    if (startedAt != null && endedAt != null) {
      DateTime start;
      DateTime end;

      if (startedAt is Timestamp) {
        start = startedAt.toDate();
      } else if (startedAt is int) {
        start = DateTime.fromMillisecondsSinceEpoch(startedAt);
      } else {
        start = DateTime.now();
      }

      if (endedAt is Timestamp) {
        end = endedAt.toDate();
      } else if (endedAt is int) {
        end = DateTime.fromMillisecondsSinceEpoch(endedAt);
      } else {
        end = DateTime.now();
      }

      durationMinutes = end.difference(start).inMinutes;
      startTimeStr = DateFormat('HH:mm').format(start);
      endTimeStr = DateFormat('HH:mm').format(end);
    }

    // 也嘗試從 totalDurationSeconds 獲取
    if (durationMinutes == 0) {
      final totalSeconds = _sessionData?['totalDurationSeconds'] ?? 0;
      durationMinutes = (totalSeconds / 60).round();
    }

    // 計算總組數和動作數
    int totalSets = 0;
    int completedSets = 0;
    int totalExercises = _exercises.length;

    for (var ex in _exercises) {
      final sets = ex['sets'] as List<dynamic>? ?? [];
      totalSets += sets.length;
      completedSets += sets.where((s) => s['status'] == 'completed').length;
    }

    // 卡路里
    double calories = 0;
    if (_sessionData?['totalCalories'] != null) {
      calories = (_sessionData!['totalCalories'] as num).toDouble();
    } else if (_sessionData?['caloriesBurned'] != null) {
      calories = (_sessionData!['caloriesBurned'] as num).toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              const Text(
                '訓練數據',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                Text(
                  '$startTimeStr - $endTimeStr',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.timer,
                value: '$durationMinutes',
                label: '分鐘',
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.fitness_center,
                value: '$totalExercises',
                label: '動作',
                color: Colors.purple,
              ),
              _buildStatItem(
                icon: Icons.format_list_numbered,
                value: '$completedSets/$totalSets',
                label: '完成組數',
                color: Colors.green,
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                value: '${calories.toInt()}',
                label: '大卡',
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildExercisesList() {
    if (_exercises.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              '沒有動作詳情資料',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                const Text(
                  '動作詳情',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_exercises.length} 個動作',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              return _buildExerciseItem(exercise, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise, int index) {
    final name = exercise['name'] ?? '動作 ${index + 1}';
    final sets = exercise['sets'] as List<dynamic>? ?? [];
    final completedSets = sets.where((s) => s['status'] == 'completed').length;

    return ExpansionTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '完成 $completedSets / ${sets.length} 組',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      children: [
        if (sets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '沒有組數記錄',
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          ...sets.asMap().entries.map((entry) {
            final setIndex = entry.key;
            final setData = entry.value as Map<String, dynamic>;
            return _buildSetRow(setIndex, setData);
          }),
      ],
    );
  }

  Widget _buildSetRow(int setIndex, Map<String, dynamic> setData) {
    final status = setData['status'] ?? 'pending';
    final reps = setData['actualReps'] ?? setData['reps'];
    final weight = setData['actualWeight'] ?? setData['weight'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '完成';
        break;
      case 'skipped':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusText = '略過';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = '未完成';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: setIndex.isEven ? Colors.grey[50] : Colors.white,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${setIndex + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (reps != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$reps 次',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (weight != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$weight kg',
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // 可以添加重新訓練功能
              Navigator.pop(context);
            },
            icon: const Icon(Icons.replay),
            label: const Text('再來一次'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
              side: const BorderSide(color: Color(0xFF6C63FF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('完成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
