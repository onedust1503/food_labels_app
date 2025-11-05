// lib/pages/workout/workout_log_page.dart
// ✅ 更新版 - 支援點擊查看訓練詳情

import 'package:flutter/material.dart';
import '../../services/unified_workout_service.dart';

class WorkoutLogPage extends StatefulWidget {
  const WorkoutLogPage({super.key});

  @override
  State<WorkoutLogPage> createState() => _WorkoutLogPageState();
}

class _WorkoutLogPageState extends State<WorkoutLogPage> {
  final UnifiedWorkoutService _workoutService = UnifiedWorkoutService();
  
  List<Map<String, dynamic>> _todayWorkouts = [];
  Map<String, dynamic> _todaySummary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayWorkouts();
  }

  Future<void> _loadTodayWorkouts() async {
    setState(() => _isLoading = true);
    try {
      final workouts = await _workoutService.getTodayWorkouts();
      final summary = await _workoutService.getTodayStats();

      setState(() {
        _todayWorkouts = workouts;
        _todaySummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗:$e', Colors.red);
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
        title: const Text('運動記錄'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWorkoutDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayWorkouts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySummaryCard(),
                    const SizedBox(height: 20),
                    _buildWorkoutList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodaySummaryCard() {
    int totalDuration = _todaySummary['totalDuration'] ?? 0;
    double totalCalories = (_todaySummary['totalCalories'] ?? 0).toDouble();
    int workoutCount = _todaySummary['workoutCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日運動',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.timer, '$totalDuration', '分鐘'),
              _buildStatItem(
                Icons.local_fire_department,
                '${totalCalories.toInt()}',
                '大卡',
              ),
              _buildStatItem(Icons.fitness_center, '$workoutCount', '次'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutList() {
    if (_todayWorkouts.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.fitness_center, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '今天還沒有運動記錄',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊右上角 + 新增運動',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今日訓練',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._todayWorkouts.map((workout) => _buildWorkoutCard(workout)),
      ],
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    IconData typeIcon;
    Color typeColor;

    String type = workout['type'] ?? '';
    switch (type) {
      case 'weight_training':
      case '重量訓練':
        typeIcon = Icons.fitness_center;
        typeColor = Colors.red;
        break;
      case 'cardio':
      case '有氧運動':
        typeIcon = Icons.directions_run;
        typeColor = Colors.blue;
        break;
      case 'yoga':
      case '瑜伽':
        typeIcon = Icons.self_improvement;
        typeColor = Colors.purple;
        break;
      default:
        typeIcon = Icons.sports;
        typeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(typeIcon, color: typeColor, size: 28),
        ),
        title: Text(
          workout['name'] ?? '未命名運動',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${workout['duration'] ?? 0} 分鐘',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (workout['sets'] != null && workout['reps'] != null)
              Text(
                '${workout['sets']} 組 × ${workout['reps']} 次',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: workout['caloriesBurned'] != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  Text(
                    '${(workout['caloriesBurned'] as num).toInt()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              )
            : null,
        // ✅ 添加點擊事件查看詳情
        onTap: () => _showWorkoutDetail(workout),
      ),
    );
  }

  // ✅ 顯示訓練詳情
  void _showWorkoutDetail(Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖動指示器
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 標題
                Row(
                  children: [
                    _getWorkoutIcon(workout['type']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        workout['name'] ?? '未命名運動',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 詳細資訊
                _buildDetailRow('運動類型', _getTypeLabel(workout['type'])),
                _buildDetailRow('時長', '${workout['duration'] ?? 0} 分鐘'),
                if (workout['sets'] != null)
                  _buildDetailRow('組數', '${workout['sets']}'),
                if (workout['reps'] != null)
                  _buildDetailRow('次數', '${workout['reps']}'),
                if (workout['weight'] != null)
                  _buildDetailRow('重量', '${workout['weight']} kg'),
                if (workout['caloriesBurned'] != null)
                  _buildDetailRow(
                    '消耗卡路里',
                    '${(workout['caloriesBurned'] as num).toInt()} 大卡',
                  ),
                if (workout['intensity'] != null)
                  _buildDetailRow('強度', _getIntensityLabel(workout['intensity'])),
                if (workout['notes'] != null && workout['notes'].isNotEmpty)
                  _buildDetailRow('備註', workout['notes']),
                if (workout['planId'] != null)
                  _buildDetailRow('來源', '訓練計畫'),

                const SizedBox(height: 20),

                // 刪除按鈕
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteWorkout(workout['id']);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('刪除記錄', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 詳情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 獲取運動圖示
  Widget _getWorkoutIcon(String? type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'weight_training':
      case '重量訓練':
        icon = Icons.fitness_center;
        color = Colors.red;
        break;
      case 'cardio':
      case '有氧運動':
        icon = Icons.directions_run;
        color = Colors.blue;
        break;
      case 'yoga':
      case '瑜伽':
        icon = Icons.self_improvement;
        color = Colors.purple;
        break;
      default:
        icon = Icons.sports;
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }

  // 獲取類型標籤
  String _getTypeLabel(String? type) {
    switch (type) {
      case 'weight_training':
        return '重量訓練';
      case 'cardio':
        return '有氧運動';
      case 'yoga':
        return '瑜伽';
      case 'stretching':
        return '伸展';
      default:
        return type ?? '未知';
    }
  }

  // 獲取強度標籤
  String _getIntensityLabel(String? intensity) {
    switch (intensity) {
      case 'low':
        return '低';
      case 'medium':
        return '中';
      case 'high':
        return '高';
      default:
        return intensity ?? '未知';
    }
  }

  // 刪除訓練記錄
  Future<void> _deleteWorkout(String? workoutId) async {
    if (workoutId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除此訓練記錄嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _workoutService.deleteWorkout(workoutId);
        _showSnackBar('已刪除訓練記錄', Colors.green);
        _loadTodayWorkouts();
      } catch (e) {
        _showSnackBar('刪除失敗:$e', Colors.red);
      }
    }
  }

  void _showAddWorkoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddWorkoutDialog(
        onSave: (data) async {
          await _workoutService.addWorkoutLog(
            type: data['type'],
            name: data['name'],
            duration: data['duration'],
            sets: data['sets'] ?? 0,
            reps: data['reps'] ?? 0,
            weight: data['weight'],
            caloriesBurned: data['calories'],
            intensity: data['intensity'],
            notes: data['notes'],
          );
          _loadTodayWorkouts();
          _showSnackBar('運動記錄成功!', Colors.green);
        },
      ),
    );
  }
}

// ========== 新增運動對話框 ==========
class AddWorkoutDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AddWorkoutDialog({super.key, required this.onSave});

  @override
  State<AddWorkoutDialog> createState() => _AddWorkoutDialogState();
}

class _AddWorkoutDialogState extends State<AddWorkoutDialog> {
  String _selectedType = 'weight_training';
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedIntensity = 'medium';

  final Map<String, String> _workoutTypes = {
    'weight_training': '重量訓練',
    'cardio': '有氧運動',
    'yoga': '瑜伽',
    'stretching': '伸展',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '新增運動',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '運動類型',
                border: OutlineInputBorder(),
              ),
              items: _workoutTypes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '運動名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: '時長(分鐘)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: '消耗卡路里',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_selectedType == 'weight_training') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _setsController,
                      decoration: const InputDecoration(
                        labelText: '組數',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      decoration: const InputDecoration(
                        labelText: '次數',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: '重量 (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isEmpty ||
                      _durationController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請填寫必填欄位')),
                    );
                    return;
                  }

                  widget.onSave({
                    'type': _selectedType,
                    'name': _nameController.text,
                    'duration': int.parse(_durationController.text),
                    'calories': _caloriesController.text.isNotEmpty
                        ? double.parse(_caloriesController.text)
                        : null,
                    'sets': _setsController.text.isNotEmpty
                        ? int.parse(_setsController.text)
                        : null,
                    'reps': _repsController.text.isNotEmpty
                        ? int.parse(_repsController.text)
                        : null,
                    'weight': _weightController.text.isNotEmpty
                        ? double.parse(_weightController.text)
                        : null,
                    'intensity': _selectedIntensity,
                    'notes': null,
                  });

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '儲存',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}