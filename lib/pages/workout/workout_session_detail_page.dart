// lib/pages/workout/workout_session_detail_page.dart
// 🔥 訓練詳情頁 - 顯示完整的動作和組數資訊

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/workout_service.dart';
import '../../models/workout_model.dart';

class WorkoutSessionDetailPage extends StatefulWidget {
  final String sessionId;
  final WorkoutModel workoutLog;

  const WorkoutSessionDetailPage({
    super.key,
    required this.sessionId,
    required this.workoutLog,
  });

  @override
  State<WorkoutSessionDetailPage> createState() =>
      _WorkoutSessionDetailPageState();
}

class _WorkoutSessionDetailPageState extends State<WorkoutSessionDetailPage> {
  final WorkoutService _service = WorkoutService();
  
  Map<String, dynamic>? _sessionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  Future<void> _loadSessionDetails() async {
    setState(() => _isLoading = true);

    try {
      final details = await _service.getWorkoutSessionDetails(widget.sessionId);
      
      if (mounted) {
        setState(() {
          _sessionDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入詳情失敗：$e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          '訓練詳情',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  
                  if (_sessionDetails != null)
                    ..._buildExercisesList(),
                ],
              ),
            ),
    );
  }

  // 頂部統計卡片
  Widget _buildHeaderCard() {
    final duration = widget.workoutLog.duration;
    final calories = widget.workoutLog.caloriesBurned?.toInt() ?? 0;
    final totalSets = widget.workoutLog.totalSets ?? 0;
    final totalExercises = widget.workoutLog.totalExercises ?? 0;

    return Container(
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 28,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.workoutLog.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(widget.workoutLog.date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 統計數據網格
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  Icons.timer,
                  '$duration',
                  '分鐘',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  Icons.local_fire_department,
                  '$calories',
                  '卡路里',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  Icons.list,
                  '$totalExercises',
                  '動作',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  Icons.fitness_center,
                  '$totalSets',
                  '總組數',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // 動作列表
  List<Widget> _buildExercisesList() {
    final exercises = _sessionDetails!['exercises'] as List<dynamic>;
    
    return [
      Text(
        '動作詳情',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      
      ...exercises.asMap().entries.map((entry) {
        final index = entry.key;
        final exercise = entry.value as Map<String, dynamic>;
        return _buildExerciseCard(exercise, index + 1);
      }).toList(),
    ];
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index) {
    final name = exercise['name'] as String;
    final sets = exercise['sets'] as List<dynamic>;
    final completedSets = sets.where((s) {
      final status = s['status'] as String?;
      return status == 'completed' || status == 'resting';
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // 動作標題
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completedSets 組',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 組數列表
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sets.asMap().entries.map((entry) {
                final setIndex = entry.key;
                final set = entry.value as Map<String, dynamic>;
                return _buildSetRow(set, setIndex + 1);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(Map<String, dynamic> set, int setNumber) {
    final status = set['status'] as String?;
    final reps = set['actualReps'] as int?;
    final weight = set['weight'] as num?;
    final note = set['note'] as String?;

    // 根據狀態設定樣式
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
      case 'resting':
        statusColor = const Color(0xFF22C55E);
        statusIcon = Icons.check_circle;
        statusText = '完成';
        break;
      case 'skipped':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusText = '略過';
        break;
      default:
        statusColor = Colors.grey.shade300;
        statusIcon = Icons.radio_button_unchecked;
        statusText = '未完成';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // 狀態圖示
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          
          // 組數標籤
          SizedBox(
            width: 50,
            child: Text(
              '第 $setNumber 組',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 數據
          Expanded(
            child: Row(
              children: [
                if (reps != null) ...[
                  const Icon(Icons.repeat, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$reps 次',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (weight != null) ...[
                  const Icon(Icons.fitness_center, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 狀態標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy年 MM月 dd日 (E)', 'zh_TW').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}