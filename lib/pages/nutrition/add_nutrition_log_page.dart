// lib/pages/nutrition/add_nutrition_log_page.dart
// Soft UI 風格的飲食記錄頁面 - 改進份量顯示

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import '../../widgets/nutrition/nutrition_progress_card.dart';

class AddNutritionLogPage extends StatefulWidget {
  final Map<String, dynamic> foodData;

  const AddNutritionLogPage({super.key, required this.foodData});

  @override
  State<AddNutritionLogPage> createState() => _AddNutritionLogPageState();
}

class _AddNutritionLogPageState extends State<AddNutritionLogPage> {
  double _servings = 1.0;
  String _selectedMealType = 'breakfast';
  final NutritionService _nutritionService = NutritionService();
  bool _isSaving = false;

  void _saveLog() async {
    setState(() => _isSaving = true);

    try {
      await _nutritionService.addFoodLog(
        foodData: widget.foodData,
        servings: _servings,
        mealType: _selectedMealType,
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        
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
                const Text(
                  '已成功記錄飲食!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    } catch (e) {
      setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    double totalCalories = (widget.foodData['calories'] ?? 0) * _servings;
    double totalProtein = (widget.foodData['protein'] ?? 0) * _servings;
    double totalCarbs = (widget.foodData['carbs'] ?? 0) * _servings;
    double totalFat = (widget.foodData['fat'] ?? 0) * _servings;

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
          '記錄飲食',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isSaving
                ? Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(10),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : GestureDetector(
                    onTap: _saveLog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            '儲存',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFoodInfoCard()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 20),

            _buildMealTypeSection()
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 20),

            _buildServingSizeSection()
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 20),

            NutritionProgressCard(
              calories: totalCalories,
              protein: totalProtein,
              carbs: totalCarbs,
              fat: totalFat,
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodInfoCard() {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
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
                  widget.foodData['name'] ?? '未知食物',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.foodData['category'] ?? '食物'} • ${widget.foodData['servingSize'] ?? '一份'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildMealTypeSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                '餐別',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MealTypeChip(
                mealType: 'breakfast',
                label: '早餐',
                isSelected: _selectedMealType == 'breakfast',
                onTap: () => setState(() => _selectedMealType = 'breakfast'),
              ),
              MealTypeChip(
                mealType: 'lunch',
                label: '午餐',
                isSelected: _selectedMealType == 'lunch',
                onTap: () => setState(() => _selectedMealType = 'lunch'),
              ),
              MealTypeChip(
                mealType: 'dinner',
                label: '晚餐',
                isSelected: _selectedMealType == 'dinner',
                onTap: () => setState(() => _selectedMealType = 'dinner'),
              ),
              MealTypeChip(
                mealType: 'snack',
                label: '點心',
                isSelected: _selectedMealType == 'snack',
                onTap: () => setState(() => _selectedMealType = 'snack'),
              ),
              MealTypeChip(
                mealType: 'latenight',
                label: '宵夜',
                isSelected: _selectedMealType == 'latenight',
                onTap: () => setState(() => _selectedMealType = 'latenight'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServingSizeSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.scale, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                '份量',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              SoftCircleButton(
                icon: Icons.remove,
                onPressed: _servings > 0.5
                    ? () => setState(() => _servings -= 0.5)
                    : null,
                color: AppColors.error,
              ),
              
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 24,
                        ),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _servings,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        onChanged: (value) => setState(() => _servings = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildScaleLabel('0.5'),
                          _buildScaleLabel('1'),
                          _buildScaleLabel('2'),
                          _buildScaleLabel('3'),
                          _buildScaleLabel('5'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SoftCircleButton(
                icon: Icons.add,
                onPressed: _servings < 5.0
                    ? () => setState(() => _servings += 0.5)
                    : null,
                color: AppColors.success,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ 改進後的份量顯示 - 使用乘號
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primaryLight.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        // 數量 (大且粗)
                        TextSpan(
                          text: _servings.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontFamily: 'Roboto', // 確保跨平台一致
                          ),
                        ),
                        // 乘號 (中等大小,半透明)
                        TextSpan(
                          text: ' × ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary.withOpacity(0.6),
                            fontFamily: 'Roboto',
                          ),
                        ),
                        // 單位 (較小,次要色)
                        TextSpan(
                          text: widget.foodData['servingSize'] ?? '份',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}