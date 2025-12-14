// lib/pages/nutrition/ai_food_confirm_page.dart
// ✨ AI 辨識確認頁面 v1.1
// 適配現有 ai_food_service.dart（Cloud Functions 版本）
// 功能：
// 1. 顯示 AI 辨識結果
// 2. 用戶可編輯餐點名稱（AI 建議 + 可修改）
// 3. 選擇/取消勾選食物
// 4. 調整份量
// 5. 選擇餐別
// 6. 確認記錄 → 寫入 Firebase
// 7. 可選：存為我的食物

import 'package:flutter/material.dart';
import '../../services/nutrition_service.dart';
import '../../services/ai_food_service.dart';
import '../../theme/app_colors.dart';

class AiFoodConfirmPage extends StatefulWidget {
  final FoodAnalysisResult aiResult;
  final String? suggestedMealName;

  const AiFoodConfirmPage({
    super.key,
    required this.aiResult,
    this.suggestedMealName,
  });

  @override
  State<AiFoodConfirmPage> createState() => _AiFoodConfirmPageState();
}

class _AiFoodConfirmPageState extends State<AiFoodConfirmPage> {
  final NutritionService _nutritionService = NutritionService();
  final TextEditingController _mealNameController = TextEditingController();
  
  // 食物選擇狀態
  late List<bool> _selectedFoods;
  late List<double> _servings;
  
  // 餐別
  String _selectedMealType = 'lunch';
  
  // 儲存狀態
  bool _isSaving = false;
  bool _saveAsCustomFood = false;

  @override
  void initState() {
    super.initState();
    
    // 初始化選擇狀態
    _selectedFoods = List.generate(widget.aiResult.foods.length, (_) => true);
    _servings = List.generate(widget.aiResult.foods.length, (_) => 1.0);
    
    // 設定建議名稱
    _mealNameController.text = widget.suggestedMealName ?? _generateDefaultName();
    
    // 根據時間自動選擇餐別
    _autoSelectMealType();
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    super.dispose();
  }

  String _generateDefaultName() {
    if (widget.aiResult.foods.length == 1) {
      return widget.aiResult.foods.first.name;
    }
    
    // 嘗試生成組合名稱
    List<String> names = widget.aiResult.foods.map((f) => f.name).toList();
    if (names.length <= 3) {
      return names.join('、');
    }
    return '${names.first}等 ${names.length} 項';
  }

