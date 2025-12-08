// lib/services/workout_share_service.dart
// 🔗 訓練分享橋樑服務 v1.1
// ✅ 訓練完成自動通知教練
// ✅ 分享訓練記錄到聊天室
// ✅ 訓練感受記錄（RPE + 備註）
// ✅ 支援計畫訓練 + 自由訓練

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 訓練來源類型
enum WorkoutSource {
  plan,  // 計畫訓練（教練指派）
  free,  // 自由訓練（自主訓練）
}

/// 自由訓練類型
class FreeWorkoutType {
  static const String weightTraining = 'weight_training';
  static const String cardio = 'cardio';
  static const String yoga = 'yoga';
  static const String hiit = 'hiit';
  static const String stretching = 'stretching';
  static const String sports = 'sports';
  static const String other = 'other';
  
  static String getLabel(String type) {
    switch (type) {
      case weightTraining: return '重量訓練';
      case cardio: return '有氧運動';
      case yoga: return '瑜伽';
      case hiit: return 'HIIT';
      case stretching: return '伸展放鬆';
      case sports: return '運動競技';
      case other: return '其他';
      default: return '訓練';
    }
  }
  
  static String getEmoji(String type) {
    switch (type) {
      case weightTraining: return '🏋️';
      case cardio: return '🏃';
      case yoga: return '🧘';
      case hiit: return '⚡';
      case stretching: return '🤸';
      case sports: return '⚽';
      case other: return '💪';
      default: return '💪';
    }
  }
  
  static const List<Map<String, String>> options = [
    {'value': weightTraining, 'label': '重量訓練', 'emoji': '🏋️'},
    {'value': cardio, 'label': '有氧運動', 'emoji': '🏃'},
    {'value': yoga, 'label': '瑜伽', 'emoji': '🧘'},
    {'value': hiit, 'label': 'HIIT', 'emoji': '⚡'},
    {'value': stretching, 'label': '伸展放鬆', 'emoji': '🤸'},
    {'value': sports, 'label': '運動競技', 'emoji': '⚽'},
    {'value': other, 'label': '其他', 'emoji': '💪'},
  ];
}

/// 訓練感受記錄
class WorkoutFeedback {
  final int? rpe;                 // 運動自覺強度 1-10
  final String? fatigueLevel;     // 疲勞程度: low, medium, high, exhausted
  final String? mood;             // 心情: great, good, okay, tired, bad
  final String? note;             // 訓練備註
  final List<String>? painPoints; // 疼痛部位
  final bool needHelp;            // 是否需要教練協助
  final String? helpMessage;      // 求助訊息
  
  const WorkoutFeedback({
    this.rpe,
    this.fatigueLevel,
    this.mood,
    this.note,
    this.painPoints,
    this.needHelp = false,
    this.helpMessage,
  });
  
  Map<String, dynamic> toMap() {
    return {
      if (rpe != null) 'rpe': rpe,
      if (fatigueLevel != null) 'fatigueLevel': fatigueLevel,
      if (mood != null) 'mood': mood,
      if (note != null && note!.isNotEmpty) 'note': note,
      if (painPoints != null && painPoints!.isNotEmpty) 'painPoints': painPoints,
      'needHelp': needHelp,
      if (helpMessage != null && helpMessage!.isNotEmpty) 'helpMessage': helpMessage,
    };
  }
  
  factory WorkoutFeedback.fromMap(Map<String, dynamic> map) {
    return WorkoutFeedback(
      rpe: map['rpe'] as int?,
      fatigueLevel: map['fatigueLevel'] as String?,
      mood: map['mood'] as String?,
      note: map['note'] as String?,
      painPoints: (map['painPoints'] as List<dynamic>?)?.cast<String>(),
      needHelp: map['needHelp'] ?? false,
      helpMessage: map['helpMessage'] as String?,
    );
  }
  
