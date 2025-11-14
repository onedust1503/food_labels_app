// lib/components/ui/progress_indicators.dart
// 📊 統一的進度指示器組件（莫蘭迪風格優化版）

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

/// 圓形進度指示器 - 用於顯示百分比（像卡路里進度）
class CircularProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int current;
  final int target;
  final Color progressColor;
  final Color backgroundColor;
  final double size;
  
  const CircularProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    this.progressColor = AppColors.success,
    this.backgroundColor = AppColors.surfaceLight,
    this.size = 130,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      children: [
        // 圓形進度環
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圓環
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10, // 🎯 線條稍微細一點
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    backgroundColor,
                  ),
                ),
              ),
              // 進度圓環
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 10, // 🎯 線條稍微細一點
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // 中間文字
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    current.toString(),
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    target.toString(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 標題和副標題
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// 線性進度條 - 用於營養素等指標
class LinearProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0.0 到 1.0
  final Color color;
  final String? displayValue;
  final bool showPercentage;
  
  const LinearProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.displayValue,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final percentage = (clampedValue * 100).toInt();
    
    return Column(
      children: [
        // 標籤行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label, style: AppTextStyles.bodyMedium),
                if (showPercentage) ...[
                  const SizedBox(width: 10),
                  Text(
                    '$percentage%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
            if (displayValue != null)
              Text(
                displayValue!,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        // 進度條
        ClipRRect(
          // 🎯 圓角改為 10
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: clampedValue,
            minHeight: 10, // 🎯 高度改為 10
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// 半圓進度指示器 - 用於分數顯示
class SemiCircularProgress extends StatelessWidget {
  final int score;
  final int maxScore;
  final Color color;
  final String label;
  final double size;
  
  const SemiCircularProgress({
    super.key,
    required this.score,
    required this.maxScore,
    required this.color,
    this.label = 'Score',
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: CustomPaint(
        painter: _SemiCircularProgressPainter(
          percentage: percentage,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.toString(),
                  style: AppTextStyles.h1.copyWith(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: size * 0.06,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SemiCircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;
  
  _SemiCircularProgressPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    const startAngle = math.pi;
    const sweepAngle = math.pi;
    
    // 背景圓弧
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 // 🎯 線條稍微細一點
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );
    
    // 進度圓弧
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 // 🎯 線條稍微細一點
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 步驟進度指示器 - 用於多步驟流程
class StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color activeColor;
  final Color inactiveColor;
  
  const StepProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.surfaceLight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? 8 : 0,
            ),
            height: 6, // 🎯 高度改為 6
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              // 🎯 圓角改為 3
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

/// 環形進度組 - 用於顯示多個指標
class CircularProgressGroup extends StatelessWidget {
  final List<CircularProgressItem> items;
  
  const CircularProgressGroup({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                SizedBox(
                  width: 70, // 🎯 稍微大一點
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 7, // 🎯 線條稍微細一點
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.color.withValues(alpha: 0.15),
                        ),
                      ),
                      CircularProgressIndicator(
                        value: item.value,
                        strokeWidth: 7, // 🎯 線條稍微細一點
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${(item.value * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: item.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class CircularProgressItem {
  final String label;
  final double value; // 0.0 到 1.0
  final Color color;
  
  CircularProgressItem({
    required this.label,
    required this.value,
    required this.color,
  });
}