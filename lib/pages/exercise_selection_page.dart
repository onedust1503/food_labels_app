// lib/pages/workout/exercise_selection_page.dart
// 🎯 運動選擇頁面 - 整合 WGER API + 優化搜尋篩選
// ✅ 新增 planId 支援，用於追蹤訓練計畫

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/wger_api_service.dart';
import 'workout/workout_execution_page.dart';

class ExerciseSelectionPage extends StatefulWidget {
  final bool isCoach;
  final String? traineeId;
  final String? planId;  // ✅ 新增：訓練計畫 ID

  const ExerciseSelectionPage({
    super.key,
    required this.isCoach,
    this.traineeId,
    this.planId,  // ✅ 新增
  });

  @override
  State<ExerciseSelectionPage> createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final WgerApiService _wgerService = WgerApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  bool _isLoading = true;
  String _selectedCategory = '全部';

  // 可用的運動分類
  final List<String> _categories = [
    '全部',
    '胸部',
    '背部',
    '腿部',
    '肩膀',
    '手臂',
    '腹肌',
    '有氧',
  ];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_filterExercises);
    
    // ✅ 調試：顯示是否為計畫訓練
    if (kDebugMode && widget.planId != null) {
      debugPrint('📋 運動選擇（計畫模式）: planId = ${widget.planId}');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 載入運動列表
  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);

    try {
      final exercises = await _wgerService.getExercises(limit: 100);
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _filteredExercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入運動失敗: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('載入運動失敗，請檢查網路連線');
      }
    }
  }

  /// 篩選運動
  void _filterExercises() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredExercises = _allExercises.where((exercise) {
        // 搜尋條件：名稱匹配
        final matchesSearch = query.isEmpty ||
            exercise.nameZhTw.toLowerCase().contains(query) ||
            exercise.name.toLowerCase().contains(query);

        // 分類條件
        final matchesCategory =
            _selectedCategory == '全部' || exercise.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  /// 導航到訓練執行頁面
  void _navigateToWorkout(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutExecutionPage(
          exercise: exercise,
          isCoach: widget.isCoach,
          traineeId: widget.traineeId,
          planId: widget.planId,  // ✅ 新增：傳遞 planId
        ),
      ),
    ).then((completed) {
      if (completed == true && mounted) {
        // 訓練完成後返回
        Navigator.pop(context, true);
      }
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '選擇運動',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            // ✅ 新增：顯示是否為計畫訓練
            if (widget.planId != null)
              Text(
                '📋 計畫訓練',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ✅ 新增：計畫訓練提示橫幅
          if (widget.planId != null) _buildPlanModeBanner(),

          // 搜尋和篩選區域
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 搜尋欄
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜尋運動名稱...',
                        prefixIcon: const Icon(Icons.search, color: Colors.green),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterExercises();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 分類篩選
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = category == _selectedCategory;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                  _filterExercises();
                                });
                              },
                              selectedColor: Colors.green,
                              backgroundColor: Colors.grey.shade200,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 結果數量
          if (!_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.green.shade50,
              child: Text(
                '找到 ${_filteredExercises.length} 個運動',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),

          // 運動列表
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : _filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadExercises,
                        color: Colors.green,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _filteredExercises[index];
                            return _buildExerciseCard(exercise);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// ✅ 新增：計畫訓練提示橫幅
  Widget _buildPlanModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade500],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.event_note,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '此次訓練將計入計畫進度',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
  }

  /// 運動卡片
  Widget _buildExerciseCard(Exercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToWorkout(exercise),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 圖示
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(exercise.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(exercise.category),
                    color: _getCategoryColor(exercise.category),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // 資訊
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nameZhTw,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // 分類標籤
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(exercise.category)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getCategoryColor(exercise.category),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          
                          // 肌肉群
                          if (exercise.muscles.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                exercise.muscles.take(2).join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 箭頭
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 空狀態
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '找不到符合的運動',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '試試調整搜尋條件或分類篩選',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedCategory = '全部';
                _filterExercises();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重置篩選'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 獲取分類圖示
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '胸部':
        return Icons.fitness_center;
      case '背部':
        return Icons.beach_access;
      case '腿部':
        return Icons.directions_run;
      case '肩膀':
        return Icons.accessibility_new;
      case '手臂':
        return Icons.front_hand;
      case '腹肌':
        return Icons.boy;
      case '有氧':
        return Icons.directions_bike;
      default:
        return Icons.sports_gymnastics;
    }
  }

  /// 獲取分類顏色
  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部':
        return Colors.red;
      case '背部':
        return Colors.blue;
      case '腿部':
        return Colors.orange;
      case '肩膀':
        return Colors.purple;
      case '手臂':
        return Colors.green;
      case '腹肌':
        return Colors.teal;
      case '有氧':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}