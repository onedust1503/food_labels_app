import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// ✅ 新增：訊息類型枚舉
enum MessageType {
  text,
  image,
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  // ✅ 新增：圖片相關欄位（使用預設值保持向後兼容）
  final MessageType type;
  final String? imageUrl;
  final int? fileSize;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,  // 預設為文字訊息
    this.imageUrl,
    this.fileSize,
  });

  // ✅ 更新：從 Firestore 讀取時支援圖片欄位
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 讀取訊息類型，如果沒有則預設為 text
    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      try {
        messageType = MessageType.values.firstWhere(
          (e) => e.toString() == 'MessageType.${data['type']}',
          orElse: () => MessageType.text,
        );
      } catch (e) {
        messageType = MessageType.text;
      }
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
    );
  }

  bool isMe(String currentUserId) => senderId == currentUserId;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ========== 原有功能保持不變 ==========

  // 創建或獲取聊天室（防止重複）
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

  // 發送訊息（保持原功能）
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
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

      // ✅ 加入 type 欄位，但保持向後兼容
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',  // ✅ 新增但不影響舊訊息
      });

      final updates = {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'isActive': true,
      };

      if (otherUserId.isNotEmpty) {
        updates['unreadCount.$otherUserId'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);
    } catch (e) {
      throw Exception('發送訊息失敗: $e');
    }
  }

  // 獲取訊息流（保持原功能）
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

  // 標記聊天室為已讀（保持原功能）
  Future<void> markAsRead(String chatRoomId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) return;

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'unreadCount.$currentUserId': 0,
      });

      print('✅ 已標記聊天室為已讀: $chatRoomId');
    } catch (e) {
      print('❌ 標記已讀失敗: $e');
    }
  }

  Future<void> markChatRoomAsRead(String chatRoomId) async {
    await markAsRead(chatRoomId);
  }

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
          print('📊 總未讀數: $totalUnread');
          return totalUnread;
        });
  }

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

  // ========== ✅ 新增：圖片上傳功能 ==========

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

  /// 發送圖片訊息
  Future<void> sendImageMessage({
    required String chatRoomId,
    required File imageFile,
  }) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      // 上傳圖片
      final imageUrl = await uploadImage(imageFile, chatRoomId);
      
      // 獲取檔案大小
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

      // 創建圖片訊息
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': '[圖片]',
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'image',
        'imageUrl': imageUrl,
        'fileSize': fileSize,
      });

      // 更新聊天室資訊
      final updates = {
        'lastMessage': '[圖片]',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'isActive': true,
      };

      if (otherUserId.isNotEmpty) {
        updates['unreadCount.$otherUserId'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);
    } catch (e) {
      throw Exception('發送圖片失敗: $e');
    }
  }
}