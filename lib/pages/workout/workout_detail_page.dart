// lib/pages/workout/workout_detail_page.dart
// 🔥 完整的訓練詳情頁面 - 支援顯示 sessionId 相關的詳細組數資訊

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';

class WorkoutDetailPage extends StatefulWidget {
  final WorkoutModel workout;

  const WorkoutDetailPage({super.key, required this.workout});

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final WorkoutService _workoutService = WorkoutService();
  Map<String, dynamic>? _sessionDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  Future<void> _loadSessionDetails() async {
    // 如果有 sessionId，載入詳細資訊
    if (widget.workout.sessionId != null && widget.workout.sessionId!.isNotEmpty) {
      try {
        final details = await _workoutService.getWorkoutSessionDetails(widget.workout.sessionId!);
        setState(() {
          _sessionDetails = details;
          _isLoading = false;
        });
      } catch (e) {
        print('載入訓練詳情失敗: $e');
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('訓練詳情'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 訓練標題卡片
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  
                  // 訓練數據
                  _buildStatsGrid(),
                  const SizedBox(height: 20),
                  
                  // 🔥 如果有詳細組數資訊，顯示完整的動作列表
                  if (_sessionDetails != null && _sessionDetails!['exercises'] != null)
                    _buildExercisesList(),
                  
                  // 基本詳細資訊
                  if (_hasAdditionalInfo()) 
                    _buildDetailSection(),
                  
                  // 備註
                  if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty)
                    _buildNotesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    IconData icon;
    Color iconColor;

    switch (widget.workout.type) {
      case 'weight_training':
        icon = Icons.fitness_center;
        iconColor = Colors.red;
        break;
      case 'cardio':
        icon = Icons.directions_run;
        iconColor = Colors.blue;
        break;
      case 'yoga':
        icon = Icons.self_improvement;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.sports;
        iconColor = Colors.orange;
    }

    // 🔥 時間精確到秒
    String timeDisplay = '${widget.workout.duration} 分鐘';
    if (_sessionDetails != null) {
      final startedAt = (_sessionDetails!['startedAt'] as Timestamp?)?.toDate();
      final endedAt = (_sessionDetails!['endedAt'] as Timestamp?)?.toDate();
      
      if (startedAt != null && endedAt != null) {
        final diff = endedAt.difference(startedAt);
        final minutes = diff.inMinutes;
        final seconds = diff.inSeconds % 60;
        timeDisplay = '$minutes 分 $seconds 秒';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            widget.workout.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getTypeLabel(widget.workout.type),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          // 🔥 顯示日期和精確時間
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('yyyy年MM月dd日 EEEE', 'zh_TW').format(widget.workout.createdAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm:ss').format(widget.workout.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '⏱ $timeDisplay',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    List<Widget> statCards = [];

    // 總時長
    statCards.add(_buildStatCard(
      icon: Icons.timer,
      label: '訓練時長',
      value: '${widget.workout.duration}',
      unit: '分鐘',
      color: Colors.blue,
    ));

    // 卡路里
    if (widget.workout.caloriesBurned != null) {
      statCards.add(_buildStatCard(
        icon: Icons.local_fire_department,
        label: '消耗',
        value: '${widget.workout.caloriesBurned!.toInt()}',
        unit: '大卡',
        color: Colors.orange,
      ));
    }

    // 🔥 總組數 (優先使用 totalSets)
    if (widget.workout.totalSets != null) {
      statCards.add(_buildStatCard(
        icon: Icons.repeat,
        label: '總組數',
        value: '${widget.workout.totalSets}',
        unit: '組',
        color: Colors.purple,
      ));
    } else if (widget.workout.sets != null) {
      statCards.add(_buildStatCard(
        icon: Icons.repeat,
        label: '組數',
        value: '${widget.workout.sets}',
        unit: '組',
        color: Colors.purple,
      ));
    }

    // 🔥 動作數
    if (widget.workout.totalExercises != null) {
      statCards.add(_buildStatCard(
        icon: Icons.fitness_center,
        label: '動作數',
        value: '${widget.workout.totalExercises}',
        unit: '個',
        color: Colors.green,
      ));
    }

    // 次數
    if (widget.workout.reps != null) {
      statCards.add(_buildStatCard(
        icon: Icons.loop,
        label: '次數',
        value: '${widget.workout.reps}',
        unit: '次',
        color: Colors.green,
      ));
    }

    // 重量
    if (widget.workout.weight != null) {
      statCards.add(_buildStatCard(
        icon: Icons.fitness_center,
        label: '重量',
        value: '${widget.workout.weight}',
        unit: 'kg',
        color: Colors.red,
      ));
    }

    // 距離
    if (widget.workout.distance != null) {
      statCards.add(_buildStatCard(
        icon: Icons.straighten,
        label: '距離',
        value: '${widget.workout.distance}',
        unit: 'km',
        color: Colors.cyan,
      ));
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: statCards,
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 顯示完整的動作列表（包含每組詳情）
  Widget _buildExercisesList() {
    final exercises = _sessionDetails!['exercises'] as List<dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.list, color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text(
              '訓練動作詳情',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ...exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final exercise = entry.value as Map<String, dynamic>;
          return _buildExerciseCard(index + 1, exercise);
        }),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildExerciseCard(int exerciseNumber, Map<String, dynamic> exercise) {
    final sets = exercise['sets'] as List<dynamic>;
    final completedSets = sets.where((s) {
      final status = s['status'] as String?;
      return status == 'completed' || status == 'resting';
    }).length;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 動作標題
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$exerciseNumber',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise['name'] ?? '未命名動作',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$completedSets/${sets.length} 組',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // 每組詳情
          ...sets.asMap().entries.map((entry) {
            final setIndex = entry.key;
            final setData = entry.value as Map<String, dynamic>;
            final status = setData['status'] as String?;
            
            // 只顯示已完成的組
            if (status != 'completed' && status != 'resting') {
              return const SizedBox.shrink();
            }
            
            return _buildSetRow(setIndex + 1, setData);
          }),
        ],
      ),
    );
  }

  Widget _buildSetRow(int setNumber, Map<String, dynamic> setData) {
    final reps = setData['actualReps'] as int?;
    final weight = setData['weight'] as double?;
    final durationSec = setData['actualDurationSec'] as int?;
    
    String details = '';
    if (weight != null && reps != null) {
      details = '${weight.toStringAsFixed(1)}kg × $reps 次';
    } else if (reps != null) {
      details = '$reps 次';
    } else if (durationSec != null) {
      final minutes = durationSec ~/ 60;
      final seconds = durationSec % 60;
      details = minutes > 0 ? '$minutes分$seconds秒' : '$seconds秒';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            '第 $setNumber 組',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            details,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                '詳細資訊',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (widget.workout.intensity != null)
            _buildDetailRow('強度', _getIntensityLabel(widget.workout.intensity!)),
          
          _buildDetailRow('日期', widget.workout.date),
          
          _buildDetailRow('記錄時間', _formatDateTime(widget.workout.createdAt)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.note_alt_outlined, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                '備註',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.workout.notes!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAdditionalInfo() {
    return widget.workout.intensity != null || 
           widget.workout.date.isNotEmpty;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'weight_training':
        return '重量訓練';
      case 'cardio':
        return '有氧運動';
      case 'yoga':
        return '瑜珈';
      case 'plan_workout':
        return '計畫訓練';
      default:
        return '其他運動';
    }
  }

  String _getIntensityLabel(String intensity) {
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

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}