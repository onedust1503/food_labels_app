// lib/pages/workout/create_workout_plan_page.dart
// 🎯 創建訓練計畫頁面 - 完整版（含分配學員功能）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/workout_model.dart';
import '../../services/workout_service.dart';
import '../../services/user_service.dart';
import '../../components/assign_trainee_dialog.dart';

class CreateWorkoutPlanPage extends StatefulWidget {
  const CreateWorkoutPlanPage({super.key});

  @override
  State<CreateWorkoutPlanPage> createState() => _CreateWorkoutPlanPageState();
}

class _CreateWorkoutPlanPageState extends State<CreateWorkoutPlanPage> {
  final WorkoutService _workoutService = WorkoutService();
  final UserService _userService = UserService();
  
  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // 🔥 移除單一學員選擇,改為批次分配
  // String? _selectedTraineeId;
  // String _selectedTraineeName = '請選擇學員';
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  List<DocumentSnapshot> _students = [];
  List<WorkoutPlanDay> _weekDays = [];
  
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
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() => _isLoadingStudents = false);
      _showSnackBar('載入學員失敗：$e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('創建訓練計畫'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 提示卡片
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    
                    // 🔥 移除學員選擇器（改為提交後選擇）
                    // _buildTraineeSelector(),
                    // const SizedBox(height: 16),
                    
                    _buildBasicInfo(),
                    const SizedBox(height: 16),
                    _buildDateSelector(),
                    const SizedBox(height: 16),
                    _buildWeeklyPlan(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // 🔥 新增：提示卡片
  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '創建計畫後,您可以選擇要分配給哪些學員',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 移除學員選擇器（改在提交後選擇）
  /*
  Widget _buildTraineeSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person, color: Colors.green),
        title: const Text('選擇學員'),
        subtitle: Text(_selectedTraineeName),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: _selectTrainee,
      ),
    );
  }

  void _selectTrainee() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '選擇學員',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _students.isEmpty
                      ? const Center(child: Text('沒有學員'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            final data = student.data() as Map<String, dynamic>;
                            final name = data['displayName'] ?? '未命名學員';
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withOpacity(0.1),
                                child: Text(
                                  name[0],
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(data['email'] ?? ''),
                              onTap: () {
                                setState(() {
                                  _selectedTraineeId = student.id;
                                  _selectedTraineeName = name;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  */

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '計畫資訊',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _planNameController,
              decoration: const InputDecoration(
                labelText: '計畫名稱',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                hintText: '例如：增肌訓練計畫',
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
              decoration: const InputDecoration(
                labelText: '計畫說明（選填）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: '詳細描述訓練計畫的目標和內容',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '計畫時間',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.green),
              title: const Text('開始日期'),
              subtitle: Text(_formatDate(_startDate)),
              onTap: _selectStartDate,
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Colors.green),
              title: const Text('結束日期（選填）'),
              subtitle: Text(_endDate != null ? _formatDate(_endDate!) : '持續進行'),
              onTap: _selectEndDate,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Widget _buildWeeklyPlan() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '每週訓練',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addTrainingDay,
                  icon: const Icon(Icons.add),
                  label: const Text('新增訓練日'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_weekDays.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '點擊「新增訓練日」開始規劃',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._weekDays.asMap().entries.map((entry) {
                return _buildDayCard(entry.key, entry.value);
              }),
          ],
        ),
      ),
    );
  }

  void _addTrainingDay() {
    showDialog(
      context: context,
      builder: (context) {
        String selectedDay = 'monday';
        return AlertDialog(
          title: const Text('選擇訓練日'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButton<String>(
                value: selectedDay,
                isExpanded: true,
                items: _dayNames.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedDay = value!);
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _weekDays.add(WorkoutPlanDay(
                    dayOfWeek: selectedDay,
                    exercises: [],
                  ));
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayCard(int dayIndex, WorkoutPlanDay day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dayNames[day.dayOfWeek] ?? day.dayOfWeek,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _addExercise(dayIndex),
                      iconSize: 20,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _weekDays.removeAt(dayIndex));
                      },
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
            if (day.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '尚無運動項目',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )
            else
              ...day.exercises.asMap().entries.map((entry) {
                int exIndex = entry.key;
                PlannedExercise ex = entry.value;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.fitness_center, size: 16),
                  title: Text(ex.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _getExerciseDetails(ex),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        day.exercises.removeAt(exIndex);
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _addExercise(int dayIndex) {
    final nameController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final durationController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增運動'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '運動名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: setsController,
                        decoration: const InputDecoration(
                          labelText: '組數',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: repsController,
                        decoration: const InputDecoration(
                          labelText: '次數',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: '時長（分鐘，選填）',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '備註（選填）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _weekDays[dayIndex].exercises.add(
                          PlannedExercise(
                            name: nameController.text,
                            sets: int.tryParse(setsController.text),
                            reps: int.tryParse(repsController.text),
                            duration: int.tryParse(durationController.text),
                            notes: notesController.text.isNotEmpty
                                ? notesController.text
                                : null,
                          ),
                        );
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  String _getExerciseDetails(PlannedExercise exercise) {
    List<String> details = [];

    if (exercise.sets != null && exercise.reps != null) {
      details.add('${exercise.sets} 組 × ${exercise.reps} 次');
    } else if (exercise.sets != null) {
      details.add('${exercise.sets} 組');
    }

    if (exercise.duration != null) {
      details.add('${exercise.duration} 分鐘');
    }

    return details.isEmpty ? '自訂訓練' : details.join(' • ');
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('創建計畫並分配', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  // 🔥 修改：提交計畫後顯示分配對話框
  Future<void> _submitPlan() async {
    if (!_formKey.currentState!.validate()) return;
    // 🔥 移除單一學員檢查
    // if (_selectedTraineeId == null) {
    //   _showSnackBar('請選擇學員', Colors.red);
    //   return;
    // }
    if (_weekDays.isEmpty) {
      _showSnackBar('請至少添加一個訓練日', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔥 修改：創建一個模板計畫（不指定特定學員）
      // 先創建計畫並獲取 planId
      final String planId = await _workoutService.createTemplatePlan(
        planName: _planNameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        startDate: _startDate,
        endDate: _endDate,
        days: _weekDays,
      );

      if (mounted) {
        _showSnackBar('訓練計畫創建成功！', Colors.green);
        // 🔥 創建成功後,彈出學員分配視窗
        _showAssignDialog(planId);
      }
    } catch (e) {
      _showSnackBar('創建失敗：$e', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // 🔥 新增：顯示分配學員的 Dialog
  void _showAssignDialog(String planId) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止點擊外部關閉
      builder: (BuildContext context) {
        return AssignTraineeDialog(
          students: _students,
          onAssign: (selectedIds) async {
            if (selectedIds.isEmpty) {
              _showSnackBar('未選擇任何學員', Colors.orange);
              Navigator.of(context).pop(); // 關閉 Dialog
              Navigator.of(context).pop(); // 關閉 CreateWorkoutPlanPage
              return;
            }
            try {
              await _workoutService.assignWorkoutPlanToStudents(
                planId,
                selectedIds,
              );
              if (mounted) {
                _showSnackBar(
                  '成功分配給 ${selectedIds.length} 位學員',
                  Colors.green,
                );
                Navigator.of(context).pop(); // 關閉 Dialog
                Navigator.of(context).pop(); // 關閉 CreateWorkoutPlanPage
              }
            } catch (e) {
              _showSnackBar('分配失敗: $e', Colors.red);
            }
          },
          onSkip: () {
            Navigator.of(context).pop(); // 關閉 Dialog
            Navigator.of(context).pop(); // 關閉 CreateWorkoutPlanPage
          },
        );
      },
    ).whenComplete(() {
      // Dialog 關閉後,恢復按鈕狀態
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}