  void _autoSelectMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      _selectedMealType = 'breakfast';
    } else if (hour >= 10 && hour < 14) {
      _selectedMealType = 'lunch';
    } else if (hour >= 14 && hour < 17) {
      _selectedMealType = 'snack';
    } else if (hour >= 17 && hour < 21) {
      _selectedMealType = 'dinner';
    } else {
      _selectedMealType = 'latenight';
    }
  }

  // 計算營養總計（適配現有 FoodItem，沒有 sugar/fiber）
  Map<String, double> _calculateTotals() {
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    
    for (int i = 0; i < widget.aiResult.foods.length; i++) {
      if (_selectedFoods[i]) {
        final food = widget.aiResult.foods[i];
        final servings = _servings[i];
        
        calories += food.calories * servings;
        protein += food.protein * servings;
        carbs += food.carbs * servings;
        fat += food.fat * servings;
      }
    }
    
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sugar': 0.0,    // 目前 AI 服務不提供
      'fiber': 0.0,    // 目前 AI 服務不提供
    };
  }

  // 獲取選中的食物列表
  List<Map<String, dynamic>> _getSelectedFoods() {
    List<Map<String, dynamic>> foods = [];
    
    for (int i = 0; i < widget.aiResult.foods.length; i++) {
      if (_selectedFoods[i]) {
        final food = widget.aiResult.foods[i];
        foods.add({
          'name': food.name,
          'portion': food.portion,
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'sugar': 0.0,
          'fiber': 0.0,
          'confidence': food.confidence,
          'servings': _servings[i],
          'notes': food.notes,
        });
      }
    }
    
    return foods;
  }

  Future<void> _confirmAndSave() async {
    final selectedFoods = _getSelectedFoods();
    
    if (selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請至少選擇一項食物'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final mealName = _mealNameController.text.trim().isEmpty 
          ? _generateDefaultName() 
          : _mealNameController.text.trim();
      
      final totals = _calculateTotals();

      // 儲存 AI 記錄
      await _nutritionService.addAiLog(
        mealName: mealName,
        mealType: _selectedMealType,
        foods: selectedFoods,
        totalNutrition: totals,
      );

      // 如果勾選了「存為我的食物」
      if (_saveAsCustomFood) {
        await _nutritionService.saveAsCustomFood(
          foodName: mealName,
          calories: totals['calories']!,
          protein: totals['protein']!,
          carbs: totals['carbs']!,
          fat: totals['fat']!,
          sugar: totals['sugar']!,
          fiber: totals['fiber']!,
          aiDetails: selectedFoods,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // 返回並傳遞成功狀態
        
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
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _saveAsCustomFood 
                        ? '已記錄「$mealName」並存為自訂食物'
                        : '已記錄「$mealName」',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('記錄失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final selectedCount = _selectedFoods.where((s) => s).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '確認記錄',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
            // 餐點名稱
            _buildMealNameSection(),
            const SizedBox(height: 20),
            
            // AI 辨識結果
            _buildFoodListSection(selectedCount),
            const SizedBox(height: 20),
            
            // 營養總計
            _buildNutritionSummary(totals),
            const SizedBox(height: 20),
            
            // 餐別選擇
            _buildMealTypeSection(),
            const SizedBox(height: 20),
            
            // 存為我的食物選項
            _buildSaveAsCustomOption(),
            const SizedBox(height: 24),
            
            // 確認按鈕
            _buildConfirmButton(selectedCount),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMealNameSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '餐點名稱',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mealNameController,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '輸入餐點名稱（如：排骨便當）',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18, color: AppColors.textTertiary),
                onPressed: () => _mealNameController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                'AI 建議名稱，可自行修改',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoodListSection(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI 辨識結果',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '已選 $selectedCount/${widget.aiResult.foods.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 食物列表
          ...widget.aiResult.foods.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return _buildFoodItem(index, food);
          }),
        ],
      ),
    );
  }

  Widget _buildFoodItem(int index, FoodItem food) {
    final isSelected = _selectedFoods[index];
    final servings = _servings[index];
    
    // 信心度顏色
    Color confidenceColor;
    String confidenceText;
    switch (food.confidence) {
      case 'high':
        confidenceColor = const Color(0xFF10B981);
        confidenceText = '高準確度';
        break;
      case 'low':
        confidenceColor = const Color(0xFFF59E0B);
        confidenceText = '低準確度';
        break;
      default:
        confidenceColor = const Color(0xFF6B7280);
        confidenceText = '中準確度';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFF10B981).withOpacity(0.05) 
            : AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF10B981).withOpacity(0.3) 
              : AppColors.divider,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // 標題列
          Row(
            children: [
              // 勾選框
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFoods[index] = !_selectedFoods[index];
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981) : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected 
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // 食物名稱
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${(food.calories * servings).toInt()} 大卡',
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? AppColors.calories : AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: confidenceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            confidenceText,
                            style: TextStyle(fontSize: 9, color: confidenceColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // 顯示份量
                        if (food.portion.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            food.portion,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 份量調整（只在選中時顯示）
          if (isSelected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 36), // 對齊勾選框
                const Text('份量', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                _buildServingAdjuster(index),
              ],
            ),
            const SizedBox(height: 8),
            // 營養素詳情
            Row(
              children: [
                const SizedBox(width: 36),
                _buildMiniNutrient('蛋白質', food.protein * servings, 'g', AppColors.protein),
                const SizedBox(width: 12),
                _buildMiniNutrient('碳水', food.carbs * servings, 'g', AppColors.carbs),
                const SizedBox(width: 12),
                _buildMiniNutrient('脂肪', food.fat * servings, 'g', AppColors.fat),
              ],
            ),
            // 備註
            if (food.notes != null && food.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              food.notes!,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildServingAdjuster(int index) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_servings[index] > 0.5) {
              setState(() {
                _servings[index] -= 0.5;
              });
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.remove,
              size: 18,
              color: _servings[index] > 0.5 ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
        Container(
          width: 60,
          alignment: Alignment.center,
          child: Text(
            '${_servings[index].toStringAsFixed(1)} 份',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (_servings[index] < 5.0) {
              setState(() {
                _servings[index] += 0.5;
              });
            }
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add,
              size: 18,
              color: _servings[index] < 5.0 ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniNutrient(String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary(Map<String, double> totals) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF34D399).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                '營養總計',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 熱量（大字）
          Center(
            child: Column(
              children: [
                Text(
                  '${totals['calories']!.toInt()}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.calories,
                  ),
                ),
                const Text(
                  '大卡',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 三大營養素
          Row(
            children: [
              Expanded(child: _buildNutrientColumn('蛋白質', totals['protein']!, 'g', AppColors.protein)),
              Expanded(child: _buildNutrientColumn('碳水', totals['carbs']!, 'g', AppColors.carbs)),
              Expanded(child: _buildNutrientColumn('脂肪', totals['fat']!, 'g', AppColors.fat)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientColumn(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeSection() {
    final mealTypes = [
      {'id': 'breakfast', 'name': '早餐', 'emoji': '🌅'},
      {'id': 'lunch', 'name': '午餐', 'emoji': '☀️'},
      {'id': 'dinner', 'name': '晚餐', 'emoji': '🌙'},
      {'id': 'snack', 'name': '點心', 'emoji': '🍪'},
      {'id': 'latenight', 'name': '宵夜', 'emoji': '🌃'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '餐別',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mealTypes.map((meal) {
              final isSelected = _selectedMealType == meal['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMealType = meal['id'] as String;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(meal['emoji'] as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        meal['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveAsCustomOption() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _saveAsCustomFood = !_saveAsCustomFood;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _saveAsCustomFood 
              ? const Color(0xFF10B981).withOpacity(0.08) 
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _saveAsCustomFood 
                ? const Color(0xFF10B981).withOpacity(0.3) 
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _saveAsCustomFood ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _saveAsCustomFood ? const Color(0xFF10B981) : AppColors.divider,
                  width: 2,
                ),
              ),
              child: _saveAsCustomFood 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '同時存為我的食物',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '下次可以直接搜尋使用',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.bookmark_add_outlined, size: 20, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(int selectedCount) {
    final isEnabled = selectedCount > 0 && !_isSaving;

    return GestureDetector(
      onTap: isEnabled ? _confirmAndSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
              : null,
          color: isEnabled ? null : AppColors.divider,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSaving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                Icons.check_circle,
                color: isEnabled ? Colors.white : AppColors.textTertiary,
                size: 22,
              ),
            const SizedBox(width: 10),
            Text(
              _isSaving ? '記錄中...' : '確認並記錄',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}