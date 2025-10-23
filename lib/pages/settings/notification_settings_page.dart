// lib/pages/settings/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  late SharedPreferences _prefs;
  bool _isLoading = true;
  bool _hasExactAlarmPermission = false;

  bool _waterReminderEnabled = false;
  List<TimeOfDay> _waterTimes = [
    const TimeOfDay(hour: 10, minute: 0),
    const TimeOfDay(hour: 14, minute: 0),
    const TimeOfDay(hour: 18, minute: 0),
  ];

  bool _workoutReminderEnabled = false;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);

  bool _mealReminderEnabled = false;
  List<MealTime> _mealTimes = [
    MealTime('早餐', const TimeOfDay(hour: 8, minute: 0)),
    MealTime('午餐', const TimeOfDay(hour: 12, minute: 0)),
    MealTime('晚餐', const TimeOfDay(hour: 18, minute: 30)),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    _hasExactAlarmPermission = await _notificationService.hasExactAlarmPermission();
    
    setState(() {
      _waterReminderEnabled = _prefs.getBool('water_reminder_enabled') ?? false;
      
      String? waterTimesJson = _prefs.getString('water_times');
      if (waterTimesJson != null) {
        try {
          List<dynamic> timeList = jsonDecode(waterTimesJson);
          _waterTimes = timeList.map((time) {
            return TimeOfDay(hour: time['hour'], minute: time['minute']);
          }).toList();
        } catch (e) {
          print('❌ 載入喝水時間失敗: $e');
        }
      }
      
      _workoutReminderEnabled = _prefs.getBool('workout_reminder_enabled') ?? false;
      int workoutHour = _prefs.getInt('workout_hour') ?? 18;
      int workoutMinute = _prefs.getInt('workout_minute') ?? 0;
      _workoutTime = TimeOfDay(hour: workoutHour, minute: workoutMinute);
      
      _mealReminderEnabled = _prefs.getBool('meal_reminder_enabled') ?? false;
      
      String? mealTimesJson = _prefs.getString('meal_times');
      if (mealTimesJson != null) {
        try {
          List<dynamic> mealList = jsonDecode(mealTimesJson);
          _mealTimes = mealList.map((meal) {
            return MealTime(
              meal['name'],
              TimeOfDay(hour: meal['hour'], minute: meal['minute']),
            );
          }).toList();
        } catch (e) {
          print('❌ 載入飲食時間失敗: $e');
        }
      }
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _prefs.setBool('water_reminder_enabled', _waterReminderEnabled);
    await _prefs.setBool('workout_reminder_enabled', _workoutReminderEnabled);
    await _prefs.setBool('meal_reminder_enabled', _mealReminderEnabled);
    
    await _prefs.setInt('workout_hour', _workoutTime.hour);
    await _prefs.setInt('workout_minute', _workoutTime.minute);
    
    List<Map<String, int>> waterTimesData = _waterTimes.map((time) {
      return {'hour': time.hour, 'minute': time.minute};
    }).toList();
    await _prefs.setString('water_times', jsonEncode(waterTimesData));
    
    List<Map<String, dynamic>> mealTimesData = _mealTimes.map((meal) {
      return {
        'name': meal.name,
        'hour': meal.time.hour,
        'minute': meal.time.minute,
      };
    }).toList();
    await _prefs.setString('meal_times', jsonEncode(mealTimesData));
  }

  // 🆕 檢查權限並處理（開關切換時使用）
  Future<bool> _checkAndRequestPermission() async {
    // 先檢查是否有權限
    bool hasPermission = await _notificationService.hasExactAlarmPermission();
    
    if (hasPermission) {
      return true;  // 有權限，直接返回
    }
    
    // 沒有權限，顯示對話框
    bool? userConfirmed = await _showPermissionDialog();
    
    if (userConfirmed == true) {
      // 用戶同意，導向設定
      await _notificationService.openAlarmSettings();
      
      // 顯示提示
      _showSnackBar('⚠️ 請在設定中開啟「鬧鐘與提醒」權限');
      
      // 等待用戶返回
      await Future.delayed(const Duration(seconds: 2));
      
      // 重新檢查權限
      hasPermission = await _notificationService.hasExactAlarmPermission();
      setState(() {
        _hasExactAlarmPermission = hasPermission;
      });
      
      if (hasPermission) {
        _showSnackBar('✅ 權限已開啟！');
        return true;
      } else {
        _showSnackBar('❌ 未開啟權限，無法使用定時提醒');
        return false;
      }
    } else {
      // 用戶拒絕
      _showSnackBar('❌ 需要權限才能使用定時提醒功能');
      return false;
    }
  }

  // 🆕 顯示權限說明對話框
  Future<bool?> _showPermissionDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,  // 不允許點擊外部關閉
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.alarm, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '需要精確鬧鐘權限',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '為了讓定時提醒功能正常運作，需要開啟「精確鬧鐘」權限。',
                style: TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '如何開啟：',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. 點擊「前往設定」\n'
                      '2. 找到「鬧鐘與提醒」\n'
                      '3. 開啟權限開關',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                '取消',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('前往設定'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 只在沒有權限時顯示警告
          if (!_hasExactAlarmPermission) _buildPermissionWarning(),
          if (!_hasExactAlarmPermission) const SizedBox(height: 16),
          
          _buildWaterReminderSection(),
          const SizedBox(height: 24),
          _buildWorkoutReminderSection(),
          const SizedBox(height: 24),
          _buildMealReminderSection(),
          const SizedBox(height: 24),
          _buildTestSection(),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade100, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ 需要開啟權限',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '定時提醒需要精確鬧鐘權限',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                bool granted = await _checkAndRequestPermission();
                if (granted) {
                  setState(() {
                    _hasExactAlarmPermission = true;
                  });
                }
              },
              icon: const Icon(Icons.settings, size: 20),
              label: const Text(
                '立即開啟權限',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 喝水提醒區塊（加入權限檢查）
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
                child: const Icon(Icons.water_drop, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('喝水提醒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('定時提醒喝水', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _waterReminderEnabled,
                onChanged: (value) async {
                  // 🆕 開啟時檢查權限
                  if (value) {
                    bool hasPermission = await _checkAndRequestPermission();
                    if (!hasPermission) {
                      return;  // 沒有權限，不執行後續操作
                    }
                  }
                  
                  setState(() => _waterReminderEnabled = value);
                  await _saveSettings();
                  
                  if (value) {
                    await _setupWaterReminders();
                    _showSnackBar('✅ 喝水提醒已開啟');
                  } else {
                    await _notificationService.cancelWaterReminders();
                    _showSnackBar('❌ 喝水提醒已關閉');
                  }
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
                    if (_waterTimes.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () async {
                          setState(() {
                            _waterTimes.removeAt(index);
                          });
                          await _saveSettings();
                          await _setupWaterReminders();
                          _showSnackBar('🗑️ 已刪除提醒');
                        },
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () async {
                setState(() {
                  _waterTimes.add(const TimeOfDay(hour: 12, minute: 0));
                });
                await _saveSettings();
                await _setupWaterReminders();
                _showSnackBar('✅ 已新增提醒');
              },
              icon: const Icon(Icons.add),
              label: const Text('新增提醒時間'),
            ),
          ],
        ],
      ),
    );
  }

  // 🆕 運動提醒區塊（加入權限檢查）
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
                child: const Icon(Icons.fitness_center, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('運動提醒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('提醒你該運動了', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _workoutReminderEnabled,
                onChanged: (value) async {
                  // 🆕 開啟時檢查權限
                  if (value) {
                    bool hasPermission = await _checkAndRequestPermission();
                    if (!hasPermission) {
                      return;
                    }
                  }
                  
                  setState(() => _workoutReminderEnabled = value);
                  await _saveSettings();
                  
                  if (value) {
                    await _setupWorkoutReminder();
                    _showSnackBar('✅ 運動提醒已開啟');
                  } else {
                    await _notificationService.cancelWorkoutReminder();
                    _showSnackBar('❌ 運動提醒已關閉');
                  }
                },
              ),
            ],
          ),
          
          if (_workoutReminderEnabled) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Text('提醒時間', style: TextStyle(fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: () => _selectTime(context, 0, 'workout'),
                  child: Text(
                    '${_workoutTime.hour.toString().padLeft(2, '0')}:${_workoutTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 🆕 飲食提醒區塊（加入權限檢查）
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
                child: const Icon(Icons.restaurant, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('飲食提醒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('提醒你用餐時間', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _mealReminderEnabled,
                onChanged: (value) async {
                  // 🆕 開啟時檢查權限
                  if (value) {
                    bool hasPermission = await _checkAndRequestPermission();
                    if (!hasPermission) {
                      return;
                    }
                  }
                  
                  setState(() => _mealReminderEnabled = value);
                  await _saveSettings();
                  
                  if (value) {
                    await _setupMealReminders();
                    _showSnackBar('✅ 飲食提醒已開啟');
                  } else {
                    await _notificationService.cancelMealReminders();
                    _showSnackBar('❌ 飲食提醒已關閉');
                  }
                },
              ),
            ],
          ),
          
          if (_mealReminderEnabled) ...[
            const Divider(height: 24),
            ..._mealTimes.asMap().entries.map((entry) {
              int index = entry.key;
              MealTime mealTime = entry.value;
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
                      onPressed: () => _selectTime(context, index, 'meal'),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await _notificationService.sendTestNotification();
                  _showSnackBar('✅ 測試通知已發送！請查看通知欄');
                } catch (e) {
                  _showSnackBar('❌ 發送失敗：$e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('🔔 發送測試通知'),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '提示：',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 測試通知：立即彈出\n'
                  '• 定時提醒：開啟開關時會檢查權限',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, int index, String type) async {
    TimeOfDay initialTime;
    
    if (type == 'water') {
      initialTime = _waterTimes[index];
    } else if (type == 'workout') {
      initialTime = _workoutTime;
    } else {
      initialTime = _mealTimes[index].time;
    }

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        if (type == 'water') {
          _waterTimes[index] = picked;
        } else if (type == 'workout') {
          _workoutTime = picked;
        } else if (type == 'meal') {
          _mealTimes[index].time = picked;
        }
      });
      
      await _saveSettings();
      
      if (type == 'water') {
        await _setupWaterReminders();
      } else if (type == 'workout') {
        await _setupWorkoutReminder();
      } else {
        await _setupMealReminders();
      }
      
      _showSnackBar('✅ 時間已更新');
    }
  }

  Future<void> _setupWaterReminders() async {
    await _notificationService.scheduleWaterReminders(
      hours: _waterTimes.map((t) => t.hour).toList(),
    );
  }

  Future<void> _setupWorkoutReminder() async {
    await _notificationService.scheduleWorkoutReminder(
      hour: _workoutTime.hour,
      minute: _workoutTime.minute,
      message: '該運動了！保持健康的身體',
    );
  }

  Future<void> _setupMealReminders() async {
    List<MealReminder> reminders = _mealTimes.map((mealTime) {
      return MealReminder(
        mealName: mealTime.name,
        hour: mealTime.time.hour,
        minute: mealTime.time.minute,
        message: '該吃${mealTime.name}了！',
      );
    }).toList();

    await _notificationService.scheduleMealReminders(meals: reminders);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class MealTime {
  final String name;
  TimeOfDay time;

  MealTime(this.name, this.time);
}