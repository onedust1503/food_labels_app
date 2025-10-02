import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  bool isMe(String currentUserId) => senderId == currentUserId;
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

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

      // 生成一致的聊天室ID（按字母順序排列用戶ID）
      final participants = [currentUserId, otherUserId];
      participants.sort();
      final chatRoomId = '${participants[0]}_${participants[1]}';

      // 檢查聊天室是否已存在
      final existingChatRoom = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();

      if (existingChatRoom.exists) {
        // 聊天室已存在，更新活躍狀態
        await _firestore.collection('chatRooms').doc(chatRoomId).update({
          'isActive': true,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
        return chatRoomId;
      }

      // 創建新聊天室
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

  // 發送訊息（更新：增加對方的未讀計數）
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

      // 獲取聊天室信息以找到對方的 ID
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();
      
      final participants = List<String>.from(
        chatRoomDoc.data()?['participants'] ?? []
      );
      
      // 找出對方的 ID
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      // 添加訊息到子集合
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 更新聊天室資訊和未讀計數
      final updates = {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'isActive': true,
      };

      // 增加對方的未讀計數
      if (otherUserId.isNotEmpty) {
        updates['unreadCount.$otherUserId'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(chatRoomId).update(updates);
    } catch (e) {
      throw Exception('發送訊息失敗: $e');
    }
  }

  // 獲取訊息流
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

  // 標記聊天室為已讀（新增方法）
  Future<void> markAsRead(String chatRoomId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) return;

      // 重置當前用戶的未讀計數
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'unreadCount.$currentUserId': 0,
      });

      print('✅ 已標記聊天室為已讀: $chatRoomId');
    } catch (e) {
      print('❌ 標記已讀失敗: $e');
    }
  }

  // 標記聊天室為已讀（舊方法，保持向後兼容）
  Future<void> markChatRoomAsRead(String chatRoomId) async {
    await markAsRead(chatRoomId);
  }

  // 新增：獲取當前用戶的總未讀訊息數
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

  // 獲取聊天室列表
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

  // 刪除聊天室
  Future<void> deleteChatRoom(String chatRoomId) async {
    try {
      // 軟刪除：標記為非活躍狀態
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('刪除聊天室失敗: $e');
    }
  }

  // 獲取聊天室資訊
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
}