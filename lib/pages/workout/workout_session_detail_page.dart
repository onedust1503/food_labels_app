// lib/pages/workout/workout_session_detail_page.dart
// ✨ 訓練記錄詳細頁面
// 顯示完整的訓練資訊、各個動作的組數、休息時間、卡路里分析等

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkoutSessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> workoutSession;

  const WorkoutSessionDetailPage({
    super.key,
    required this.workoutSession,
  });

  @override
  Widget build(BuildContext context) {
    // 解析資料
    final name = workoutSession['name'] ?? '訓練記錄';
    final duration = workoutSession['duration'] ?? 0;
    final calories = (workoutSession['caloriesBurned'] ?? 0.0).toDouble();
    final exercises = workoutSession['exercises'] as List<dynamic>? ?? [];
    final hasplanId = workoutSession['planId'] != null;
    
    // 解析時間戳記
    final timestamp = workoutSession['completedAt'] ?? workoutSession['createdAt'];
    DateTime? dateTime;
    if (timestamp != null) {
      dateTime = timestamp.toDate();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: hasplanId ? Colors.blue : Colors.green,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (dateTime != null)
              Text(
                _formatFullDateTime(dateTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          if (hasplanId)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.event_note, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '計畫訓練',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 訓練總覽卡片
            _buildSummaryCard(duration, calories, exercises.length, dateTime),

            // 運動列表
            _buildExercisesList(exercises),

            // 訓練分析
            _buildAnalysisCard(exercises, duration, calories),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 訓練總覽卡片
  Widget _buildSummaryCard(int duration, double calories, int exerciseCount, DateTime? dateTime) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                '訓練總覽',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (dateTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  _formatFullDateTime(dateTime),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.fitness_center,
                value: '$exerciseCount',
                label: '個動作',
                color: Colors.white,
              ),
              _buildStatItem(
                icon: Icons.timer,
                value: '$duration',
                label: '分鐘',
                color: Colors.white,
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                value: calories.toStringAsFixed(0),
                label: '卡路里',
                color: Colors.white,
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 運動列表
  Widget _buildExercisesList(List<dynamic> exercises) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                Icon(Icons.list, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '運動詳情',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  '無運動記錄',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final exercise = exercises[index] as Map<String, dynamic>;
                return _buildExerciseItem(exercise, index + 1);
              },
            ),
        ],
      ),
    );
  }

  /// 單個運動項目
  Widget _buildExerciseItem(Map<String, dynamic> exercise, int index) {
    final name = exercise['name'] ?? '未知運動';
    final type = exercise['exerciseType'] ?? 'other';
    final sets = exercise['sets'] as List<dynamic>? ?? [];
    
    // 計算總次數和總重量
    int totalReps = 0;
    double totalWeight = 0;
    for (var set in sets) {
      totalReps += (set['reps'] ?? 0) as int;
      totalWeight += ((set['weight'] ?? 0) as num).toDouble();
    }
    final avgWeight = sets.isNotEmpty ? totalWeight / sets.length : 0;

    // 圖示和顏色
    IconData icon;
    Color iconColor;
    switch (type) {
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

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4, left: 34),
        child: Text(
          '${sets.length} 組 • $totalReps 次${avgWeight > 0 ? ' • 平均 ${avgWeight.toStringAsFixed(1)}kg' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(60, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 組數詳情
              ...sets.asMap().entries.map((entry) {
                final setIndex = entry.key + 1;
                final set = entry.value as Map<String, dynamic>;
                final reps = set['reps'] ?? 0;
                final weight = (set['weight'] ?? 0).toDouble();
                final rest = set['restAfter'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$setIndex',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            if (weight > 0) ...[
                              Icon(Icons.fitness_center, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${weight.toStringAsFixed(1)}kg',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '$reps 次',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            if (rest > 0) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '休息 ${rest}s',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// 訓練分析卡片
  Widget _buildAnalysisCard(List<dynamic> exercises, int duration, double calories) {
    // 計算總組數和總次數
    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0; // 總訓練量 (重量 × 次數)

    for (var exercise in exercises) {
      final sets = exercise['sets'] as List<dynamic>? ?? [];
      totalSets += sets.length;
      for (var set in sets) {
        final reps = (set['reps'] ?? 0) as int;
        final weight = ((set['weight'] ?? 0) as num).toDouble();
        totalReps += reps;
        totalVolume += weight * reps;
      }
    }

    final avgCaloriesPerMinute = duration > 0 ? calories / duration : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '訓練分析',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildAnalysisRow('總組數', '$totalSets 組', Icons.format_list_numbered, Colors.blue),
          const SizedBox(height: 12),
          _buildAnalysisRow('總次數', '$totalReps 次', Icons.repeat, Colors.orange),
          const SizedBox(height: 12),
          if (totalVolume > 0) ...[
            _buildAnalysisRow(
              '訓練量',
              '${totalVolume.toStringAsFixed(0)} kg',
              Icons.trending_up,
              Colors.purple,
            ),
            const SizedBox(height: 12),
          ],
          _buildAnalysisRow(
            '平均強度',
            '${avgCaloriesPerMinute.toStringAsFixed(1)} 卡/分鐘',
            Icons.local_fire_department,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 格式化完整日期時間 (包含秒數)
  String _formatFullDateTime(DateTime dateTime) {
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(dateTime);
  }
}