  /// RPE 描述文字
  static String getRpeDescription(int rpe) {
    switch (rpe) {
      case 1:
      case 2:
        return '非常輕鬆';
      case 3:
      case 4:
        return '輕鬆';
      case 5:
      case 6:
        return '有點吃力';
      case 7:
      case 8:
        return '吃力';
      case 9:
      case 10:
        return '非常吃力';
      default:
        return '未知';
    }
  }
  
  /// 疲勞度選項
  static const List<Map<String, String>> fatigueLevels = [
    {'value': 'low', 'label': '精力充沛', 'emoji': '💪'},
    {'value': 'medium', 'label': '正常', 'emoji': '😊'},
    {'value': 'high', 'label': '有點累', 'emoji': '😮‍💨'},
    {'value': 'exhausted', 'label': '很疲憊', 'emoji': '😵'},
  ];
  
  /// 心情選項
  static const List<Map<String, String>> moods = [
    {'value': 'great', 'label': '超棒', 'emoji': '🔥'},
    {'value': 'good', 'label': '不錯', 'emoji': '😊'},
    {'value': 'okay', 'label': '一般', 'emoji': '😐'},
    {'value': 'tired', 'label': '疲憊', 'emoji': '😴'},
    {'value': 'bad', 'label': '不好', 'emoji': '😞'},
  ];
}

/// 訓練分享卡片資料
class WorkoutShareCard {
  final String sessionId;
  final WorkoutSource source;           // 訓練來源
  final String workoutName;
  final String? planName;               // 計畫訓練專用
  final String? planDayOfWeek;          // 計畫訓練專用
  final String? freeWorkoutType;        // 自由訓練類型
  final String? freeWorkoutCategory;    // 自由訓練分類（胸、背等）
  final int durationMinutes;
  final double caloriesBurned;
  final int exerciseCount;
  final int totalSets;
  final bool isOnSchedule;              // 計畫訓練專用
  final String statusLabel;             // 計畫：準時/提前/補做，自由：自主訓練
  final WorkoutFeedback? feedback;
  final DateTime completedAt;
  final Map<String, dynamic>? highlights;
  
  const WorkoutShareCard({
    required this.sessionId,
    required this.source,
    required this.workoutName,
    this.planName,
    this.planDayOfWeek,
    this.freeWorkoutType,
    this.freeWorkoutCategory,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.exerciseCount,
    required this.totalSets,
    this.isOnSchedule = true,
    required this.statusLabel,
    this.feedback,
    required this.completedAt,
    this.highlights,
  });
  
  /// 從計畫訓練創建
  factory WorkoutShareCard.fromPlan({
    required String sessionId,
    required String workoutName,
    required String planName,
    String? planDayOfWeek,
    required int durationMinutes,
    required double caloriesBurned,
    required int exerciseCount,
    required int totalSets,
    required bool isOnSchedule,
    required String statusLabel,
    WorkoutFeedback? feedback,
    required DateTime completedAt,
    Map<String, dynamic>? highlights,
  }) {
    return WorkoutShareCard(
      sessionId: sessionId,
      source: WorkoutSource.plan,
      workoutName: workoutName,
      planName: planName,
      planDayOfWeek: planDayOfWeek,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      exerciseCount: exerciseCount,
      totalSets: totalSets,
      isOnSchedule: isOnSchedule,
      statusLabel: statusLabel,
      feedback: feedback,
      completedAt: completedAt,
      highlights: highlights,
    );
  }
  
  /// 從自由訓練創建
  factory WorkoutShareCard.fromFree({
    required String sessionId,
    required String workoutName,
    required String freeWorkoutType,
    String? freeWorkoutCategory,
    required int durationMinutes,
    required double caloriesBurned,
    required int exerciseCount,
    required int totalSets,
    WorkoutFeedback? feedback,
    required DateTime completedAt,
    Map<String, dynamic>? highlights,
  }) {
    return WorkoutShareCard(
      sessionId: sessionId,
      source: WorkoutSource.free,
      workoutName: workoutName,
      freeWorkoutType: freeWorkoutType,
      freeWorkoutCategory: freeWorkoutCategory,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      exerciseCount: exerciseCount,
      totalSets: totalSets,
      isOnSchedule: true,
      statusLabel: '自主訓練',
      feedback: feedback,
      completedAt: completedAt,
      highlights: highlights,
    );
  }
  
