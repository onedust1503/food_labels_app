// lib/pages/coach/trainee_nutrition_tab.dart
// 🎯 學員飲食日誌分頁 v2.1
// ✅ 修復：Overflow 問題（改用 Wrap）
// ✅ 莫蘭迪設計風格

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class TraineeNutritionTab extends StatelessWidget {
  final String traineeId;

  const TraineeNutritionTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('nutritionLogs')
          .where('userId', isEqualTo: traineeId)
          .orderBy('date', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        // 錯誤處理
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '載入失敗',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    snapshot.error.toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // 沒有資料
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: AppColors.warning.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '尚無飲食紀錄',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '學員開始記錄後會顯示在這裡',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            final logId = logs[index].id;
            
            // ✅ 處理日期欄位
            DateTime date;
            if (log['date'] is Timestamp) {
              date = (log['date'] as Timestamp).toDate();
            } else if (log['date'] is String) {
              try {
                date = DateTime.parse(log['date'] as String);
              } catch (e) {
                date = DateTime.now();
              }
            } else {
              date = DateTime.now();
            }
            
            // ✅ 型別轉換
            final calories = _toInt(log['calories']);
            final protein = _toDouble(log['protein']);
            final carbs = _toDouble(log['carbs']);
            final fat = _toDouble(log['fat']);
            final foodName = log['foodName']?.toString() ?? '未命名食物';
            final mealType = log['mealType']?.toString() ?? '';
            
            return _buildNutritionCard(
              context: context,
              log: log,
              date: date,
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
              foodName: foodName,
              mealType: mealType,
            );
          },
        );
      },
    );
  }

  // 🎨 飲食記錄卡片（修復版）
  Widget _buildNutritionCard({
    required BuildContext context,
    required Map<String, dynamic> log,
    required DateTime date,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required String foodName,
    required String mealType,
  }) {
    final calorieColor = _getCalorieColor(calories);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showNutritionDetail(context, log, date),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側：日期圓圈
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: calorieColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: AppTextStyles.h3.copyWith(
                          color: calorieColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${date.month}月',
                        style: AppTextStyles.caption.copyWith(
                          color: calorieColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // 中間：營養資訊（使用 Expanded + Flexible）
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 食物名稱
                      Text(
                        foodName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 餐別（如果有）
                      if (mealType.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getMealColor(mealType).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getMealTypeText(mealType),
                            style: AppTextStyles.caption.copyWith(
                              color: _getMealColor(mealType),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // 熱量
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$calories kcal',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 🔥 修復：使用 Wrap 避免 Overflow
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildNutrientChip('蛋白質', protein, AppColors.error),
                          _buildNutrientChip('碳水', carbs, AppColors.info),
                          _buildNutrientChip('脂肪', fat, AppColors.warning),
                        ],
                      ),
                    ],
                  ),
                ),

                // 右側：箭頭
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 營養素標籤（縮小版）
  Widget _buildNutrientChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}g',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: 11, // 稍微縮小字體
        ),
      ),
    );
  }

  // 🎨 根據熱量取得顏色
  Color _getCalorieColor(int calories) {
    if (calories < 100) {
      return AppColors.success;
    } else if (calories < 300) {
      return AppColors.info;
    } else if (calories < 500) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }

  // 🎨 根據餐別取得顏色
  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return AppColors.warning;
      case 'lunch':
        return AppColors.success;
      case 'dinner':
        return AppColors.accent3;
      case 'snack':
        return AppColors.accent4;
      default:
        return AppColors.primary;
    }
  }

  // 取得餐別文字
  String _getMealTypeText(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '🌅 早餐';
      case 'lunch':
        return '☀️ 午餐';
      case 'dinner':
        return '🌙 晚餐';
      case 'snack':
        return '🍪 點心';
      default:
        return mealType;
    }
  }

  // 🔥 顯示飲食詳情
  void _showNutritionDetail(
    BuildContext context,
    Map<String, dynamic> log,
    DateTime date,
  ) {
    final calories = _toInt(log['calories']);
    final protein = _toDouble(log['protein']);
    final carbs = _toDouble(log['carbs']);
    final fat = _toDouble(log['fat']);
    final foodName = log['foodName']?.toString() ?? '未命名食物';
    final mealType = log['mealType']?.toString() ?? '';
    final servingSize = log['servingSize']?.toString() ?? '';
    final servings = _toInt(log['servings']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // 頂部拖拉指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 內容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppColors.warmGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.restaurant,
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
                                  foodName,
                                  style: AppTextStyles.h3.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.year}/${date.month}/${date.day}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 餐別標籤
                      if (mealType.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getMealColor(mealType).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getMealTypeText(mealType),
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _getMealColor(mealType),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 營養總覽
                      _buildNutritionSummary(
                        calories,
                        protein,
                        carbs,
                        fat,
                      ),
                      const SizedBox(height: 24),

                      // 份量資訊
                      if (servingSize.isNotEmpty || servings > 0) ...[
                        Text(
                          '份量資訊',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (servingSize.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '份量：$servingSize',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              if (servings > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.numbers,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '數量：$servings 份',
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 營養總覽卡片
  Widget _buildNutritionSummary(
    int calories,
    double protein,
    double carbs,
    double fat,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.warmGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.coloredShadow(AppColors.warning),
      ),
      child: Column(
        children: [
          // 第一行：熱量
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                '$calories',
                style: AppTextStyles.h1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'kcal',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 第二行：三大營養素
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionItem('蛋白質', protein.toStringAsFixed(1), 'g'),
              _buildDivider(),
              _buildNutritionItem('碳水', carbs.toStringAsFixed(1), 'g'),
              _buildDivider(),
              _buildNutritionItem('脂肪', fat.toStringAsFixed(1), 'g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.3),
    );
  }

  // 🔧 型別轉換輔助方法
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}