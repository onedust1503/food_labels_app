// lib/pages/nutrition/manual_nutrition_input_page.dart
// OCR 掃描後的手動確認/輸入頁面 - Soft UI 風格
// ✨ v2.0: 統一風格、5種餐別、自動餐別選擇、recordMethod 支援

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class ManualNutritionInputPage extends StatefulWidget {
  final Map<String, dynamic>? initialData; // OCR 辨識結果預填

  const ManualNutritionInputPage({
    super.key,
    this.initialData,
  });

  @override
  State<ManualNutritionInputPage> createState() => _ManualNutritionInputPageState();
}

class _ManualNutritionInputPageState extends State<ManualNutritionInputPage> {
  final _formKey = GlobalKey<FormState>();
  final NutritionService _nutritionService = NutritionService();

  // 表單控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();
  
  // ✨ 詳細營養素
  final TextEditingController _saturatedFatController = TextEditingController();
  final TextEditingController _transFatController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();

  late String _selectedMealType;
  double _servings = 1.0;
  bool _isSaving = false;
  bool _showNutritionDetails = false;
  bool _hasInitialData = false;

  @override
  void initState() {
    super.initState();
    _selectedMealType = _getDefaultMealType(); // ✨ 自動選擇餐別
    _loadInitialData();
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

  /// 載入 OCR 辨識的初始資料
  void _loadInitialData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _hasInitialData = true;
      
      // 預填數值（如果 OCR 有辨識到）
      if (data['calories'] != null) {
        _caloriesController.text = data['calories'].toString();
      }
      if (data['protein'] != null) {
        _proteinController.text = data['protein'].toString();
      }
      if (data['fat'] != null) {
        _fatController.text = data['fat'].toString();
      }
      if (data['carbs'] != null) {
        _carbsController.text = data['carbs'].toString();
      }
      if (data['sodium'] != null) {
        _sodiumController.text = data['sodium'].toString();
      }
      if (data['servingSize'] != null) {
        _servingSizeController.text = data['servingSize'].toString();
      }
      if (data['name'] != null) {
        _nameController.text = data['name'].toString();
      }
      
      // 詳細營養素
      if (data['saturatedFat'] != null) {
        _saturatedFatController.text = data['saturatedFat'].toString();
      }
      if (data['transFat'] != null) {
        _transFatController.text = data['transFat'].toString();
      }
      if (data['fiber'] != null) {
        _fiberController.text = data['fiber'].toString();
      }
      if (data['sugar'] != null) {
        _sugarController.text = data['sugar'].toString();
      }
      if (data['cholesterol'] != null) {
        _cholesterolController.text = data['cholesterol'].toString();
      }
      
      // 如果有詳細營養素，自動展開
      if ((data['saturatedFat'] ?? 0) > 0 || 
          (data['transFat'] ?? 0) > 0 || 
          (data['fiber'] ?? 0) > 0 ||
          (data['sugar'] ?? 0) > 0) {
        _showNutritionDetails = true;
      }
    }
  }

  /// 儲存飲食記錄
  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 建立食物資料
      Map<String, dynamic> foodData = {
        'name': _nameController.text.trim(),
        'servingSize': _servingSizeController.text.trim().isEmpty 
            ? '1份' 
            : _servingSizeController.text.trim(),
        'calories': double.tryParse(_caloriesController.text) ?? 0,
        'protein': double.tryParse(_proteinController.text) ?? 0,
        'fat': double.tryParse(_fatController.text) ?? 0,
        'carbs': double.tryParse(_carbsController.text) ?? 0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0,
        'saturatedFat': double.tryParse(_saturatedFatController.text) ?? 0,
        'transFat': double.tryParse(_transFatController.text) ?? 0,
        'fiber': double.tryParse(_fiberController.text) ?? 0,
        'sugar': double.tryParse(_sugarController.text) ?? 0,
        'cholesterol': double.tryParse(_cholesterolController.text) ?? 0,
        'category': '手動輸入',
        'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      };

      // ✨ 儲存記錄，傳遞 recordMethod
      await _nutritionService.addFoodLog(
        foodData: foodData,
        servings: _servings,
        mealType: _selectedMealType,
        recordMethod: 'manual', // ✨ 手動輸入
      );

      if (mounted) {
        // 返回兩層（關閉輸入頁和掃描頁）
        Navigator.pop(context);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
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
                  '記錄成功！',
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
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _sodiumController.dispose();
    _saturatedFatController.dispose();
    _transFatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _cholesterolController.dispose();
    super.dispose();
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
          '確認營養資訊',
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✨ OCR 提示訊息
                if (_hasInitialData)
                  _buildOcrHintCard()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, duration: 400.ms),
                
                if (_hasInitialData) const SizedBox(height: 20),
                
                // 基本資訊
                _buildBasicInfoSection()
                    .animate(delay: _hasInitialData ? 100.ms : 0.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),
                
                const SizedBox(height: 20),

                // 餐別選擇
                _buildMealTypeSection()
                    .animate(delay: _hasInitialData ? 200.ms : 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),
                
                const SizedBox(height: 20),

                // 主要營養素
                _buildMainNutrientsSection()
                    .animate(delay: _hasInitialData ? 300.ms : 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),
                
                const SizedBox(height: 20),

                // 份數選擇
                _buildServingsSection()
                    .animate(delay: _hasInitialData ? 400.ms : 300.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),
                
                const SizedBox(height: 20),

                // 詳細營養素按鈕
                _buildAddNutritionButton()
                    .animate(delay: _hasInitialData ? 500.ms : 400.ms)
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
      ),

      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  /// ✨ OCR 提示卡片
  Widget _buildOcrHintCard() {
    return SoftCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.document_scanner,
              color: AppColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已自動填入辨識結果',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '請確認數值是否正確，可自行修改',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 基本資訊區塊
  Widget _buildBasicInfoSection() {
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
                '基本資訊',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 食物名稱
          _buildTextField(
            label: '食物名稱',
            controller: _nameController,
            required: true,
            hint: '請輸入食物名稱',
            icon: Icons.restaurant,
          ),
          
          const SizedBox(height: 12),
          
          // 份量大小
          _buildTextField(
            label: '份量大小',
            controller: _servingSizeController,
            hint: '例如：100g, 1碗',
            icon: Icons.straighten,
          ),
        ],
      ),
    );
  }

  /// 餐別選擇區塊
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
                  Icons.schedule,
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
          
          // ✨ 餐別按鈕 - 第一排
          Row(
            children: [
              Expanded(child: _buildMealChip('breakfast', '🌅', '早餐')),
              const SizedBox(width: 8),
              Expanded(child: _buildMealChip('lunch', '☀️', '午餐')),
              const SizedBox(width: 8),
              Expanded(child: _buildMealChip('dinner', '🌙', '晚餐')),
            ],
          ),
          const SizedBox(height: 8),
          // ✨ 餐別按鈕 - 第二排（點心 + 宵夜）
          Row(
            children: [
              Expanded(child: _buildMealChip('snack', '🍪', '點心')),
              const SizedBox(width: 8),
              Expanded(child: _buildMealChip('latenight', '🌃', '宵夜')),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()), // 占位，保持對齊
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealChip(String type, String emoji, String label) {
    final isSelected = _selectedMealType == type;
    final color = _getMealColor(type);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMealType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.8), color])
              : null,
          color: isSelected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
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
        return const Color(0xFFFFB74D);
      case 'lunch':
        return const Color(0xFF4FC3F7);
      case 'dinner':
        return const Color(0xFF9575CD);
      case 'snack':
        return const Color(0xFFFF8A80);
      case 'latenight':
        return const Color(0xFF7C4DFF);
      default:
        return AppColors.primary;
    }
  }

  /// 主要營養素區塊
  Widget _buildMainNutrientsSection() {
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
                '營養資訊（每份）',
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
          
          _buildNutrientInput(
            label: '熱量',
            controller: _caloriesController,
            unit: '大卡',
            color: AppColors.calories,
            icon: Icons.local_fire_department,
            required: true,
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  /// 份數選擇區塊
  Widget _buildServingsSection() {
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
                  Icons.exposure,
                  color: Color(0xFF4FACFE),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '份數',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // 減少按鈕
              GestureDetector(
                onTap: () {
                  if (_servings > 0.5) {
                    setState(() => _servings -= 0.5);
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowDark,
                        offset: const Offset(2, 2),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: AppColors.shadowLight,
                        offset: const Offset(-2, -2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.remove,
                    color: _servings > 0.5 ? const Color(0xFF4FACFE) : AppColors.textTertiary,
                    size: 24,
                  ),
                ),
              ),
              
              // 份數顯示
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4FACFE).withOpacity(0.1),
                        const Color(0xFF00F2FE).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4FACFE).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _servings.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4FACFE),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 增加按鈕
              GestureDetector(
                onTap: () {
                  if (_servings < 10) {
                    setState(() => _servings += 0.5);
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowDark,
                        offset: const Offset(2, 2),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: AppColors.shadowLight,
                        offset: const Offset(-2, -2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: _servings < 10 ? const Color(0xFF4FACFE) : AppColors.textTertiary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 快速選擇按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickServingButton(0.5),
              const SizedBox(width: 8),
              _buildQuickServingButton(1.0),
              const SizedBox(width: 8),
              _buildQuickServingButton(1.5),
              const SizedBox(width: 8),
              _buildQuickServingButton(2.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServingButton(double value) {
    final isSelected = _servings == value;
    
    return GestureDetector(
      onTap: () => setState(() => _servings = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4FACFE) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4FACFE) : AppColors.divider,
          ),
        ),
        child: Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 展開/收合詳細營養素按鈕
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
                _showNutritionDetails ? '隱藏詳細營養素' : '新增詳細營養素 (選填)',
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

  /// 詳細營養素區塊
  Widget _buildNutritionDetailsSection() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const Divider(),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: icon != null 
                ? Icon(icon, size: 20, color: AppColors.textSecondary)
                : null,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入$label';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildNutrientInput({
    required String label,
    required TextEditingController controller,
    required String unit,
    required Color color,
    required IconData icon,
    bool required = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 100,
          child: TextFormField(
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
              hintStyle: const TextStyle(
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
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '必填';
                    }
                    return null;
                  }
                : null,
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
                        Color(0xFFFA709A),
                        Color(0xFFFEAC5E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFA709A).withOpacity(0.4),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: _isSaving
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
                              '儲存記錄',
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
}