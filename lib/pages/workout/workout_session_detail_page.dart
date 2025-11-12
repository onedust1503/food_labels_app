// lib/pages/workout/workout_session_detail_page.dart
// ✨ 訓練記錄詳細頁面 - 最終完整修正版
// 🔥 修正1: 從 Firestore timestamps 計算實際訓練秒數
// 🔥 修正2: 只顯示已完成的組數(不包含 pending/skipped)
// 🔥 修正3: 平均強度 = 總卡路里 ÷ 訓練時長(分鐘)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkoutSessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> workoutSession;

  const WorkoutSessionDetailPage({
    super.key,
    required this.workoutSession,
  });

  /// 🔥 從 startedAt 和 endedAt 計算實際秒數
  int _calculateActualDuration() {
    final startedAt = workoutSession['startedAt'];
    final endedAt = workoutSession['endedAt'];
    
    if (startedAt != null && endedAt != null) {
      try {
        final start = startedAt.toDate();
        final end = endedAt.toDate();
        return end.difference(start).inSeconds;
      } catch (e) {
        print('計算時長失敗: $e');
      }
    }
    
    // 降級處理:使用分鐘數
    final duration = workoutSession['duration'] ?? 0;
    return duration * 60;
  }

  /// 🔥 格式化時長為 "XX分XX秒"
  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (seconds == 0) {
      return '$minutes分';
    }
    return '$minutes分$seconds秒';
  }

  @override
  Widget build(BuildContext context) {
    // 解析資料
    final name = workoutSession['name'] ?? '訓練記錄';
    final calories = (workoutSession['caloriesBurned'] ?? 
                     workoutSession['calories'] ?? 0.0).toDouble();
    final exercises = workoutSession['exercises'] as List<dynamic>? ?? [];
    final hasplanId = workoutSession['planId'] != null;
    
    // 🔥 計算實際訓練秒數
    final actualDurationSeconds = _calculateActualDuration();
    
    // 解析時間戳記
    final timestamp = workoutSession['completedAt'] ?? 
                     workoutSession['endedAt'] ?? 
                     workoutSession['createdAt'];
    DateTime? dateTime;
    if (timestamp != null) {
      try {
        dateTime = timestamp.toDate();
      } catch (e) {
        print('時間解析失敗: $e');
      }
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
            // 🔥 訓練總覽卡片 - 使用實際秒數
            _buildSummaryCard(actualDurationSeconds, calories, exercises.length, dateTime),
            _buildExercisesList(exercises),
            _buildAnalysisCard(exercises, actualDurationSeconds, calories),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 🔥 訓練總覽卡片 - 顯示實際秒數
  Widget _buildSummaryCard(int durationSeconds, double calories, int exerciseCount, DateTime? dateTime) {
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
                value: _formatDuration(durationSeconds), // ✅ 顯示實際秒數
                label: '訓練時長',
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
            fontSize: 18, // 稍微小一點
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercises.length} 個動作',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

  /// 🔥 單個運動項目 - 只計算已完成的組
  Widget _buildExerciseItem(Map<String, dynamic> exercise, int index) {
    final name = exercise['exerciseName'] ?? exercise['name'] ?? '未知運動';
    final type = exercise['exerciseType'] ?? exercise['type'] ?? 'other';
    final allSets = exercise['sets'] as List<dynamic>? ?? [];
    
    // 🔥 只顯示 status = 'completed' 或 'resting' 的組
    final completedSets = allSets.where((set) {
      final status = set['status'] as String?;
      return status == 'completed' || status == 'resting';
    }).toList();
    
    // 計算總次數和總重量
    int totalReps = 0;
    double totalWeight = 0;
    for (var set in completedSets) {
      final reps = (set['actualReps'] ?? set['reps'] ?? 0) as int;
      final weight = ((set['weight'] ?? 0) as num).toDouble();
      totalReps += reps;
      totalWeight += weight;
    }
    final avgWeight = completedSets.isNotEmpty ? totalWeight / completedSets.length : 0;

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
          '${completedSets.length} 組 • $totalReps 次${avgWeight > 0 ? ' • 平均 ${avgWeight.toStringAsFixed(1)}kg' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(60, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 只顯示已完成的組
              ...completedSets.asMap().entries.map((entry) {
                final displayIndex = entry.key + 1; // 顯示序號
                final set = entry.value as Map<String, dynamic>;
                final actualSetIndex = (set['index'] ?? set['setIndex'] ?? 0) as int; // 實際組號
                final reps = (set['actualReps'] ?? set['reps'] ?? 0) as int;
                final weight = ((set['weight'] ?? 0) as num).toDouble();
                final rest = (set['restTakenSec'] ?? set['restAfter'] ?? 0) as int;

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
                            '$displayIndex', // ✅ 顯示連續編號
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

  /// 🔥 訓練分析卡片 - 只計算已完成的組
  Widget _buildAnalysisCard(List<dynamic> exercises, int durationSeconds, double calories) {
    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0;

    for (var exercise in exercises) {
      final allSets = exercise['sets'] as List<dynamic>? ?? [];
      
      // 🔥 只計算已完成的組
      final completedSets = allSets.where((set) {
        final status = set['status'] as String?;
        return status == 'completed' || status == 'resting';
      }).toList();
      
      totalSets += completedSets.length;
      
      for (var set in completedSets) {
        final reps = (set['actualReps'] ?? set['reps'] ?? 0) as int;
        final weight = ((set['weight'] ?? 0) as num).toDouble();
        totalReps += reps;
        totalVolume += weight * reps;
      }
    }

    // 🔥 平均強度 = 總卡路里 ÷ 訓練時長(分鐘)
    final durationMinutes = durationSeconds / 60.0;
    final avgCaloriesPerMinute = durationMinutes > 0 ? calories / durationMinutes : 0;

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

  String _formatFullDateTime(DateTime dateTime) {
    return DateFormat('yyyy/MM/dd (E) HH:mm:ss', 'zh_TW').format(dateTime);
  }
}