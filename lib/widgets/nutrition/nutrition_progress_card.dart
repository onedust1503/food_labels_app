// lib/widgets/nutrition/nutrition_progress_card.dart
// 營養成分展示卡片 - 帶有視覺化進度條

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class NutritionProgressCard extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? dailyCalorieGoal;
  final double? dailyProteinGoal;
  final double? dailyCarbsGoal;
  final double? dailyFatGoal;

  const NutritionProgressCard({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.dailyCalorieGoal,
    this.dailyProteinGoal,
    this.dailyCarbsGoal,
    this.dailyFatGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryPale,
            AppColors.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '營養成分',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 熱量 - 最突出
          _buildNutrientRow(
            icon: Icons.local_fire_department,
            label: '熱量',
            value: calories,
            unit: '大卡',
            color: AppColors.calories,
            goal: dailyCalorieGoal,
            isLarge: true,
          ),
          const SizedBox(height: 16),

          // 三大營養素
          _buildNutrientRow(
            icon: Icons.fitness_center,
            label: '蛋白質',
            value: protein,
            unit: 'g',
            color: AppColors.protein,
            goal: dailyProteinGoal,
          ),
          const SizedBox(height: 12),
          
          _buildNutrientRow(
            icon: Icons.grain,
            label: '碳水化合物',
            value: carbs,
            unit: 'g',
            color: AppColors.carbs,
            goal: dailyCarbsGoal,
          ),
          const SizedBox(height: 12),
          
          _buildNutrientRow(
            icon: Icons.water_drop,
            label: '脂肪',
            value: fat,
            unit: 'g',
            color: AppColors.fat,
            goal: dailyFatGoal,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow({
    required IconData icon,
    required String label,
    required double value,
    required String unit,
    required Color color,
    double? goal,
    bool isLarge = false,
  }) {
    // 計算進度百分比
    double progress = goal != null && goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標籤和數值
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: isLarge ? 20 : 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isLarge ? 16 : 14,
                    fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                  style: TextStyle(
                    fontSize: isLarge ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: isLarge ? 14 : 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        // 進度條 (如果有目標值)
        if (goal != null && goal > 0) ...[
          const SizedBox(height: 8),
          Stack(
            children: [
              // 背景條
              Container(
                height: isLarge ? 8 : 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                ),
              ),
              // 進度條
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: isLarge ? 8 : 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isLarge ? 4 : 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 百分比文字
          Text(
            '${(progress * 100).toStringAsFixed(0)}% / ${goal.toStringAsFixed(0)} $unit',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// 簡化版營養資訊卡片 - 用於列表展示
class NutritionSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String unit;
  final Color color;

  const NutritionSummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}