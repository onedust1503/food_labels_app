// lib/pages/workout/workout_session_detail_page.dart
// 🔥 v3 統一風格版：與 workout_summary_page.dart 風格一致
// ✅ 綠色 Soft UI 風格
// ✅ 2x2 網格統計卡片
// ✅ 支援從 workout_log_page 導航
// ✅ 時長顯示「X 分 Y 秒」格式
// ✅ 新增動作的 [新增] 標籤

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkoutSessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> workoutSession;

  const WorkoutSessionDetailPage({
    super.key,
    required this.workoutSession,
  });

  // 🎨 統一色彩系統（與 workout_summary_page.dart 一致）
  static const Color _primaryGreen = Color(0xFF4CAF50);
  static const Color _lightGreen = Color(0xFFE8F5E9);
  static const Color _backgroundColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    debugPrint('📋 [SessionDetail] 收到資料: ${workoutSession.keys}');

    // 解析基本資料
    final name = workoutSession['name'] ?? '訓練記錄';
    final exercises = workoutSession['exercises'] as List<dynamic>? ?? [];

    // 解析時間
    String dateStr = '';
    String timeStr = '';
    int durationSeconds = 0;

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
        durationSeconds = endTime.difference(startTime).inSeconds;
      }
    }

    // 如果沒有計算出時長，嘗試從其他欄位獲取
    if (durationSeconds == 0) {
      if (workoutSession['totalDurationSeconds'] != null) {
        durationSeconds = (workoutSession['totalDurationSeconds'] as num).toInt();
      } else if (workoutSession['duration'] != null) {
        durationSeconds = (workoutSession['duration'] as num).toInt() * 60;
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
    int addedExercisesCount = workoutSession['addedExercisesCount'] ?? 0;

    // 從 exercises 計算
    if (totalSets == 0 && exercises.isNotEmpty) {
      for (var ex in exercises) {
        final sets = ex['sets'] as List<dynamic>? ?? [];
        if (ex['addedDuringSession'] == true && addedExercisesCount == 0) {
          addedExercisesCount++;
        }
        final validSets = sets.where((s) {
          final status = s['status'] as String?;
          if (status == 'completed' || status == 'resting') return true;
          if (status == 'skipped') {
            return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
          }
          return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
        }).toList();
        totalSets += validSets.length;
        completedSets += validSets.where((s) => s['status'] == 'completed').length;
      }
    }

    if (addedExercisesCount == 0) {
      for (var ex in exercises) {
        if (ex['addedDuringSession'] == true) {
          addedExercisesCount++;
        }
      }
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          '訓練詳情',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _cardColor,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 訓練數據卡片（與 workout_summary_page 一致的 2x2 網格）
            _buildStatsCard(
              name: name,
              timeStr: timeStr,
              durationSeconds: durationSeconds,
              totalExercises: totalExercises,
              totalSets: totalSets,
              completedSets: completedSets,
              calories: calories,
              addedExercisesCount: addedExercisesCount,
            ),
            const SizedBox(height: 16),

            // 🔥 動作詳情卡片
            _buildExercisesCard(exercises),
          ],
        ),
      ),
    );
  }

  // 🔥 統計卡片（2x2 網格，與 workout_summary_page.dart 風格一致）
  Widget _buildStatsCard({
    required String name,
    required String timeStr,
    required int durationSeconds,
    required int totalExercises,
    required int totalSets,
    required int completedSets,
    required double calories,
    required int addedExercisesCount,
  }) {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: _primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🔥 2x2 網格統計（與 workout_summary_page.dart 一致）
          Row(
            children: [
              // 訓練時長
              Expanded(
                child: _buildStatBox(
                  icon: Icons.timer_outlined,
                  iconColor: Colors.blue,
                  value: seconds > 0 ? '$minutes 分 $seconds 秒' : '$minutes 分鐘',
                  label: '訓練時長',
                ),
              ),
              const SizedBox(width: 12),
              // 動作數量
              Expanded(
                child: _buildStatBoxWithBadge(
                  icon: Icons.fitness_center,
                  iconColor: _primaryGreen,
                  value: '$totalExercises',
                  unit: '個',
                  label: '動作數量',
                  badgeText: addedExercisesCount > 0 ? '+$addedExercisesCount 新增' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 完成組數
              Expanded(
                child: _buildStatBox(
                  icon: Icons.repeat,
                  iconColor: Colors.purple,
                  value: completedSets > 0 ? '$completedSets/$totalSets' : '$totalSets',
                  label: '完成組數',
                ),
              ),
              const SizedBox(width: 12),
              // 消耗熱量
              Expanded(
                child: _buildStatBox(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  value: '${calories.toInt()}',
                  unit: '大卡',
                  label: '消耗熱量',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔥 統計方塊（與 workout_summary_page.dart 風格一致）
  Widget _buildStatBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    String? unit,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 帶徽章的統計方塊
  Widget _buildStatBoxWithBadge({
    required IconData icon,
    required Color iconColor,
    required String value,
    String? unit,
    required String label,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // 🔥 新增徽章
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 動作詳情卡片
  Widget _buildExercisesCard(List<dynamic> exercises) {
    if (exercises.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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

    int addedCount = exercises.where((ex) => ex['addedDuringSession'] == true).length;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.list_alt,
                    color: _primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '動作詳情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      '${exercises.length} 個動作',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (addedCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$addedCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
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
    final name = exercise['name'] ?? exercise['exerciseName'] ?? '動作 ${index + 1}';
    final allSets = exercise['sets'] as List<dynamic>? ?? [];
    final isAddedDuringSession = exercise['addedDuringSession'] == true;

    final sets = allSets.where((s) {
      final status = s['status'] as String?;
      if (status == 'completed' || status == 'resting') return true;
      return s['reps'] != null || s['weight'] != null || s['actualReps'] != null;
    }).toList();

    final completedSets = sets.where((s) => s['status'] == 'completed').length;

    return ExpansionTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _lightGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
              fontSize: 16,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          if (isAddedDuringSession) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '新增',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        sets.isEmpty
            ? '無組數記錄'
            : '完成 $completedSets / ${sets.length} 組',
        style: const TextStyle(color: _textSecondary, fontSize: 13),
      ),
      iconColor: _primaryGreen,
      collapsedIconColor: _textSecondary,
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
    final restSec = setData['restTakenSec'] ?? setData['restSec'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = _primaryGreen;
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
      color: setIndex.isEven ? Colors.grey[50] : _cardColor,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
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
                  fontSize: 13,
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
                  fontSize: 13,
                ),
              ),
            ),
          ],
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