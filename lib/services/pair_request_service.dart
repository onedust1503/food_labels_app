import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PairRequestStatus {
  pending,    // 待處理
  accepted,   // 已接受
  rejected,   // 已拒絕
  cancelled,  // 已取消
}

class PairRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromUserName;
  final String toUserName;
  final PairRequestStatus status;
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
      status: _parseStatus(data['status']),
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  static PairRequestStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted': return PairRequestStatus.accepted;
      case 'rejected': return PairRequestStatus.rejected;
      case 'cancelled': return PairRequestStatus.cancelled;
      default: return PairRequestStatus.pending;
    }
  }
}

class PairRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// 🔍 檢查配對狀態
  Future<PairRequestStatus?> checkPairStatus(String coachId, String studentId) async {
    try {
      // 檢查是否已配對
      final pairId = _generatePairId(coachId, studentId);
      final pairDoc = await _firestore.collection('pairs').doc(pairId).get();
      
      if (pairDoc.exists && pairDoc.data()?['status'] == 'active') {
        return PairRequestStatus.accepted;
      }

      // 檢查待處理請求
      final requestQuery = await _firestore
          .collection('pairRequests')
          .where('coachId', isEqualTo: coachId)
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        return null; // 無請求
      }

      final latestRequest = requestQuery.docs.first.data();
      return PairRequest._parseStatus(latestRequest['status']);
    } catch (e) {
      print('檢查配對狀態錯誤: $e');
      return null;
    }
  }

  /// 📤 發送配對請求
Future<String> sendPairRequest({
  required String coachId,
  String? message,
}) async {
  try {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw Exception('用戶未登入');
    }

    // 獲取用戶資料
    final studentDoc = await _firestore.collection('users').doc(currentUserId).get();
    final coachDoc = await _firestore.collection('users').doc(coachId).get();

    if (!studentDoc.exists || !coachDoc.exists) {
      throw Exception('用戶資料不存在');
    }

    final studentData = studentDoc.data() as Map<String, dynamic>;
    final coachData = coachDoc.data() as Map<String, dynamic>;

    // 檢查現有狀態
    final existingStatus = await checkPairStatus(coachId, currentUserId);
    if (existingStatus == PairRequestStatus.accepted) {
      throw Exception('已經與此教練配對');
    }
    if (existingStatus == PairRequestStatus.pending) {
      throw Exception('已有待處理的配對請求');
    }

    // 創建配對請求（統一使用 coachId 和 studentId）
    final requestDoc = await _firestore.collection('pairRequests').add({
      'coachId': coachId,
      'studentId': currentUserId,
      'coachName': coachData['displayName'] ?? '教練',
      'studentName': studentData['displayName'] ?? '學員',
      'fromUserId': currentUserId,
      'toUserId': coachId,
      'fromUserName': studentData['displayName'] ?? '學員',
      'toUserName': coachData['displayName'] ?? '教練',
      'status': 'pending',
      'message': message ?? '希望能與您配對學習健身，請多指教！',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });

    print('✅ 配對請求已發送: ${requestDoc.id}');
    return requestDoc.id;
  } catch (e) {
    print('❌ 發送配對請求失敗: $e');
    rethrow;
  }
}

  /// ✅ 接受配對請求（教練使用）
  Future<String> acceptPairRequest(String requestId) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      return await _firestore.runTransaction((transaction) async {
        // 獲取請求資料
        final requestRef = _firestore.collection('pairRequests').doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('配對請求不存在');
        }

        final requestData = requestDoc.data() as Map<String, dynamic>;

        // 驗證權限
        if (requestData['coachId'] != currentUserId) {
          throw Exception('無權限處理此請求');
        }

        if (requestData['status'] != 'pending') {
          throw Exception('請求已被處理');
        }

        final coachId = requestData['coachId'];
        final studentId = requestData['studentId'];
        final pairId = _generatePairId(coachId, studentId);

        // 創建配對記錄
        final pairRef = _firestore.collection('pairs').doc(pairId);
        transaction.set(pairRef, {
          'coachId': coachId,
          'traineeId': studentId,
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
        final chatRoomId = _generateChatRoomId(coachId, studentId);
        final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
        transaction.set(chatRoomRef, {
          'participants': [coachId, studentId],
          'participantRoles': {
            coachId: 'coach',
            studentId: 'trainee',
          },
          'pairId': pairId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageSender': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'isActive': true,
          'unreadCount': {
            coachId: 0,
            studentId: 0,
          },
        });

        print('✅ 配對成功: $pairId');
        return pairId;
      });
    } catch (e) {
      print('❌ 接受配對請求失敗: $e');
      rethrow;
    }
  }

  /// ❌ 拒絕配對請求
  Future<void> rejectPairRequest(String requestId) async {
    try {
      await _firestore.collection('pairRequests').doc(requestId).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      print('✅ 已拒絕配對請求: $requestId');
    } catch (e) {
      print('❌ 拒絕配對請求失敗: $e');
      rethrow;
    }
  }

  /// 📋 獲取收到的配對請求（教練查看）
  Stream<List<PairRequest>> getReceivedRequestsStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('pairRequests')
        .where('coachId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PairRequest.fromFirestore(doc))
            .toList());
  }

  /// 📋 獲取已發送的配對請求（學員查看）
  Stream<List<PairRequest>> getSentRequestsStream() {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('pairRequests')
        .where('studentId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PairRequest.fromFirestore(doc))
            .toList());
  }

  /// 🔗 獲取聊天室ID
  Future<String?> getChatRoomIdByPair(String coachId, String studentId) async {
    try {
      return _generateChatRoomId(coachId, studentId);
    } catch (e) {
      print('獲取聊天室ID失敗: $e');
      return null;
    }
  }

  /// 🗑️ 取消配對
  Future<void> cancelPairing(String pairId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final pairRef = _firestore.collection('pairs').doc(pairId);
        
        transaction.update(pairRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // 停用聊天室
        final pairDoc = await transaction.get(pairRef);
        if (pairDoc.exists) {
          final coachId = pairDoc.data()?['coachUid'];
          final studentId = pairDoc.data()?['traineeUid'];
          
          if (coachId != null && studentId != null) {
            final chatRoomId = _generateChatRoomId(coachId, studentId);
            final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
            
            transaction.update(chatRoomRef, {
              'isActive': false,
              'cancelledAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
      
      print('✅ 已取消配對: $pairId');
    } catch (e) {
      print('❌ 取消配對失敗: $e');
      rethrow;
    }
  }

  // 🔧 輔助方法

  String _generatePairId(String coachId, String studentId) {
    return '${coachId}_$studentId';
  }

  String _generateChatRoomId(String userId1, String userId2) {
    final participants = [userId1, userId2];
    participants.sort();
    return '${participants[0]}_${participants[1]}';
  }
}