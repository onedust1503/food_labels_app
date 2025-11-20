// lib/pages/nutrition/create_combo_page.dart
// 建立/編輯組合頁面 - Soft UI 風格
// ✅ 已更新支援多選功能

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/meal_combo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'select_foods_for_combo_page.dart';

class CreateComboPage extends StatefulWidget {
  final Map<String, dynamic>? existingCombo; // 編輯模式

  const CreateComboPage({super.key, this.existingCombo});

  @override
  State<CreateComboPage> createState() => _CreateComboPageState();
}

class _CreateComboPageState extends State<CreateComboPage> {
  final MealComboService _comboService = MealComboService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  
  List<Map<String, dynamic>> _selectedFoods = []; // [{foodData, servings}]
  bool _isSaving = false;
  bool get _isEditMode => widget.existingCombo != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditMode) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final combo = widget.existingCombo!;
    
    _nameController.text = combo['comboName'] ?? '';
    _categoryController.text = combo['category'] ?? '';
    
    // 載入食物列表
    List<dynamic> foods = combo['foods'] ?? [];
    for (var food in foods) {
      _selectedFoods.add({
        'foodData': {
          'id': food['foodId'],
          'name': food['foodName'],
          'servingSize': food['servingSize'],
          'calories': food['calories'] / food['servings'],
          'protein': food['protein'] / food['servings'],
          'carbs': food['carbs'] / food['servings'],
          'fat': food['fat'] / food['servings'],
          'saturatedFat': (food['saturatedFat'] ?? 0) / food['servings'],
          'transFat': (food['transFat'] ?? 0) / food['servings'],
          'fiber': (food['fiber'] ?? 0) / food['servings'],
          'sugar': (food['sugar'] ?? 0) / food['servings'],
          'sodium': (food['sodium'] ?? 0) / food['servings'],
          'cholesterol': (food['cholesterol'] ?? 0) / food['servings'],
          'isCustom': food['isCustom'] ?? false,
        },
        'servings': food['servings'].toDouble(),
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _saveCombo() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('請輸入組合名稱');
      return;
    }

    if (_selectedFoods.isEmpty) {
      _showErrorSnackBar('請至少新增一個食物');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await _comboService.updateCombo(
          comboId: widget.existingCombo!['id'],
          comboName: _nameController.text.trim(),
          category: _categoryController.text.trim().isEmpty 
              ? '組合' 
              : _categoryController.text.trim(),
          foods: _selectedFoods,
        );
      } else {
        await _comboService.createCombo(
          comboName: _nameController.text.trim(),
          category: _categoryController.text.trim().isEmpty 
              ? '組合' 
              : _categoryController.text.trim(),
          foods: _selectedFoods,
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
                Text(_isEditMode ? '已更新組合!' : '已建立組合!'),
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

  // ✅ 更新: 支援多選
  void _addFood() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectFoodsForComboPage(
          alreadySelected: _selectedFoods
              .map((item) => item['foodData'] as Map<String, dynamic>)
              .toList(),
        ),
      ),
    );

    // ✅ 處理多選結果
    if (result != null && result is List && mounted) {
      setState(() {
        for (var food in result) {
          // 檢查是否已存在
          bool exists = _selectedFoods.any(
            (item) => item['foodData']['id'] == food['id']
          );
          
          if (!exists) {
            _selectedFoods.add({
              'foodData': food,
              'servings': 1.0,
            });
          }
        }
      });
      
      // 顯示成功提示
      if (result.length > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('已加入 ${result.length} 項食物'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
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

  Map<String, double> _calculateTotals() {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (var item in _selectedFoods) {
      Map<String, dynamic> food = item['foodData'];
      double servings = item['servings'];

      totalCalories += (food['calories'] ?? 0) * servings;
      totalProtein += (food['protein'] ?? 0) * servings;
      totalCarbs += (food['carbs'] ?? 0) * servings;
      totalFat += (food['fat'] ?? 0) * servings;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

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
          _isEditMode ? '編輯組合' : '建立組合',
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
              // 基本資訊
              _buildBasicInfoSection()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              // 食物列表
              if (_selectedFoods.isNotEmpty)
                _buildFoodListSection()
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              if (_selectedFoods.isNotEmpty)
                const SizedBox(height: 20),

              // 新增食物按鈕
              _buildAddFoodButton()
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),
              
              const SizedBox(height: 20),

              // 營養總計
              if (_selectedFoods.isNotEmpty)
                _buildNutritionSummary(totals)
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),

      bottomNavigationBar: _buildBottomButtons(),
    );
  }

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
                  color: const Color(0xFF4FACFE).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF4FACFE),
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
          
          _buildTextField(
            label: '組合名稱',
            controller: _nameController,
            required: true,
            hint: '例如:健身早餐',
          ),
          
          const SizedBox(height: 12),
          
          _buildTextField(
            label: '分類',
            controller: _categoryController,
            hint: '例如:早餐、午餐、點心',
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

  Widget _buildFoodListSection() {
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
                      const Color(0xFF4FACFE).withOpacity(0.8),
                      const Color(0xFF00F2FE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.list_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '組合內容',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedFoods.length} 項',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ..._selectedFoods.asMap().entries.map((entry) {
            int index = entry.key;
            return _buildSelectedFoodCard(entry.value, index);
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedFoodCard(Map<String, dynamic> item, int index) {
    Map<String, dynamic> food = item['foodData'];
    double servings = item['servings'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food['name'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${food['servingSize']} • ${((food['calories'] ?? 0) * servings).toInt()} 卡',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _selectedFoods.removeAt(index);
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Text(
                '份數',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: servings > 0.5
                    ? () {
                        setState(() {
                          item['servings'] -= 0.5;
                        });
                      }
                    : null,
                color: const Color(0xFF4FACFE),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4FACFE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  servings.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4FACFE),
                  ),
                ),
              ),
              
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: servings < 10
                    ? () {
                        setState(() {
                          item['servings'] += 0.5;
                        });
                      }
                    : null,
                color: const Color(0xFF4FACFE),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddFoodButton() {
    return GestureDetector(
      onTap: _addFood,
      child: SoftCard(
        child: Row(
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                '新增食物',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary(Map<String, double> totals) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF4FACFE), size: 20),
              SizedBox(width: 8),
              Text(
                '營養總計',
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
              Expanded(
                child: _buildNutrientBox(
                  '熱量',
                  totals['calories']!.toInt().toString(),
                  '大卡',
                  AppColors.calories,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '蛋白質',
                  totals['protein']!.toStringAsFixed(1),
                  'g',
                  AppColors.protein,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNutrientBox(
                  '碳水',
                  totals['carbs']!.toStringAsFixed(1),
                  'g',
                  AppColors.carbs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '脂肪',
                  totals['fat']!.toStringAsFixed(1),
                  'g',
                  AppColors.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBox(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
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
                onTap: _isSaving ? null : _saveCombo,
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