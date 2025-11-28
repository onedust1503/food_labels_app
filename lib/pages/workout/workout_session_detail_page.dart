// lib/pages/workout/workout_session_detail_page.dart
// 🔥 完整修正版：確保能正確讀取 UnifiedWorkoutService 傳來的資料
// ✅ 支援從 workout_log_page 導航
// ✅ 支援從 workoutSessions 集合讀取的資料格式

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkoutSessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> workoutSession;

  const WorkoutSessionDetailPage({
    super.key,
    required this.workoutSession,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('📋 [SessionDetail] 收到資料: ${workoutSession.keys}');

    // 解析基本資料
    final name = workoutSession['name'] ?? '訓練記錄';
    final exercises = workoutSession['exercises'] as List<dynamic>? ?? [];

    // 解析時間
    String dateStr = '';
    String timeStr = '';
    int durationMinutes = 0;

    // 嘗試多種時間格式
    final startedAt = workoutSession['startedAt'];
    final endedAt = workoutSession['endedAt'];
    final completedAt = workoutSession['completedAt'];
    final timestamp = workoutSession['timestamp'];
    final createdAt = workoutSession['createdAt'];

    DateTime? startTime;
    DateTime? endTime;

    // 解析開始時間
    if (startedAt != null) {
      if (startedAt is Timestamp) {
        startTime = startedAt.toDate();
      } else if (startedAt is int) {
        startTime = DateTime.fromMillisecondsSinceEpoch(startedAt);
      }
    } else if (timestamp != null) {
      if (timestamp is int) {
        startTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } else if (createdAt != null) {
      if (createdAt is Timestamp) {
        startTime = createdAt.toDate();
      } else if (createdAt is int) {
        startTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
      }
    }

    // 解析結束時間
    if (endedAt != null) {
      if (endedAt is Timestamp) {
        endTime = endedAt.toDate();
      } else if (endedAt is int) {
        endTime = DateTime.fromMillisecondsSinceEpoch(endedAt);
      }
    } else if (completedAt != null) {
      if (completedAt is Timestamp) {
        endTime = completedAt.toDate();
      } else if (completedAt is int) {
        endTime = DateTime.fromMillisecondsSinceEpoch(completedAt);
      }
    }

    if (startTime != null) {
      dateStr = DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(startTime);
      timeStr = DateFormat('HH:mm').format(startTime);
      if (endTime != null) {
        timeStr += ' - ${DateFormat('HH:mm').format(endTime)}';
        durationMinutes = endTime.difference(startTime).inMinutes;
      }
    }

    // 如果沒有計算出時長，嘗試從其他欄位獲取
    if (durationMinutes == 0) {
      if (workoutSession['totalDurationSeconds'] != null) {
        durationMinutes = (workoutSession['totalDurationSeconds'] / 60).round();
      } else if (workoutSession['duration'] != null) {
        durationMinutes = workoutSession['duration'] as int;
      }
    }

    // 卡路里
    double calories = 0;
    if (workoutSession['totalCalories'] != null) {
      calories = (workoutSession['totalCalories'] as num).toDouble();
    } else if (workoutSession['caloriesBurned'] != null) {
      calories = (workoutSession['caloriesBurned'] as num).toDouble();
    } else if (workoutSession['calories'] != null) {
      calories = (workoutSession['calories'] as num).toDouble();
    }

    // 總組數和動作數
    int totalSets = workoutSession['totalSets'] ?? 0;
    int totalExercises = workoutSession['totalExercises'] ?? exercises.length;
    int completedSets = 0;

    // 從 exercises 計算
    if (totalSets == 0 && exercises.isNotEmpty) {
      for (var ex in exercises) {
        final sets = ex['sets'] as List<dynamic>? ?? [];
        // 🔥 修正：只計算有實際數據的組（排除空的 pending 組）
        final validSets = sets.where((s) {
          final status = s['status'] as String?;
          // completed 或 resting 的組一定是有效的
          if (status == 'completed' || status == 'resting') return true;
          // skipped 的組如果有 reps 或 weight 數據也算有效
          if (status == 'skipped') {
            return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
          }
          // pending 的組只有在有數據時才算
          return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
        }).toList();
        totalSets += validSets.length;
        completedSets += validSets.where((s) => s['status'] == 'completed').length;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('訓練詳情'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題卡片
            _buildHeaderCard(
              name: name,
              dateStr: dateStr,
              timeStr: timeStr,
            ),
            const SizedBox(height: 16),

            // 統計概覽
            _buildStatsCard(
              durationMinutes: durationMinutes,
              totalExercises: totalExercises,
              totalSets: totalSets,
              completedSets: completedSets,
              calories: calories,
            ),
            const SizedBox(height: 16),

            // 動作詳情
            _buildExercisesCard(exercises),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String name,
    required String dateStr,
    required String timeStr,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF2DC4EA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFF6C63FF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard({
    required int durationMinutes,
    required int totalExercises,
    required int totalSets,
    required int completedSets,
    required double calories,
  }) {
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
            ],
          ),
          const SizedBox(height: 16),
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
                value: completedSets > 0 ? '$completedSets/$totalSets' : '$totalSets',
                label: '組數',
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
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

  Widget _buildExercisesCard(List<dynamic> exercises) {
    if (exercises.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              '這筆記錄可能是事後手動添加的',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                  '${exercises.length} 個動作',
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
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exercise = exercises[index] as Map<String, dynamic>;
              return _buildExerciseItem(exercise, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise, int index) {
    final name = exercise['name'] ?? '動作 ${index + 1}';
    final allSets = exercise['sets'] as List<dynamic>? ?? [];
    
    // 🔥 修正：過濾掉空的 pending 組
    final sets = allSets.where((s) {
      final status = s['status'] as String?;
      // completed 或 resting 的組一定是有效的
      if (status == 'completed' || status == 'resting') return true;
      // 其他狀態的組必須有數據才算有效
      return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
    }).toList();
    
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
        sets.isEmpty
            ? '無組數記錄'
            : '完成 $completedSets / ${sets.length} 組',
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
    // 支援多種欄位名稱
    final reps = setData['actualReps'] ?? setData['reps'];
    final weight = setData['actualWeight'] ?? setData['weight'];
    final restSec = setData['restTakenSec'] ?? setData['restSec'];

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
      case 'resting':
        statusColor = Colors.orange;
        statusIcon = Icons.timer;
        statusText = '休息中';
        break;
      case 'active':
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        statusText = '進行中';
        break;
      default:
        statusColor = Colors.grey[400]!;
        statusIcon = Icons.radio_button_unchecked;
        statusText = '待完成';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: setIndex.isEven ? Colors.grey[50] : Colors.white,
      child: Row(
        children: [
          // 組數編號
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
          
          // 狀態圖標和文字
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
          
          // 次數
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
                  fontSize: 13,
                ),
              ),
            ),
          
          // 重量
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
                  fontSize: 13,
                ),
              ),
            ),
          ],
          
          // 休息時間
          if (restSec != null && restSec > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '休${restSec}s',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}