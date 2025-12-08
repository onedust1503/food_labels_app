// lib/services/chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/result.dart';
import '../providers/network_provider.dart';

// ========== 數據模型 ==========

enum MessageType {
  text,
  image,
  system,
  workoutShare,
}

/// 🆕 回覆引用資料
class ReplyData {
  final String messageId;
  final String messageType;
  final String previewText;
  final String? senderName;
  final Map<String, dynamic>? workoutData;
  
  ReplyData({
    required this.messageId,
    required this.messageType,
    required this.previewText,
    this.senderName,
    this.workoutData,
  });
  
  factory ReplyData.fromMap(Map<String, dynamic> map) {
    return ReplyData(
      messageId: map['messageId'] ?? '',
      messageType: map['messageType'] ?? 'text',
      previewText: map['previewText'] ?? '',
      senderName: map['senderName'],
      workoutData: map['workoutData'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'messageType': messageType,
      'previewText': previewText,
      if (senderName != null) 'senderName': senderName,
      if (workoutData != null) 'workoutData': workoutData,
    };
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;
  final String? imageUrl;
  final int? fileSize;
  final Map<String, dynamic>? workoutData;
  final ReplyData? replyTo;  // 🆕 回覆引用

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.isRead,
    required this.type,
    this.imageUrl,
    this.fileSize,
    this.workoutData,
    this.replyTo,  // 🆕
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      switch (data['type']) {
        case 'image':
          messageType = MessageType.image;
          break;
        case 'system':
          messageType = MessageType.system;
          break;
        case 'workout_share':
          messageType = MessageType.workoutShare;
          break;
        default:
          messageType = MessageType.text;
      }
    }

    // 🆕 解析回覆資料
    ReplyData? replyData;
    if (data['replyTo'] != null) {
      replyData = ReplyData.fromMap(data['replyTo'] as Map<String, dynamic>);
    }

    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: messageType,
      imageUrl: data['imageUrl'],
      fileSize: data['fileSize'],
      workoutData: data['workoutData'] as Map<String, dynamic>?,
      replyTo: replyData,  // 🆕
    );
  }

  bool isMe(String currentUserId) => senderId == currentUserId;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ========== ✅ 原有方法 - 完全保留 ==========

  /// 創建或獲取聊天室（防止重複）
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      if (currentUserId == otherUserId) {
        throw Exception('不能與自己創建聊天室');
      }

      final participants = [currentUserId, otherUserId];
      participants.sort();
      final chatRoomId = '${participants[0]}_${participants[1]}';

      final existingChatRoom = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();

      if (existingChatRoom.exists) {
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
          currentUserId: 0,
          otherUserId: 0,
        },
      });

      return chatRoomId;
    } catch (e) {
      throw Exception('創建聊天室失敗: $e');
    }
  }

  /// 🔔 發送文字訊息（已加入推播通知）
  /// 🆕 新增 replyTo 參數支援回覆功能
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    ReplyData? replyTo,  // 🆕 回覆引用
  }) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      if (text.trim().isEmpty) {
        throw Exception('訊息內容不能為空');
      }

      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      final participants = List<String>.from(
        chatRoomDoc.data()?['participants'] ?? []
      );
      
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      // 創建訊息（🆕 包含回覆資料）
      final messageData = <String, dynamic>{
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      };
      
      // 🆕 如果有回覆引用，加入訊息資料
      if (replyTo != null) {
        messageData['replyTo'] = replyTo.toMap();
        debugPrint('📤 發送訊息帶回覆: previewText="${replyTo.previewText}", senderName="${replyTo.senderName}"');
      } else {
        debugPrint('📤 發送訊息不帶回覆');
      }

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      // 更新聊天室資訊
      final updates = <String, dynamic>{
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'isActive': true,
      };

      if (otherUserId.isNotEmpty) {
        updates['unreadCount.$otherUserId'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);

      // 🔔 發送推播通知
      try {
        final String? recipientId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        
        if (recipientId != null && recipientId.isNotEmpty) {
          final senderDoc = await _firestore.collection('users').doc(currentUserId).get();
          final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
          
          final senderName = senderDoc.data()?['displayName'] ?? '用戶';
          final String? fcmToken = recipientDoc.data()?['fcmToken'];
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _firestore.collection('notifications').add({
              'to': fcmToken,
              'notification': {
                'title': senderName,
                'body': text.length > 100 ? '${text.substring(0, 100)}...' : text,
                'sound': 'default',
              },
              'data': {
                'chatId': chatRoomId,
                'type': 'chat_message',
                'senderId': currentUserId,
              },
              'createdAt': FieldValue.serverTimestamp(),
              'sent': false,
            });
            
            debugPrint('✅ 訊息通知已排程：發送給 $recipientId');
          }
        }
      } catch (e) {
        debugPrint('❌ 發送通知時發生錯誤: $e');
      }
    } catch (e) {
      throw Exception('發送訊息失敗: $e');
    }
  }

  /// 🔔 發送圖片訊息（已加入推播通知）
  Future<void> sendImageMessage({
    required String chatRoomId,
    required File imageFile,
    ReplyData? replyTo,  // 🆕 回覆引用
  }) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      final imageUrl = await uploadImage(imageFile, chatRoomId);
      final fileSize = await imageFile.length();

      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      final participants = List<String>.from(
        chatRoomDoc.data()?['participants'] ?? []
      );
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      // 創建圖片訊息（🆕 包含回覆資料）
      final messageData = <String, dynamic>{
        'text': '[圖片]',
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'image',
        'imageUrl': imageUrl,
        'fileSize': fileSize,
      };
      
      // 🆕 如果有回覆引用，加入訊息資料
      if (replyTo != null) {
        messageData['replyTo'] = replyTo.toMap();
      }

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageData);

      // 更新聊天室資訊
      final updates = <String, dynamic>{
        'lastMessage': '[圖片]',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'isActive': true,
      };

      if (otherUserId.isNotEmpty) {
        updates['unreadCount.$otherUserId'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);

      // 🔔 發送圖片推播通知
      try {
        final String? recipientId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        
        if (recipientId != null && recipientId.isNotEmpty) {
          final senderDoc = await _firestore.collection('users').doc(currentUserId).get();
          final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
          
          final senderName = senderDoc.data()?['displayName'] ?? '用戶';
          final String? fcmToken = recipientDoc.data()?['fcmToken'];
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await _firestore.collection('notifications').add({
              'to': fcmToken,
              'notification': {
                'title': senderName,
                'body': '[圖片]',
                'sound': 'default',
              },
              'data': {
                'chatId': chatRoomId,
                'type': 'chat_message',
                'senderId': currentUserId,
                'imageUrl': imageUrl,
              },
              'createdAt': FieldValue.serverTimestamp(),
              'sent': false,
            });
            
            debugPrint('✅ 圖片通知已排程');
          }
        }
      } catch (e) {
        debugPrint('❌ 發送圖片通知時發生錯誤: $e');
      }
    } catch (e) {
      throw Exception('發送圖片失敗: $e');
    }
  }

  /// 上傳圖片到 Firebase Storage
  Future<String> uploadImage(File imageFile, String chatRoomId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final storageRef = _storage.ref().child('chats/$chatRoomId/$fileName');

      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('上傳圖片失敗: $e');
    }
  }

  /// 獲取訊息流
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  /// 標記聊天室為已讀
  Future<void> markAsRead(String chatRoomId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) return;

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'unreadCount.$currentUserId': 0,
      });

      debugPrint('✅ 已標記聊天室為已讀: $chatRoomId');
    } catch (e) {
      debugPrint('❌ 標記已讀失敗: $e');
    }
  }

  Future<void> markChatRoomAsRead(String chatRoomId) async {
    await markAsRead(chatRoomId);
  }

  /// 獲取總未讀數流
  Stream<int> getTotalUnreadCountStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          int totalUnread = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
            if (unreadCount != null && unreadCount.containsKey(currentUserId)) {
              totalUnread += (unreadCount[currentUserId] as int?) ?? 0;
            }
          }
          debugPrint('📊 總未讀數: $totalUnread');
          return totalUnread;
        });
  }

  /// 獲取聊天室列表流
  Stream<QuerySnapshot> getChatRoomsStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// 刪除聊天室（軟刪除）
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('刪除聊天室失敗: $e');
    }
  }

  /// 獲取聊天室資訊
  Future<DocumentSnapshot?> getChatRoomInfo(String chatRoomId) async {
    try {
      final doc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  // ========== 🆕 回覆功能工具方法 ==========

  /// 從訊息創建回覆資料
  ReplyData createReplyDataFromMessage(ChatMessage message, {String? senderName}) {
    String previewText;
    String messageType;
    
    switch (message.type) {
      case MessageType.image:
        previewText = '[圖片]';
        messageType = 'image';
        break;
      case MessageType.workoutShare:
        final workoutName = message.workoutData?['workoutName'] ?? '訓練記錄';
        final planName = message.workoutData?['planName'];
        previewText = planName ?? workoutName;
        messageType = 'workout_share';
        break;
      case MessageType.system:
        previewText = message.text;
        messageType = 'system';
        break;
      default:
        previewText = message.text.length > 50 
            ? '${message.text.substring(0, 50)}...'
            : message.text;
        messageType = 'text';
    }
    
    return ReplyData(
      messageId: message.id,
      messageType: messageType,
      previewText: previewText,
      senderName: senderName,
      workoutData: message.workoutData,
    );
  }
  
  /// 從訓練資料創建回覆資料（用於回覆訓練卡片）
  /// 注意：如果是需要協助的回覆，previewText 顯示求助訊息（helpMessage）
  ReplyData createReplyDataFromWorkout(
    Map<String, dynamic> workoutData, {
    String? senderName,
  }) {
    final planName = workoutData['planName'] as String?;
    final workoutName = workoutData['workoutName'] as String? ?? '訓練記錄';
    final planDayOfWeek = workoutData['planDayOfWeek'] as String?;
    final needsHelp = workoutData['feedback']?['needHelp'] == true;
    final helpMessage = workoutData['feedback']?['helpMessage'] as String?;
    
    // 決定 previewText
    String previewText;
    if (needsHelp && helpMessage != null && helpMessage.isNotEmpty) {
      // 🆕 協助回覆：顯示學生的求助訊息
      previewText = helpMessage;
    } else {
      // 一般訓練回覆：顯示訓練名稱
      previewText = planName ?? workoutName;
      if (planDayOfWeek != null && planDayOfWeek.isNotEmpty) {
        previewText = '$previewText - $planDayOfWeek';
      }
    }
    
    return ReplyData(
      messageId: workoutData['sessionId'] ?? '',
      messageType: 'workout_share',
      previewText: previewText,
      senderName: senderName,
      workoutData: workoutData,  // 保留完整資料，UI 層可以判斷 needHelp
    );
  }

  // ========== 🆕 Safe 方法 - 完整錯誤處理 ==========

  /// 🆕 創建或獲取聊天室（Safe 版本）
  Future<Result<String>> createOrGetChatRoomSafe(String otherUserId) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network());
      }

      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized(
          message: '請先登入才能使用聊天功能',
        ));
      }

      if (otherUserId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '用戶 ID 不能為空',
        ));
      }

      if (currentUserId == otherUserId) {
        return Result.failure(AppException.validation(
          message: '不能與自己創建聊天室',
        ));
      }

      final chatRoomId = await createOrGetChatRoom(otherUserId);
      
      debugPrint('✅ 聊天室創建/獲取成功: $chatRoomId');
      return Result.success(chatRoomId);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 創建聊天室失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 發送文字訊息（Safe 版本）
  Future<Result<void>> sendMessageSafe({
    required String chatRoomId,
    required String text,
    ReplyData? replyTo,  // 🆕
  }) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法發送訊息',
        ));
      }

      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized(
          message: '請先登入才能發送訊息',
        ));
      }

      if (chatRoomId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '聊天室 ID 不能為空',
        ));
      }

      if (text.trim().isEmpty) {
        return Result.failure(AppException.validation(
          message: '訊息內容不能為空',
        ));
      }

      await sendMessage(chatRoomId: chatRoomId, text: text, replyTo: replyTo);
      
      debugPrint('✅ 訊息發送成功');
      return Result.success(null);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 發送訊息失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 發送圖片訊息（Safe 版本）
  Future<Result<void>> sendImageMessageSafe({
    required String chatRoomId,
    required File imageFile,
    ReplyData? replyTo,  // 🆕
  }) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法發送圖片',
        ));
      }

      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized(
          message: '請先登入才能發送圖片',
        ));
      }

      if (chatRoomId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '聊天室 ID 不能為空',
        ));
      }

      if (!await imageFile.exists()) {
        return Result.failure(AppException.validation(
          message: '圖片檔案不存在',
        ));
      }

      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        return Result.failure(AppException.validation(
          message: '圖片大小不能超過 10MB',
        ));
      }

      await sendImageMessage(chatRoomId: chatRoomId, imageFile: imageFile, replyTo: replyTo);
      
      debugPrint('✅ 圖片發送成功');
      return Result.success(null);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: '圖片上傳失敗：${_handleFirebaseError(e)}',
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 發送圖片失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 上傳圖片（Safe 版本）
  Future<Result<String>> uploadImageSafe(File imageFile, String chatRoomId) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法上傳圖片',
        ));
      }

      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized());
      }

      if (!await imageFile.exists()) {
        return Result.failure(AppException.validation(
          message: '圖片檔案不存在',
        ));
      }

      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        return Result.failure(AppException.validation(
          message: '圖片大小不能超過 10MB',
        ));
      }

      final imageUrl = await uploadImage(imageFile, chatRoomId);
      
      debugPrint('✅ 圖片上傳成功: $imageUrl');
      return Result.success(imageUrl);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase Storage 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: '圖片上傳失敗：${_handleFirebaseError(e)}',
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 上傳圖片失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 刪除聊天室（Safe 版本）
  Future<Result<void>> deleteChatRoomSafe(String chatRoomId) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network());
      }

      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized());
      }

      if (chatRoomId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '聊天室 ID 不能為空',
        ));
      }

      await deleteChatRoom(chatRoomId);
      
      debugPrint('✅ 聊天室刪除成功');
      return Result.success(null);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 刪除聊天室失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 獲取聊天室資訊（Safe 版本）
  Future<Result<DocumentSnapshot?>> getChatRoomInfoSafe(String chatRoomId) async {
    try {
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network());
      }

      if (chatRoomId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '聊天室 ID 不能為空',
        ));
      }

      final doc = await getChatRoomInfo(chatRoomId);
      
      return Result.success(doc);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 獲取聊天室資訊失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  // ========== 輔助方法 ==========

  /// 處理 Firebase 錯誤訊息
  String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return '您沒有權限執行此操作';
      case 'not-found':
        return '找不到聊天室或訊息';
      case 'already-exists':
        return '聊天室已存在';
      case 'unavailable':
        return '服務暫時無法使用，請稍後再試';
      case 'deadline-exceeded':
        return '請求超時，請檢查網路連接';
      case 'unauthenticated':
        return '請先登入';
      case 'resource-exhausted':
        return '操作過於頻繁，請稍後再試';
      default:
        return '操作失敗，請稍後再試';
    }
  }
}