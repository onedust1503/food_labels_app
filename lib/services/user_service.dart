import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // 獲取推薦教練
  Future<List<DocumentSnapshot>> getRecommendedCoaches({int limit = 20}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(limit)
          .get();
      
      // 客戶端排序
      List<DocumentSnapshot> coaches = snapshot.docs;
      coaches.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = aData['displayName'] ?? '';
        final bName = bData['displayName'] ?? '';
        return aName.compareTo(bName);
      });
      
      return coaches;
    } catch (e) {
      throw Exception('獲取教練列表失敗: $e');
    }
  }

  // 搜索教練
  Future<List<DocumentSnapshot>> searchCoaches({
    String? query,
    List<String>? specialties,
    int limit = 20,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(limit * 2)
          .get();
      
      List<DocumentSnapshot> results = snapshot.docs;
      
      // 客戶端過濾
      if (query != null && query.isNotEmpty) {
        final searchTerm = query.toLowerCase();
        results = results.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] ?? '').toLowerCase();
          final bio = (data['bio'] ?? '').toLowerCase();
          return name.contains(searchTerm) || bio.contains(searchTerm);
        }).toList();
      }
      
      if (specialties != null && specialties.isNotEmpty) {
        results = results.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docSpecialties = List<String>.from(data['specialties'] ?? []);
          return specialties.any((selected) =>
            docSpecialties.any((specialty) =>
              specialty.toLowerCase().contains(selected.toLowerCase())
            )
          );
        }).toList();
      }
      
      // 客戶端排序和限制
      results.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = aData['displayName'] ?? '';
        final bName = bData['displayName'] ?? '';
        return aName.compareTo(bName);
      });
      
      return results.take(limit).toList();
    } catch (e) {
      throw Exception('搜索教練失敗: $e');
    }
  }

  // 簡化：檢查配對關係（避免複雜查詢）
  Future<bool> isCoachStudentPaired(String coachId, String studentId) async {
    try {
      // 簡化查詢，只檢查基本配對
      final doc = await _firestore
          .collection('pairs')
          .doc('${coachId}_$studentId')
          .get();
      
      return doc.exists && 
             (doc.data()?['status'] == 'active');
    } catch (e) {
      print('檢查配對關係失敗: $e');
      return false;
    }
  }

  // 修正：創建配對（使用確定性的文檔 ID）
  Future<String> createCoachStudentPair(String coachId, String studentId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      // 使用確定性的文檔 ID
      final pairId = '${coachId}_$studentId';
      
      // 檢查是否已經配對
      final existingPair = await _firestore
          .collection('pairs')
          .doc(pairId)
          .get();
          
      if (existingPair.exists) {
        final data = existingPair.data() as Map<String, dynamic>;
        if (data['status'] == 'active') {
          return pairId; // 已經存在活躍配對
        }
      }

      // 創建或更新配對文檔
      await _firestore.collection('pairs').doc(pairId).set({
        'coachUid': coachId,
        'traineeUid': studentId,
        'status': 'active',
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('成功創建配對: $pairId');
      return pairId;
    } catch (e) {
      print('創建配對失敗: $e');
      throw Exception('創建配對關係失敗: $e');
    }
  }

  // 修正：獲取教練的學員列表
  Future<List<DocumentSnapshot>> getCoachStudents(String coachId) async {
    try {
      print('查詢教練 $coachId 的學員...');
      
      // 簡化查詢：先獲取所有配對記錄
      final QuerySnapshot allPairs = await _firestore
          .collection('pairs')
          .get();
      
      print('總共找到 ${allPairs.docs.length} 個配對記錄');
      
      // 客戶端過濾教練的配對
      List<String> studentIds = [];
      for (final doc in allPairs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('檢查配對記錄: ${data}');
        
        if (data['coachUid'] == coachId && data['status'] == 'active') {
          final studentId = data['traineeUid'] as String?;
          if (studentId != null && studentId.isNotEmpty) {
            studentIds.add(studentId);
            print('找到學員ID: $studentId');
          }
        }
      }

      print('找到 ${studentIds.length} 個配對的學員ID');
      
      if (studentIds.isEmpty) {
        return [];
      }

      // 獲取學員資料
      List<DocumentSnapshot> students = [];
      
      for (final studentId in studentIds) {
        try {
          final studentDoc = await _firestore
              .collection('users')
              .doc(studentId)
              .get();
          
          if (studentDoc.exists) {
            students.add(studentDoc);
            print('成功獲取學員資料: ${studentDoc.data()}');
          }
        } catch (e) {
          print('獲取學員 $studentId 資料失敗: $e');
        }
      }

      print('最終返回 ${students.length} 個學員');
      return students;
    } catch (e) {
      print('獲取學員列表失敗: $e');
      return [];
    }
  }

  // 獲取學員的教練列表
  Future<List<DocumentSnapshot>> getStudentCoaches(String studentId) async {
    try {
      // 簡化查詢
      final QuerySnapshot allPairs = await _firestore
          .collection('pairs')
          .get();

      List<String> coachIds = [];
      for (final doc in allPairs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['traineeUid'] == studentId && data['status'] == 'active') {
          final coachId = data['coachUid'] as String?;
          if (coachId != null && coachId.isNotEmpty) {
            coachIds.add(coachId);
          }
        }
      }

      if (coachIds.isEmpty) {
        return [];
      }

      List<DocumentSnapshot> coaches = [];
      for (final coachId in coachIds) {
        try {
          final coachDoc = await _firestore
              .collection('users')
              .doc(coachId)
              .get();
          if (coachDoc.exists) {
            coaches.add(coachDoc);
          }
        } catch (e) {
          print('獲取教練 $coachId 資料失敗: $e');
        }
      }

      return coaches;
    } catch (e) {
      throw Exception('獲取教練列表失敗: $e');
    }
  }

  // 獲取用戶統計數據
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      // 模擬統計數據
      return {
        'totalWorkouts': 15,
        'streak': 7,
        'completionRate': 85,
        'totalCalories': 2400,
      };
    } catch (e) {
      return {
        'totalWorkouts': 0,
        'streak': 0,
        'completionRate': 0,
        'totalCalories': 0,
      };
    }
  }

  // 取消配對
  Future<void> unpairCoachStudent(String coachId, String studentId) async {
    try {
      final pairId = '${coachId}_$studentId';
      await _firestore.collection('pairs').doc(pairId).update({
        'status': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('取消配對失敗: $e');
    }
  }

  // 獲取用戶詳細資料
  Future<DocumentSnapshot?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  // 更新用戶資料
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('更新用戶資料失敗: $e');
    }
  }
}