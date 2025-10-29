// lib/pages/workout/workout_calendar_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/workout_service.dart';
import '../../models/workout_model.dart';

/// 訓練日曆頁面 - 顯示訓練歷史和計畫
class WorkoutCalendarPage extends StatefulWidget {
  const WorkoutCalendarPage({super.key});

  @override
  State<WorkoutCalendarPage> createState() => _WorkoutCalendarPageState();
}

class _WorkoutCalendarPageState extends State<WorkoutCalendarPage> {
  final WorkoutService _workoutService = WorkoutService();
  
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Map<String, List<WorkoutModel>> _workoutsByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthWorkouts();
  }

  Future<void> _loadMonthWorkouts() async {
    setState(() => _isLoading = true);
    try {
      // TODO: 實作從 Firebase 載入當月所有訓練記錄
      // 目前先用空數據
      setState(() {
        _workoutsByDate = {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
    _loadMonthWorkouts();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練日曆'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildCalendar(),
          Expanded(
            child: _buildDayDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    String monthYear = DateFormat('yyyy年 M月').format(_selectedMonth);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            monthYear,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    // 計算月份第一天是星期幾
    DateTime firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    int firstWeekday = firstDayOfMonth.weekday; // 1 = 星期一, 7 = 星期日
    
    // 計算月份總天數
    DateTime lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    int daysInMonth = lastDayOfMonth.day;
    
    List<Widget> dayWidgets = [];
    
    // 添加空白格 (從星期一開始，所以星期一 = 0 格空白)
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }
    
    // 添加日期格
    for (int day = 1; day <= daysInMonth; day++) {
      DateTime date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      bool hasWorkout = _workoutsByDate.containsKey(dateKey) && 
                        _workoutsByDate[dateKey]!.isNotEmpty;
      bool isSelected = _selectedDate.year == date.year &&
                        _selectedDate.month == date.month &&
                        _selectedDate.day == date.day;
      bool isToday = DateTime.now().year == date.year &&
                     DateTime.now().month == date.month &&
                     DateTime.now().day == date.day;
      
      dayWidgets.add(_buildDayCell(date, hasWorkout, isSelected, isToday));
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 星期標題
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['一', '二', '三', '四', '五', '六', '日'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          
          // 日期格子
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: dayWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, bool hasWorkout, bool isSelected, bool isToday) {
    return GestureDetector(
      onTap: () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange
              : (isToday ? Colors.orange.shade50 : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday && !isSelected
                ? Colors.orange
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (hasWorkout)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    List<WorkoutModel>? workouts = _workoutsByDate[dateKey];
    
    if (workouts == null || workouts.isEmpty) {
      return _buildEmptyState();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('M月d日 (EEEE)', 'zh_TW').format(_selectedDate),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                return _buildWorkoutCard(workouts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutModel workout) {
    IconData icon;
    Color color;
    
    switch (workout.type) {
      case 'weight_training':
        icon = Icons.fitness_center;
        color = Colors.orange;
        break;
      case 'cardio':
        icon = Icons.directions_run;
        color = Colors.blue;
        break;
      case 'yoga':
        icon = Icons.self_improvement;
        color = Colors.purple;
        break;
      default:
        icon = Icons.sports_gymnastics;
        color = Colors.green;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${workout.duration} 分鐘',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (workout.sets != null || workout.caloriesBurned != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (workout.sets != null)
                    _buildStatChip('${workout.sets}組', Icons.repeat),
                  if (workout.sets != null && workout.caloriesBurned != null)
                    const SizedBox(width: 8),
                  if (workout.caloriesBurned != null)
                    _buildStatChip(
                      '${workout.caloriesBurned!.toStringAsFixed(0)}卡',
                      Icons.local_fire_department,
                    ),
                ],
              ),
            ],
            if (workout.notes != null) ...[
              const SizedBox(height: 12),
              Text(
                workout.notes!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '這天沒有訓練記錄',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}