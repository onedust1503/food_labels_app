// lib/pages/nutrition/add_combo_log_page.dart
// 快速記錄組合頁面 - Soft UI 風格
// ✨ v2.0: 新增自動餐別選擇

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/meal_combo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'nutrition_log_list_page.dart';

class AddComboLogPage extends StatefulWidget {
  final Map<String, dynamic> combo;

  const AddComboLogPage({
    super.key,
    required this.combo,
  });

  @override
  State<AddComboLogPage> createState() => _AddComboLogPageState();
}

class _AddComboLogPageState extends State<AddComboLogPage> {
  final MealComboService _comboService = MealComboService();
  
  late String _selectedMealType; // ✨ 改為 late，由 initState 初始化
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _selectedMealType = _getDefaultMealType(); // ✨ 自動選擇餐別
  }

  /// ✨ 根據當前時間自動選擇餐別
  String _getDefaultMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return 'breakfast';  // 05:00-10:00 早餐
    } else if (hour >= 10 && hour < 14) {
      return 'lunch';      // 10:00-14:00 午餐
    } else if (hour >= 14 && hour < 17) {
      return 'snack';      // 14:00-17:00 點心
    } else if (hour >= 17 && hour < 21) {
      return 'dinner';     // 17:00-21:00 晚餐
    } else {
      return 'latenight';  // 21:00-05:00 宵夜
    }
  }

  @override
  Widget build(BuildContext context) {
    String comboName = widget.combo['comboName'] ?? '未命名組合';
    int itemCount = widget.combo['itemCount'] ?? 0;
    double totalCalories = (widget.combo['totalCalories'] ?? 0).toDouble();
    double totalProtein = (widget.combo['totalProtein'] ?? 0).toDouble();
    double totalCarbs = (widget.combo['totalCarbs'] ?? 0).toDouble();
    double totalFat = (widget.combo['totalFat'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '快速記錄',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 組合資訊卡片
            _buildComboInfoCard(
              comboName,
              itemCount,
              totalCalories,
              totalProtein,
              totalCarbs,
              totalFat,
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 24),

            // 選擇餐別
            _buildMealTypeSection()
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 24),

            // 食物列表
            _buildFoodsList()
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),

            const SizedBox(height: 100),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildComboInfoCard(
    String comboName,
    int itemCount,
    double totalCalories,
    double totalProtein,
    double totalCarbs,
    double totalFat,
  ) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4FACFE).withOpacity(0.8),
                      const Color(0xFF00F2FE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comboName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '包含 $itemCount 項食物',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNutrientBox(
                    '熱量',
                    totalCalories.toInt().toString(),
                    '大卡',
                    AppColors.calories,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNutrientBox(
                    '蛋白質',
                    totalProtein.toStringAsFixed(1),
                    'g',
                    AppColors.protein,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNutrientBox(
                    '碳水',
                    totalCarbs.toStringAsFixed(1),
                    'g',
                    AppColors.carbs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNutrientBox(
                    '脂肪',
                    totalFat.toStringAsFixed(1),
                    'g',
                    AppColors.fat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBox(String label, String value, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealTypeSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4FACFE).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Color(0xFF4FACFE),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '選擇餐別',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ✨ 餐別按鈕 - 第一排
          Row(
            children: [
              Expanded(child: _buildMealTypeChip('breakfast', '早餐', '🌅')),
              const SizedBox(width: 10),
              Expanded(child: _buildMealTypeChip('lunch', '午餐', '☀️')),
              const SizedBox(width: 10),
              Expanded(child: _buildMealTypeChip('dinner', '晚餐', '🌙')),
            ],
          ),
          const SizedBox(height: 10),
          // ✨ 餐別按鈕 - 第二排（點心 + 宵夜）
          Row(
            children: [
              Expanded(child: _buildMealTypeChip('snack', '點心', '🍪')),
              const SizedBox(width: 10),
              Expanded(child: _buildMealTypeChip('latenight', '宵夜', '🌃')),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox()), // 占位，保持對齊
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeChip(String mealType, String label, String emoji) {
    bool isSelected = _selectedMealType == mealType;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMealType = mealType;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    _getMealColor(mealType).withOpacity(0.8),
                    _getMealColor(mealType),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _getMealColor(mealType)
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _getMealColor(mealType).withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✨ 獲取餐別對應顏色
  Color _getMealColor(String type) {
    switch (type) {
      case 'breakfast':
        return const Color(0xFFFFB74D); // 橘色
      case 'lunch':
        return const Color(0xFF4FC3F7); // 藍色
      case 'dinner':
        return const Color(0xFF9575CD); // 紫色
      case 'snack':
        return const Color(0xFFFF8A80); // 粉色
      case 'latenight':
        return const Color(0xFF7C4DFF); // 深紫色
      default:
        return AppColors.primary;
    }
  }

  Widget _buildFoodsList() {
    List<dynamic> foods = widget.combo['foods'] ?? [];
    
    if (foods.isEmpty) {
      return const SizedBox.shrink();
    }

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.list_alt,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '將記錄以下食物',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...foods.asMap().entries.map((entry) {
            int index = entry.key;
            var food = entry.value;
            
            return Container(
              margin: EdgeInsets.only(
                bottom: index < foods.length - 1 ? 12 : 0,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4FACFE),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food['foodName'] ?? '未知食物',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4FACFE).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${food['servings'].toStringAsFixed(1)} ${food['servingSize']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4FACFE),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(food['calories'] ?? 0).toInt()} 大卡',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowDark,
                        offset: const Offset(4, 4),
                        blurRadius: 8,
                      ),
                      BoxShadow(
                        color: AppColors.shadowLight,
                        offset: const Offset(-4, -4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    '取消',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),

            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _isLogging ? null : _logCombo,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4FACFE),
                        Color(0xFF00F2FE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4FACFE).withOpacity(0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: _isLogging
                      ? const Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '開始記錄',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logCombo() async {
    setState(() => _isLogging = true);

    try {
      await _comboService.logCombo(
        comboId: widget.combo['id'],
        comboName: widget.combo['comboName'],
        foods: widget.combo['foods'],
        mealType: _selectedMealType,
      );

      if (mounted) {
        // 跳轉到飲食記錄頁面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NutritionLogListPage(),
          ),
        );
        
        // 顯示成功訊息
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('已記錄組合!'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    } catch (e) {
      setState(() => _isLogging = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('記錄失敗: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}