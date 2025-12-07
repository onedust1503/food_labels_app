// lib/components/completion_status_badge.dart
// 🔥 訓練完成狀態標籤元件 v2.0
// ✅ v2.0 更新：使用新類名避免衝突
//    - WeeklyPlanProgress → WeeklyCompletionSummary
//    - DayProgress → DayCompletionInfo
// 統一的狀態顯示元件，用於列表和詳情頁面

import 'package:flutter/material.dart';
import '../models/completion_status.dart';

/// 🔥 狀態標籤（緊湊版）- 用於列表項目
class CompletionStatusBadge extends StatelessWidget {
  final CompletionStatusType statusType;
  final bool showIcon;
  final bool compact;
  
  const CompletionStatusBadge({
    super.key,
    required this.statusType,
    this.showIcon = true,
    this.compact = false,
  });
  
  /// 從舊的 isOnSchedule 布林值創建（向後相容）
  factory CompletionStatusBadge.fromBool({
    required bool isOnSchedule,
    bool showIcon = true,
    bool compact = false,
  }) {
    return CompletionStatusBadge(
      statusType: isOnSchedule 
          ? CompletionStatusType.onTime 
          : CompletionStatusType.makeup,
      showIcon: showIcon,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = CompletionStatus.fromType(statusType);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: status.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              status.icon,
              size: compact ? 12 : 14,
              color: status.color,
            ),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            compact ? status.shortLabel : status.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔥 狀態圖標（極簡版）- 用於週曆視圖
class CompletionStatusDot extends StatelessWidget {
  final CompletionStatusType? statusType;
  final double size;
  final bool showBorder;
  
  const CompletionStatusDot({
    super.key,
    this.statusType,
    this.size = 12,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (statusType == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          border: showBorder ? Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ) : null,
        ),
      );
    }
    
    final status = CompletionStatus.fromType(statusType!);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: status.backgroundColor,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(
          color: status.color.withOpacity(0.5),
          width: 1.5,
        ) : null,
      ),
      child: Icon(
        status.icon,
        size: size * 0.6,
        color: status.color,
      ),
    );
  }
}

/// 🔥 週進度條 - 顯示本週七天的完成狀態
/// v2.0：使用 DayCompletionInfo（舊名 DayProgress）
class WeekProgressBar extends StatelessWidget {
  final List<DayCompletionInfo> dayProgress;
  final List<String>? planDays; // 計畫訓練日
  
  const WeekProgressBar({
    super.key,
    required this.dayProgress,
    this.planDays,
  });

  @override
  Widget build(BuildContext context) {
    // 建立完整的一週資料
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final isToday = date.day == now.day && 
                        date.month == now.month && 
                        date.year == now.year;
        
        // 找到對應的進度資料
        // 🔥 v2.0：使用 DayCompletionInfo
        final progress = dayProgress.firstWhere(
          (p) => p.date.day == date.day && 
                 p.date.month == date.month && 
                 p.date.year == date.year,
          orElse: () => DayCompletionInfo(
            dayOfWeek: '星期${weekDays[index]}',
            date: date,
            hasPlannedWorkout: false,
          ),
        );
        
        return _WeekDayItem(
          label: weekDays[index],
          date: date.day.toString(),
          isToday: isToday,
          hasWorkout: progress.hasPlannedWorkout,
          status: progress.status,
        );
      }),
    );
  }
}

class _WeekDayItem extends StatelessWidget {
  final String label;
  final String date;
  final bool isToday;
  final bool hasWorkout;
  final CompletionStatusType? status;
  
  const _WeekDayItem({
    required this.label,
    required this.date,
    required this.isToday,
    required this.hasWorkout,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color? statusColor;
    IconData? statusIcon;
    
    if (status != null) {
      final statusInfo = CompletionStatus.fromType(status!);
      statusColor = statusInfo.color;
      statusIcon = statusInfo.icon;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 星期標籤
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isToday ? Colors.blue : Colors.grey[600],
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        // 日期圓圈
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isToday 
                ? Colors.blue.withOpacity(0.1)
                : (hasWorkout ? statusColor?.withOpacity(0.1) : Colors.grey[100]),
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday 
                  ? Colors.blue 
                  : (hasWorkout && statusColor != null ? statusColor : Colors.grey[300]!),
              width: isToday ? 2 : 1,
            ),
          ),
          child: Center(
            child: hasWorkout && statusIcon != null
                ? Icon(statusIcon, size: 16, color: statusColor)
                : Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.blue : Colors.grey[700],
                    ),
                  ),
          ),
        ),
        // 訓練日標記
        const SizedBox(height: 4),
        if (hasWorkout)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor ?? Colors.grey,
              shape: BoxShape.circle,
            ),
          )
        else
          const SizedBox(height: 6),
      ],
    );
  }
}

