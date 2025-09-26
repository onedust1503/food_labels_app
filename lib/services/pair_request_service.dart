import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // 發送配對請求
  Future<String> sendPairRequest({
    required String coachId,
    required String coachName,
    String? message,
  }) async {
    try {
      final currentUserId = this.currentUserId;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      // 獲取當前用戶資料
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final studentName = userData['displayName'] ?? '學員';

      // 檢查是否已經有配對請求或配對關係
      final existingRequest = await _firestore
          .collection('pairRequests')
          .where('studentId', isEqualTo: currentUserId)
          .where('coachId', isEqualTo: coachId)
          .where('status', whereIn: ['pending', 'accepted'])
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        final status = existingRequest.docs.first.data()['status'];
        if (status == 'pending') {
          throw Exception('已經向此教練發送過配對請求，請等待回應');
        } else if (status == 'accepted') {
          throw Exception('已經與此教練配對成功');
        }
      }

      // 創建配對請求
      final requestDoc = await _firestore.collection('pairRequests').add({
        'studentId': currentUserId,
        'coachId': coachId,
        'studentName': studentName,
        'coachName': coachName,
        'status': 'pending',
        'message': message ?? '希望能與您配對學習健身，請多指教！',
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      print('配對請求已發送: ${requestDoc.id}');
      return requestDoc.id;
    } catch (e) {
      print('發送配對請求失敗: $e');
      throw Exception('發送配對請求失敗: $e');
    }
  }

  // 檢查是否有待處理的請求
  Future<bool> hasPendingRequest(String coachId, String studentId) async {
    try {
      final requestQuery = await _firestore
          .collection('pairRequests')
          .where('coachId', isEqualTo: coachId)
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      return requestQuery.docs.isNotEmpty;
    } catch (e) {
      print('檢查待處理請求失敗: $e');
      return false;
    }
  }

  // 取消配對請求
  Future<void> cancelPairRequest(String requestId) async {
    try {
      await _firestore.collection('pairRequests').doc(requestId).update({
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('取消配對請求失敗: $e');
    }
  }
}