  /// 是否為計畫訓練
  bool get isPlanWorkout => source == WorkoutSource.plan;
  
  /// 是否為自由訓練
  bool get isFreeWorkout => source == WorkoutSource.free;
  
  /// 取得顯示標題
  String get displayTitle {
    if (isPlanWorkout) {
      return planName ?? workoutName;
    } else {
      final emoji = FreeWorkoutType.getEmoji(freeWorkoutType ?? '');
      final typeLabel = FreeWorkoutType.getLabel(freeWorkoutType ?? '');
      if (freeWorkoutCategory != null && freeWorkoutCategory!.isNotEmpty) {
        return '$typeLabel - $freeWorkoutCategory';
      }
      return typeLabel;
    }
  }
  
  /// 取得副標題
  String? get displaySubtitle {
    if (isPlanWorkout) {
      return planDayOfWeek;
    } else {
      return workoutName.isNotEmpty ? workoutName : null;
    }
  }
  
  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'source': source == WorkoutSource.plan ? 'plan' : 'free',
      'workoutName': workoutName,
      if (planName != null) 'planName': planName,
      if (planDayOfWeek != null) 'planDayOfWeek': planDayOfWeek,
      if (freeWorkoutType != null) 'freeWorkoutType': freeWorkoutType,
      if (freeWorkoutCategory != null) 'freeWorkoutCategory': freeWorkoutCategory,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'exerciseCount': exerciseCount,
      'totalSets': totalSets,
      'isOnSchedule': isOnSchedule,
      'statusLabel': statusLabel,
      if (feedback != null) 'feedback': feedback!.toMap(),
      'completedAt': Timestamp.fromDate(completedAt),
      if (highlights != null) 'highlights': highlights,
    };
  }
  
  factory WorkoutShareCard.fromMap(Map<String, dynamic> map) {
    final sourceStr = map['source'] as String? ?? 'plan';
    final source = sourceStr == 'free' ? WorkoutSource.free : WorkoutSource.plan;
    final feedbackData = map['feedback'] as Map<String, dynamic>?;
    
    return WorkoutShareCard(
      sessionId: map['sessionId'] ?? '',
      source: source,
      workoutName: map['workoutName'] ?? '',
      planName: map['planName'],
      planDayOfWeek: map['planDayOfWeek'],
      freeWorkoutType: map['freeWorkoutType'],
      freeWorkoutCategory: map['freeWorkoutCategory'],
      durationMinutes: map['durationMinutes'] ?? 0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0,
      exerciseCount: map['exerciseCount'] ?? 0,
      totalSets: map['totalSets'] ?? 0,
      isOnSchedule: map['isOnSchedule'] ?? true,
      statusLabel: map['statusLabel'] ?? '',
      feedback: feedbackData != null ? WorkoutFeedback.fromMap(feedbackData) : null,
      completedAt: map['completedAt'] is Timestamp
          ? (map['completedAt'] as Timestamp).toDate()
          : DateTime.now(),
      highlights: map['highlights'] as Map<String, dynamic>?,
    );
  }
  
  /// 生成分享文字
  String generateShareText() {
    final buffer = StringBuffer();
    
    // 標題
    if (isPlanWorkout) {
      buffer.writeln('🏋️ 完成訓練：$planName');
      if (planDayOfWeek != null) {
        buffer.writeln('📅 $planDayOfWeek $statusLabel');
      }
    } else {
      final emoji = FreeWorkoutType.getEmoji(freeWorkoutType ?? '');
      final typeLabel = FreeWorkoutType.getLabel(freeWorkoutType ?? '');
      buffer.writeln('$emoji 完成訓練：$typeLabel');
      if (freeWorkoutCategory != null && freeWorkoutCategory!.isNotEmpty) {
        buffer.writeln('📋 分類：$freeWorkoutCategory');
      }
      buffer.writeln('🎯 自主訓練');
    }
    
    buffer.writeln('');
    
    // 訓練數據
    buffer.writeln('⏱️ 時長：$durationMinutes 分鐘');
    buffer.writeln('🔥 消耗：${caloriesBurned.toStringAsFixed(0)} 卡路里');
    buffer.writeln('💪 動作：$exerciseCount 個 / $totalSets 組');
    
    // 訓練亮點
    if (highlights != null) {
      buffer.writeln('');
      if (highlights!['maxWeight'] != null) {
        buffer.writeln('🏆 最大重量：${highlights!['maxWeight']}kg (${highlights!['maxWeightExercise']})');
      }
      if (highlights!['totalVolume'] != null) {
        buffer.writeln('📊 總訓練量：${(highlights!['totalVolume'] as num).toStringAsFixed(0)}kg');
      }
    }
    
    // 訓練感受
    if (feedback != null) {
      buffer.writeln('');
      if (feedback!.rpe != null) {
        buffer.writeln('📈 強度感受：${feedback!.rpe}/10 (${WorkoutFeedback.getRpeDescription(feedback!.rpe!)})');
      }
      if (feedback!.mood != null) {
        final moodInfo = WorkoutFeedback.moods.firstWhere(
          (m) => m['value'] == feedback!.mood,
          orElse: () => {'emoji': '', 'label': ''},
        );
        buffer.writeln('${moodInfo['emoji']} 心情：${moodInfo['label']}');
      }
      if (feedback!.note != null && feedback!.note!.isNotEmpty) {
        buffer.writeln('💬 備註：${feedback!.note}');
      }
    }
    
    return buffer.toString();
  }
}

