// lib/pages/nutrition/add_nutrition_log_page.dart
// 新增飲食記錄頁面 - Soft UI 風格
// ✨ v2.1: 支援掃描記錄 + 可編輯食物名稱 + 完整餐別（含宵夜）

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/nutrition_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

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
  
  // ✨ 食物名稱編輯
  late TextEditingController _nameController;
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.foodData['name'] ?? '未命名食物',
    );
    
    // 如果是掃描的食物，預設開啟編輯
    if (widget.foodData['isScanned'] == true) {
      _isEditingName = true;
    }
    
    // ✨ 根據當前時間自動選擇餐別
    _selectedMealType = _getDefaultMealType();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// ✨ 根據當前時間自動選擇餐別
  String _getDefaultMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return 'breakfast';
    } else if (hour >= 10 && hour < 14) {
      return 'lunch';
    } else if (hour >= 14 && hour < 17) {
      return 'snack';
    } else if (hour >= 17 && hour < 21) {
      return 'dinner';
    } else {
      return 'latenight'; // 21:00 ~ 05:00 宵夜
    }
  }

  /// 儲存記錄
  void _saveLog() async {
    // 驗證食物名稱
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('請輸入食物名稱');
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      // ✨ 決定記錄方式
      String recordMethod = 'search';
      if (widget.foodData['isScanned'] == true) {
        recordMethod = 'scan';
      } else if (widget.foodData['isManual'] == true) {
        recordMethod = 'manual';
      } else if (widget.foodData['isCombo'] == true) {
        recordMethod = 'combo';
      }

      // ✨ 更新食物名稱
      final updatedFoodData = Map<String, dynamic>.from(widget.foodData);
      updatedFoodData['name'] = _nameController.text.trim();

      await _nutritionService.addFoodLog(
        foodData: updatedFoodData,
        servings: _servings,
        mealType: _selectedMealType,
        recordMethod: recordMethod,
      );

      if (mounted) {
        // 返回兩層（掃描頁面 + 搜尋頁面）或一層
        Navigator.pop(context);
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('已記錄 ${_nameController.text.trim()}'),
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
      _showErrorSnackBar('記錄失敗: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 計算總營養
    double totalCalories = (widget.foodData['calories'] ?? 0).toDouble() * _servings;
    double totalProtein = (widget.foodData['protein'] ?? 0).toDouble() * _servings;
    double totalCarbs = (widget.foodData['carbs'] ?? 0).toDouble() * _servings;
    double totalFat = (widget.foodData['fat'] ?? 0).toDouble() * _servings;
    
    final bool isScanned = widget.foodData['isScanned'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食物資訊卡片
            _buildFoodInfoCard(isScanned)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 20),
            
            // 餐別選擇
            _buildMealSelector()
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 20),
            
            // 份數調整
            _buildServingsSelector()
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 20),
            
            // 營養總計
            _buildNutritionSummary(totalCalories, totalProtein, totalCarbs, totalFat)
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 32),
            
            // 儲存按鈕
            _buildSaveButton()
                .animate(delay: 400.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  /// 食物資訊卡片
  Widget _buildFoodInfoCard(bool isScanned) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 圖標
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isScanned 
                        ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
                        : [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isScanned ? Icons.document_scanner : Icons.restaurant,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // 名稱和標籤
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✨ 可編輯的食物名稱
                    if (_isEditingName)
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '輸入食物名稱',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          setState(() => _isEditingName = false);
                        },
                      )
                    else
                      GestureDetector(
                        onTap: () => setState(() => _isEditingName = true),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _nameController.text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 6),
                    
                    // 標籤
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.foodData['servingSize'] ?? '份',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isScanned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.document_scanner, size: 12, color: Color(0xFF8B5CF6)),
                                SizedBox(width: 4),
                                Text(
                                  '掃描',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8B5CF6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
          
          // 提示（掃描時）
          if (isScanned) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF856404)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '點擊食物名稱可以編輯',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF856404),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 餐別選擇 - ✅ 包含宵夜
  Widget _buildMealSelector() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '餐別',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ✅ 餐別按鈕 - 第一排
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
          // ✅ 餐別按鈕 - 第二排（點心 + 宵夜）
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
      onTap: () => setState(() => _selectedMealType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMealColor(String type) {
    switch (type) {
      case 'breakfast': return const Color(0xFFFFB74D);
      case 'lunch': return const Color(0xFF4FC3F7);
      case 'dinner': return const Color(0xFF9575CD);
      case 'snack': return const Color(0xFFFF8A80);
      case 'latenight': return const Color(0xFF7C4DFF); // ✅ 宵夜顏色
      default: return AppColors.primary;
    }
  }

  /// 份數選擇
  Widget _buildServingsSelector() {
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
                  Icons.straighten,
                  color: Color(0xFFFEAC5E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '份數',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 份數顯示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _servings.toStringAsFixed(_servings % 1 == 0 ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 調整按鈕
          Row(
            children: [
              _buildServingButton(
                icon: Icons.remove,
                onTap: _servings > 0.5 ? () => setState(() => _servings -= 0.5) : null,
              ),
              
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.divider,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.2),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: _servings,
                    min: 0.5,
                    max: 10,
                    divisions: 19,
                    onChanged: (value) => setState(() => _servings = value),
                  ),
                ),
              ),
              
              _buildServingButton(
                icon: Icons.add,
                onTap: _servings < 10 ? () => setState(() => _servings += 0.5) : null,
              ),
            ],
          ),
          
          // 快速選擇
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [0.5, 1.0, 1.5, 2.0, 3.0].map((s) {
              final isSelected = _servings == s;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _servings = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      s.toStringAsFixed(s % 1 == 0 ? 0 : 1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServingButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.shadowDark,
                    offset: const Offset(3, 3),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: AppColors.shadowLight,
                    offset: const Offset(-3, -3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isEnabled ? AppColors.primary : AppColors.textTertiary,
          size: 20,
        ),
      ),
    );
  }

  /// 營養總計
  Widget _buildNutritionSummary(double calories, double protein, double carbs, double fat) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFFFF6B6B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '營養總計',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 熱量（大顯示）
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.1),
                  const Color(0xFFFFE66D).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Color(0xFFFF6B6B), size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '熱量',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          calories.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            '大卡',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 三大營養素
          Row(
            children: [
              Expanded(
                child: _buildNutrientItem('蛋白質', protein, 'g', const Color(0xFFEF4444)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientItem('碳水', carbs, 'g', const Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientItem('脂肪', fat, 'g', const Color(0xFF8B5CF6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 儲存按鈕
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveLog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: _isSaving
              ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!])
              : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isSaving
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
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
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              _isSaving ? '儲存中...' : '確認記錄',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}