// lib/pages/nutrition/my_foods_page.dart
// 我的食物頁面 - Soft UI 風格 (增強版 v2.1)
// ✨ 新增: 搜尋、排序、統計、快速複製、我的最愛

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/food_database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'add_custom_food_page.dart';
import 'add_nutrition_log_page.dart';

class MyFoodsPage extends StatefulWidget {
  const MyFoodsPage({super.key});

  @override
  State<MyFoodsPage> createState() => _MyFoodsPageState();
}

class _MyFoodsPageState extends State<MyFoodsPage> {
  final FoodDatabaseService _foodService = FoodDatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  // ✨ 排序方式
  String _sortBy = 'newest'; // newest, oldest, name, calories
  
  // ✨ 搜尋關鍵字
  String _searchQuery = '';
  
  // ✨ 最愛狀態緩存
  Map<String, bool> _favoriteStatus = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✨ 載入最愛狀態
  Future<void> _loadFavoriteStatus(List<Map<String, dynamic>> foods) async {
    Map<String, bool> status = {};
    
    for (var food in foods) {
      String id = food['id'] ?? '';
      bool isFav = await _foodService.isFavorite(refId: id, type: 'custom');
      status['custom_$id'] = isFav;
    }
    
    if (mounted) {
      setState(() {
        _favoriteStatus = status;
      });
    }
  }

