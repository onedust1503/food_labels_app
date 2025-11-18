// lib/pages/nutrition/food_search_page.dart
// Soft UI 風格的食物搜尋頁面 - 四按鈕版本
// 保留原有搜尋功能,新增四大記錄方式

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/food_database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'add_nutrition_log_page.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FoodDatabaseService _foodService = FoodDatabaseService();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _selectedCategory;
  bool _showSearchResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 按分類篩選
  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _searchController.text = category;
      _isSearching = true;
      _showSearchResults = true;
    });

    _foodService.searchFoods('').then((allFoods) {
      final filtered = allFoods.where((food) {
        String foodCategory = food['category'] ?? '';
        return foodCategory.contains(category);
      }).toList();

      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    }).catchError((e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showErrorSnackBar('載入失敗: $e');
      }
    });
  }

  /// 執行搜尋
  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _selectedCategory = null;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedCategory = null;
      _showSearchResults = true;
    });

    try {
      List<Map<String, dynamic>> results = await _foodService.searchFoods(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showErrorSnackBar('搜尋失敗: $e');
      }
    }
  }

  /// 清除搜尋
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _isSearching = false;
      _selectedCategory = null;
      _showSearchResults = false;
    });
  }

  /// 返回按鈕邏輯
  Future<bool> _onWillPop() async {
    if (_showSearchResults) {
      _clearSearch();
      return false;
    }
    return true;
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
            onPressed: () {
              if (_showSearchResults) {
                _clearSearch();
              } else {
                Navigator.pop(context);
              }
            },
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
        ),

        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // 搜尋欄
              _buildSearchBar(),
              
              // 根據狀態顯示不同內容
              Expanded(
                child: _showSearchResults
                    ? _buildSearchResultsView()
                    : _buildMainView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 搜尋欄
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
            hintStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 15,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.search,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: _clearSearch,
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

  /// 主視圖 (未搜尋時) - 固定佈局
  Widget _buildMainView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16), // ✅ 搜尋欄下方增加間距
          
          // 四大功能按鈕
          _buildFunctionButtons()
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0, duration: 400.ms),
          
          const SizedBox(height: 24),

          // 快速篩選區塊
          _buildQuickFilterSection()
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0, duration: 400.ms),

          // 底部空白佔位
          const Spacer(),
        ],
      ),
    );
  }

  /// 四大功能按鈕
  Widget _buildFunctionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 上排 - 快速記錄
        Row(
          children: [
            Expanded(
              child: _buildFunctionCard(
                icon: Icons.edit_note,
                title: '手動記錄',
                color: const Color(0xFFFA709A),
                onTap: () {
                  // TODO: 導航到手動記錄頁面
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('手動記錄功能開發中...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFunctionCard(
                icon: Icons.favorite,
                title: '我的最愛',
                color: const Color(0xFFFF6B95),
                onTap: () {
                  // TODO: 導航到我的最愛頁面
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('我的最愛功能開發中...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        // 下排 - 新增管理
        Row(
          children: [
            Expanded(
              child: _buildFunctionCard(
                icon: Icons.restaurant_menu,
                title: '我的食物',
                color: const Color(0xFFFEAC5E),
                onTap: () {
                  // TODO: 導航到我的食物頁面
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('我的食物功能開發中...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFunctionCard(
                icon: Icons.add_box,
                title: '我的組合',
                color: const Color(0xFF4FACFE),
                onTap: () {
                  // TODO: 導航到我的組合頁面
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('我的組合功能開發中...'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 功能卡片 - Soft UI 風格
  Widget _buildFunctionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark,
              offset: const Offset(8, 8),
              blurRadius: 16,
            ),
            BoxShadow(
              color: AppColors.shadowLight,
              offset: const Offset(-8, -8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 快速篩選區塊
  Widget _buildQuickFilterSection() {
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
                  Icons.dashboard_customize,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '快速篩選',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 3x2 網格佈局
          Row(
            children: [
              Expanded(
                child: _buildCategoryChip('🍚', '中式主食', () => _filterByCategory('中式主食')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryChip('🍝', '西式主食', () => _filterByCategory('西式主食')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryChip('🍖', '蛋白質', () => _filterByCategory('蛋白質')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCategoryChip('🥤', '飲品', () => _filterByCategory('飲品')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryChip('🥗', '沙拉', () => _filterByCategory('沙拉')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCategoryChip('🍎', '水果', () => _filterByCategory('水果')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分類篩選按鈕 - 統一大小
  Widget _buildCategoryChip(String emoji, String label, VoidCallback onTap) {
    final bool isSelected = _selectedCategory == label;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.shadowLight,
              offset: const Offset(0, 2),
              blurRadius: isSelected ? 8 : 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 搜尋結果視圖
  Widget _buildSearchResultsView() {
    if (_isSearching) {
      return _buildLoadingState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // 結果統計
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '找到 ${_searchResults.length} 項食物',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_selectedCategory != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedCategory!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // 結果列表
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final food = _searchResults[index];
              return _buildFoodCard(food, index);
            },
          ),
        ),
      ],
    );
  }

  /// 食物卡片
  Widget _buildFoodCard(Map<String, dynamic> food, int index) {
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddNutritionLogPage(foodData: food),
          ),
        );
      },
      child: Row(
        children: [
          // 左側圖標
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withOpacity(0.8), AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant,
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
                Text(
                  food['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
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
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        food['servingSize'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
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
          
          // 右側箭頭
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.2, end: 0, duration: 300.ms);
  }

  /// 載入中狀態
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedCategory != null ? '載入 $_selectedCategory...' : '搜尋中...',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 無結果狀態
  Widget _buildNoResultsState() {
    final bool hasInput = _searchController.text.isNotEmpty;
    
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
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primaryLight.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasInput ? Icons.search_off : Icons.restaurant_menu,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasInput ? '找不到相關食物' : '開始搜尋食物',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasInput
                  ? '試試其他關鍵字或使用上方功能按鈕'
                  : '輸入關鍵字開始搜尋',
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