// lib/pages/coach/trainee_plans_tab.dart
// 🎯 學員計畫進度分頁 v3.0
// ✅ 整合新的 CompletionStatus 狀態系統
// ✅ 支援 6 種完成狀態：準時、提前、補做、今日待做、逾期、待完成
// ✅ 修復 isOnSchedule 判斷邏輯

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/completion_status.dart';
import '../../services/workout_completion_service.dart';
import '../../components/completion_status_badge.dart';

class TraineePlansTab extends StatelessWidget {
  final String traineeId;

  const TraineePlansTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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

  // 🔥 v3.0 更新：狀態圖例 - 6 種狀態
  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '狀態說明',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.onTime),
              ),
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.early),
              ),
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.makeup),
              ),
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.dueToday),
              ),
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.overdue),
              ),
              _buildLegendItem(
                CompletionStatus.fromType(CompletionStatusType.pending),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(CompletionStatus status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: status.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: status.color, width: 2),
          ),
          child: Icon(status.icon, size: 10, color: status.color),
        ),
        const SizedBox(width: 4),
        Text(
          status.shortLabel,
          style: AppTextStyles.caption.copyWith(
            color: status.color,
            fontWeight: FontWeight.w500,
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
      future: _getPlanProgressV3(planId),
      builder: (context, progressSnapshot) {
        final progress = progressSnapshot.data ?? {};
        final totalCompletions = progress['total'] ?? 0;
        final onTimeCount = progress['onTime'] ?? 0;
        final earlyCount = progress['early'] ?? 0;
        final makeupCount = progress['makeup'] ?? 0;
        final totalDuration = progress['totalDuration'] ?? 0;
        
        // 準時率 = (準時 + 提前) / 總完成
        final onTimeRate = totalCompletions > 0
            ? ((onTimeCount + earlyCount) / totalCompletions * 100).round()
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
              // 標題區
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

              // 🔥 v3.0：更新統計區 - 顯示各狀態數量
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 主要統計
                    Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.check_circle_outline,
                          label: '完成次數',
                          value: '$totalCompletions',
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _buildStatItem(
                          icon: Icons.schedule,
                          label: '準時率',
                          value: '$onTimeRate%',
                          color: onTimeRate >= 80
                              ? AppColors.success
                              : onTimeRate >= 50
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        _buildStatItem(
                          icon: Icons.timer_outlined,
                          label: '總時長',
                          value: _formatDuration(totalDuration),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    
                    // 狀態分佈
                    if (totalCompletions > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildMiniStat('準時', onTimeCount, CompletionStatusType.onTime),
                            _buildMiniStat('提前', earlyCount, CompletionStatusType.early),
                            _buildMiniStat('補做', makeupCount, CompletionStatusType.makeup),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 本週進度
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
                      future: _getWeeklyProgressV3(planId, daysList),
                      builder: (context, weekSnapshot) {
                        final weekProgress = weekSnapshot.data ?? {};
                        return _buildWeekProgressBarV3(daysList, weekProgress);
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

  Widget _buildMiniStat(String label, int count, CompletionStatusType type) {
    final status = CompletionStatus.fromType(type);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: status.color),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: AppTextStyles.caption.copyWith(
            color: status.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

  // 🔥 v3.0：更新週進度條 - 支援 6 種狀態顏色
  Widget _buildWeekProgressBarV3(
    List<Map<String, dynamic>> daysList,
    Map<String, Map<String, dynamic>> weekProgress,
  ) {
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    
    final today = DateTime.now().weekday;

    // 建立計畫日集合
    final plannedDaysSet = <String>{};
    for (final day in daysList) {
      final dayOfWeek = day['dayOfWeek']?.toString() ?? '';
      if (dayOfWeek.isNotEmpty) {
        final normalized = _normalizeDayOfWeek(dayOfWeek);
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
        final isPast = today > index + 1;

        final isPlanned = plannedDaysSet.contains(dayKey);
        final progressData = weekProgress[dayKey];
        
        // 🔥 計算狀態
        CompletionStatusType? statusType;
        if (progressData != null) {
          statusType = progressData['statusType'] as CompletionStatusType?;
        } else if (isPlanned) {
          if (isToday) {
            statusType = CompletionStatusType.dueToday;
          } else if (isPast) {
            statusType = CompletionStatusType.overdue;
          } else {
            statusType = CompletionStatusType.pending;
          }
        }

        return _buildWeekDayItemV3(
          dayLabel: dayLabel,
          isToday: isToday,
          isPlanned: isPlanned,
          statusType: statusType,
        );
      }).toList(),
    );
  }

  Widget _buildWeekDayItemV3({
    required String dayLabel,
    required bool isToday,
    required bool isPlanned,
    CompletionStatusType? statusType,
  }) {
    Color bgColor;
    Color borderColor;
    Widget? centerWidget;

    if (statusType != null) {
      final status = CompletionStatus.fromType(statusType);
      
      // 已完成狀態
      if (statusType == CompletionStatusType.onTime ||
          statusType == CompletionStatusType.early ||
          statusType == CompletionStatusType.makeup) {
        bgColor = status.color;
        borderColor = status.color;
        centerWidget = Icon(status.icon, size: 18, color: Colors.white);
      } 
      // 待完成狀態
      else if (statusType == CompletionStatusType.dueToday) {
        bgColor = status.backgroundColor;
        borderColor = status.color;
        centerWidget = Icon(Icons.today, size: 16, color: status.color);
      }
      // 逾期狀態
      else if (statusType == CompletionStatusType.overdue) {
        bgColor = status.backgroundColor;
        borderColor = status.color;
        centerWidget = Icon(Icons.warning_amber, size: 16, color: status.color);
      }
      // 未來待做
      else {
        bgColor = Colors.white;
        borderColor = AppColors.textTertiary;
      }
    } else if (!isPlanned) {
      // 非訓練日
      bgColor = AppColors.background;
      borderColor = AppColors.divider;
    } else {
      bgColor = Colors.white;
      borderColor = AppColors.textTertiary;
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
            boxShadow: statusType != null && 
                (statusType == CompletionStatusType.onTime ||
                 statusType == CompletionStatusType.early ||
                 statusType == CompletionStatusType.makeup)
                ? AppShadows.small 
                : null,
          ),
          child: centerWidget,
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
  }

  // 🔥 v3.0：取得計畫進度（區分三種完成狀態）
  Future<Map<String, dynamic>> _getPlanProgressV3(String planId) async {
    try {
      final completions = await FirebaseFirestore.instance
          .collection('workoutCompletions')
          .where('planId', isEqualTo: planId)
          .where('userId', isEqualTo: traineeId)
          .get();

      int total = completions.docs.length;
      int onTime = 0;
      int early = 0;
      int makeup = 0;
      int totalDuration = 0;

      for (final doc in completions.docs) {
        final data = doc.data();
        totalDuration += _toInt(data['totalDuration']);
        
        // 使用新的狀態計算邏輯
        final planDayOfWeek = data['planDayOfWeek'] ?? data['dayOfWeek'] ?? '';
        final actualDate = data['actualDate'] != null 
            ? (data['actualDate'] as Timestamp).toDate()
            : null;
        
        if (actualDate != null) {
          final statusType = WorkoutCompletionService().calculateStatus(
            planDayOfWeek: planDayOfWeek,
            actualDate: actualDate,
            referenceDate: actualDate, // 使用完成日期作為參考
          );
          
          switch (statusType) {
            case CompletionStatusType.onTime:
              onTime++;
              break;
            case CompletionStatusType.early:
              early++;
              break;
            case CompletionStatusType.makeup:
              makeup++;
              break;
            default:
              break;
          }
        } else {
          // 向後相容：使用舊的 isOnSchedule 欄位
          if (data['isOnSchedule'] == true) {
            onTime++;
          } else {
            makeup++;
          }
        }
      }

      return {
        'total': total,
        'onTime': onTime,
        'early': early,
        'makeup': makeup,
        'totalDuration': totalDuration,
      };
    } catch (e) {
      debugPrint('取得計畫進度錯誤: $e');
      return {'total': 0, 'onTime': 0, 'early': 0, 'makeup': 0, 'totalDuration': 0};
    }
  }

  // 🔥 v3.0：取得本週進度（包含狀態類型）
  Future<Map<String, Map<String, dynamic>>> _getWeeklyProgressV3(
    String planId,
    List<Map<String, dynamic>> daysList,
  ) async {
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
      final completionService = WorkoutCompletionService();

      for (final doc in completions.docs) {
        final data = doc.data();
        
        DateTime? completionDate;
        if (data['actualDate'] is Timestamp) {
          completionDate = (data['actualDate'] as Timestamp).toDate();
        } else if (data['completionDate'] is Timestamp) {
          completionDate = (data['completionDate'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          completionDate = (data['createdAt'] as Timestamp).toDate();
        }
        
        // 只處理本週的記錄
        if (completionDate != null && 
            completionDate.isAfter(startDate.subtract(const Duration(hours: 1)))) {
          
          final planDayOfWeek = data['planDayOfWeek']?.toString() ?? 
                                data['dayOfWeek']?.toString() ?? '';
          final normalizedDay = _normalizeDayOfWeek(planDayOfWeek);
          
          if (normalizedDay.isNotEmpty) {
            // 計算狀態類型
            final statusType = completionService.calculateStatus(
              planDayOfWeek: planDayOfWeek,
              actualDate: completionDate,
              referenceDate: now,
            );
            
            result[normalizedDay] = {
              'statusType': statusType,
              'completionDate': completionDate,
              'isOnSchedule': data['isOnSchedule'] ?? false,
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

  // 🔥 星期格式正規化
  String _normalizeDayOfWeek(String dayOfWeek) {
    final normalized = dayOfWeek.toLowerCase().trim();
    
    const mapping = {
      '星期一': 'monday', '週一': 'monday', 'monday': 'monday', 'mon': 'monday',
      '星期二': 'tuesday', '週二': 'tuesday', 'tuesday': 'tuesday', 'tue': 'tuesday',
      '星期三': 'wednesday', '週三': 'wednesday', 'wednesday': 'wednesday', 'wed': 'wednesday',
      '星期四': 'thursday', '週四': 'thursday', 'thursday': 'thursday', 'thu': 'thursday',
      '星期五': 'friday', '週五': 'friday', 'friday': 'friday', 'fri': 'friday',
      '星期六': 'saturday', '週六': 'saturday', 'saturday': 'saturday', 'sat': 'saturday',
      '星期日': 'sunday', '週日': 'sunday', 'sunday': 'sunday', 'sun': 'sunday',
    };
    
    return mapping[normalized] ?? normalized;
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