  /// ✨ 切換最愛狀態
  Future<void> _toggleFavorite(Map<String, dynamic> food) async {
    String id = food['id'] ?? '';
    String key = 'custom_$id';
    String name = food['name'] ?? '';
    double calories = (food['calories'] ?? 0).toDouble();
    String servingSize = food['servingSize'] ?? '份';
    
    bool currentStatus = _favoriteStatus[key] ?? false;
    
    // 先更新 UI
    setState(() {
      _favoriteStatus[key] = !currentStatus;
    });
    
    try {
      bool newStatus = await _foodService.toggleFavorite(
        refId: id,
        type: 'custom',
        name: name,
        calories: calories,
        servingSize: servingSize,
      );
      
      setState(() {
        _favoriteStatus[key] = newStatus;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(newStatus ? '已加入最愛' : '已從最愛移除'),
              ],
            ),
            backgroundColor: newStatus ? const Color(0xFFFF6B95) : AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _favoriteStatus[key] = currentStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失敗: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// ✨ 篩選和排序食物
  List<Map<String, dynamic>> _filterAndSortFoods(List<Map<String, dynamic>> foods) {
    // 1. 搜尋篩選
    List<Map<String, dynamic>> filtered = foods;
    if (_searchQuery.isNotEmpty) {
      filtered = foods.where((food) {
        String name = food['name'].toString().toLowerCase();
        String category = (food['category'] ?? '').toString().toLowerCase();
        String query = _searchQuery.toLowerCase();
        return name.contains(query) || category.contains(query);
      }).toList();
    }

    // 2. 排序
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) {
          var aTime = a['createdAt'];
          var bTime = b['createdAt'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        break;
      case 'oldest':
        filtered.sort((a, b) {
          var aTime = a['createdAt'];
          var bTime = b['createdAt'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });
        break;
      case 'name':
        filtered.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        break;
      case 'calories':
        filtered.sort((a, b) {
          double aCalories = (a['calories'] ?? 0).toDouble();
          double bCalories = (b['calories'] ?? 0).toDouble();
          return bCalories.compareTo(aCalories);
        });
        break;
    }

    return filtered;
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
          '我的食物',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // ✨ 排序按鈕
        actions: [
          IconButton(
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
                Icons.sort,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            onPressed: _showSortOptions,
          ),
          const SizedBox(width: 16),
        ],
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _foodService.getMyCustomFoodsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final allFoods = snapshot.data ?? [];
          final filteredFoods = _filterAndSortFoods(allFoods);
          
          // ✨ 載入最愛狀態
          if (allFoods.isNotEmpty && _favoriteStatus.isEmpty) {
            _loadFavoriteStatus(allFoods);
          }

          return Column(
            children: [
              // ✨ 統計資訊卡片
              if (allFoods.isNotEmpty)
                _buildStatsCard(allFoods)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0, duration: 400.ms),

              // ✨ 搜尋欄
              if (allFoods.isNotEmpty)
                _buildSearchBar(),

              // 食物列表
              Expanded(
                child: filteredFoods.isEmpty
                    ? (allFoods.isEmpty 
                        ? _buildEmptyState() 
                        : _buildNoResultsState())
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: filteredFoods.length,
                        itemBuilder: (context, index) {
                          final food = filteredFoods[index];
                          return _buildFoodCard(food, index);
                        },
                      ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: _buildAddButton(),
    );
  }

  /// ✨ 統計資訊卡片
  Widget _buildStatsCard(List<Map<String, dynamic>> foods) {
    int totalFoods = foods.length;
    double totalCalories = foods.fold(0, (sum, food) => sum + (food['calories'] ?? 0).toDouble());
    double avgCalories = totalCalories / totalFoods;

    // 統計分類
    Map<String, int> categoryCount = {};
    for (var food in foods) {
      String category = food['category'] ?? '其他';
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }
    String mostCategory = categoryCount.entries.isEmpty 
        ? '無' 
        : categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SoftCard(
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
                        const Color(0xFFFEAC5E).withOpacity(0.8),
                        const Color(0xFFFD9B63),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '統計資訊',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('總數', totalFoods.toString(), Icons.inventory_2),
                ),
                Expanded(
                  child: _buildStatItem('平均', '${avgCalories.toInt()} 卡', Icons.show_chart),
                ),
                Expanded(
                  child: _buildStatItem('常用', mostCategory, Icons.star),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFEAC5E)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// ✨ 搜尋欄
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '搜尋食物名稱或分類...',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFFFEAC5E),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// ✨ 排序選項對話框
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: Color(0xFFFEAC5E), size: 20),
                    SizedBox(width: 10),
                    Text(
                      '排序方式',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('最新建立', 'newest', Icons.fiber_new),
              _buildSortOption('最早建立', 'oldest', Icons.access_time),
              _buildSortOption('名稱排序', 'name', Icons.sort_by_alpha),
              _buildSortOption('熱量排序', 'calories', Icons.local_fire_department),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    bool isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFEAC5E).withOpacity(0.15) 
              : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFFEAC5E) 
                : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFEAC5E) : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFFEAC5E) : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFFEAC5E),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// ✨ 食物卡片 (加愛心)
  Widget _buildFoodCard(Map<String, dynamic> food, int index) {
    String id = food['id'] ?? '';
    String key = 'custom_$id';
    bool isFavorite = _favoriteStatus[key] ?? false;
    
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFEAC5E).withOpacity(0.8),
                      const Color(0xFFFEAC5E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              
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
                        // ✨ 愛心按鈕
                        GestureDetector(
                          onTap: () => _toggleFavorite(food),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                key: ValueKey(isFavorite),
                                size: 22,
                                color: isFavorite 
                                    ? const Color(0xFFFF6B95) 
                                    : AppColors.textTertiary,
                              ),
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
                            color: const Color(0xFFFEAC5E).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            food['servingSize'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFEAC5E),
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
                          '${food['calories'].toInt()} 大卡',
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
              
              // ✨ 更多選項按鈕
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'record':
                      _quickAddLog(food);
                      break;
                    case 'edit':
                      _editFood(food);
                      break;
                    case 'duplicate':
                      _duplicateFood(food);
                      break;
                    case 'delete':
                      _confirmDelete(food);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'record',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('記錄'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
                        SizedBox(width: 10),
                        Text('編輯'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18, color: Color(0xFFFEAC5E)),
                        SizedBox(width: 10),
                        Text('複製'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 10),
                        Text('刪除'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _buildMiniNutrient('P', food['protein'], AppColors.protein),
              const SizedBox(width: 12),
              _buildMiniNutrient('C', food['carbs'], AppColors.carbs),
              const SizedBox(width: 12),
              _buildMiniNutrient('F', food['fat'], AppColors.fat),
              const Spacer(),
              // 分類標籤
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  food['category'] ?? '其他',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.2, end: 0, duration: 300.ms);
  }

  Widget _buildMiniNutrient(String label, dynamic value, Color color) {
    double numValue = (value is int) ? value.toDouble() : (value ?? 0.0);
    
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          numValue.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// ✨ 複製食物功能
  void _duplicateFood(Map<String, dynamic> food) async {
    try {
      await _foodService.addCustomFood(
        name: '${food['name']} (複製)',
        category: food['category'] ?? '',
        servingSize: food['servingSize'] ?? '',
        calories: (food['calories'] ?? 0).toDouble(),
        protein: (food['protein'] ?? 0).toDouble(),
        carbs: (food['carbs'] ?? 0).toDouble(),
        fat: (food['fat'] ?? 0).toDouble(),
        saturatedFat: (food['saturatedFat'] ?? 0).toDouble(),
        transFat: (food['transFat'] ?? 0).toDouble(),
        fiber: (food['fiber'] ?? 0).toDouble(),
        sugar: (food['sugar'] ?? 0).toDouble(),
        sodium: (food['sodium'] ?? 0).toDouble(),
        cholesterol: (food['cholesterol'] ?? 0).toDouble(),
      );
      
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
                const Text('已複製食物!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('複製失敗: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddCustomFoodPage(),
          ),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEAC5E),
              Color(0xFFFD9B63),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFEAC5E).withOpacity(0.4),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  void _quickAddLog(Map<String, dynamic> food) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNutritionLogPage(foodData: food),
      ),
    );
  }

  void _editFood(Map<String, dynamic> food) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomFoodPage(existingFood: food),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${food['name']}」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFood(food['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _deleteFood(String foodId) async {
    try {
      await _foodService.deleteCustomFood(foodId);
      
      // ✨ 同時從最愛移除
      await _foodService.removeFromFavorites(refId: foodId, type: 'custom');
      
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
                const Text('已刪除'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFEAC5E)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '載入中...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                '載入失敗',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                    const Color(0xFFFEAC5E).withOpacity(0.1),
                    const Color(0xFFFD9B63).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 80,
                color: const Color(0xFFFEAC5E).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '尚未建立自訂食物',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '點擊右下角按鈕\n開始建立你的專屬食物庫',
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

  /// ✨ 搜尋無結果狀態
  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.search_off,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '找不到相關食物',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '搜尋「$_searchQuery」沒有結果\n試試其他關鍵字',
              textAlign: TextAlign.center,
              style: const TextStyle(
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