/// 🔥 進度統計卡片 - 顯示完成率和各狀態數量
/// v2.0：使用 WeeklyCompletionSummary（舊名 WeeklyPlanProgress）
class ProgressStatsCard extends StatelessWidget {
  final WeeklyCompletionSummary progress;
  final bool showDetails;
  
  const ProgressStatsCard({
    super.key,
    required this.progress,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // 標題和完成率
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本週進度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getProgressColor(progress.completionRate).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress.completionRate * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getProgressColor(progress.completionRate),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.completionRate,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(progress.completionRate),
              ),
              minHeight: 8,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 摘要文字
          Text(
            progress.summaryText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          
          if (showDetails) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // 詳細統計
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (progress.completedOnTime > 0)
                  _buildStatChip(
                    CompletionStatusType.onTime, 
                    progress.completedOnTime,
                  ),
                if (progress.completedEarly > 0)
                  _buildStatChip(
                    CompletionStatusType.early, 
                    progress.completedEarly,
                  ),
                if (progress.completedMakeup > 0)
                  _buildStatChip(
                    CompletionStatusType.makeup, 
                    progress.completedMakeup,
                  ),
                if (progress.dueToday > 0)
                  _buildStatChip(
                    CompletionStatusType.dueToday, 
                    progress.dueToday,
                  ),
                if (progress.overdue > 0)
                  _buildStatChip(
                    CompletionStatusType.overdue, 
                    progress.overdue,
                  ),
                if (progress.pending > 0)
                  _buildStatChip(
                    CompletionStatusType.pending, 
                    progress.pending,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatChip(CompletionStatusType type, int count) {
    final status = CompletionStatus.fromType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            '${status.shortLabel} $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getProgressColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981); // 綠色
    if (rate >= 0.5) return const Color(0xFFF59E0B); // 黃色
    return const Color(0xFFEF4444); // 紅色
  }
}

/// 🔥 訓練記錄卡片 - 用於列表顯示
class WorkoutLogCard extends StatelessWidget {
  final WorkoutCompletionRecord record;
  final VoidCallback? onTap;
  final bool showPlanName;
  
  const WorkoutLogCard({
    super.key,
    required this.record,
    this.onTap,
    this.showPlanName = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = record.status;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status.color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部：日期 + 狀態標籤
            Row(
              children: [
                // 日期圓圈
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        record.actualDate?.day.toString() ?? '--',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                      Text(
                        '${record.actualDate?.month ?? '--'}月',
                        style: TextStyle(
                          fontSize: 11,
                          color: status.color.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 計畫名稱和星期
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showPlanName)
                        Text(
                          record.planName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '計畫日: ${record.planDayOfWeek}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (record.actualDayOfWeek != null && 
                              record.actualDayOfWeek != record.planDayOfWeek) ...[
                            Text(
                              ' → ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              '實際: ${record.actualDayOfWeek}',
                              style: TextStyle(
                                fontSize: 12,
                                color: status.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 狀態標籤
                CompletionStatusBadge(
                  statusType: record.statusType,
                  compact: true,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 底部：訓練統計
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.fitness_center,
                    '${record.exerciseCount} 動作',
                  ),
                  _buildStatItem(
                    Icons.timer_outlined,
                    '${record.duration} 分鐘',
                  ),
                  _buildStatItem(
                    Icons.local_fire_department_outlined,
                    '${record.calories.round()} 卡',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 🔥 狀態圖例說明
class StatusLegend extends StatelessWidget {
  final bool compact;
  
  const StatusLegend({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      CompletionStatusType.onTime,
      CompletionStatusType.early,
      CompletionStatusType.makeup,
      CompletionStatusType.dueToday,
      CompletionStatusType.overdue,
      CompletionStatusType.pending,
    ];
    
    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: statuses.map((type) {
          final status = CompletionStatus.fromType(type);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        }).toList(),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statuses.map((type) {
        final status = CompletionStatus.fromType(type);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(status.icon, size: 18, color: status.color),
              const SizedBox(width: 8),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: status.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}