/// 訓練分享橋樑服務
class WorkoutShareService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? get _currentUserId => _auth.currentUser?.uid;
  
  // ============================================================
  // 🔔 通知功能
  // ============================================================
  
  /// 獲取學員的所有教練
  Future<List<Map<String, dynamic>>> getMyCoaches() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    
    try {
      // 查詢配對關係
      final pairsSnapshot = await _firestore
          .collection('pairs')
          .where('traineeId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();
      
      final List<Map<String, dynamic>> coaches = [];
      
      for (final pairDoc in pairsSnapshot.docs) {
        final coachId = pairDoc.data()['coachId'] as String?;
        if (coachId == null) continue;
        
        // 獲取教練資料
        final coachDoc = await _firestore.collection('users').doc(coachId).get();
        if (coachDoc.exists) {
          final coachData = coachDoc.data() as Map<String, dynamic>;
          coaches.add({
            'id': coachId,
            'displayName': coachData['displayName'] ?? '教練',
            'email': coachData['email'],
            'photoUrl': coachData['photoUrl'],
          });
        }
      }
      
      return coaches;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 獲取教練列表失敗: $e');
      }
      return [];
    }
  }
  
  /// 訓練完成後通知教練
  Future<void> notifyCoachOnWorkoutComplete({
    required WorkoutShareCard shareCard,
    bool autoSend = true,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    
    try {
      // 獲取所有教練
      final coaches = await getMyCoaches();
      if (coaches.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ 沒有配對的教練，跳過通知');
        }
        return;
      }
      
      // 獲取學員名稱
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.data()?['displayName'] ?? '學員';
      
      // 為每個教練創建通知
      final batch = _firestore.batch();
      final needsHelp = shareCard.feedback?.needHelp ?? false;
      
      for (final coach in coaches) {
        final coachId = coach['id'] as String;
        
        // 根據是否需要協助決定通知類型和標題
        final notificationType = needsHelp ? 'workout_help_request' : 'workout_completed';
        final notificationTitle = needsHelp 
            ? '【需要協助】$userName 完成訓練'
            : '$userName 完成訓練';
        
        // 創建通知文檔
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': notificationType,
          'recipientId': coachId,
          'senderId': userId,
          'senderName': userName,
          'title': notificationTitle,
          'body': _buildNotificationBody(shareCard),
          'priority': needsHelp ? 'high' : 'normal',  // 高優先級
          'data': {
            'sessionId': shareCard.sessionId,
            'planName': shareCard.planName,
            'workoutName': shareCard.workoutName,
            'statusLabel': shareCard.statusLabel,
            'durationMinutes': shareCard.durationMinutes,
            'caloriesBurned': shareCard.caloriesBurned,
            'needHelp': needsHelp,
            'helpMessage': shareCard.feedback?.helpMessage,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('📤 發送通知給教練: ${coach['displayName']}');
        }
      }
      
      await batch.commit();
      
      if (kDebugMode) {
        debugPrint('✅ 已通知 ${coaches.length} 位教練');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 通知教練失敗: $e');
      }
    }
  }
  
  String _buildNotificationBody(WorkoutShareCard card) {
    final buffer = StringBuffer();
    
    if (card.planName != null) {
      buffer.write('${card.planName}');
      if (card.planDayOfWeek != null) {
        buffer.write(' - ${card.planDayOfWeek}');
      }
      buffer.write(' (${card.statusLabel})');
    } else {
      buffer.write(card.workoutName);
    }
    
    buffer.write('\n${card.durationMinutes}分鐘 / ${card.caloriesBurned.toStringAsFixed(0)}卡路里');
    
    if (card.feedback?.needHelp == true) {
      buffer.write('\n');
      if (card.feedback?.helpMessage != null && card.feedback!.helpMessage!.isNotEmpty) {
        buffer.write('求助訊息：${card.feedback!.helpMessage}');
      } else {
        buffer.write('學員標記需要協助，請主動關心');
      }
    }
    
    return buffer.toString();
  }
  
  // ============================================================
  // 💬 聊天室分享功能
  // ============================================================
  
  /// 分享訓練記錄到聊天室
  Future<void> shareToChat({
    required String chatRoomId,
    required WorkoutShareCard shareCard,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('用戶未登入');
    
    try {
      // 獲取聊天室資料
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (!chatRoomDoc.exists) {
        throw Exception('聊天室不存在');
      }
      
      final participants = List<String>.from(
        chatRoomDoc.data()?['participants'] ?? [],
      );
      
      final otherUserId = participants.firstWhere(
        (id) => id != userId,
        orElse: () => '',
      );
      
      // 創建訓練分享訊息
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'type': 'workout_share', // 特殊訊息類型
        'text': shareCard.generateShareText(),
        'senderId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'workoutData': shareCard.toMap(),
      });
      
      // 更新聊天室最後訊息
      final needsHelp = shareCard.feedback?.needHelp ?? false;
      final lastMessageText = needsHelp 
          ? '【需要協助】分享了訓練記錄'
          : '分享了訓練記錄';
      
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': lastMessageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': userId,
        'unreadCount': {
          otherUserId: FieldValue.increment(1),
        },
      });
      
      if (kDebugMode) {
        debugPrint('✅ 訓練記錄已分享到聊天室');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 分享到聊天室失敗: $e');
      }
      rethrow;
    }
  }
  
  /// 獲取與教練的聊天室 ID
  Future<String?> getChatRoomWithCoach(String coachId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    
    try {
      // 生成聊天室 ID（排序後組合）
      final participants = [userId, coachId];
      participants.sort();
      final chatRoomId = '${participants[0]}_${participants[1]}';
      
      // 檢查聊天室是否存在
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      if (chatRoomDoc.exists && chatRoomDoc.data()?['isActive'] == true) {
        return chatRoomId;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 創建或獲取與教練的聊天室
  Future<String> createOrGetChatRoom(String coachId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('用戶未登入');
    
    final participants = [userId, coachId];
    participants.sort();
    final chatRoomId = '${participants[0]}_${participants[1]}';
    
    final existingRoom = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .get();
    
    if (existingRoom.exists) {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'isActive': true,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      return chatRoomId;
    }
    
    await _firestore.collection('chatRooms').doc(chatRoomId).set({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': '',
      'isActive': true,
      'unreadCount': {
        userId: 0,
        coachId: 0,
      },
    });
    
    return chatRoomId;
  }
  
  // ============================================================
  // 📝 訓練感受記錄
  // ============================================================
  
  /// 保存訓練感受
  Future<void> saveFeedback({
    required String sessionId,
    required WorkoutFeedback feedback,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('用戶未登入');
    
    try {
      // 更新 workoutSessions
      await _firestore
          .collection('workoutSessions')
          .doc(sessionId)
          .update({
        'feedback': feedback.toMap(),
        'feedbackAt': FieldValue.serverTimestamp(),
      });
      
      // 如果有求助訊息，也更新 workoutCompletions
      if (feedback.needHelp) {
        final completionQuery = await _firestore
            .collection('workoutCompletions')
            .where('sessionId', isEqualTo: sessionId)
            .limit(1)
            .get();
        
        if (completionQuery.docs.isNotEmpty) {
          await completionQuery.docs.first.reference.update({
            'needHelp': true,
            'helpMessage': feedback.helpMessage,
          });
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ 訓練感受已保存');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 保存訓練感受失敗: $e');
      }
      rethrow;
    }
  }
  
  /// 獲取訓練感受
  Future<WorkoutFeedback?> getFeedback(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('workoutSessions')
          .doc(sessionId)
          .get();
      
      if (!doc.exists) return null;
      
      final feedbackData = doc.data()?['feedback'] as Map<String, dynamic>?;
      if (feedbackData == null) return null;
      
      return WorkoutFeedback.fromMap(feedbackData);
    } catch (e) {
      return null;
    }
  }
  
  // ============================================================
  // 📊 一鍵完成：通知 + 分享 + 感受
  // ============================================================
  
  /// 完成訓練後的完整流程
  /// 1. 保存訓練感受
  /// 2. 通知教練
  /// 3. 可選：自動分享到聊天室
  Future<void> completeWorkoutWithFeedback({
    required WorkoutShareCard shareCard,
    required WorkoutFeedback feedback,
    bool notifyCoach = true,
    bool autoShareToChat = false,
  }) async {
    // 1. 保存感受
    await saveFeedback(
      sessionId: shareCard.sessionId,
      feedback: feedback,
    );
    
    // 更新 shareCard 的 feedback
    final updatedCard = WorkoutShareCard(
      sessionId: shareCard.sessionId,
      source: shareCard.source,                       // 🔥 修正：加入 source
      workoutName: shareCard.workoutName,
      planName: shareCard.planName,
      planDayOfWeek: shareCard.planDayOfWeek,
      freeWorkoutType: shareCard.freeWorkoutType,     // 🔥 修正：加入自由訓練欄位
      freeWorkoutCategory: shareCard.freeWorkoutCategory,
      durationMinutes: shareCard.durationMinutes,
      caloriesBurned: shareCard.caloriesBurned,
      exerciseCount: shareCard.exerciseCount,
      totalSets: shareCard.totalSets,
      isOnSchedule: shareCard.isOnSchedule,
      statusLabel: shareCard.statusLabel,
      feedback: feedback,
      completedAt: shareCard.completedAt,
      highlights: shareCard.highlights,
    );
    
    // 2. 通知教練
    if (notifyCoach) {
      await notifyCoachOnWorkoutComplete(shareCard: updatedCard);
    }
    
    // 3. 自動分享到聊天室（如果啟用）
    if (autoShareToChat) {
      final coaches = await getMyCoaches();
      for (final coach in coaches) {
        final chatRoomId = await getChatRoomWithCoach(coach['id']);
        if (chatRoomId != null) {
          await shareToChat(chatRoomId: chatRoomId, shareCard: updatedCard);
        }
      }
    }
  }
}