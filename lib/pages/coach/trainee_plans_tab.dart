// lib/pages/coach/trainee_plans_tab.dart
// 🎯 學員計畫進度分頁 v2.1
// ✅ 修復：移除 orderBy 避免索引問題
// ✅ 修復：支援 days 陣列格式
// ✅ 修復：workoutCompletions 頂層集合查詢

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class TraineePlansTab extends StatelessWidget {
  final String traineeId;

  const TraineePlansTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // 🔥 修復：移除 orderBy，只用 where
      stream: FirebaseFirestore.instance
          .collection('workoutPlans')
          .where('traineeId', isEqualTo: traineeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // 🔥 手動排序
        final plans = snapshot.data!.docs.toList();
        plans.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = _getDateTime(aData['createdAt']);
          final bDate = _getDateTime(bData['createdAt']);
          return bDate.compareTo(aDate);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildLegend();
            }
            final plan = plans[index - 1];
            final data = plan.data() as Map<String, dynamic>;
            return _buildPlanCard(context, plan.id, data);
          },
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(AppColors.success, '按時'),
          const SizedBox(width: 16),
          _buildLegendItem(AppColors.warning, '補做'),
          const SizedBox(width: 16),
          _buildLegendItem(Colors.white, '待完成'),
          const SizedBox(width: 16),
          _buildLegendItem(AppColors.background, '休息'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    final isWhite = color == Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isWhite ? AppColors.textTertiary : color,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String planId,
    Map<String, dynamic> data,
  ) {
    final planName = data['planName']?.toString() ?? '未命名計畫';
    final status = data['status']?.toString() ?? 'active';
    final isActive = status == 'active';

    // 🔥 支援 days 陣列或 Map 格式
    final daysData = data['days'];
    List<Map<String, dynamic>> daysList = [];
    
    if (daysData is List) {
      daysList = daysData.map((d) => d as Map<String, dynamic>).toList();
    } else if (daysData is Map) {
      daysList = (daysData as Map<String, dynamic>).values
          .map((d) => d as Map<String, dynamic>)
          .toList();
    }

    final plannedDays = daysList.where((day) {
      final exercises = day['exercises'];
      if (exercises is List) {
        return exercises.isNotEmpty;
      }
      return false;
    }).length;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getPlanProgress(planId),
      builder: (context, progressSnapshot) {
        final progress = progressSnapshot.data ?? {};
        final totalCompletions = progress['total'] ?? 0;
        final onScheduleCount = progress['onSchedule'] ?? 0;
        final totalDuration = progress['totalDuration'] ?? 0;
        final onScheduleRate = totalCompletions > 0
            ? (onScheduleCount / totalCompletions * 100).round()
            : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.small,
            border: Border.all(
              color: isActive
                  ? AppColors.coach.withOpacity(0.3)
                  : AppColors.divider,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? AppColors.secondaryGradient
                      : AppColors.neutralGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$plannedDays 天訓練 / 週',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? '進行中' : '已完成',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.check_circle_outline,
                      label: '完成次數',
                      value: '$totalCompletions',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      icon: Icons.schedule,
                      label: '按時率',
                      value: '$onScheduleRate%',
                      color: onScheduleRate >= 80
                          ? AppColors.success
                          : onScheduleRate >= 50
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      icon: Icons.timer_outlined,
                      label: '總時長',
                      value: _formatDuration(totalDuration),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本週進度',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, Map<String, dynamic>>>(
                      future: _getWeeklyProgress(planId),
                      builder: (context, weekSnapshot) {
                        final weekProgress = weekSnapshot.data ?? {};
                        return _buildWeekProgressBar(daysList, weekProgress);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.h4.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekProgressBar(
    List<Map<String, dynamic>> daysList,
    Map<String, Map<String, dynamic>> weekProgress,
  ) {
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final chineseDayMap = {
      '星期一': 'monday', '星期二': 'tuesday', '星期三': 'wednesday',
      '星期四': 'thursday', '星期五': 'friday', '星期六': 'saturday', '星期日': 'sunday',
      '週一': 'monday', '週二': 'tuesday', '週三': 'wednesday',
      '週四': 'thursday', '週五': 'friday', '週六': 'saturday', '週日': 'sunday',
    };
    
    final today = DateTime.now().weekday;

    final plannedDaysSet = <String>{};
    for (final day in daysList) {
      final dayOfWeek = day['dayOfWeek']?.toString().toLowerCase() ?? '';
      if (dayOfWeek.isNotEmpty) {
        final normalized = chineseDayMap[dayOfWeek] ?? dayOfWeek;
        final exercises = day['exercises'];
        if (exercises is List && exercises.isNotEmpty) {
          plannedDaysSet.add(normalized);
        }
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: dayKeys.asMap().entries.map((entry) {
        final index = entry.key;
        final dayKey = entry.value;
        final dayLabel = dayLabels[index];
        final isToday = today == index + 1;

        final isPlanned = plannedDaysSet.contains(dayKey);
        
        final progress = weekProgress[dayKey];
        final isCompleted = progress != null;
        final isOnSchedule = progress?['isOnSchedule'] ?? false;

        Color bgColor;
        Color borderColor;
        IconData? icon;

        if (isCompleted) {
          bgColor = isOnSchedule ? AppColors.success : AppColors.warning;
          borderColor = bgColor;
          icon = isOnSchedule ? Icons.check : Icons.schedule;
        } else if (isPlanned) {
          bgColor = Colors.white;
          borderColor = isToday ? AppColors.warning : AppColors.textTertiary;
        } else {
          bgColor = AppColors.background;
          borderColor = AppColors.divider;
        }

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isToday ? 2.5 : 1.5,
                ),
                boxShadow: isCompleted ? AppShadows.small : null,
              ),
              child: icon != null
                  ? Icon(icon, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              dayLabel,
              style: AppTextStyles.caption.copyWith(
                color: isToday ? AppColors.warning : AppColors.textSecondary,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  // 🔥 取得計畫進度（移除 orderBy）
  Future<Map<String, dynamic>> _getPlanProgress(String planId) async {
    try {
      final completions = await FirebaseFirestore.instance
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: traineeId)
          .get();

      int total = completions.docs.length;
      int onSchedule = 0;
      int totalDuration = 0;

      for (final doc in completions.docs) {
        final data = doc.data();
        if (data['isOnSchedule'] == true) {
          onSchedule++;
        }
        totalDuration += _toInt(data['totalDuration']);
      }

      return {
        'total': total,
        'onSchedule': onSchedule,
        'totalDuration': totalDuration,
      };
    } catch (e) {
      debugPrint('取得計畫進度錯誤: $e');
      return {'total': 0, 'onSchedule': 0, 'totalDuration': 0};
    }
  }

  // 🔥 取得本週進度
  Future<Map<String, Map<String, dynamic>>> _getWeeklyProgress(String planId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final completions = await FirebaseFirestore.instance
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: traineeId)
          .get();

      final result = <String, Map<String, dynamic>>{};

      final chineseDayMap = {
        '星期一': 'monday', '星期二': 'tuesday', '星期三': 'wednesday',
        '星期四': 'thursday', '星期五': 'friday', '星期六': 'saturday', '星期日': 'sunday',
      };

      for (final doc in completions.docs) {
        final data = doc.data();
        
        DateTime? completionDate;
        if (data['completionDate'] is Timestamp) {
          completionDate = (data['completionDate'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          completionDate = (data['createdAt'] as Timestamp).toDate();
        }
        
        if (completionDate != null && completionDate.isAfter(startDate)) {
          final dayOfWeek = data['dayOfWeek']?.toString() ?? '';
          final normalizedDay = chineseDayMap[dayOfWeek] ?? dayOfWeek.toLowerCase();
          
          if (normalizedDay.isNotEmpty) {
            result[normalizedDay] = {
              'isOnSchedule': data['isOnSchedule'] ?? false,
              'completionDate': completionDate,
            };
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('取得週進度錯誤: $e');
      return {};
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            '載入失敗',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.coach.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '尚無訓練計畫',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '為這位學員創建訓練計畫吧！',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes 分';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours 時';
    return '$hours 時 $mins 分';
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _getDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}