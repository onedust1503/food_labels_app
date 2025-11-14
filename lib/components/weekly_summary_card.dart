// lib/components/weekly_summary_card.dart
// 🎨 明亮版莫蘭迪風格 - 本週統計卡片
// ✨ 優化：使用明亮漸層與每日結果卡片區分 + 增強獎盃可見度

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeeklySummaryCard extends StatefulWidget {
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
  State<WeeklySummaryCard> createState() => _WeeklySummaryCardState();
}

class _WeeklySummaryCardState extends State<WeeklySummaryCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completionRate = widget.totalDays > 0 
        ? (widget.daysCompleted / widget.totalDays * 100).toInt() 
        : 0;
    
    // 🔥 本週表現卡片使用明亮莫蘭迪綠色漸層 (與下方灰藍色區分)
    const cardGradient = LinearGradient(
      colors: [
        Color(0xFFA8D5BA),  // 明亮薄荷綠
        Color(0xFF88B9A1),  // 莫蘭迪綠
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.emphasized,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題區
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Text(
                    '本週表現',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: AppShadows.textShadow,
                    ),
                  ),
                ),
                
                // 完成率徽章
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    final animatedRate = (_progressAnimation.value * completionRate).toInt();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$animatedRate%',
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.coach,  // 使用綠色
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // 統計數據
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle_outline,
                    label: '達標天數',
                    value: '${widget.daysCompleted}/${widget.totalDays}',
                    progress: _progressAnimation,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.local_fire_department_outlined,
                    label: '平均熱量',
                    value: '${widget.avgCalories.toInt()}',
                    unit: '卡',
                    progress: _progressAnimation,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.water_drop_outlined,
                    label: '平均喝水',
                    value: '${widget.avgWater.toInt()}',
                    unit: 'ml',
                    progress: _progressAnimation,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 🔥 運動天數橫條 - 增強獎盃可見度
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本週運動',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            final animatedDays = (_progressAnimation.value * widget.workoutDays).toInt();
                            return Text(
                              '$animatedDays 天',
                              style: AppTextStyles.h3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // 🔥 增強版成就圖標 - 更大更清楚
                  AnimatedSwitcher(
                    duration: AppAnimations.normal,
                    child: _buildAchievementIcon(widget.workoutDays),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    required Animation<double> progress,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 12),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        FadeTransition(
          opacity: progress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: AppShadows.textShadow,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 🔥 增強版成就圖標 - 更大、更清楚、有白色背景
  Widget _buildAchievementIcon(int days) {
    IconData iconData;
    Color iconColor;
    
    if (days >= 5) {
      iconData = Icons.emoji_events;
      iconColor = const Color(0xFFFFD700);  // 金色
    } else if (days >= 3) {
      iconData = Icons.emoji_events;
      iconColor = const Color(0xFFC0C0C0);  // 銀色
    } else if (days >= 1) {
      iconData = Icons.emoji_events;
      iconColor = const Color(0xFFCD7F32);  // 銅色
    } else {
      iconData = Icons.trending_up;
      iconColor = Colors.white.withValues(alpha: 0.7);
    }
    
    return Container(
      key: ValueKey(days),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 🔥 白色背景讓獎盃更清楚
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 32,  // 🔥 加大圖標
      ),
    );
  }
}