// lib/pages/nutrition/nutrition_log_list_page.dart
// Soft UI 風格的今日飲食記錄列表頁面 - 新增分析標籤頁

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/nutrition/soft_card.dart';
import 'nutrition_analysis_page.dart';

class NutritionLogListPage extends StatefulWidget {
  const NutritionLogListPage({super.key});

  @override
  State<NutritionLogListPage> createState() => _NutritionLogListPageState();
}

class _NutritionLogListPageState extends State<NutritionLogListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🎯 展開狀態管理
  final Set<String> _expandedCards = {};
  
  // 🎯 滾動控制器
  final ScrollController _scrollController = ScrollController();
  
  // 🎯 餐別對應的 GlobalKey (用於定位)
  final Map<String, GlobalKey> _mealKeys = {
    'breakfast': GlobalKey(),
    'lunch': GlobalKey(),
    'dinner': GlobalKey(),
    'snack': GlobalKey(),
    'latenight': GlobalKey(),
  };
  
  // 🎯 當前選中的餐別
  String _selectedMeal = '';
  
  // 🎯 當前選中的標籤頁 (0=記錄, 1=分析)
  int _currentTabIndex = 0;
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 🎨 Soft UI 風格的標籤按鈕
  Widget _buildSoftTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.95),
                    AppColors.primaryLight,
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎯 滾動到指定餐別
  void _scrollToMeal(String mealType) {
    setState(() {
      _selectedMeal = mealType;
    });

    final GlobalKey? key = _mealKeys[mealType];
    if (key?.currentContext != null) {
      final RenderBox renderBox = key!.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final targetPosition = position.dy + _scrollController.offset - 180;

      _scrollController.animateTo(
        targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = _auth.currentUser!.uid;
    String today = DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      backgroundColor: AppColors.background,
      
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(106),
        child: Container(
          color: AppColors.background,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 頂部:返回按鈕 + 標題
                  SizedBox(
                    height: 42,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
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
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            '飲食記錄',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Soft UI 風格的標籤切換
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
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
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSoftTab(
                            icon: Icons.receipt_long,
                            label: '記錄',
                            isSelected: _currentTabIndex == 0,
                            onTap: () {
                              setState(() {
                                _currentTabIndex = 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildSoftTab(
                            icon: Icons.analytics,
                            label: '分析',
                            isSelected: _currentTabIndex == 1,
                            onTap: () {
                              setState(() {
                                _currentTabIndex = 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // 📝 記錄標籤頁
          _buildRecordsTab(userId, today),
          
          // 📊 分析標籤頁
          NutritionAnalysisPage(userId: userId),
        ],
      ),
    );
  }

  /// 📝 記錄標籤頁
  Widget _buildRecordsTab(String userId, String today) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('nutritionLogs')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        Map<String, List<QueryDocumentSnapshot>> groupedLogs = {
          'breakfast': [],
          'lunch': [],
          'dinner': [],
          'snack': [],
          'latenight': [],
        };

        for (var doc in snapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String mealType = (data['mealType'] ?? 'snack').toLowerCase();
          
          if (mealType == 'late_night') {
            mealType = 'latenight';
          }
          
          if (groupedLogs.containsKey(mealType)) {
            groupedLogs[mealType]!.add(doc);
          }
        }

        Map<String, double> mealCalories = {
          'breakfast': 0,
          'lunch': 0,
          'dinner': 0,
          'snack': 0,
          'latenight': 0,
        };

        for (var entry in groupedLogs.entries) {
          for (var doc in entry.value) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            mealCalories[entry.key] = (mealCalories[entry.key] ?? 0) + (data['calories'] ?? 0);
          }
        }

        double totalCalories = 0;
        double totalProtein = 0;
        double totalCarbs = 0;
        double totalFat = 0;

        for (var doc in snapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          totalCalories += (data['calories'] ?? 0);
          totalProtein += (data['protein'] ?? 0);
          totalCarbs += (data['carbs'] ?? 0);
          totalFat += (data['fat'] ?? 0);
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDailySummary(
                    totalCalories,
                    totalProtein,
                    totalCarbs,
                    totalFat,
                  ),
                  
                  const SizedBox(height: 24),

                  if (groupedLogs['breakfast']!.isNotEmpty)
                    Container(
                      key: _mealKeys['breakfast'],
                      child: _buildMealSection('早餐', 'breakfast', groupedLogs['breakfast']!),
                    ),
                  
                  if (groupedLogs['lunch']!.isNotEmpty)
                    Container(
                      key: _mealKeys['lunch'],
                      child: _buildMealSection('午餐', 'lunch', groupedLogs['lunch']!),
                    ),
                  
                  if (groupedLogs['dinner']!.isNotEmpty)
                    Container(
                      key: _mealKeys['dinner'],
                      child: _buildMealSection('晚餐', 'dinner', groupedLogs['dinner']!),
                    ),
                  
                  if (groupedLogs['snack']!.isNotEmpty)
                    Container(
                      key: _mealKeys['snack'],
                      child: _buildMealSection('點心', 'snack', groupedLogs['snack']!),
                    ),
                  
                  if (groupedLogs['latenight']!.isNotEmpty)
                    Container(
                      key: _mealKeys['latenight'],
                      child: _buildMealSection('宵夜', 'latenight', groupedLogs['latenight']!),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailySummary(
    double calories,
    double protein,
    double carbs,
    double fat,
  ) {
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
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
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
                '今日攝取總計',
                style: TextStyle(
                  fontSize: 18,
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
                  calories.toInt().toString(),
                  '大卡',
                  AppColors.calories,
                  Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '蛋白質',
                  protein.toStringAsFixed(1),
                  'g',
                  AppColors.protein,
                  Icons.fitness_center,
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
                  carbs.toStringAsFixed(1),
                  'g',
                  AppColors.carbs,
                  Icons.grain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNutrientBox(
                  '脂肪',
                  fat.toStringAsFixed(1),
                  'g',
                  AppColors.fat,
                  Icons.water_drop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBox(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
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
            style: TextStyle(
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
                style: TextStyle(
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

  Widget _buildMealSection(
    String title,
    String mealType,
    List<QueryDocumentSnapshot> logs,
  ) {
    if (logs.isEmpty) return const SizedBox.shrink();

    double totalCalories = logs.fold(0, (sum, doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return sum + (data['calories'] ?? 0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                AppColors.getMealEmoji(mealType),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.getMealLightColor(mealType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalCalories.toInt()} 大卡',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getMealColor(mealType),
                  ),
                ),
              ),
            ],
          ),
        ),

        ...logs.map((doc) => _buildFoodLogCard(doc, mealType)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFoodLogCard(QueryDocumentSnapshot doc, String mealType) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;
    bool isExpanded = _expandedCards.contains(docId);
    
    String foodName = data['foodName'] ?? '未知食物';
    double servings = (data['servings'] ?? 1).toDouble();
    String servingSize = data['servingSize'] ?? '份';
    int calories = (data['calories'] ?? 0).toInt();
    double protein = (data['protein'] ?? 0).toDouble();
    double carbs = (data['carbs'] ?? 0).toDouble();
    double fat = (data['fat'] ?? 0).toDouble();
    
    double saturatedFat = (data['saturatedFat'] ?? 0).toDouble();
    double transFat = (data['transFat'] ?? 0).toDouble();
    double fiber = (data['fiber'] ?? 0).toDouble();
    double sugar = (data['sugar'] ?? 0).toDouble();
    double sodium = (data['sodium'] ?? 0).toDouble();
    double cholesterol = (data['cholesterol'] ?? 0).toDouble();
    
    String timeStr = _formatTime(data['createdAt']);
    
    bool hasDetails = protein > 0 || carbs > 0 || fat > 0 || 
                      saturatedFat > 0 || transFat > 0 || fiber > 0 || 
                      sugar > 0 || sodium > 0 || cholesterol > 0;

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.getMealColor(mealType),
                  borderRadius: BorderRadius.circular(2),
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
                            foodName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
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
                            '${servings.toStringAsFixed(1)} $servingSize',
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
                          '$calories 大卡',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        _buildMiniNutrient('P', protein, AppColors.protein),
                        const SizedBox(width: 8),
                        _buildMiniNutrient('C', carbs, AppColors.carbs),
                        const SizedBox(width: 8),
                        _buildMiniNutrient('F', fat, AppColors.fat),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => _showEditDialog(doc),
              ),

              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(doc),
              ),
            ],
          ),
          
          if (hasDetails)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCards.remove(docId);
                  } else {
                    _expandedCards.add(docId);
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isExpanded 
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExpanded
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.primary.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpanded ? Icons.visibility : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isExpanded ? '隱藏詳細營養素' : '查看詳細營養素',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.background,
                    AppColors.primary.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
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
                        child: Icon(
                          Icons.science_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '詳細營養成分',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildNutrientRow('蛋白質', protein, 'g', AppColors.protein, Icons.fitness_center),
                  _buildNutrientRow('碳水化合物', carbs, 'g', AppColors.carbs, Icons.grain),
                  _buildNutrientRow('脂肪', fat, 'g', AppColors.fat, Icons.water_drop),
                  
                  if (saturatedFat > 0 || transFat > 0) ...[
                    const SizedBox(height: 8),
                    Divider(color: AppColors.divider.withOpacity(0.5)),
                    const SizedBox(height: 8),
                  ],
                  
                  if (saturatedFat > 0)
                    _buildNutrientRow('飽和脂肪', saturatedFat, 'g', const Color(0xFFE57373), Icons.opacity),
                  
                  if (transFat > 0)
                    _buildNutrientRow('反式脂肪', transFat, 'g', const Color(0xFFEF5350), Icons.warning_amber_rounded),
                  
                  if (fiber > 0 || sugar > 0 || sodium > 0 || cholesterol > 0) ...[
                    const SizedBox(height: 8),
                    Divider(color: AppColors.divider.withOpacity(0.5)),
                    const SizedBox(height: 8),
                  ],
                  
                  if (fiber > 0)
                    _buildNutrientRow('膳食纖維', fiber, 'g', const Color(0xFF66BB6A), Icons.spa),
                  
                  if (sugar > 0)
                    _buildNutrientRow('糖', sugar, 'g', const Color(0xFFFF9800), Icons.cake),
                  
                  if (sodium > 0)
                    _buildNutrientRow('鈉', sodium, 'mg', const Color(0xFF42A5F5), Icons.grain),
                  
                  if (cholesterol > 0)
                    _buildNutrientRow('膽固醇', cholesterol, 'mg', const Color(0xFFAB47BC), Icons.favorite_border),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    String foodName = data['foodName'] ?? '未知食物';
    double originalServings = (data['servings'] ?? 1).toDouble();
    String servingSize = data['servingSize'] ?? '份';
    String originalMealType = (data['mealType'] ?? 'breakfast').toLowerCase();
    
    double perServingCalories = (data['calories'] ?? 0) / originalServings;
    double perServingProtein = (data['protein'] ?? 0) / originalServings;
    double perServingCarbs = (data['carbs'] ?? 0) / originalServings;
    double perServingFat = (data['fat'] ?? 0) / originalServings;
    
    double editedServings = originalServings;
    String editedMealType = originalMealType;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int newCalories = (perServingCalories * editedServings).round();
          double newProtein = perServingProtein * editedServings;
          double newCarbs = perServingCarbs * editedServings;
          double newFat = perServingFat * editedServings;
          
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDark,
                    offset: const Offset(8, 8),
                    blurRadius: 24,
                  ),
                  BoxShadow(
                    color: AppColors.shadowLight,
                    offset: const Offset(-8, -8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.8),
                                AppColors.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '快速編輯',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.restaurant,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              foodName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    const Text(
                      '餐別',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMealTypeChipForDialog('breakfast', '早餐', editedMealType, (type) => setDialogState(() => editedMealType = type)),
                        _buildMealTypeChipForDialog('lunch', '午餐', editedMealType, (type) => setDialogState(() => editedMealType = type)),
                        _buildMealTypeChipForDialog('dinner', '晚餐', editedMealType, (type) => setDialogState(() => editedMealType = type)),
                        _buildMealTypeChipForDialog('snack', '點心', editedMealType, (type) => setDialogState(() => editedMealType = type)),
                        _buildMealTypeChipForDialog('latenight', '宵夜', editedMealType, (type) => setDialogState(() => editedMealType = type)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    const Text(
                      '份量',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        _buildServingButton(Icons.remove, editedServings > 0.5, () => setDialogState(() => editedServings -= 0.5)),
                        
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 6,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: editedServings,
                                  min: 0.5,
                                  max: 5.0,
                                  divisions: 9,
                                  onChanged: (value) => setDialogState(() => editedServings = value),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${editedServings.toStringAsFixed(1)} $servingSize',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        _buildServingButton(Icons.add, editedServings < 5.0, () => setDialogState(() => editedServings += 0.5)),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.08),
                            AppColors.primaryLight.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.preview, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '修改後營養素',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildNutrientPreview('熱量', newCalories.toString(), '大卡', AppColors.calories)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildNutrientPreview('蛋白質', newProtein.toStringAsFixed(1), 'g', AppColors.protein)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildNutrientPreview('碳水', newCarbs.toStringAsFixed(1), 'g', AppColors.carbs)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildNutrientPreview('脂肪', newFat.toStringAsFixed(1), 'g', AppColors.fat)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              '取消',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _updateLog(doc, editedServings, editedMealType, newCalories.toDouble(), newProtein, newCarbs, newFat);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text(
                              '儲存修改',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealTypeChipForDialog(String mealType, String label, String selectedMealType, Function(String) onTap) {
    final bool isSelected = selectedMealType == mealType;
    
    return GestureDetector(
      onTap: () => onTap(mealType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getMealColor(mealType) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.getMealColor(mealType) : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppColors.getMealEmoji(mealType), style: const TextStyle(fontSize: 14)),
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

  Widget _buildServingButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.cardBackground : AppColors.background,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(color: AppColors.shadowDark, offset: const Offset(3, 3), blurRadius: 6),
                  BoxShadow(color: AppColors.shadowLight, offset: const Offset(-3, -3), blurRadius: 6),
                ]
              : null,
        ),
        child: Icon(icon, color: enabled ? AppColors.primary : AppColors.textTertiary, size: 20),
      ),
    );
  }

  Widget _buildNutrientPreview(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateLog(
    QueryDocumentSnapshot doc,
    double newServings,
    String newMealType,
    double newCalories,
    double newProtein,
    double newCarbs,
    double newFat,
  ) async {
    try {
      Map<String, dynamic> oldData = doc.data() as Map<String, dynamic>;
      String userId = _auth.currentUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];

      double caloriesDiff = newCalories - (oldData['calories'] ?? 0);
      double proteinDiff = newProtein - (oldData['protein'] ?? 0);
      double carbsDiff = newCarbs - (oldData['carbs'] ?? 0);
      double fatDiff = newFat - (oldData['fat'] ?? 0);

      await doc.reference.update({
        'servings': newServings,
        'mealType': newMealType,
        'calories': newCalories,
        'protein': newProtein,
        'carbs': newCarbs,
        'fat': newFat,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DocumentReference summaryRef = _firestore.collection('users').doc(userId).collection('dailySummary').doc(today);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(summaryRef);

        if (snapshot.exists) {
          Map<String, dynamic> summaryData = snapshot.data() as Map<String, dynamic>;
          
          transaction.update(summaryRef, {
            'totalCalories': (summaryData['totalCalories'] ?? 0) + caloriesDiff,
            'totalProtein': (summaryData['totalProtein'] ?? 0) + proteinDiff,
            'totalCarbs': (summaryData['totalCarbs'] ?? 0) + carbsDiff,
            'totalFat': (summaryData['totalFat'] ?? 0) + fatDiff,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

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
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('已更新記錄'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('更新記錄失敗: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失敗: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Widget _buildMiniNutrient(String label, double value, Color color) {
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
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(String label, double value, String unit, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '--:--';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return '--:--';
      }
      
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return '--:--';
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                Icons.restaurant_menu,
                size: 80,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '今日尚無飲食記錄',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '開始記錄你的飲食\n養成健康的飲食習慣',
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

  void _confirmDelete(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String foodName = data['foodName'] ?? '此記錄';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認刪除'),
        content: Text('確定要刪除「$foodName」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLog(doc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(QueryDocumentSnapshot doc) async {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userId = _auth.currentUser!.uid;
      String today = DateTime.now().toIso8601String().split('T')[0];

      await doc.reference.delete();

      DocumentReference summaryRef = _firestore.collection('users').doc(userId).collection('dailySummary').doc(today);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(summaryRef);

        if (snapshot.exists) {
          Map<String, dynamic> summaryData = snapshot.data() as Map<String, dynamic>;
          
          transaction.update(summaryRef, {
            'totalCalories': (summaryData['totalCalories'] ?? 0) - (data['calories'] ?? 0),
            'totalProtein': (summaryData['totalProtein'] ?? 0) - (data['protein'] ?? 0),
            'totalCarbs': (summaryData['totalCarbs'] ?? 0) - (data['carbs'] ?? 0),
            'totalFat': (summaryData['totalFat'] ?? 0) - (data['fat'] ?? 0),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

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
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('已刪除記錄'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('刪除記錄失敗: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}