// lib/pages/nutrition/add_custom_food_page.dart
// 新增/編輯自訂食物頁面 - Soft UI 風格

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/food_database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class AddCustomFoodPage extends StatefulWidget {
  final Map<String, dynamic>? existingFood; // ✅ 如果有值,代表是編輯模式

  const AddCustomFoodPage({super.key, this.existingFood});

  @override
  State<AddCustomFoodPage> createState() => _AddCustomFoodPageState();
}

class _AddCustomFoodPageState extends State<AddCustomFoodPage> {
  final FoodDatabaseService _foodService = FoodDatabaseService();
  
  // 表單控制器
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  
  // 詳細營養素
  final TextEditingController _saturatedFatController = TextEditingController();
  final TextEditingController _transFatController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _sodiumController = TextEditingController();
  final TextEditingController _cholesterolController = TextEditingController();

  bool _showNutritionDetails = false;
  bool _isSaving = false;
  bool get _isEditMode => widget.existingFood != null;

  @override
  void initState() {
    super.initState();
    
    // ✅ 編輯模式: 載入現有資料
    if (_isEditMode) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final food = widget.existingFood!;
    
    _nameController.text = food['name'] ?? '';
    _categoryController.text = food['category'] ?? '';
    _servingSizeController.text = food['servingSize'] ?? '';
    _caloriesController.text = food['calories']?.toString() ?? '';
    _proteinController.text = food['protein']?.toString() ?? '';
    _carbsController.text = food['carbs']?.toString() ?? '';
    _fatController.text = food['fat']?.toString() ?? '';
    
    _saturatedFatController.text = food['saturatedFat']?.toString() ?? '';
    _transFatController.text = food['transFat']?.toString() ?? '';
    _fiberController.text = food['fiber']?.toString() ?? '';
    _sugarController.text = food['sugar']?.toString() ?? '';
    _sodiumController.text = food['sodium']?.toString() ?? '';
    _cholesterolController.text = food['cholesterol']?.toString() ?? '';
    
    // 如果有詳細營養素,自動展開
    if ((food['saturatedFat'] ?? 0) > 0 || 
        (food['transFat'] ?? 0) > 0 || 
        (food['fiber'] ?? 0) > 0) {
      _showNutritionDetails = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
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

  void _saveFood() async {
    // 驗證必填欄位
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('請輸入食物名稱');
      return;
    }
    if (_caloriesController.text.trim().isEmpty) {
      _showErrorSnackBar('請輸入熱量');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 準備資料
      String name = _nameController.text.trim();
      String category = _categoryController.text.trim().isEmpty 
          ? '自訂分類' 
          : _categoryController.text.trim();
      String servingSize = _servingSizeController.text.trim().isEmpty 
          ? '1份' 
          : _servingSizeController.text.trim();
      
      double calories = double.tryParse(_caloriesController.text) ?? 0;
      double protein = double.tryParse(_proteinController.text) ?? 0;
      double carbs = double.tryParse(_carbsController.text) ?? 0;
      double fat = double.tryParse(_fatController.text) ?? 0;
      
      double saturatedFat = double.tryParse(_saturatedFatController.text) ?? 0;
      double transFat = double.tryParse(_transFatController.text) ?? 0;
      double fiber = double.tryParse(_fiberController.text) ?? 0;
      double sugar = double.tryParse(_sugarController.text) ?? 0;
      double sodium = double.tryParse(_sodiumController.text) ?? 0;
      double cholesterol = double.tryParse(_cholesterolController.text) ?? 0;

      if (_isEditMode) {
        // ✅ 更新模式
        await _foodService.updateCustomFood(
          foodId: widget.existingFood!['id'],
          name: name,
          category: category,
          servingSize: servingSize,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          saturatedFat: saturatedFat,
          transFat: transFat,
          fiber: fiber,
          sugar: sugar,
          sodium: sodium,
          cholesterol: cholesterol,
        );
      } else {
        // ✅ 新增模式
        await _foodService.addCustomFood(
          name: name,
          category: category,
          servingSize: servingSize,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          saturatedFat: saturatedFat,
          transFat: transFat,
          fiber: fiber,
          sugar: sugar,
          sodium: sodium,
          cholesterol: cholesterol,
        );
      }

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
                Text(_isEditMode ? '已更新食物!' : '已新增食物!'),
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
        _showErrorSnackBar('儲存失敗: $e');
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
        title: Text(
          _isEditMode ? '編輯食物' : '新增食物',
          style: const TextStyle(
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
              _buildBasicInfoSection()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              _buildMainNutrientsSection()
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              _buildAddNutritionButton()
                  .animate(delay: 200.ms)
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
                  color: const Color(0xFFFEAC5E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFFEAC5E),
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
            hint: '例如:自製雞胸沙拉',
          ),
          
          const SizedBox(height: 12),
          
          // 分類
          _buildTextField(
            label: '分類',
            controller: _categoryController,
            hint: '例如:蛋白質、主食、點心',
          ),
          
          const SizedBox(height: 12),
          
          // 份量單位
          _buildTextField(
            label: '份量單位',
            controller: _servingSizeController,
            hint: '例如:1碗、100g、1份',
          ),
        ],
      ),
    );
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '營養成分',
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
        TextField(
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
                onTap: _isSaving ? null : _saveFood,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFEAC5E),
                        Color(0xFFFD9B63),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFEAC5E).withOpacity(0.4),
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
                      : Text(
                          _isEditMode ? '更新' : '儲存',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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