// lib/services/water_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // 🕐 獲取台灣時間
  DateTime get _taiwanNow {
    return DateTime.now().toUtc().add(Duration(hours: 8));
  }

  // 🕐 獲取台灣日期字串
  String get _todayTaiwan {
    DateTime tw = _taiwanNow;
    return '${tw.year}-${tw.month.toString().padLeft(2, '0')}-${tw.day.toString().padLeft(2, '0')}';
  }

  // 🕐 將 Firestore Timestamp 轉為台灣時間
  DateTime _toTaiwanTime(Timestamp? timestamp) {
    if (timestamp == null) return _taiwanNow;
    return timestamp.toDate().toUtc().add(Duration(hours: 8));
  }

  // 🔥 獲取今日喝水總量
  Future<Map<String, dynamic>> getTodayWaterData() async {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // 轉換所有時間為台灣時間
        if (data['logs'] != null) {
          List<dynamic> logs = data['logs'];
          data['logs'] = logs.map((log) {
            if (log['timestamp'] != null) {
              DateTime twTime = _toTaiwanTime(log['timestamp']);
              log['timestamp'] = Timestamp.fromDate(twTime);
              log['displayTime'] = '${twTime.hour.toString().padLeft(2, '0')}:${twTime.minute.toString().padLeft(2, '0')}';
            }
            return log;
          }).toList();
        }
        
        return data;
      }

      // 返回預設值
      return {
        'date': today,
        'totalWater': 0,
        'targetWater': 2000,
        'logs': [],
      };
    } catch (e) {
      print('獲取今日喝水數據失敗: $e');
      return {
        'totalWater': 0,
        'targetWater': 2000,
        'logs': [],
      };
    }
  }

  // 🔥 添加喝水記錄（使用台灣時間）
  Future<void> addWaterLog({
    required int amount, // 毫升
    String? note,
  }) async {
    try {
      String userId = _currentUserId!;
      String today = _todayTaiwan;
      DateTime nowTaiwan = _taiwanNow;

      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('waterLogs')
          .doc(today);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);

        Map<String, dynamic> newLog = {
          'amount': amount,
          'timestamp': Timestamp.fromDate(nowTaiwan),
          'note': note ?? '',
          'displayTime': '${nowTaiwan.hour.toString().padLeft(2, '0')}:${nowTaiwan.minute.toString().padLeft(2, '0')}',
        };

        if (snapshot.exists) {
          // 更新現有記錄
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
          // 創建新記錄
          transaction.set(docRef, {
            'date': today,
            'totalWater': amount,
            'targetWater': 2000, // 預設目標
            'logs': [newLog],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 喝水記錄已添加: ${amount}ml at $nowTaiwan');
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

      // 同時更新用戶的預設目標
      await _firestore.collection('users').doc(userId).update({
        'waterTargetDefault': targetMl,
      });

      print('✅ 喝水目標已更新: ${targetMl}ml');
    } catch (e) {
      print('❌ 更新喝水目標失敗: $e');
      rethrow;
    }
  }

  // 🔥 獲取歷史記錄（最近7天，使用台灣時間）
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
        'completionRate': weekData.isNotEmpty ? ((daysCompleted / weekData.length) * 100).round() : 0,
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

  // 🔥 即時監聽今日喝水數據（主頁用）
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
              
              // 轉換時間為台灣時間
              if (data['logs'] != null) {
                List<dynamic> logs = data['logs'];
                data['logs'] = logs.map((log) {
                  if (log['timestamp'] != null) {
                    DateTime twTime = _toTaiwanTime(log['timestamp']);
                    log['displayTime'] = '${twTime.hour.toString().padLeft(2, '0')}:${twTime.minute.toString().padLeft(2, '0')}';
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

  // 🔥 僅獲取今日喝水總量（輕量版，主頁用）
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
}