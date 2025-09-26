// lib/services/pairing_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PairStatus {
  none,           // 未配對
  requestPending, // 請求待處理
  paired,         // 已配對
  rejected,       // 被拒絕
}

class PairRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromUserName;
  final String toUserName;
  final String status;
  final String message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  PairRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUserName,
    required this.toUserName,
    required this.status,
    required this.message,
    required this.createdAt,
    this.respondedAt,
  });

  factory PairRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PairRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserName: data['toUserName'] ?? '',
      status: data['status'] ?? 'pending',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class PairingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // 🎯 核心方法：檢查配對狀態
  Future<PairStatus> getPairStatus(String otherUserId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) return PairStatus.none;

      // 檢查是否已配對
      final isPaired = await _isPaired(currentUserId, otherUserId);
      if (isPaired) return PairStatus.paired;

      // 檢查是否有待處理的請求
      final hasPendingRequest = await _hasPendingRequest(currentUserId, otherUserId);
      if (hasPendingRequest) return PairStatus.requestPending;

      // 檢查是否被拒絕（24小時內）
      final wasRejected = await _wasRecentlyRejected(currentUserId, otherUserId);
      if (wasRejected) return PairStatus.rejected;

      return PairStatus.none;
    } catch (e) {
      print('檢查配對狀態失敗: $e');
      return PairStatus.none;
    }
  }

  // 🚀 發送配對請求
  Future<String> sendPairRequest({
    required String toUserId,
    required String message,
  }) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      if (currentUserId == toUserId) {
        throw Exception('不能向自己發送配對請求');
      }

      // 檢查當前狀態
      final status = await getPairStatus(toUserId);
      if (status == PairStatus.paired) {
        throw Exception('已經與此用戶配對');
      }
      if (status == PairStatus.requestPending) {
        throw Exception('已經發送過配對請求，請等待回應');
      }
      if (status == PairStatus.rejected) {
        throw Exception('請稍後再試');
      }

      // 獲取用戶資料
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final toUserDoc = await _firestore.collection('users').doc(toUserId).get();
      
      if (!currentUserDoc.exists || !toUserDoc.exists) {
        throw Exception('用戶資料不存在');
      }

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final toUserData = toUserDoc.data() as Map<String, dynamic>;

      // 創建配對請求
      final requestDoc = await _firestore.collection('pairRequests').add({
        'fromUserId': currentUserId,
        'toUserId': toUserId,
        'fromUserName': currentUserData['displayName'] ?? '用戶',
        'toUserName': toUserData['displayName'] ?? '用戶',
        'fromUserRole': currentUserData['role'] ?? 'trainee',
        'toUserRole': toUserData['role'] ?? 'coach',
        'status': 'pending',
        'message': message.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      // TODO: 發送推送通知給目標用戶
      await _sendPairRequestNotification(toUserId, currentUserData['displayName'] ?? '用戶');

      print('配對請求已發送: ${requestDoc.id}');
      return requestDoc.id;
    } catch (e) {
      print('發送配對請求失敗: $e');
      rethrow;
    }
  }

  // ✅ 接受配對請求
  Future<String> acceptPairRequest(String requestId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      // 使用事務確保數據一致性
      return await _firestore.runTransaction((transaction) async {
        // 獲取請求資料
        final requestRef = _firestore.collection('pairRequests').doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('配對請求不存在');
        }

        final requestData = requestDoc.data() as Map<String, dynamic>;
        
        // 驗證請求
        if (requestData['toUserId'] != currentUserId) {
          throw Exception('無權限處理此請求');
        }
        if (requestData['status'] != 'pending') {
          throw Exception('請求已被處理');
        }

        final fromUserId = requestData['fromUserId'];
        final coachId = requestData['toUserRole'] == 'coach' ? currentUserId : fromUserId;
        final traineeId = requestData['toUserRole'] == 'coach' ? fromUserId : currentUserId;

        // 創建配對記錄
        final pairId = '${coachId}_$traineeId';
        final pairRef = _firestore.collection('pairs').doc(pairId);
        
        transaction.set(pairRef, {
          'coachId': coachId,
          'traineeId': traineeId,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUserId,
          'requestId': requestId,
        });

        // 更新請求狀態
        transaction.update(requestRef, {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        // 創建聊天室
        final participants = [coachId, traineeId];
        participants.sort();
        final chatRoomId = '${participants[0]}_${participants[1]}';
        final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
        
        transaction.set(chatRoomRef, {
          'participants': participants,
          'participantRoles': {
            coachId: 'coach',
            traineeId: 'trainee'
          },
          'pairId': pairId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageSender': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'isActive': true,
          'unreadCount': {
            coachId: 0,
            traineeId: 0,
          },
        });

        return pairId;
      });
    } catch (e) {
      print('接受配對請求失敗: $e');
      rethrow;
    }
  }

  // ❌ 拒絕配對請求
  Future<void> rejectPairRequest(String requestId) async {
    try {
      await _firestore.collection('pairRequests').doc(requestId).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('拒絕配對請求失敗: $e');
      rethrow;
    }
  }

  // 📋 獲取待處理的配對請求
  Stream<List<PairRequest>> getPendingRequestsStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('pairRequests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PairRequest.fromFirestore(doc))
            .toList());
  }

  // 📋 獲取已發送的配對請求
  Stream<List<PairRequest>> getSentRequestsStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('pairRequests')
        .where('fromUserId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PairRequest.fromFirestore(doc))
            .toList());
  }

  // 🔗 根據配對ID獲取聊天室ID
  Future<String?> getChatRoomIdByPairId(String pairId) async {
    try {
      final query = await _firestore
          .collection('chatRooms')
          .where('pairId', isEqualTo: pairId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty ? query.docs.first.id : null;
    } catch (e) {
      print('獲取聊天室ID失敗: $e');
      return null;
    }
  }

  // 🗑️ 取消配對
  Future<void> cancelPairing(String pairId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final pairRef = _firestore.collection('pairs').doc(pairId);
        
        // 更新配對狀態
        transaction.update(pairRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // 停用相關聊天室
        final chatRoomQuery = await _firestore
            .collection('chatRooms')
            .where('pairId', isEqualTo: pairId)
            .get();

        for (final chatRoomDoc in chatRoomQuery.docs) {
          transaction.update(chatRoomDoc.reference, {
            'isActive': false,
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('取消配對失敗: $e');
      rethrow;
    }
  }

  // 🔍 私有輔助方法

  Future<bool> _isPaired(String userId1, String userId2) async {
    try {
      final participants = [userId1, userId2];
      participants.sort();
      final pairId = '${participants[0]}_${participants[1]}';
      
      final doc = await _firestore.collection('pairs').doc(pairId).get();
      return doc.exists && (doc.data()?['status'] == 'active');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasPendingRequest(String userId1, String userId2) async {
    try {
      // 檢查雙向請求
      final query1 = await _firestore
          .collection('pairRequests')
          .where('fromUserId', isEqualTo: userId1)
          .where('toUserId', isEqualTo: userId2)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      final query2 = await _firestore
          .collection('pairRequests')
          .where('fromUserId', isEqualTo: userId2)
          .where('toUserId', isEqualTo: userId1)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return query1.docs.isNotEmpty || query2.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _wasRecentlyRejected(String userId1, String userId2) async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      
      final query = await _firestore
          .collection('pairRequests')
          .where('fromUserId', isEqualTo: userId1)
          .where('toUserId', isEqualTo: userId2)
          .where('status', isEqualTo: 'rejected')
          .where('respondedAt', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendPairRequestNotification(String toUserId, String fromUserName) async {
    // TODO: 實現推送通知
    // 可以使用 Firebase Cloud Messaging (FCM)
    print('應該發送配對請求通知給 $toUserId，來自 $fromUserName');
  }
}