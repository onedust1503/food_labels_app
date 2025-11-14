// lib/components/weekly_summary_card.dart
// ✅ 莫蘭迪風格優化版 - 更圓潤、更舒適的本週統計卡片

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeeklySummaryCard extends StatelessWidget {
  final int daysCompleted;
  final int totalDays;
  final double avgCalories;
  final double avgWater;
  final int workoutDays;

  const WeeklySummaryCard({
    super.key,
    required this.daysCompleted,
    required this.totalDays,
    required this.avgCalories,
    required this.avgWater,
    required this.workoutDays,
  });

  @override
  Widget build(BuildContext context) {
    final completionRate = totalDays > 0 
        ? (daysCompleted / totalDays * 100).toInt() 
        : 0;

    return Container(
      // 🎯 移除 margin，由父組件統一控制
      padding: const EdgeInsets.all(24), // 增加 padding
      decoration: BoxDecoration(
        // 🎯 使用莫蘭迪漸層
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28), // 更大的圓角
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 標題區 - 增加間距
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '本週表現',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completionRate%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24), // 增加間距
          
          // 🎯 統計數據 - 使用更好的排版
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.check_circle_outline,
                label: '達標天數',
                value: '$daysCompleted/$totalDays',
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildStatItem(
                icon: Icons.local_fire_department_outlined,
                label: '平均熱量',
                value: '${avgCalories.toInt()}',
                unit: '卡',
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _buildStatItem(
                icon: Icons.water_drop_outlined,
                label: '平均喝水',
                value: '${avgWater.toInt()}',
                unit: 'ml',
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 🎯 運動天數 - 更好的視覺層次
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '本週運動 $workoutDays 天',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  workoutDays >= 3 ? Icons.emoji_events : Icons.trending_up,
                  color: Colors.amber[300],
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}