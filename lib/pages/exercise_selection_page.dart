// lib/pages/workout/exercise_selection_page.dart
// 🎯 多選運動頁面 - FitFit 風格
// ✅ 修正導航流程：完成訓練 → 總結頁面 → 返回上一頁

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/wger_api_service.dart';
import 'workout/free_workout_execution_page.dart';
import 'workout/workout_summary_page.dart'; // 🔥 新增引入

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
  State<ExerciseSelectionPage> createState() =>
      _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState
    extends State<ExerciseSelectionPage> {
  final WgerApiService _wgerService = WgerApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  List<SelectedExercise> _selectedExercises = [];

  bool _isLoading = true;
  String _selectedCategory = '全部';

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

  // 🔥 修正：開始訓練 → 完成後先顯示總結 → 再返回
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

    // 1. 先進入訓練執行頁面
    final sessionId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => FreeWorkoutExecutionPage(
          exercises: exercises,
        ),
      ),
    );

    if (!mounted) return;

    // 2. 如果訓練完成（有返回 sessionId），顯示總結頁面
    if (sessionId != null && sessionId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryPage(sessionId: sessionId),
        ),
      );

      if (!mounted) return;

      // 3. 總結頁面關閉後，返回到上一頁（workout_log_page）
      // 傳遞 true 表示訓練已完成，上一頁需要刷新
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '選擇運動',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.planId != null)
              Text(
                '📋 計畫訓練',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_selectedExercises.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '已選 ${_selectedExercises.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          if (_selectedExercises.isNotEmpty) _buildSelectedArea(),
          if (!_isLoading) _buildResultCount(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                    ),
                  )
                : _filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadExercises,
                        color: const Color(0xFF6C63FF),
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
      bottomNavigationBar: _selectedExercises.isNotEmpty
          ? _buildBottomActionBar()
          : null,
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜尋運動名稱...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
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
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                        selectedColor: const Color(0xFF6C63FF),
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
    );
  }

  Widget _buildSelectedArea() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  '已選擇',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(width: 4),
                Text(
                  '長按拖曳排序',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
      width: 140,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _toggleSelection(selected.exercise),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selected.exercise.nameZhTw,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCount() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF6C63FF).withOpacity(0.05),
      child: Text(
        '找到 ${_filteredExercises.length} 個運動',
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final isSelected = _isSelected(exercise);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: const Color(0xFF6C63FF), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF6C63FF).withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSelection(exercise),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(exercise.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(exercise.category),
                    color: _getCategoryColor(exercise.category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nameZhTw,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(exercise.category)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: _getCategoryColor(exercise.category),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
              backgroundColor: const Color(0xFF6C63FF),
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

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
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
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '開始訓練 (${_selectedExercises.length} 個動作)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

class SelectedExercise {
  final Exercise exercise;
  int restSec;

  SelectedExercise({
    required this.exercise,
    this.restSec = 90,
  });
}