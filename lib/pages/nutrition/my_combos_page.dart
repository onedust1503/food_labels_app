// lib/pages/nutrition/my_combos_page.dart
// 我的組合主頁面 - Soft UI 風格
// ✅ 修正 null safety 問題

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/meal_combo_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'create_combo_page.dart';
import 'add_combo_log_page.dart';

class MyCombosPage extends StatefulWidget {
  const MyCombosPage({super.key});

  @override
  State<MyCombosPage> createState() => _MyCombosPageState();
}

class _MyCombosPageState extends State<MyCombosPage> {
  final MealComboService _comboService = MealComboService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest, name, calories
  
  @override
  void dispose() {
    _searchController.dispose();
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
          '我的組合',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
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
              _buildSortMenuItem('newest', '最新建立', Icons.access_time),
              _buildSortMenuItem('oldest', '最早建立', Icons.history),
              _buildSortMenuItem('name', '名稱排序', Icons.sort_by_alpha),
              _buildSortMenuItem('calories', '熱量排序', Icons.local_fire_department),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // 搜尋欄
          _buildSearchBar(),
          
          // 組合列表
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _comboService.getMyCombosStream(),
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

                List<Map<String, dynamic>> combos = _filterAndSortCombos(snapshot.data!);

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    // 統計卡片
                    _buildStatsCard(snapshot.data!),
                    
                    const SizedBox(height: 20),
                    
                    // 組合列表
                    ...combos.asMap().entries.map((entry) {
                      int index = entry.key;
                      return _buildComboCard(entry.value, index);
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // 新增按鈕
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateComboPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF4FACFE),
        elevation: 8,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '新增組合',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            color: isSelected ? const Color(0xFF4FACFE) : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF4FACFE) : AppColors.textPrimary,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(
              Icons.check,
              size: 18,
              color: Color(0xFF4FACFE),
            ),
          ],
        ],
      ),
    );
  }

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
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '搜尋組合名稱或分類...',
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
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
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

  List<Map<String, dynamic>> _filterAndSortCombos(List<Map<String, dynamic>> combos) {
    // 搜尋過濾
    List<Map<String, dynamic>> filtered = combos.where((combo) {
      if (_searchQuery.isEmpty) return true;
      
      String comboName = (combo['comboName'] ?? '').toLowerCase();
      String category = (combo['category'] ?? '').toLowerCase();
      
      return comboName.contains(_searchQuery) || category.contains(_searchQuery);
    }).toList();

    // 排序
    switch (_sortBy) {
      case 'oldest':
        filtered.sort((a, b) {
          var aTime = a['createdAt'] ?? DateTime.now();
          var bTime = b['createdAt'] ?? DateTime.now();
          return aTime.compareTo(bTime);
        });
        break;
      
      case 'name':
        filtered.sort((a, b) {
          String aName = (a['comboName'] ?? '').toLowerCase();
          String bName = (b['comboName'] ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      
      case 'calories':
        filtered.sort((a, b) {
          double aCal = (a['totalCalories'] ?? 0).toDouble();
          double bCal = (b['totalCalories'] ?? 0).toDouble();
          return bCal.compareTo(aCal);
        });
        break;
      
      case 'newest':
      default:
        // 預設已經是最新排序
        break;
    }

    return filtered;
  }

  Widget _buildStatsCard(List<Map<String, dynamic>> allCombos) {
    int totalCombos = allCombos.length;
    
    // ✅ 修正: 明確指定類型並處理空值
    double avgCalories = totalCombos > 0
        ? allCombos.fold<double>(0.0, (sum, combo) => sum + ((combo['totalCalories'] ?? 0) as num).toDouble()) / totalCombos
        : 0.0;
    
    // ✅ 修正: 明確指定類型並處理空值
    int totalFoods = allCombos.fold<int>(0, (sum, combo) => sum + ((combo['itemCount'] ?? 0) as int));

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '統計資訊',
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
                child: _buildStatBox(
                  '組合數量',
                  totalCombos.toString(),
                  '個',
                  const Color(0xFF4FACFE),
                  Icons.restaurant_menu,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  '平均熱量',
                  avgCalories.toInt().toString(),
                  '大卡',
                  AppColors.calories,
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  '總食物數',
                  totalFoods.toString(),
                  '項',
                  AppColors.success,
                  Icons.fastfood,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF4FACFE).withOpacity(0.1),
                        const Color(0xFF00F2FE).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 14,
                            color: const Color(0xFFFEAC5E),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '小提示',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '快速記錄',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildStatBox(String label, String value, String unit, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
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

  Widget _buildComboCard(Map<String, dynamic> combo, int index) {
    String comboName = combo['comboName'] ?? '未命名組合';
    String category = combo['category'] ?? '組合';
    int itemCount = combo['itemCount'] ?? 0;
    double totalCalories = (combo['totalCalories'] ?? 0).toDouble();
    double totalProtein = (combo['totalProtein'] ?? 0).toDouble();
    double totalCarbs = (combo['totalCarbs'] ?? 0).toDouble();
    double totalFat = (combo['totalFat'] ?? 0).toDouble();

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部資訊
          Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF4FACFE),
                      const Color(0xFF00F2FE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comboName,
                      style: const TextStyle(
                        fontSize: 17,
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
                            color: const Color(0xFF4FACFE).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4FACFE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.restaurant,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount 項食物',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 更多選項
              PopupMenuButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18, color: Color(0xFF4FACFE)),
                        const SizedBox(width: 12),
                        const Text('編輯'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateComboPage(existingCombo: combo),
                          ),
                        );
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.copy, size: 18, color: AppColors.success),
                        const SizedBox(width: 12),
                        const Text('複製'),
                      ],
                    ),
                    onTap: () => _duplicateCombo(combo['id']),
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 18, color: AppColors.error),
                        const SizedBox(width: 12),
                        const Text('刪除'),
                      ],
                    ),
                    onTap: () => _confirmDelete(combo),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 營養素資訊
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNutrientMini('熱量', totalCalories.toInt().toString(), '大卡', AppColors.calories),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildNutrientMini('蛋白質', totalProtein.toStringAsFixed(1), 'g', AppColors.protein),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildNutrientMini('碳水', totalCarbs.toStringAsFixed(1), 'g', AppColors.carbs),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildNutrientMini('脂肪', totalFat.toStringAsFixed(1), 'g', AppColors.fat),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 快速記錄按鈕
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddComboLogPage(combo: combo),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4FACFE).withOpacity(0.8),
                    const Color(0xFF00F2FE),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4FACFE).withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '快速記錄',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.2, end: 0, duration: 400.ms);
  }

  Widget _buildNutrientMini(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _duplicateCombo(String comboId) async {
    try {
      await _comboService.duplicateCombo(comboId);
      
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
                const Text('已複製組合!'),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> combo) {
    String comboName = combo['comboName'] ?? '此組合';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$comboName」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCombo(combo['id']);
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

  Future<void> _deleteCombo(String comboId) async {
    try {
      await _comboService.deleteCombo(comboId);
      
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
                const Text('已刪除組合'),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
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
                    const Color(0xFF4FACFE).withOpacity(0.1),
                    const Color(0xFF00F2FE).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 80,
                color: const Color(0xFF4FACFE).withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '尚無組合',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '建立你的第一個組合\n快速記錄常吃的餐點',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateComboPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                '建立組合',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FACFE),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}