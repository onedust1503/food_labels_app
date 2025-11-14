// lib/components/ui/progress_indicators.dart
// 📊 統一的進度指示器組件

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
    this.size = 120,
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
                  strokeWidth: 12,
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
                  strokeWidth: 12,
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
                  const SizedBox(height: 2),
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
        
        const SizedBox(height: AppSizes.gapMedium),
        
        // 標題和副標題
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
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
                  const SizedBox(width: 8),
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
        
        const SizedBox(height: 8),
        
        // 進度條
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          child: LinearProgressIndicator(
            value: clampedValue,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// 半圓進度指示器 - 用於分數顯示（像 Learning Pathway Status）
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
          backgroundColor: color.withOpacity(0.15),
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
    const startAngle = math.pi; // 從左邊開始
    const sweepAngle = math.pi; // 180度半圓
    
    // 背景圓弧
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
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
      ..strokeWidth = 20
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
        final isCurrent = index == currentStep - 1;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? AppSizes.gapSmall : 0,
            ),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// 環形進度組 - 用於顯示多個指標（像今日活動的三個指標）
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.color.withOpacity(0.15),
                        ),
                      ),
                      CircularProgressIndicator(
                        value: item.value,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '${(item.value * 100).toInt()}%',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: item.color,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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