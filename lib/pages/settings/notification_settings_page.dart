// lib/pages/settings/notification_settings_page.dart
import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();

  // 喝水提醒設定
  bool _waterReminderEnabled = false;
  List<TimeOfDay> _waterTimes = [
    const TimeOfDay(hour: 10, minute: 0),
    const TimeOfDay(hour: 14, minute: 0),
    const TimeOfDay(hour: 18, minute: 0),
  ];

  // 運動提醒設定
  bool _workoutReminderEnabled = false;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);

  // 飲食提醒設定
  bool _mealReminderEnabled = false;
  List<MealTime> _mealTimes = [
    MealTime('早餐', const TimeOfDay(hour: 8, minute: 0)),
    MealTime('午餐', const TimeOfDay(hour: 12, minute: 0)),
    MealTime('晚餐', const TimeOfDay(hour: 18, minute: 30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 喝水提醒
          _buildWaterReminderSection(),
          const SizedBox(height: 24),

          // 運動提醒
          _buildWorkoutReminderSection(),
          const SizedBox(height: 24),

          // 飲食提醒
          _buildMealReminderSection(),
          const SizedBox(height: 24),

          // 測試按鈕（開發用）
          _buildTestSection(),
        ],
      ),
    );
  }

  // 喝水提醒區塊
  Widget _buildWaterReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '喝水提醒',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '定時提醒你補充水分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _waterReminderEnabled,
                onChanged: (value) async {
                  setState(() => _waterReminderEnabled = value);
                  if (value) {
                    await _setupWaterReminders();
                  } else {
                    await _notificationService.cancelWaterReminders();
                  }
                  _showSnackBar(value ? '喝水提醒已開啟' : '喝水提醒已關閉');
                },
              ),
            ],
          ),
          if (_waterReminderEnabled) ...[
            const Divider(height: 24),
            ..._waterTimes.asMap().entries.map((entry) {
              int index = entry.key;
              TimeOfDay time = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '提醒 ${index + 1}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectTime(context, index, 'water'),
                      child: Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _waterTimes.removeAt(index);
                        });
                        _setupWaterReminders();
                      },
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _waterTimes.add(const TimeOfDay(hour: 12, minute: 0));
                });
                _setupWaterReminders();
              },
              icon: const Icon(Icons.add),
              label: const Text('新增提醒時間'),
            ),
          ],
        ],
      ),
    );
  }

  // 運動提醒區塊
  Widget _buildWorkoutReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '運動提醒',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '提醒你該運動了',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _workoutReminderEnabled,
                onChanged: (value) async {
                  setState(() => _workoutReminderEnabled = value);
                  if (value) {
                    await _setupWorkoutReminder();
                  } else {
                    await _notificationService.cancelWorkoutReminder();
                  }
                  _showSnackBar(value ? '運動提醒已開啟' : '運動提醒已關閉');
                },
              ),
            ],
          ),
          if (_workoutReminderEnabled) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '提醒時間',
                  style: TextStyle(fontSize: 14),
                ),
                TextButton(
                  onPressed: () => _selectTime(context, 0, 'workout'),
                  child: Text(
                    '${_workoutTime.hour.toString().padLeft(2, '0')}:${_workoutTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 飲食提醒區塊
  Widget _buildMealReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '飲食提醒',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '提醒你用餐時間',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _mealReminderEnabled,
                onChanged: (value) async {
                  setState(() => _mealReminderEnabled = value);
                  if (value) {
                    await _setupMealReminders();
                  } else {
                    await _notificationService.cancelMealReminders();
                  }
                  _showSnackBar(value ? '飲食提醒已開啟' : '飲食提醒已關閉');
                },
              ),
            ],
          ),
          if (_mealReminderEnabled) ...[
            const Divider(height: 24),
            ..._mealTimes.map((mealTime) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mealTime.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectTime(
                        context,
                        _mealTimes.indexOf(mealTime),
                        'meal',
                      ),
                      child: Text(
                        '${mealTime.time.hour.toString().padLeft(2, '0')}:${mealTime.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // 測試區塊（開發用）
  Widget _buildTestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧪 測試通知',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              _notificationService.initialize();
              _showSnackBar('通知服務已初始化');
            },
            child: const Text('初始化通知服務'),
          ),
        ],
      ),
    );
  }

  // 選擇時間
  Future<void> _selectTime(
    BuildContext context,
    int index,
    String type,
  ) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: type == 'water'
          ? _waterTimes[index]
          : type == 'workout'
              ? _workoutTime
              : _mealTimes[index].time,
    );

    if (picked != null) {
      setState(() {
        if (type == 'water') {
          _waterTimes[index] = picked;
          _setupWaterReminders();
        } else if (type == 'workout') {
          _workoutTime = picked;
          _setupWorkoutReminder();
        } else if (type == 'meal') {
          _mealTimes[index].time = picked;
          _setupMealReminders();
        }
      });
    }
  }

  // 設定喝水提醒
  Future<void> _setupWaterReminders() async {
    List<int> hours = _waterTimes.map((time) => time.hour).toList();
    await _notificationService.scheduleWaterReminders(hours: hours);
  }

  // 設定運動提醒
  Future<void> _setupWorkoutReminder() async {
    await _notificationService.scheduleWorkoutReminder(
      hour: _workoutTime.hour,
      minute: _workoutTime.minute,
      message: '該做運動了！保持活力！',
    );
  }

  // 設定飲食提醒
  Future<void> _setupMealReminders() async {
    List<MealReminder> reminders = _mealTimes
        .map((mealTime) => MealReminder(
              mealName: mealTime.name,
              hour: mealTime.time.hour,
              minute: mealTime.time.minute,
              message: '記得均衡飲食哦！',
            ))
        .toList();

    await _notificationService.scheduleMealReminders(meals: reminders);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// 輔助類別
class MealTime {
  final String name;
  TimeOfDay time;

  MealTime(this.name, this.time);
}