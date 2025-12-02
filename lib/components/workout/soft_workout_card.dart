// lib/components/workout/soft_workout_card.dart
// 🎨 Soft UI 風格的運動卡片元件

import 'package:flutter/material.dart';
import '../../theme/workout_colors.dart';

/// Soft UI 基礎卡片
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  
  const SoftCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.boxShadow,
    this.borderRadius,
    this.border,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? WorkoutColors.cardBackground,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow: boxShadow ?? WorkoutColors.softShadow,
        border: border,
      ),
      child: child,
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

/// 組數狀態指示器
enum SetStatus { pending, active, resting, completed, skipped }

class SetStatusIndicator extends StatelessWidget {
  final int setNumber;
  final SetStatus status;
  final VoidCallback? onTap;
  final bool isLarge;
  
  const SetStatusIndicator({
    super.key,
    required this.setNumber,
    required this.status,
    this.onTap,
    this.isLarge = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 56.0 : 44.0;
    final fontSize = isLarge ? 16.0 : 14.0;
    final iconSize = isLarge ? 24.0 : 18.0;
    
    Color backgroundColor;
    Color borderColor;
    Color contentColor;
    IconData? icon;
    
    switch (status) {
      case SetStatus.pending:
        backgroundColor = WorkoutColors.pendingSoft;
        borderColor = WorkoutColors.pendingLight;
        contentColor = WorkoutColors.pending;
        icon = null;
        break;
      case SetStatus.active:
        backgroundColor = WorkoutColors.activeSoft;
        borderColor = WorkoutColors.active;
        contentColor = WorkoutColors.primaryDark;
        icon = Icons.play_arrow_rounded;
        break;
      case SetStatus.resting:
        backgroundColor = WorkoutColors.restSoft;
        borderColor = WorkoutColors.rest;
        contentColor = WorkoutColors.rest;
        icon = Icons.timer_outlined;
        break;
      case SetStatus.completed:
        backgroundColor = WorkoutColors.successSoft;
        borderColor = WorkoutColors.success;
        contentColor = WorkoutColors.success;
        icon = Icons.check_rounded;
        break;
      case SetStatus.skipped:
        backgroundColor = Colors.grey[100]!;
        borderColor = Colors.grey[400]!;
        contentColor = Colors.grey[500]!;
        icon = Icons.skip_next_rounded;
        break;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: status == SetStatus.active || status == SetStatus.resting
              ? [
                  BoxShadow(
                    color: borderColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: contentColor, size: iconSize)
              : Text(
                  '$setNumber',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: contentColor,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 運動進度卡片（頂部顯示）
class ExerciseProgressCard extends StatelessWidget {
  final String exerciseName;
  final String exerciseType;
  final int currentIndex;
  final int totalExercises;
  final int completedSets;
  final int totalSets;
  
  const ExerciseProgressCard({
    super.key,
    required this.exerciseName,
    required this.exerciseType,
    required this.currentIndex,
    required this.totalExercises,
    required this.completedSets,
    required this.totalSets,
  });
  
  @override
  Widget build(BuildContext context) {
    final typeColor = WorkoutColors.getExerciseTypeColor(exerciseType);
    final progress = totalSets > 0 ? completedSets / totalSets : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: WorkoutColors.headerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WorkoutColors.elevatedShadow,
      ),
      child: Column(
        children: [
          // 進度指示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '第 $currentIndex / $totalExercises 個動作',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  exerciseType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 運動名稱
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已完成 $completedSets / $totalSets 組',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圓形計時器
class CircularTimer extends StatelessWidget {
  final int seconds;
  final int totalSeconds;
  final bool isResting;
  final VoidCallback? onAdd30Seconds;
  final VoidCallback? onSkip;
  
  const CircularTimer({
    super.key,
    required this.seconds,
    required this.totalSeconds,
    this.isResting = false,
    this.onAdd30Seconds,
    this.onSkip,
  });
  
  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
    final color = isResting ? WorkoutColors.rest : WorkoutColors.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圓圈
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 12,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.1)),
                ),
              ),
              // 進度圓圈
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // 時間顯示
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isResting ? Icons.timer_outlined : Icons.fitness_center,
                    size: 32,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(seconds),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    isResting ? '休息中' : '訓練中',
                    style: TextStyle(
                      fontSize: 14,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isResting) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onAdd30Seconds != null)
                OutlinedButton.icon(
                  onPressed: onAdd30Seconds,
                  icon: const Icon(Icons.add),
                  label: const Text('+30s'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WorkoutColors.rest,
                    side: const BorderSide(color: WorkoutColors.rest),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              if (onSkip != null)
                ElevatedButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('跳過休息'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorkoutColors.rest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 輸入組件 - 次數/重量
class SetInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? suffix;
  final Color? accentColor;
  
  const SetInputField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.suffix,
    this.accentColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? WorkoutColors.primary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: color.withOpacity(0.3),
                    ),
                    suffixText: suffix,
                    suffixStyle: TextStyle(
                      fontSize: 16,
                      color: color.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}