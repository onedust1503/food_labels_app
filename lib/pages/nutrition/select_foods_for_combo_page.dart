// lib/pages/nutrition/select_foods_for_combo_page.dart
// 選擇食物頁面 - 用於建立組合時選擇食物
// ✨ 改進版: 支援多選、自訂食物篩選、更好的操作體驗

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/food_database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';

class SelectFoodsForComboPage extends StatefulWidget {
  final List<Map<String, dynamic>>? alreadySelected; // 已選擇的食物
  
  const SelectFoodsForComboPage({
    super.key,
    this.alreadySelected,
  });

  @override
  State<SelectFoodsForComboPage> createState() => _SelectFoodsForComboPageState();
}

class _SelectFoodsForComboPageState extends State<SelectFoodsForComboPage> {
  final TextEditingController _searchController = TextEditingController();
  final FoodDatabaseService _foodService = FoodDatabaseService();
  
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedFoods = []; // 多選清單
  bool _isSearching = false;
  
  // 🆕 篩選模式
  String _filterMode = 'all'; // all, custom, system

  @override
  void initState() {
    super.initState();
    // 如果有已選擇的食物,載入它們
    if (widget.alreadySelected != null) {
      _selectedFoods = List.from(widget.alreadySelected!);
    }
    _loadAllFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAllFoods() async {
    setState(() => _isSearching = true);
    
    try {
      List<Map<String, dynamic>> results = await _foodService.getAllFoods();
      setState(() {
        _searchResults = _applyFilter(results);
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showErrorSnackBar('載入失敗: $e');
      }
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      _loadAllFoods();
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<Map<String, dynamic>> results = await _foodService.searchFoods(query);
      setState(() {
        _searchResults = _applyFilter(results);
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showErrorSnackBar('搜尋失敗: $e');
      }
    }
  }

  // 🆕 套用篩選
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> foods) {
    switch (_filterMode) {
      case 'custom':
        return foods.where((food) => food['isCustom'] == true).toList();
      case 'system':
        return foods.where((food) => food['isCustom'] != true).toList();
      default:
        return foods;
    }
  }

  // 🆕 切換篩選模式
  void _changeFilterMode(String mode) {
    setState(() {
      _filterMode = mode;
    });
    
    // 重新套用篩選
    if (_searchController.text.isEmpty) {
      _loadAllFoods();
    } else {
      _performSearch(_searchController.text);
    }
  }

  // 🆕 切換選擇狀態
  void _toggleSelection(Map<String, dynamic> food) {
    setState(() {
      bool isAlreadySelected = _selectedFoods.any((f) => f['id'] == food['id']);
      
      if (isAlreadySelected) {
        _selectedFoods.removeWhere((f) => f['id'] == food['id']);
      } else {
        _selectedFoods.add(food);
      }
    });
  }

  // 🆕 檢查是否已選擇
  bool _isSelected(Map<String, dynamic> food) {
    return _selectedFoods.any((f) => f['id'] == food['id']);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // 🆕 完成選擇
  void _confirmSelection() {
    if (_selectedFoods.isEmpty) {
      _showErrorSnackBar('請至少選擇一個食物');
      return;
    }
    
    Navigator.pop(context, _selectedFoods);
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
        title: Column(
          children: [
            const Text(
              '選擇食物',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedFoods.isNotEmpty)
              Text(
                '已選 ${_selectedFoods.length} 項',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          // 🆕 清除所有選擇
          if (_selectedFoods.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFoods.clear();
                });
              },
              child: const Text(
                '清除',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // 搜尋欄
          _buildSearchBar(),
          
          // 🆕 篩選按鈕
          _buildFilterButtons(),
          
          // 食物列表
          Expanded(
            child: _isSearching
                ? _buildLoadingState()
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final food = _searchResults[index];
                          final isSelected = _isSelected(food);
                          return _buildFoodCard(food, index, isSelected);
                        },
                      ),
          ),
        ],
      ),

      // 🆕 底部確認按鈕
      bottomNavigationBar: _selectedFoods.isNotEmpty
          ? _buildBottomButton()
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _performSearch,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '搜尋食物名稱...',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 15,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.search,
                color: Color(0xFF4FACFE),
                size: 22,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _loadAllFoods();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 篩選按鈕
  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            '篩選:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: '全部',
                    value: 'all',
                    icon: Icons.restaurant_menu,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: '我的自訂',
                    value: 'custom',
                    icon: Icons.person,
                    color: const Color(0xFFFEAC5E),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: '系統食物',
                    value: 'system',
                    icon: Icons.inventory_2,
                    color: const Color(0xFF4FACFE),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final bool isSelected = _filterMode == value;
    final Color chipColor = color ?? const Color(0xFF4FACFE);
    
    return GestureDetector(
      onTap: () => _changeFilterMode(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
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
  }

  Widget _buildFoodCard(Map<String, dynamic> food, int index, bool isSelected) {
    bool isCustom = food['isCustom'] ?? false;
    
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _toggleSelection(food),
      child: Stack(
        children: [
          Row(
            children: [
              // 左側圖標
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            AppColors.success.withOpacity(0.8),
                            AppColors.success,
                          ]
                        : [
                            const Color(0xFF4FACFE).withOpacity(0.8),
                            const Color(0xFF00F2FE),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : (isCustom ? Icons.person : Icons.restaurant),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              
              // 中間內容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEAC5E).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '自訂',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFEAC5E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FACFE).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            food['servingSize'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4FACFE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: AppColors.calories,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${food['calories']} 大卡',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 右側選擇指示器
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.success : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.success : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
          
          // 選中效果覆蓋層
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
        ],
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.2, end: 0, duration: 300.ms);
  }

  // 🆕 底部確認按鈕
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
        child: GestureDetector(
          onTap: _confirmSelection,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '加入 ${_selectedFoods.length} 項食物',
                  style: const TextStyle(
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
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4FACFE)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '載入中...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4FACFE).withOpacity(0.1),
                    const Color(0xFF00F2FE).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 80,
                color: const Color(0xFF4FACFE).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '找不到食物',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '試試其他關鍵字或切換篩選',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}