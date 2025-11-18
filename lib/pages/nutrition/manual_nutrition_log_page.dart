// lib/pages/nutrition/manual_nutrition_log_page.dart
// 手動記錄飲食頁面 - Soft UI 風格 (修正版)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class ManualNutritionLogPage extends StatefulWidget {
  const ManualNutritionLogPage({super.key});

  @override
  State<ManualNutritionLogPage> createState() => _ManualNutritionLogPageState();
}

class _ManualNutritionLogPageState extends State<ManualNutritionLogPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _saturatedFatController = TextEditingController();
  final TextEditingController _transFatController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();
  
  String _selectedMealType = 'breakfast';
  int _selectedCalories = 500;
  bool _showNutritionDetails = false;
  bool _isSaving = false;
  final NutritionService _nutritionService = NutritionService();

  @override
  void dispose() {
    _nameController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _saturatedFatController.dispose();
    _transFatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    super.dispose();
  }

  void _saveLog() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('請輸入食物名稱');
      return;
    }

    if (_selectedCalories <= 0) {
      _showErrorSnackBar('請選擇熱量');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 建立食物資料
      Map<String, dynamic> foodData = {
        'name': _nameController.text.trim(),
        'calories': _selectedCalories,
        'protein': double.tryParse(_proteinController.text) ?? 0,
        'carbs': double.tryParse(_carbsController.text) ?? 0,
        'fat': double.tryParse(_fatController.text) ?? 0,
        'saturatedFat': double.tryParse(_saturatedFatController.text) ?? 0,
        'transFat': double.tryParse(_transFatController.text) ?? 0,
        'fiber': double.tryParse(_fiberController.text) ?? 0,
        'sugar': double.tryParse(_sugarController.text) ?? 0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0,
        'cholesterol': double.tryParse(_cholesterolController.text) ?? 0,
        'servingSize': '份',
        'category': '手動記錄',
        'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      };

      await _nutritionService.addFoodLog(
        foodData: foodData,
        servings: 1.0,
        mealType: _selectedMealType,
      );

      if (mounted) {
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
        _showErrorSnackBar('記錄失敗: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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

  @override
  Widget build(BuildContext context) {
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
          '手動記錄',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFoodNameSection()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              _buildMealTypeSection()
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              _buildCaloriesSection()
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              _buildAddNutritionButton()
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),

              if (_showNutritionDetails) ...[
                const SizedBox(height: 20),
                _buildNutritionDetailsSection()
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildFoodNameSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFA709A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Color(0xFFFA709A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '食物名稱',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _nameController,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '輸入食物名稱',
              hintStyle: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 15,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
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
              _buildMealTypeChip('breakfast', '早餐'),
              _buildMealTypeChip('lunch', '午餐'),
              _buildMealTypeChip('dinner', '晚餐'),
              _buildMealTypeChip('snack', '點心'),
              _buildMealTypeChip('latenight', '宵夜'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeChip(String mealType, String label) {
    final bool isSelected = _selectedMealType == mealType;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMealType = mealType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getMealColor(mealType) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected 
                ? AppColors.getMealColor(mealType) 
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppColors.getMealEmoji(mealType),
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

  /// ✅ 修正版 - 熱量選擇區
  Widget _buildCaloriesSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.calories.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: AppColors.calories,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '每份熱量',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => _showCaloriesPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.calories.withOpacity(0.1),
                    AppColors.calories.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.calories.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _selectedCalories.toString(),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppColors.calories,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '大卡',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.expand_more,
                    color: AppColors.textTertiary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              '點擊數字可滾動選擇',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 修正版 - 顯示熱量選擇器 (每100大卡有橘色標記)
  void _showCaloriesPicker(BuildContext context) {
    int initialIndex = (_selectedCalories ~/ 5).clamp(0, 400);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.divider,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Text(
                      '選擇熱量',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Stack(
                  children: [
                    ListWheelScrollView.useDelegate(
                      controller: FixedExtentScrollController(
                        initialItem: initialIndex,
                      ),
                      itemExtent: 60,
                      perspective: 0.002,
                      diameterRatio: 2.0,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _selectedCalories = index * 5;
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) {
                          if (index < 0 || index > 400) return null;
                          
                          final calories = index * 5;
                          final isSelected = calories == _selectedCalories;
                          final isMultipleOf100 = calories % 100 == 0; // ✅ 判斷是否為100的倍數
                          
                          return Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontSize: isSelected ? 38 : 28,
                                fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : (isMultipleOf100 ? FontWeight.w600 : FontWeight.w500), // ✅ 100的倍數加粗
                                color: isSelected 
                                    ? AppColors.calories
                                    : (isMultipleOf100 
                                        ? AppColors.calories.withOpacity(0.6) // ✅ 100的倍數用橘色
                                        : AppColors.textTertiary),
                                height: 1.2,
                              ),
                              child: Text('$calories'),
                            ),
                          );
                        },
                        childCount: 401,
                      ),
                    ),
                    
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: AppColors.calories.withOpacity(0.3),
                                width: 2,
                              ),
                              bottom: BorderSide(
                                color: AppColors.calories.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            color: AppColors.calories.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '大卡',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddNutritionButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showNutritionDetails = !_showNutritionDetails;
        });
      },
      child: SoftCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _showNutritionDetails ? Icons.remove : Icons.add,
                color: AppColors.info,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _showNutritionDetails ? '隱藏營養成分' : '新增營養成分 (選填)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              _showNutritionDetails 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionDetailsSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '三大營養素',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildNutrientInput(
            label: '蛋白質',
            controller: _proteinController,
            unit: 'g',
            color: AppColors.protein,
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '碳水化合物',
            controller: _carbsController,
            unit: 'g',
            color: AppColors.carbs,
            icon: Icons.grain,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '脂肪',
            controller: _fatController,
            unit: 'g',
            color: AppColors.fat,
            icon: Icons.water_drop,
          ),
          
          const SizedBox(height: 20),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '脂肪明細',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildNutrientInput(
            label: '飽和脂肪',
            controller: _saturatedFatController,
            unit: 'g',
            color: const Color(0xFFE57373),
            icon: Icons.warning_amber,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '反式脂肪',
            controller: _transFatController,
            unit: 'mg',
            color: const Color(0xFFEF5350),
            icon: Icons.dangerous,
          ),

          const SizedBox(height: 20),
          Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '其他營養素',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildNutrientInput(
            label: '膳食纖維',
            controller: _fiberController,
            unit: 'g',
            color: const Color(0xFF66BB6A),
            icon: Icons.eco,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '糖',
            controller: _sugarController,
            unit: 'g',
            color: const Color(0xFFFF9800),
            icon: Icons.cake,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '鈉',
            controller: _sodiumController,
            unit: 'mg',
            color: const Color(0xFF42A5F5),
            icon: Icons.opacity,
          ),
          const SizedBox(height: 12),
          _buildNutrientInput(
            label: '膽固醇',
            controller: _cholesterolController,
            unit: 'mg',
            color: const Color(0xFFAB47BC),
            icon: Icons.favorite_border,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientInput({
    required String label,
    required TextEditingController controller,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
            ],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: TextStyle(
                color: AppColors.textTertiary,
              ),
              suffixText: unit,
              suffixStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
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
                onTap: _isSaving ? null : _saveLog,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        color: AppColors.primary.withOpacity(0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '儲存',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}