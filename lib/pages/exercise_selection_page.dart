// lib/pages/workout/exercise_selection_page.dart
// 多選運動頁面 - Soft UI 清新綠風格
// 修正：顏色更明亮清新、UI 溢出問題

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/wger_api_service.dart';
import 'workout/free_workout_execution_page.dart';
import 'workout/workout_summary_page.dart';

class ExerciseSelectionPage extends StatefulWidget {
  final bool isCoach;
  final String? traineeId;
  final String? planId;

  const ExerciseSelectionPage({
    super.key,
    required this.isCoach,
    this.traineeId,
    this.planId,
  });

  @override
  State<ExerciseSelectionPage> createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final WgerApiService _wgerService = WgerApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  List<SelectedExercise> _selectedExercises = [];

  bool _isLoading = true;
  String _selectedCategory = '全部';

  // ===== 清爽淡雅 Soft UI 配色（參考現代極簡風格）=====
  // 主色：淡薄荷綠（不會太綠，很清爽）
  static const Color _primaryColor = Color(0xFF81C784);      // 薄荷綠（主按鈕）
  static const Color _primaryLight = Color(0xFFE8F5E9);      // 超淡綠（選中背景）
  static const Color _primarySoft = Color(0xFFC8E6C9);       // 淡綠（色塊）
  static const Color _primaryDark = Color(0xFF66BB6A);       // 深綠（漸層用）
  
  // 基礎色 - 幾乎純白
  static const Color _backgroundColor = Color(0xFFFAFBFC);   // 極淺灰白背景
  static const Color _cardColor = Color(0xFFFFFFFF);         // 純白卡片
  static const Color _surfaceColor = Color(0xFFF5F7F6);      // 淺灰表面
  
  // 文字色
  static const Color _textPrimary = Color(0xFF2D3436);       // 深灰文字
  static const Color _textSecondary = Color(0xFF8E9AAF);     // 柔和灰文字
  
  // Soft UI 陰影 - 更柔和
  static List<BoxShadow> get _softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get _softShadowSmall => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  void _filterExercises() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredExercises = _allExercises.where((exercise) {
        final matchesSearch = query.isEmpty ||
            exercise.nameZhTw.toLowerCase().contains(query) ||
            exercise.name.toLowerCase().contains(query);

        final matchesCategory =
            _selectedCategory == '全部' || exercise.category == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _toggleSelection(Exercise exercise) {
    setState(() {
      final index = _selectedExercises
          .indexWhere((e) => e.exercise.id == exercise.id);

      if (index >= 0) {
        _selectedExercises.removeAt(index);
      } else {
        _selectedExercises.add(SelectedExercise(
          exercise: exercise,
          restSec: 90,
        ));
      }
    });
  }

  bool _isSelected(Exercise exercise) {
    return _selectedExercises.any((e) => e.exercise.id == exercise.id);
  }

  Future<void> _startWorkout() async {
    if (_selectedExercises.isEmpty) {
      _showSnackBar('請至少選擇一個動作');
      return;
    }

    final exercises = _selectedExercises.map((selected) {
      return {
        'id': selected.exercise.id,
        'name': selected.exercise.nameZhTw,
        'category': selected.exercise.category,
        'muscles': selected.exercise.muscles,
        'restSec': selected.restSec,
      };
    }).toList();

    final sessionId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FreeWorkoutExecutionPage(
          exercises: exercises,
        ),
      ),
    );

    if (!mounted) return;

    if (sessionId != null && sessionId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          if (_selectedExercises.isNotEmpty) _buildSelectedArea(),
          if (!_isLoading) _buildResultCount(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 3,
                    ),
                  )
                : _filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadExercises,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
      bottomNavigationBar: _selectedExercises.isNotEmpty
          ? _buildBottomActionBar()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '選擇運動',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      backgroundColor: _cardColor,
      foregroundColor: _textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      actions: [
        if (_selectedExercises.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '已選 ${_selectedExercises.length}',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: _softShadowSmall,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            // 搜尋框 - 大圓角、淡色
            Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜尋運動名稱...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 20, color: _textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _filterExercises();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            
            // 分類標籤 - 藥丸形狀、淡色
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                          _filterExercises();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? _primarySoft : _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _primaryColor.withOpacity(0.3) : _surfaceColor,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? _primaryDark : _textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedArea() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        color: _primaryLight.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: _primarySoft.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  '已選擇',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 14,
                  color: _primaryColor.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '長按拖曳排序',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _selectedExercises.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _selectedExercises.removeAt(oldIndex);
                  _selectedExercises.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final selected = _selectedExercises[index];
                return _buildSelectedChip(selected, index, key: ValueKey(selected.exercise.id));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChip(SelectedExercise selected, int index, {required Key key}) {
    return Container(
      key: key,
      width: 120,
      height: 52,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primarySoft, width: 1.5),
        boxShadow: _softShadowSmall,
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              selected.exercise.nameZhTw,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _toggleSelection(selected.exercise),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: _textSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCount() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _surfaceColor,
      child: Text(
        '找到 ${_filteredExercises.length} 個運動',
        style: TextStyle(
          color: _textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final isSelected = _isSelected(exercise);
    final categoryColor = _getCategoryColor(exercise.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: _primarySoft, width: 2)
            : null,
        boxShadow: _softShadowSmall,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSelection(exercise),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 選擇框 - 更圓潤
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? _primarySoft : _surfaceColor,
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: _primaryColor,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                
                // 圖標 - 淡色背景塊
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getCategoryIcon(exercise.category),
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                
                // 內容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nameZhTw,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          exercise.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 44,
              color: _textSecondary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '找不到符合的運動',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _searchController.clear();
                _selectedCategory = '全部';
                _filterExercises();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: _primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '重置篩選',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '可在訓練中新增動作或調整組數',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _startWorkout,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      '開始訓練 (${_selectedExercises.length} 個動作)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '胸部':
        return Icons.fitness_center;
      case '背部':
        return Icons.sports_gymnastics;
      case '腿部':
        return Icons.directions_run;
      case '肩膀':
        return Icons.accessibility_new;
      case '手臂':
        return Icons.front_hand;
      case '腹肌':
        return Icons.sports_martial_arts;
      case '有氧':
        return Icons.directions_bike;
      default:
        return Icons.sports;
    }
  }

  Color _getCategoryColor(String category) {
    // 柔和淡雅的分類色彩（參考參考圖的淡色風格）
    switch (category) {
      case '胸部':
        return const Color(0xFFE57373);  // 淡紅
      case '背部':
        return const Color(0xFF81C784);  // 淡綠
      case '腿部':
        return const Color(0xFFFFB74D);  // 淡橘
      case '肩膀':
        return const Color(0xFFBA68C8);  // 淡紫
      case '手臂':
        return const Color(0xFF4FC3F7);  // 淡青
      case '腹肌':
        return const Color(0xFF64B5F6);  // 淡藍
      case '有氧':
        return const Color(0xFFF06292);  // 淡粉
      default:
        return const Color(0xFF90A4AE);  // 淡灰
    }
  }
}

class SelectedExercise {
  final Exercise exercise;
  int restSec;

  SelectedExercise({
    required this.exercise,
    this.restSec = 90,
  });
}