// lib/pages/nutrition/my_favorites_page.dart
// 我的最愛頁面 - Soft UI 風格
// ✨ 統一收藏庫 + 智慧排序

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/food_database_service.dart';
import '../../services/meal_combo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'add_nutrition_log_page.dart';
import 'add_combo_log_page.dart';

class MyFavoritesPage extends StatefulWidget {
  const MyFavoritesPage({super.key});

  @override
  State<MyFavoritesPage> createState() => _MyFavoritesPageState();
}

class _MyFavoritesPageState extends State<MyFavoritesPage> {
  final FoodDatabaseService _foodService = FoodDatabaseService();
  final MealComboService _comboService = MealComboService();
  
  String _sortBy = 'recent'; // recent, frequency, type, name
  String _filterType = 'all'; // all, food, custom, combo

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
          '我的最愛',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // 排序按鈕
          PopupMenuButton<String>(
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
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              _buildSortMenuItem('recent', '最近使用', Icons.access_time),
              _buildSortMenuItem('frequency', '使用頻率', Icons.trending_up),
              _buildSortMenuItem('type', '類型排序', Icons.category),
              _buildSortMenuItem('name', '名稱排序', Icons.sort_by_alpha),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // 篩選按鈕
          _buildFilterButtons(),
          
          // 最愛列表
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _foodService.getMyFavoritesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                List<Map<String, dynamic>> favorites = _filterAndSortFavorites(snapshot.data!);

                if (favorites.isEmpty) {
                  return _buildNoFilterResultState();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: favorites.length + 1, // +1 for stats card
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildStatsCard(snapshot.data!);
                    }
                    return _buildFavoriteCard(favorites[index - 1], index - 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label, IconData icon) {
    bool isSelected = _sortBy == value;
    
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? const Color(0xFFFF6B95) : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFFFF6B95) : AppColors.textPrimary,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(
              Icons.check,
              size: 18,
              color: Color(0xFFFF6B95),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', '全部', Icons.favorite),
            const SizedBox(width: 8),
            _buildFilterChip('food', '資料庫', Icons.restaurant, color: AppColors.primary),
            const SizedBox(width: 8),
            _buildFilterChip('custom', '自訂食物', Icons.person, color: const Color(0xFFFEAC5E)),
            const SizedBox(width: 8),
            _buildFilterChip('combo', '組合', Icons.restaurant_menu, color: const Color(0xFF4FACFE)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, {Color? color}) {
    final bool isSelected = _filterType == value;
    final Color chipColor = color ?? const Color(0xFFFF6B95);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
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

  List<Map<String, dynamic>> _filterAndSortFavorites(List<Map<String, dynamic>> favorites) {
    // 1. 篩選
    List<Map<String, dynamic>> filtered = favorites;
    if (_filterType != 'all') {
      filtered = favorites.where((fav) => fav['type'] == _filterType).toList();
    }

    // 2. 排序
    switch (_sortBy) {
      case 'frequency':
        filtered.sort((a, b) {
          int aCount = (a['useCount'] ?? 0);
          int bCount = (b['useCount'] ?? 0);
          return bCount.compareTo(aCount);
        });
        break;
      
      case 'type':
        filtered.sort((a, b) {
          String aType = a['type'] ?? '';
          String bType = b['type'] ?? '';
          return aType.compareTo(bType);
        });
        break;
      
      case 'name':
        filtered.sort((a, b) {
          String aName = (a['name'] ?? '').toLowerCase();
          String bName = (b['name'] ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      
      case 'recent':
      default:
        // 預設已經是按 lastUsedAt 排序
        break;
    }

    return filtered;
  }

  Widget _buildStatsCard(List<Map<String, dynamic>> allFavorites) {
    int totalCount = allFavorites.length;
    int foodCount = allFavorites.where((f) => f['type'] == 'food').length;
    int customCount = allFavorites.where((f) => f['type'] == 'custom').length;
    int comboCount = allFavorites.where((f) => f['type'] == 'combo').length;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B95), Color(0xFFFF8A80)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '收藏統計',
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
                child: _buildStatItem('總數', totalCount.toString(), const Color(0xFFFF6B95), Icons.favorite),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('資料庫', foodCount.toString(), AppColors.primary, Icons.restaurant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('自訂', customCount.toString(), const Color(0xFFFEAC5E), Icons.person),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('組合', comboCount.toString(), const Color(0xFF4FACFE), Icons.restaurant_menu),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms);
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite, int index) {
    String type = favorite['type'] ?? 'food';
    String name = favorite['name'] ?? '未知';
    double calories = (favorite['calories'] ?? 0).toDouble();
    String servingSize = favorite['servingSize'] ?? '份';
    int useCount = favorite['useCount'] ?? 0;

    // 類型對應的樣式
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (type) {
      case 'custom':
        typeColor = const Color(0xFFFEAC5E);
        typeIcon = Icons.person;
        typeLabel = '自訂';
        break;
      case 'combo':
        typeColor = const Color(0xFF4FACFE);
        typeIcon = Icons.restaurant_menu;
        typeLabel = '組合';
        break;
      case 'food':
      default:
        typeColor = AppColors.primary;
        typeIcon = Icons.restaurant;
        typeLabel = '資料庫';
        break;
    }

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _onFavoriteTap(favorite),
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
                colors: [
                  typeColor.withOpacity(0.8),
                  typeColor,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              typeIcon,
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
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 類型標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: typeColor,
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
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        servingSize,
                        style: const TextStyle(
                          fontSize: 11,
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
                      '${calories.toInt()} 大卡',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (useCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '使用 $useCount 次',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 右側操作
          Column(
            children: [
              // 移除最愛
              GestureDetector(
                onTap: () => _removeFavorite(favorite),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B95).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF6B95),
                    size: 20,
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

  void _onFavoriteTap(Map<String, dynamic> favorite) async {
    String type = favorite['type'] ?? 'food';
    String refId = favorite['refId'] ?? '';
    String favoriteId = favorite['id'] ?? '';

    // 更新使用記錄
    if (favoriteId.isNotEmpty) {
      _foodService.updateFavoriteUsage(favoriteId);
    }

    if (type == 'combo') {
      // 組合 - 獲取組合資料後進入快速記錄
      try {
        Map<String, dynamic>? comboData = await _comboService.getComboById(refId);
        
        if (comboData != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddComboLogPage(combo: comboData),
            ),
          );
        } else {
          _showErrorSnackBar('找不到此組合，可能已被刪除');
        }
      } catch (e) {
        _showErrorSnackBar('載入組合失敗: $e');
      }
    } else {
      // 食物 (food 或 custom) - 獲取食物資料後進入份量調整
      try {
        Map<String, dynamic>? foodData;
        
        if (type == 'custom') {
          foodData = await _foodService.getCustomFoodById(refId);
        } else {
          foodData = await _foodService.getFoodById(refId);
        }
        
        if (foodData != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddNutritionLogPage(foodData: foodData!),
            ),
          );
        } else {
          _showErrorSnackBar('找不到此食物，可能已被刪除');
        }
      } catch (e) {
        _showErrorSnackBar('載入食物失敗: $e');
      }
    }
  }

  void _removeFavorite(Map<String, dynamic> favorite) async {
    String name = favorite['name'] ?? '此項目';
    String refId = favorite['refId'] ?? '';
    String type = favorite['type'] ?? 'food';

    // 顯示確認對話框
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('移除最愛'),
        content: Text('確定要將「$name」從最愛移除嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _foodService.removeFromFavorites(refId: refId, type: type);
        
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
                  Text('已從最愛移除「$name」'),
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
        _showErrorSnackBar('移除失敗: $e');
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B95)),
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
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
                    const Color(0xFFFF6B95).withOpacity(0.1),
                    const Color(0xFFFF8A80).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 80,
                color: const Color(0xFFFF6B95).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '尚無收藏',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '在搜尋結果、自訂食物或組合\n點擊愛心即可加入最愛',
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

  Widget _buildNoFilterResultState() {
    return Center(
      child: Padding(
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
                Icons.filter_list_off,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '無符合的收藏',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '試試切換其他篩選條件',
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