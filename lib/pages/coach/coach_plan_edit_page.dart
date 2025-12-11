// lib/pages/coach/coach_plan_edit_page.dart
// 🎯 教練端計畫編輯頁 v1.1
// ✨ 完整客製化調整學員訓練計畫
// ✅ v1.0: 基本編輯功能
// ✅ v1.1: 修正 UI 適配問題（2x2 網格）
// ✅ v1.1: 新增版本控制，記錄修改歷史
// ✅ v1.1: 改善變更摘要，讓學員清楚知道改了什麼

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';

class CoachPlanEditPage extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final String traineeId;
  final String traineeName;

  const CoachPlanEditPage({
    super.key,
    required this.planId,
    required this.planData,
    required this.traineeId,
    required this.traineeName,
  });

  @override
  State<CoachPlanEditPage> createState() => _CoachPlanEditPageState();
}

class _CoachPlanEditPageState extends State<CoachPlanEditPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // 原始數據（用於比較變更）
  late List<Map<String, dynamic>> _originalDays;
  
  // 編輯中的計畫數據（深拷貝）
  late List<Map<String, dynamic>> _editingDays;
  
  // 是否有修改
  bool _hasChanges = false;
  bool _isSaving = false;

  // 調整說明
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initEditingData();
    _tabController = TabController(length: _editingDays.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 初始化編輯數據（深拷貝）
  void _initEditingData() {
    final daysData = widget.planData['days'];
    _originalDays = [];
    _editingDays = [];

    if (daysData is List) {
      for (var day in daysData) {
        _originalDays.add(_deepCopyDay(day as Map));
        _editingDays.add(_deepCopyDay(day as Map));
      }
    } else if (daysData is Map) {
      for (var day in (daysData as Map).values) {
        _originalDays.add(_deepCopyDay(day as Map));
        _editingDays.add(_deepCopyDay(day as Map));
      }
    }
  }

  Map<String, dynamic> _deepCopyDay(Map day) {
    final copied = Map<String, dynamic>.from(day);
    if (copied['exercises'] is List) {
      copied['exercises'] = (copied['exercises'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return copied;
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '編輯計畫',
                style: AppTextStyles.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.traineeName,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.secondaryGradient,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _onWillPop().then((canPop) {
              if (canPop) Navigator.pop(context);
            }),
          ),
          actions: [
            if (_hasChanges)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      '未儲存',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _hasChanges && !_isSaving ? _showSaveDialog : null,
              tooltip: '儲存變更',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
            tabs: _editingDays.map((day) {
              final dayOfWeek = day['dayOfWeek']?.toString() ?? '未設定';
              return Tab(text: dayOfWeek);
            }).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _editingDays.asMap().entries.map((entry) {
            return _buildDayEditor(entry.key, entry.value);
          }).toList(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddExerciseDialog(_tabController.index),
          backgroundColor: AppColors.coach,
          icon: const Icon(Icons.add),
          label: const Text('新增動作'),
        ),
      ),
    );
  }

  /// 返回確認
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('放棄變更？'),
          ],
        ),
        content: const Text('您有未儲存的變更，確定要離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('繼續編輯', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('放棄變更'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 單日編輯器
  Widget _buildDayEditor(int dayIndex, Map<String, dynamic> day) {
    final exercises = day['exercises'] as List? ?? [];

    return Column(
      children: [
        // 訓練日資訊
        _buildDayInfoBar(dayIndex, day),
        
        // 動作列表
        Expanded(
          child: exercises.isEmpty
              ? _buildEmptyExercises(dayIndex)
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    _reorderExercise(dayIndex, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final exercise = exercises[index] as Map<String, dynamic>;
                    return _buildExerciseCard(
                      key: ValueKey('$dayIndex-$index-${exercise['name']}'),
                      dayIndex: dayIndex,
                      exerciseIndex: index,
                      exercise: exercise,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDayInfoBar(int dayIndex, Map<String, dynamic> day) {
    final exercises = day['exercises'] as List? ?? [];
    final totalSets = exercises.fold<int>(0, (sum, e) {
      final ex = e as Map<String, dynamic>;
      return sum + (ex['sets'] as int? ?? 0);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: AppColors.coach, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exercises.length} 個動作',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '共 $totalSets 組',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 快速調整按鈕
          _buildQuickAdjustButton(
            icon: Icons.add,
            label: '+1組',
            color: AppColors.success,
            onTap: () => _batchAdjustSets(dayIndex, 1),
          ),
          const SizedBox(width: 8),
          _buildQuickAdjustButton(
            icon: Icons.remove,
            label: '-1組',
            color: AppColors.warning,
            onTap: () => _batchAdjustSets(dayIndex, -1),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdjustButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExercises(int dayIndex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center,
              size: 48,
              color: AppColors.coach.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '尚無動作',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊下方按鈕新增動作',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  /// 動作卡片 - v1.1 修正：使用 2x2 網格佈局
  Widget _buildExerciseCard({
    required Key key,
    required int dayIndex,
    required int exerciseIndex,
    required Map<String, dynamic> exercise,
  }) {
    final name = exercise['name'] ?? '未命名';
    final type = exercise['type']?.toString() ?? '';
    final sets = exercise['sets'] ?? 3;
    final reps = exercise['reps'] ?? 12;
    final weight = exercise['weight'];
    final restSeconds = exercise['restSeconds'] ?? 60;
    final categoryColor = _getCategoryColor(type);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withOpacity(0.2)),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          // 標題行
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // 拖曳手把
                ReorderableDragStartListener(
                  index: exerciseIndex,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.drag_indicator,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ),
                ),
                // 序號
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${exerciseIndex + 1}',
                      style: AppTextStyles.caption.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 名稱
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (type.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type,
                            style: AppTextStyles.caption.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 替換按鈕
                IconButton(
                  icon: Icon(Icons.swap_horiz, color: AppColors.info, size: 20),
                  onPressed: () => _showReplaceExerciseDialog(dayIndex, exerciseIndex, exercise),
                  tooltip: '替換動作',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                // 刪除按鈕
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDeleteExercise(dayIndex, exerciseIndex),
                  tooltip: '刪除動作',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 🔥 v1.1: 參數編輯區 - 改用 2x2 網格
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8, // 寬高比
              children: [
                // 組數
                _buildParamEditor(
                  label: '組數',
                  value: sets,
                  unit: '組',
                  color: AppColors.primary,
                  onChanged: (newValue) {
                    _updateExerciseParam(dayIndex, exerciseIndex, 'sets', newValue);
                  },
                  min: 1,
                  max: 10,
                ),
                // 次數
                _buildParamEditor(
                  label: '次數',
                  value: reps,
                  unit: '次',
                  color: AppColors.coach,
                  onChanged: (newValue) {
                    _updateExerciseParam(dayIndex, exerciseIndex, 'reps', newValue);
                  },
                  min: 1,
                  max: 30,
                  step: 1,
                ),
                // 重量
                _buildParamEditor(
                  label: '重量',
                  value: weight ?? 0,
                  unit: 'kg',
                  color: AppColors.warning,
                  onChanged: (newValue) {
                    _updateExerciseParam(dayIndex, exerciseIndex, 'weight', newValue == 0 ? null : newValue);
                  },
                  min: 0,
                  max: 200,
                  step: 2.5,
                  allowDecimal: true,
                ),
                // 休息時間
                _buildParamEditor(
                  label: '休息',
                  value: restSeconds,
                  unit: '秒',
                  color: AppColors.info,
                  onChanged: (newValue) {
                    _updateExerciseParam(dayIndex, exerciseIndex, 'restSeconds', newValue);
                  },
                  min: 15,
                  max: 180,
                  step: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔥 v1.1: 重新設計的參數編輯器 - 更緊湊
  Widget _buildParamEditor({
    required String label,
    required num value,
    required String unit,
    required Color color,
    required Function(num) onChanged,
    required num min,
    required num max,
    num step = 1,
    bool allowDecimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 標籤
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          // 數值控制
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 減少按鈕
              _buildCircleButton(
                icon: Icons.remove,
                color: color,
                enabled: value > min,
                onTap: () => onChanged(allowDecimal 
                    ? (value - step).clamp(min, max)
                    : ((value - step) as num).clamp(min, max).toInt()),
              ),
              // 數值
              Expanded(
                child: Center(
                  child: Text(
                    allowDecimal && value is double && value != value.toInt()
                        ? value.toStringAsFixed(1)
                        : value.toInt().toString(),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              // 增加按鈕
              _buildCircleButton(
                icon: Icons.add,
                color: color,
                enabled: value < max,
                onTap: () => onChanged(allowDecimal 
                    ? (value + step).clamp(min, max)
                    : ((value + step) as num).clamp(min, max).toInt()),
              ),
            ],
          ),
          // 單位
          Text(
            unit,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? color : AppColors.textTertiary.withOpacity(0.3),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.textSecondary;
    }
  }

  // ===========================================================
  // 🔧 編輯操作
  // ===========================================================

  void _updateExerciseParam(int dayIndex, int exerciseIndex, String key, dynamic value) {
    setState(() {
      final exercises = _editingDays[dayIndex]['exercises'] as List;
      final exercise = exercises[exerciseIndex] as Map<String, dynamic>;
      exercise[key] = value;
      _markChanged();
    });
  }

  void _batchAdjustSets(int dayIndex, int delta) {
    setState(() {
      final exercises = _editingDays[dayIndex]['exercises'] as List;
      for (var exercise in exercises) {
        final ex = exercise as Map<String, dynamic>;
        final currentSets = ex['sets'] as int? ?? 3;
        final newSets = (currentSets + delta).clamp(1, 10);
        ex['sets'] = newSets;
      }
      _markChanged();
    });
    
    _showSnackBar(delta > 0 ? '所有動作 +$delta 組' : '所有動作 $delta 組');
  }

  void _reorderExercise(int dayIndex, int oldIndex, int newIndex) {
    setState(() {
      final exercises = _editingDays[dayIndex]['exercises'] as List;
      if (newIndex > oldIndex) newIndex--;
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
      _markChanged();
    });
  }

  void _confirmDeleteExercise(int dayIndex, int exerciseIndex) async {
    final exercises = _editingDays[dayIndex]['exercises'] as List;
    final exercise = exercises[exerciseIndex] as Map<String, dynamic>;
    final name = exercise['name'] ?? '未命名';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('刪除動作'),
          ],
        ),
        content: Text('確定要刪除「$name」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        exercises.removeAt(exerciseIndex);
        _markChanged();
      });
      _showSnackBar('已刪除「$name」');
    }
  }

  void _showAddExerciseDialog(int dayIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExercisePickerSheet(
        title: '新增動作',
        onSelected: (exercise) {
          setState(() {
            final exercises = _editingDays[dayIndex]['exercises'] as List;
            exercises.add(exercise);
            _markChanged();
          });
          Navigator.pop(context);
          _showSnackBar('已新增「${exercise['name']}」');
        },
      ),
    );
  }

  void _showReplaceExerciseDialog(
    int dayIndex, 
    int exerciseIndex, 
    Map<String, dynamic> currentExercise,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExercisePickerSheet(
        title: '替換動作',
        currentExercise: currentExercise,
        onSelected: (newExercise) {
          // 保留原本的組數、次數等設定
          newExercise['sets'] = currentExercise['sets'] ?? 3;
          newExercise['reps'] = currentExercise['reps'] ?? 12;
          newExercise['weight'] = currentExercise['weight'];
          newExercise['restSeconds'] = currentExercise['restSeconds'] ?? 60;
          
          setState(() {
            final exercises = _editingDays[dayIndex]['exercises'] as List;
            exercises[exerciseIndex] = newExercise;
            _markChanged();
          });
          Navigator.pop(context);
          _showSnackBar('已替換為「${newExercise['name']}」');
        },
      ),
    );
  }

  // ===========================================================
  // 💾 儲存 - v1.1: 新增版本控制 + 變更摘要
  // ===========================================================

  /// 生成變更摘要
  String _generateChangeSummary() {
    final changes = <String>[];
    
    for (int i = 0; i < _editingDays.length; i++) {
      final dayOfWeek = _editingDays[i]['dayOfWeek'] ?? '未設定';
      final originalExercises = _originalDays[i]['exercises'] as List? ?? [];
      final editingExercises = _editingDays[i]['exercises'] as List? ?? [];
      
      // 檢查動作數量變化
      if (originalExercises.length != editingExercises.length) {
        final diff = editingExercises.length - originalExercises.length;
        if (diff > 0) {
          changes.add('$dayOfWeek：新增 $diff 個動作');
        } else {
          changes.add('$dayOfWeek：刪除 ${-diff} 個動作');
        }
      }
      
      // 檢查動作內容變化
      for (int j = 0; j < editingExercises.length && j < originalExercises.length; j++) {
        final original = originalExercises[j] as Map<String, dynamic>;
        final editing = editingExercises[j] as Map<String, dynamic>;
        
        if (original['name'] != editing['name']) {
          changes.add('$dayOfWeek：${original['name']} → ${editing['name']}');
        } else if (original['sets'] != editing['sets'] || original['reps'] != editing['reps']) {
          final setsChange = (editing['sets'] ?? 3) - (original['sets'] ?? 3);
          final repsChange = (editing['reps'] ?? 12) - (original['reps'] ?? 12);
          final parts = <String>[];
          if (setsChange != 0) parts.add('${setsChange > 0 ? '+' : ''}$setsChange 組');
          if (repsChange != 0) parts.add('${repsChange > 0 ? '+' : ''}$repsChange 次');
          if (parts.isNotEmpty) {
            changes.add('$dayOfWeek ${editing['name']}：${parts.join('、')}');
          }
        }
      }
    }
    
    return changes.isEmpty ? '細部調整' : changes.take(5).join('\n');
  }

  void _showSaveDialog() {
    final changeSummary = _generateChangeSummary();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.coach.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.save, color: AppColors.coach, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('儲存變更'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 變更摘要
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, size: 16, color: AppColors.info),
                        const SizedBox(width: 6),
                        Text(
                          '變更摘要',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      changeSummary,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                '給學員的說明（選填）',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: '例如：增加訓練強度，注意姿勢...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              
              // 提示
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '學員將會收到計畫更新通知',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _savePlan(changeSummary);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coach,
              foregroundColor: Colors.white,
            ),
            child: const Text('儲存並通知'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlan(String changeSummary) async {
    setState(() => _isSaving = true);

    try {
      final planRef = _firestore.collection('workoutPlans').doc(widget.planId);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final now = Timestamp.now();
      
      // 1. 獲取當前版本號
      final currentDoc = await planRef.get();
      final currentData = currentDoc.data() as Map<String, dynamic>?;
      final currentVersion = currentData?['version'] as int? ?? 1;
      final newVersion = currentVersion + 1;

      // 2. 更新計畫數據 + 版本號
      await planRef.update({
        'days': _editingDays,
        'version': newVersion,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': currentUserId,
        // 標記有未讀更新
        'hasUnreadUpdate': true,
        'lastUpdateAt': now,
      });

      // 3. 記錄版本歷史
      final versionRecord = {
        'version': newVersion,
        'days': _originalDays, // 保存舊版本
        'modifiedAt': now,
        'modifiedBy': currentUserId,
        'changeSummary': changeSummary,
        'note': _noteController.text.trim(),
      };

      await planRef.update({
        'versionHistory': FieldValue.arrayUnion([versionRecord]),
      });

      // 4. 發送更新通知給學員
      final noteContent = '''
📋 計畫更新通知 (v$newVersion)

$changeSummary
${_noteController.text.isNotEmpty ? '\n教練說明：${_noteController.text}' : ''}

⚠️ 本週尚未完成的訓練日將按新計畫執行
'''.trim();

      await planRef.update({
        'coachNotes': FieldValue.arrayUnion([
          {
            'content': noteContent,
            'createdAt': now,
            'coachId': currentUserId,
            'isAdjustmentNotice': true,
            'version': newVersion,
          }
        ]),
      });

      setState(() {
        _hasChanges = false;
        _isSaving = false;
        // 更新原始數據為當前編輯數據
        _originalDays = _editingDays.map((d) => _deepCopyDay(d)).toList();
      });
      
      _noteController.clear();
      _showSnackBar('計畫已儲存 (v$newVersion)，已通知學員');

      // 返回並傳回更新後的數據
      if (mounted) {
        Navigator.pop(context, {
          'updated': true,
          'days': _editingDays,
          'version': newVersion,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('儲存失敗: $e');
      setState(() => _isSaving = false);
      _showSnackBar('儲存失敗：$e', isError: true);
    }
  }
}

// ===========================================================
// 🏋️ 動作選擇器
// ===========================================================

class _ExercisePickerSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? currentExercise;
  final Function(Map<String, dynamic>) onSelected;

  const _ExercisePickerSheet({
    required this.title,
    this.currentExercise,
    required this.onSelected,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _selectedCategory = '全部';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 預設動作庫
  static const List<Map<String, dynamic>> _exerciseDatabase = [
    // 胸部
    {'name': '槓鈴臥推', 'type': '胸部', 'sets': 4, 'reps': 10},
    {'name': '啞鈴臥推', 'type': '胸部', 'sets': 4, 'reps': 12},
    {'name': '上斜臥推', 'type': '胸部', 'sets': 4, 'reps': 10},
    {'name': '下斜臥推', 'type': '胸部', 'sets': 3, 'reps': 12},
    {'name': '飛鳥夾胸', 'type': '胸部', 'sets': 3, 'reps': 15},
    {'name': '纜繩夾胸', 'type': '胸部', 'sets': 3, 'reps': 15},
    {'name': '伏地挺身', 'type': '胸部', 'sets': 3, 'reps': 15},
    
    // 背部
    {'name': '引體向上', 'type': '背部', 'sets': 4, 'reps': 8},
    {'name': '滑輪下拉', 'type': '背部', 'sets': 4, 'reps': 12},
    {'name': '槓鈴划船', 'type': '背部', 'sets': 4, 'reps': 10},
    {'name': '啞鈴划船', 'type': '背部', 'sets': 4, 'reps': 12},
    {'name': '坐姿划船', 'type': '背部', 'sets': 4, 'reps': 12},
    {'name': '硬舉', 'type': '背部', 'sets': 4, 'reps': 8},
    {'name': '直臂下壓', 'type': '背部', 'sets': 3, 'reps': 15},
    
    // 腿部
    {'name': '槓鈴深蹲', 'type': '腿部', 'sets': 4, 'reps': 10},
    {'name': '腿推', 'type': '腿部', 'sets': 4, 'reps': 12},
    {'name': '羅馬尼亞硬舉', 'type': '腿部', 'sets': 4, 'reps': 10},
    {'name': '腿彎舉', 'type': '腿部', 'sets': 3, 'reps': 12},
    {'name': '腿伸展', 'type': '腿部', 'sets': 3, 'reps': 15},
    {'name': '弓箭步', 'type': '腿部', 'sets': 3, 'reps': 12},
    {'name': '小腿提踵', 'type': '腿部', 'sets': 4, 'reps': 15},
    
    // 肩膀
    {'name': '槓鈴肩推', 'type': '肩膀', 'sets': 4, 'reps': 10},
    {'name': '啞鈴肩推', 'type': '肩膀', 'sets': 4, 'reps': 12},
    {'name': '側平舉', 'type': '肩膀', 'sets': 4, 'reps': 15},
    {'name': '前平舉', 'type': '肩膀', 'sets': 3, 'reps': 12},
    {'name': '俯身飛鳥', 'type': '肩膀', 'sets': 3, 'reps': 15},
    {'name': '面拉', 'type': '肩膀', 'sets': 3, 'reps': 15},
    
    // 手臂
    {'name': '槓鈴彎舉', 'type': '手臂', 'sets': 3, 'reps': 12},
    {'name': '啞鈴彎舉', 'type': '手臂', 'sets': 3, 'reps': 12},
    {'name': '錘式彎舉', 'type': '手臂', 'sets': 3, 'reps': 12},
    {'name': '三頭下壓', 'type': '手臂', 'sets': 3, 'reps': 15},
    {'name': '過頭三頭伸展', 'type': '手臂', 'sets': 3, 'reps': 12},
    {'name': '仰臥三頭伸展', 'type': '手臂', 'sets': 3, 'reps': 12},
    
    // 腹肌
    {'name': '捲腹', 'type': '腹肌', 'sets': 3, 'reps': 20},
    {'name': '抬腿', 'type': '腹肌', 'sets': 3, 'reps': 15},
    {'name': '平板支撐', 'type': '腹肌', 'sets': 3, 'reps': 60},
    {'name': '俄羅斯轉體', 'type': '腹肌', 'sets': 3, 'reps': 20},
    {'name': '登山者', 'type': '腹肌', 'sets': 3, 'reps': 30},
    
    // 有氧
    {'name': '跑步機', 'type': '有氧', 'sets': 1, 'reps': 30},
    {'name': '飛輪', 'type': '有氧', 'sets': 1, 'reps': 30},
    {'name': '橢圓機', 'type': '有氧', 'sets': 1, 'reps': 20},
    {'name': '划船機', 'type': '有氧', 'sets': 1, 'reps': 15},
    {'name': '跳繩', 'type': '有氧', 'sets': 3, 'reps': 100},
  ];

  List<String> get _categories => ['全部', '胸部', '背部', '腿部', '肩膀', '手臂', '腹肌', '有氧'];

  List<Map<String, dynamic>> get _filteredExercises {
    return _exerciseDatabase.where((exercise) {
      final matchCategory = _selectedCategory == '全部' || exercise['type'] == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty || 
          exercise['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '胸部': return const Color(0xFFE57373);
      case '背部': return const Color(0xFF64B5F6);
      case '腿部': return const Color(0xFFFFB74D);
      case '肩膀': return const Color(0xFFBA68C8);
      case '手臂': return AppColors.coach;
      case '腹肌': return const Color(0xFF4DB6AC);
      case '有氧': return const Color(0xFFF06292);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 拖動指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 標題
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Text(
                  widget.title,
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 搜尋框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: '搜尋動作...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 分類選擇
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                final color = category == '全部' ? AppColors.primary : _getCategoryColor(category);
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 動作列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _filteredExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                final isCurrent = widget.currentExercise != null &&
                    widget.currentExercise!['name'] == exercise['name'];
                final color = _getCategoryColor(exercise['type']);

                return GestureDetector(
                  onTap: isCurrent ? null : () => widget.onSelected(Map<String, dynamic>.from(exercise)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.divider : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent ? AppColors.textTertiary : color.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.fitness_center, color: color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise['name'],
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? AppColors.textTertiary : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${exercise['sets']}組 × ${exercise['reps']}次',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            exercise['type'],
                            style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle, color: AppColors.textTertiary, size: 20),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}