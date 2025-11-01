// lib/pages/workout/create_workout_plan_page.dart
// ✨ 改進的教練端訓練計畫建立頁面
// 📌 整合 WGER API + 多學員選擇 + 週期重複設定

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';
import '../../services/user_service.dart';
import '../../services/wger_api_service.dart';

class CreateWorkoutPlanPage extends StatefulWidget {
  const CreateWorkoutPlanPage({super.key});

  @override
  State<CreateWorkoutPlanPage> createState() =>
      _CreateWorkoutPlanPage();
}

class _CreateWorkoutPlanPage
    extends State<CreateWorkoutPlanPage> {
  final WorkoutService _workoutService = WorkoutService();
  final UserService _userService = UserService();
  final WgerApiService _wgerService = WgerApiService();

  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 選中的學員（支援多選）
  List<String> _selectedTraineeIds = [];
  List<DocumentSnapshot> _students = [];

  // 日期設定
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // 重複設定
  bool _isSingleSession = false; // 是否為單次訓練
  List<String> _selectedWeekDays = []; // 選中的星期幾

  // 每日訓練內容
  Map<String, List<PlanExercise>> _weekDaysExercises = {};

  bool _isLoading = false;
  bool _isLoadingStudents = true;

  final Map<String, String> _dayNames = {
    'monday': '星期一',
    'tuesday': '星期二',
    'wednesday': '星期三',
    'thursday': '星期四',
    'friday': '星期五',
    'saturday': '星期六',
    'sunday': '星期日',
  };

  final List<String> _dayOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _userService.getCoachStudents(
        _userService.currentUserId!,
      );
      if (mounted) {
        setState(() {
          _students = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
        _showSnackBar('載入學員失敗：$e');
      }
    }
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
        title: const Text(
          '創建訓練計畫',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 提示訊息
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '創建計畫後，您可以選擇要分配給哪些學員',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 計畫資訊
                    _buildPlanInfo(),
                    const SizedBox(height: 16),

                    // 日期設定
                    _buildDateSettings(),
                    const SizedBox(height: 16),

                    // 重複設定
                    _buildRepeatSettings(),
                    const SizedBox(height: 16),

                    // 訓練內容
                    if (!_isSingleSession && _selectedWeekDays.isNotEmpty)
                      _buildTrainingContent(),

                    if (_isSingleSession) _buildSingleSessionContent(),

                    const SizedBox(height: 24),

                    // 提交按鈕（先創建計畫，然後選擇學員）
                    _buildSubmitButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// 計畫資訊卡片
  Widget _buildPlanInfo() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                '計畫資訊',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _planNameController,
            decoration: InputDecoration(
              labelText: '計畫名稱 *',
              hintText: '例：胸與三頭訓練',
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '請輸入計畫名稱';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: '計畫說明（選填）',
              hintText: '說明訓練目標和重點',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// 日期設定卡片
  Widget _buildDateSettings() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                '計畫時間',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event, color: Colors.green),
            ),
            title: const Text('開始日期'),
            subtitle: Text(
              _formatDate(_startDate),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_available, color: Colors.orange),
            ),
            title: const Text('結束日期（選填）'),
            subtitle: Text(
              _endDate != null ? _formatDate(_endDate!) : '持續進行',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _endDate != null ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
            trailing: _endDate != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() => _endDate = null),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                firstDate: _startDate,
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _endDate = picked);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 重複設定卡片
  Widget _buildRepeatSettings() {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                '重複設定',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('單次訓練'),
            subtitle: const Text('僅執行一次，不重複'),
            value: _isSingleSession,
            activeColor: Colors.green,
            onChanged: (value) {
              setState(() {
                _isSingleSession = value;
                if (value) {
                  _selectedWeekDays.clear();
                  _weekDaysExercises.clear();
                }
              });
            },
          ),
          if (!_isSingleSession) ...[
            const SizedBox(height: 16),
            const Text(
              '選擇訓練日（可多選）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dayOrder.map((day) {
                final isSelected = _selectedWeekDays.contains(day);
                return FilterChip(
                  label: Text(_dayNames[day]!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWeekDays.add(day);
                        if (!_weekDaysExercises.containsKey(day)) {
                          _weekDaysExercises[day] = [];
                        }
                      } else {
                        _selectedWeekDays.remove(day);
                        _weekDaysExercises.remove(day);
                      }
                    });
                  },
                  selectedColor: Colors.green,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 訓練內容（週期訓練）
  Widget _buildTrainingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _selectedWeekDays.map((day) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _dayNames[day]!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_weekDaysExercises[day]?.length ?? 0} 個動作',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_weekDaysExercises[day]?.isEmpty ?? true)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '尚未添加運動',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _weekDaysExercises[day]!.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final exercise = _weekDaysExercises[day]![index];
                    return _buildExerciseCard(exercise, day, index);
                  },
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => _addExerciseToDay(day),
                  icon: const Icon(Icons.add),
                  label: const Text('新增運動'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 訓練內容（單次訓練）
  Widget _buildSingleSessionContent() {
    return Container(
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '訓練動作',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_weekDaysExercises['single']?.length ?? 0} 個動作',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (_weekDaysExercises['single']?.isEmpty ?? true)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '尚未添加運動',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _weekDaysExercises['single']!.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exercise = _weekDaysExercises['single']![index];
                return _buildExerciseCard(exercise, 'single', index);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _addExerciseToDay('single'),
              icon: const Icon(Icons.add),
              label: const Text('新增運動'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 運動卡片
  Widget _buildExerciseCard(PlanExercise exercise, String day, int index) {
    // 根據分類設定顏色
    Color categoryColor;
    switch (exercise.category) {
      case '胸部':
        categoryColor = Colors.red;
        break;
      case '背部':
        categoryColor = Colors.blue;
        break;
      case '腿部':
        categoryColor = Colors.orange;
        break;
      case '肩膀':
        categoryColor = Colors.purple;
        break;
      case '手臂':
        categoryColor = Colors.green;
        break;
      case '腹肌':
        categoryColor = Colors.teal;
        break;
      case '有氧':
        categoryColor = Colors.pink;
        break;
      default:
        categoryColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // 序號
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 運動圖示
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fitness_center,
              color: categoryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 運動資訊
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exercise.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (exercise.sets != null && exercise.reps != null) ...[
                      Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${exercise.sets} 組 × ${exercise.reps} 次',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (exercise.weight != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.line_weight, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${exercise.weight} kg',
                        style: TextStyle(
                          fontSize: 13,
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                if (exercise.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 刪除按鈕
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () {
              setState(() {
                _weekDaysExercises[day]?.removeAt(index);
              });
              _showSnackBar('已移除運動');
            },
          ),
        ],
      ),
    );
  }

  /// 添加運動到指定日期
  Future<void> _addExerciseToDay(String day) async {
    // 顯示運動選擇對話框
    final result = await showDialog<Exercise>(
      context: context,
      builder: (context) => ExercisePickerDialog(wgerService: _wgerService),
    );

    if (result != null) {
      // 顯示設定對話框（組數、次數等）
      final exerciseDetail = await showDialog<PlanExercise>(
        context: context,
        builder: (context) => ExerciseDetailDialog(exercise: result),
      );

      if (exerciseDetail != null) {
        setState(() {
          if (!_weekDaysExercises.containsKey(day)) {
            _weekDaysExercises[day] = [];
          }
          _weekDaysExercises[day]!.add(exerciseDetail);
        });
        _showSnackBar('已添加 ${exerciseDetail.name}');
      }
    }
  }

  /// 提交按鈕
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _createPlanAndSelectStudents,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isLoading ? '創建中...' : '下一步：選擇學員',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  /// 創建計畫並選擇學員
  Future<void> _createPlanAndSelectStudents() async {
    // 表單驗證
    if (!_formKey.currentState!.validate()) return;

    // 檢查是否有添加運動
    bool hasExercises = false;
    if (_isSingleSession) {
      hasExercises = _weekDaysExercises['single']?.isNotEmpty ?? false;
    } else {
      hasExercises = _weekDaysExercises.values.any((list) => list.isNotEmpty);
    }

    if (!hasExercises) {
      _showSnackBar('請至少添加一個運動');
      return;
    }

    // 顯示學員選擇對話框
    final selectedStudents = await showDialog<List<String>>(
      context: context,
      builder: (context) => StudentSelectorDialog(
        students: _students,
        preSelectedIds: _selectedTraineeIds,
      ),
    );

    if (selectedStudents == null || selectedStudents.isEmpty) {
      _showSnackBar('請至少選擇一位學員');
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedTraineeIds = selectedStudents;
    });

    try {
      // 為每個學員創建訓練計畫
      for (String traineeId in _selectedTraineeIds) {
        List<WorkoutPlanDay> days = [];

        if (_isSingleSession) {
          // 單次訓練
          days.add(WorkoutPlanDay(
            dayOfWeek: 'single',
            exercises: _weekDaysExercises['single']!
                .map((e) => PlannedExercise(
                      name: e.name,
                      type: e.category,
                      sets: e.sets,
                      reps: e.reps,
                      notes: e.description,
                    ))
                .toList(),
          ));
        } else {
          // 週期訓練
          for (String day in _selectedWeekDays) {
            if (_weekDaysExercises[day]?.isNotEmpty ?? false) {
              days.add(WorkoutPlanDay(
                dayOfWeek: day,
                exercises: _weekDaysExercises[day]!
                    .map((e) => PlannedExercise(
                          name: e.name,
                          type: e.category,
                          sets: e.sets,
                          reps: e.reps,
                          notes: e.description,
                        ))
                    .toList(),
              ));
            }
          }
        }

        await _workoutService.createWorkoutPlan(
          traineeId: traineeId,
          planName: _planNameController.text,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          startDate: _startDate,
          endDate: _endDate,
          days: days,
        );
      }

      if (mounted) {
        _showSnackBar('成功為 ${_selectedTraineeIds.length} 位學員創建訓練計畫！');
        Navigator.pop(context, true); // 返回並刷新列表
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('創建訓練計畫失敗: $e');
      }
      _showSnackBar('創建失敗：$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

// ===================================
// 📌 運動選擇對話框
// ===================================

class ExercisePickerDialog extends StatefulWidget {
  final WgerApiService wgerService;

  const ExercisePickerDialog({super.key, required this.wgerService});

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
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
    try {
      final exercises = await widget.wgerService.getExercises(limit: 100);
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _filteredExercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 標題
            Row(
              children: [
                Icon(Icons.fitness_center, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '選擇運動',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 搜尋欄
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋運動名稱...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterExercises();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
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
                  final categoryColor = category == '全部' 
                      ? Colors.green 
                      : _getCategoryColor(category);

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
                      selectedColor: categoryColor,
                      backgroundColor: categoryColor.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : categoryColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: categoryColor.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 運動列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredExercises.isEmpty
                      ? const Center(child: Text('找不到符合的運動'))
                      : ListView.builder(
                          itemCount: _filteredExercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _filteredExercises[index];
                            final categoryColor = _getCategoryColor(exercise.category);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.fitness_center,
                                    color: categoryColor,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  exercise.nameZhTw,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    exercise.category,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: categoryColor,
                                ),
                                onTap: () => Navigator.pop(context, exercise),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: categoryColor.withValues(alpha: 0.2),
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
}

// ===================================
// 📌 運動詳情設定對話框
// ===================================

class ExerciseDetailDialog extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailDialog({super.key, required this.exercise});

  @override
  State<ExerciseDetailDialog> createState() => _ExerciseDetailDialogState();
}

class _ExerciseDetailDialogState extends State<ExerciseDetailDialog> {
  final _setsController = TextEditingController(); // 移除預設值
  final _repsController = TextEditingController(); // 移除預設值
  final _weightController = TextEditingController(); // 新增重量欄位

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(widget.exercise.category);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.fitness_center, color: categoryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.nameZhTw,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.exercise.category,
                    style: TextStyle(
                      fontSize: 12,
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.exercise.description != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, 
                      size: 16, 
                      color: Colors.grey.shade600
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.exercise.description!,
                        style: TextStyle(
                          color: Colors.grey.shade600, 
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            const Text(
              '訓練參數',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 組數
            TextField(
              controller: _setsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '組數',
                hintText: '例：3',
                prefixIcon: Icon(Icons.repeat, color: categoryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            
            // 次數
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '次數',
                hintText: '例：12',
                prefixIcon: Icon(Icons.format_list_numbered, color: categoryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            
            // 重量（選填）
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '重量 (kg) - 選填',
                hintText: '例：20',
                prefixIcon: Icon(Icons.line_weight, color: categoryColor),
                suffixText: 'kg',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '💡 提示：重量可以不填，讓學員自行調整',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final sets = int.tryParse(_setsController.text);
            final reps = int.tryParse(_repsController.text);
            final weight = _weightController.text.isEmpty 
                ? null 
                : double.tryParse(_weightController.text);

            if (sets == null || reps == null || sets <= 0 || reps <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('請輸入有效的組數和次數'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              PlanExercise(
                name: widget.exercise.nameZhTw,
                category: widget.exercise.category,
                sets: sets,
                reps: reps,
                weight: weight, // 加上重量
                description: widget.exercise.description,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: categoryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('確定'),
        ),
      ],
    );
  }
}

// ===================================
// 📌 學員選擇對話框
// ===================================

class StudentSelectorDialog extends StatefulWidget {
  final List<DocumentSnapshot> students;
  final List<String> preSelectedIds;

  const StudentSelectorDialog({
    super.key,
    required this.students,
    this.preSelectedIds = const [],
  });

  @override
  State<StudentSelectorDialog> createState() => _StudentSelectorDialogState();
}

class _StudentSelectorDialogState extends State<StudentSelectorDialog> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.preSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('選擇學員'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.students.isEmpty
            ? const Center(child: Text('尚無配對學員'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.students.length,
                itemBuilder: (context, index) {
                  final student = widget.students[index];
                  final data = student.data() as Map<String, dynamic>;
                  final name = data['displayName'] ?? '未命名學員';
                  final isSelected = _selectedIds.contains(student.id);

                  return CheckboxListTile(
                    title: Text(name),
                    subtitle: Text(data['email'] ?? ''),
                    value: isSelected,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(student.id);
                        } else {
                          _selectedIds.remove(student.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text('確定（${_selectedIds.length}）'),
        ),
      ],
    );
  }
}

// ===================================
// 📌 運動模型
// ===================================

class PlanExercise {
  final String name;
  final String category;
  final int? sets;
  final int? reps;
  final double? weight; // 新增重量欄位
  final String? description;

  PlanExercise({
    required this.name,
    required this.category,
    this.sets,
    this.reps,
    this.weight, // 新增
    this.description,
  });
}