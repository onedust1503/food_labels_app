// lib/services/water_service.dart
// 🎯 增強版喝水服務 - 支援編輯、自訂水杯、進階分析
// 🔧 修復版 - 解決類型錯誤

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  DateTime get _taiwanNow => DateTime.now().toUtc().add(const Duration(hours: 8));

  String get _todayTaiwan {
    DateTime tw = _taiwanNow;
    return '${tw.year}-${tw.month.toString().padLeft(2, '0')}-${tw.day.toString().padLeft(2, '0')}';
  }

  DateTime _toTaiwanTime(Timestamp? timestamp) {
    if (timestamp == null) return _taiwanNow;
    return timestamp.toDate().toUtc().add(const Duration(hours: 8));
  }

  // ✨ 新增：編輯記錄
  Future<void> editWaterLog({
    required String date,
    required int logIndex,
    required int newAmount,
    DateTime? newTime,
    String? newNote,
  }) async {
    try {
      String userId = _currentUserId!;

      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(date);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          List<dynamic> logs = List.from(data['logs'] ?? []);

          if (logIndex >= 0 && logIndex < logs.length) {
            int oldAmount = logs[logIndex]['amount'] ?? 0;
            
            // 更新記錄
            logs[logIndex]['amount'] = newAmount;
            if (newTime != null) {
              logs[logIndex]['timestamp'] = Timestamp.fromDate(newTime);
              logs[logIndex]['displayTime'] = 
                  '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
            }
            if (newNote != null) {
              logs[logIndex]['note'] = newNote;
            }

            // 更新總量
            int currentTotal = data['totalWater'] ?? 0;
            int newTotal = currentTotal - oldAmount + newAmount;
            if (newTotal < 0) newTotal = 0;

            transaction.update(docRef, {
              'totalWater': newTotal,
              'logs': logs,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      print('✅ 喝水記錄已編輯');
    } catch (e) {
      print('❌ 編輯喝水記錄失敗: $e');
      rethrow;
    }
  }

  // ✨ 新增：獲取自訂水杯列表
  Future<List<int>> getCustomCups() async {
    try {
      String userId = _currentUserId!;
      
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('customWaterCups')) {
          return List<int>.from(data['customWaterCups']);
        }
      }

      // 預設水杯容量
      return [100, 200, 300, 500];
    } catch (e) {
      print('獲取自訂水杯失敗: $e');
      return [100, 200, 300, 500];
    }
  }

  // ✨ 新增:更新自訂水杯
  Future<void> updateCustomCups(List<int> cups) async {
    try {
      String userId = _currentUserId!;
      
      await _firestore.collection('users').doc(userId).update({
        'customWaterCups': cups,
      });

      print('✅ 自訂水杯已更新');
    } catch (e) {
      print('❌ 更新自訂水杯失敗: $e');
      rethrow;
    }
  }

  // 🔥 添加喝水記錄（使用台灣時間）
  Future<void> addWaterLog({
    required int amount,
    String? note,
    DateTime? customTime,  // 允許自訂時間
  }) async {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;
      DateTime recordTime = customTime ?? _taiwanNow;

      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        Map<String, dynamic> newLog = {
          'amount': amount,
          'timestamp': Timestamp.fromDate(recordTime),
          'note': note ?? '',
          'displayTime': '${recordTime.hour.toString().padLeft(2, '0')}:${recordTime.minute.toString().padLeft(2, '0')}',
        };

        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          int currentTotal = data['totalWater'] ?? 0;
          List<dynamic> logs = List.from(data['logs'] ?? []);

          logs.add(newLog);

          transaction.update(docRef, {
            'totalWater': currentTotal + amount,
            'logs': logs,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(docRef, {
            'date': today,
            'totalWater': amount,
            'targetWater': 2000,
            'logs': [newLog],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 喝水記錄已添加: ${amount}ml at $recordTime');
    } catch (e) {
      print('❌ 添加喝水記錄失敗: $e');
      rethrow;
    }
  }

  // 🔥 刪除喝水記錄
  Future<void> deleteWaterLog({
    required String date,
    required int logIndex,
  }) async {
    try {
      String userId = _currentUserId!;

      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(date);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          List<dynamic> logs = List.from(data['logs'] ?? []);

          if (logIndex >= 0 && logIndex < logs.length) {
            int deletedAmount = logs[logIndex]['amount'] ?? 0;
            logs.removeAt(logIndex);

            int newTotal = (data['totalWater'] ?? 0) - deletedAmount;
            if (newTotal < 0) newTotal = 0;

            transaction.update(docRef, {
              'totalWater': newTotal,
              'logs': logs,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      print('✅ 喝水記錄已刪除');
    } catch (e) {
      print('❌ 刪除喝水記錄失敗: $e');
      rethrow;
    }
  }

  // 🔥 更新每日喝水目標
  Future<void> updateWaterTarget(int targetMl) async {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;

      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today);

      DocumentSnapshot snapshot = await docRef.get();

      if (snapshot.exists) {
        await docRef.update({
          'targetWater': targetMl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'date': today,
          'totalWater': 0,
          'targetWater': targetMl,
          'logs': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('users').doc(userId).update({
        'waterTargetDefault': targetMl,
      });

      print('✅ 喝水目標已更新: ${targetMl}ml');
    } catch (e) {
      print('❌ 更新喝水目標失敗: $e');
      rethrow;
    }
  }

  // 🔥 獲取歷史記錄
  Future<List<Map<String, dynamic>>> getRecentWaterLogs({int days = 7}) async {
    try {
      String userId = _currentUserId!;
      DateTime nowTaiwan = _taiwanNow;
      List<Map<String, dynamic>> results = [];

      for (int i = 0; i < days; i++) {
        DateTime date = nowTaiwan.subtract(Duration(days: i));
        String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('waterLogs')
            .doc(dateStr)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          results.add({
            'date': dateStr,
            'totalWater': data['totalWater'] ?? 0,
            'targetWater': data['targetWater'] ?? 2000,
            'logs': data['logs'] ?? [],
          });
        } else {
          results.add({
            'date': dateStr,
            'totalWater': 0,
            'targetWater': 2000,
            'logs': [],
          });
        }
      }

      return results;
    } catch (e) {
      print('獲取歷史記錄失敗: $e');
      return [];
    }
  }

  // 📊 新增：每小時攝水量分析 (修復版)
  Future<Map<int, int>> getHourlyDistribution({int days = 7}) async {
    try {
      String userId = _currentUserId!;
      Map<int, int> hourlyData = {};
      
      // 初始化 0-23 小時
      for (int i = 0; i < 24; i++) {
        hourlyData[i] = 0;
      }

      List<Map<String, dynamic>> recentLogs = await getRecentWaterLogs(days: days);
      
      for (var dayData in recentLogs) {
        List<dynamic> logs = dayData['logs'] ?? [];
        for (var log in logs) {
          if (log['timestamp'] != null) {
            DateTime time = _toTaiwanTime(log['timestamp']);
            int hour = time.hour;
            // 🔧 修復：確保 amount 轉換為 int
            int amount = (log['amount'] is int) 
                ? log['amount'] as int 
                : (log['amount'] as num).toInt();
            hourlyData[hour] = (hourlyData[hour] ?? 0) + amount;
          }
        }
      }

      return hourlyData;
    } catch (e) {
      print('獲取每小時分佈失敗: $e');
      return {};
    }
  }

  // 📊 新增：本月達標率趨勢
  Future<Map<String, dynamic>> getMonthlyTrend() async {
    try {
      String userId = _currentUserId!;
      DateTime nowTaiwan = _taiwanNow;
      
      List<bool> dailyCompletion = [];
      int totalWater = 0;
      int completedDays = 0;

      for (int i = 1; i <= nowTaiwan.day; i++) {
        DateTime date = DateTime(nowTaiwan.year, nowTaiwan.month, i);
        String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('waterLogs')
            .doc(dateStr)
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int dayTotal = data['totalWater'] ?? 0;
          int dayTarget = data['targetWater'] ?? 2000;
          
          totalWater += dayTotal;
          bool completed = dayTotal >= dayTarget;
          dailyCompletion.add(completed);
          if (completed) completedDays++;
        } else {
          dailyCompletion.add(false);
        }
      }

      return {
        'dailyCompletion': dailyCompletion,
        'completionRate': nowTaiwan.day > 0 
            ? ((completedDays / nowTaiwan.day) * 100).round() 
            : 0,
        'totalWater': totalWater,
        'avgDaily': nowTaiwan.day > 0 
            ? (totalWater / nowTaiwan.day).round() 
            : 0,
        'completedDays': completedDays,
        'totalDays': nowTaiwan.day,
      };
    } catch (e) {
      print('獲取本月趨勢失敗: $e');
      return {};
    }
  }

  // 📊 新增：喝水時間熱力圖數據
  Future<Map<String, dynamic>> getDrinkingPattern({int days = 30}) async {
    try {
      Map<int, Map<int, int>> pattern = {}; // [hour][weekday] = count
      
      for (int hour = 0; hour < 24; hour++) {
        pattern[hour] = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
      }

      List<Map<String, dynamic>> recentLogs = await getRecentWaterLogs(days: days);
      
      for (var dayData in recentLogs) {
        DateTime date = DateTime.parse(dayData['date']);
        int weekday = date.weekday;
        
        List<dynamic> logs = dayData['logs'] ?? [];
        for (var log in logs) {
          if (log['timestamp'] != null) {
            DateTime time = _toTaiwanTime(log['timestamp']);
            int hour = time.hour;
            pattern[hour]![weekday] = (pattern[hour]![weekday] ?? 0) + 1;
          }
        }
      }

      return {
        'pattern': pattern,
        'peakHour': _findPeakHour(pattern),
        'peakDay': _findPeakDay(pattern),
      };
    } catch (e) {
      print('獲取喝水模式失敗: $e');
      return {};
    }
  }

  int _findPeakHour(Map<int, Map<int, int>> pattern) {
    int peakHour = 0;
    int maxCount = 0;
    
    pattern.forEach((hour, weekdayData) {
      int hourTotal = weekdayData.values.reduce((a, b) => a + b);
      if (hourTotal > maxCount) {
        maxCount = hourTotal;
        peakHour = hour;
      }
    });
    
    return peakHour;
  }

  int _findPeakDay(Map<int, Map<int, int>> pattern) {
    Map<int, int> dayTotals = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    
    pattern.forEach((hour, weekdayData) {
      weekdayData.forEach((day, count) {
        dayTotals[day] = (dayTotals[day] ?? 0) + count;
      });
    });
    
    int peakDay = 1;
    int maxCount = 0;
    dayTotals.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        peakDay = day;
      }
    });
    
    return peakDay;
  }

  // 🔥 獲取本週統計
  Future<Map<String, dynamic>> getWeeklyStats() async {
    try {
      List<Map<String, dynamic>> weekData = await getRecentWaterLogs(days: 7);
      
      int totalWater = 0;
      int daysCompleted = 0;
      
      for (var day in weekData) {
        int dayTotal = day['totalWater'] ?? 0;
        int dayTarget = day['targetWater'] ?? 2000;
        
        totalWater += dayTotal;
        if (dayTotal >= dayTarget) {
          daysCompleted++;
        }
      }

      int avgDaily = weekData.isNotEmpty ? (totalWater / weekData.length).round() : 0;

      return {
        'totalWater': totalWater,
        'avgDaily': avgDaily,
        'daysCompleted': daysCompleted,
        'completionRate': weekData.isNotEmpty 
            ? ((daysCompleted / weekData.length) * 100).round() 
            : 0,
      };
    } catch (e) {
      print('獲取本週統計失敗: $e');
      return {
        'totalWater': 0,
        'avgDaily': 0,
        'daysCompleted': 0,
        'completionRate': 0,
      };
    }
  }

  // 🔥 即時監聽今日喝水數據
  Stream<Map<String, dynamic>> getTodayWaterStream() {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists) {
              Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
              
              if (data['logs'] != null) {
                List<dynamic> logs = data['logs'];
                data['logs'] = logs.map((log) {
                  if (log['timestamp'] != null) {
                    DateTime twTime = _toTaiwanTime(log['timestamp']);
                    log['displayTime'] = 
                        '${twTime.hour.toString().padLeft(2, '0')}:${twTime.minute.toString().padLeft(2, '0')}';
                  }
                  return log;
                }).toList();
              }
              
              return data;
            }
            return {
              'date': today,
              'totalWater': 0,
              'targetWater': 2000,
              'logs': [],
            };
          });
    } catch (e) {
      print('監聽今日喝水數據失敗: $e');
      return Stream.value({
        'totalWater': 0,
        'targetWater': 2000,
        'logs': [],
      });
    }
  }

  // 🔥 僅獲取今日喝水總量
  Stream<int> getTodayWaterTotalStream() {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists) {
              return (snapshot.data()?['totalWater'] ?? 0) as int;
            }
            return 0;
          });
    } catch (e) {
      print('監聽今日喝水總量失敗: $e');
      return Stream.value(0);
    }
  }

  // 💡 AI 健康建議
  String getHealthAdvice(Map<String, dynamic> weeklyStats, Map<int, int> hourlyData) {
    int avgDaily = weeklyStats['avgDaily'] ?? 0;
    int completionRate = weeklyStats['completionRate'] ?? 0;
    
    // 找出最常喝水的時段
    int peakHour = 0;
    int maxAmount = 0;
    hourlyData.forEach((hour, amount) {
      if (amount > maxAmount) {
        maxAmount = amount;
        peakHour = hour;
      }
    });

    if (avgDaily < 1500) {
      return '💧 您的日均攝水量偏低,建議增加到2000ml以上,有助於新陳代謝和皮膚健康。';
    } else if (completionRate < 50) {
      return '📈 本週達標率${completionRate}%,建議設定鬧鐘提醒自己定時喝水。';
    } else if (maxAmount > 0 && peakHour >= 20) {
      return '🌙 您常在晚上${peakHour}點後喝水較多,建議將攝水時間提前,避免影響睡眠。';
    } else if (completionRate >= 80) {
      return '🎉 太棒了!您的喝水習慣很好,本週達標率${completionRate}%,繼續保持!';
    } else {
      return '💪 您的喝水狀況良好,可以嘗試在上午和下午各補充500ml水分。';
    }
  }
}