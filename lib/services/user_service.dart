import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // 🆕 用於 debugPrint
import '../utils/result.dart'; // 🆕 引入 Result 封裝
import '../providers/network_provider.dart'; // 🆕 引入網路檢查

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ========== ✅ 原有方法 - 完全保留，一個字都不改 ==========

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

  // 修正：檢查配對關係（統一使用 coachId 和 traineeId）
  Future<bool> isCoachStudentPaired(String coachId, String studentId) async {
    try {
      // 使用一致的 pairId 格式：coachId_studentId
      final pairId = '${coachId}_$studentId';
      
      final doc = await _firestore
          .collection('pairs')
          .doc(pairId)
          .get();
      
      return doc.exists && (doc.data()?['status'] == 'active');
    } catch (e) {
      print('檢查配對關係失敗: $e');
      return false;
    }
  }

  // 創建配對（使用確定性的文檔 ID）
  Future<String> createCoachStudentPair(String coachId, String studentId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('用戶未登入');
      }

      // 使用確定性的文檔 ID（coachId_studentId 格式）
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

      // 創建或更新配對文檔（只使用 coachId 和 traineeId）
      await _firestore.collection('pairs').doc(pairId).set({
        'coachId': coachId,
        'traineeId': studentId,
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

  // 修正：獲取教練的學員列表（只使用 coachId 和 traineeId）
  Future<List<DocumentSnapshot>> getCoachStudents(String coachId) async {
    try {
      print('查詢教練 $coachId 的學員...');
      
      // 簡化查詢：先獲取所有配對記錄
      final QuerySnapshot allPairs = await _firestore
          .collection('pairs')
          .get();
      
      print('總共找到 ${allPairs.docs.length} 個配對記錄');
      
      // 客戶端過濾教練的配對（只使用 coachId）
      List<String> studentIds = [];
      for (final doc in allPairs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('檢查配對記錄: $data');
        
        // 只檢查 coachId 欄位
        if (data['coachId'] == coachId && data['status'] == 'active') {
          final studentId = data['traineeId'];
          if (studentId != null && studentId.isNotEmpty) {
            studentIds.add(studentId as String);
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

  // 修正：獲取學員的教練列表（只使用 traineeId 和 coachId）
  Future<List<DocumentSnapshot>> getStudentCoaches(String studentId) async {
    try {
      // 簡化查詢
      final QuerySnapshot allPairs = await _firestore
          .collection('pairs')
          .get();

      List<String> coachIds = [];
      for (final doc in allPairs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // 只檢查 traineeId 欄位
        if (data['traineeId'] == studentId && data['status'] == 'active') {
          final coachId = data['coachId'];
          if (coachId != null && coachId.isNotEmpty) {
            coachIds.add(coachId as String);
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

  // ========== 🆕 新增 Safe 方法 - 完整錯誤處理 ==========

  /// 🆕 獲取推薦教練（Safe 版本）
  Future<Result<List<DocumentSnapshot>>> getRecommendedCoachesSafe({
    int limit = 20,
  }) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法載入教練列表',
        ));
      }

      // 驗證參數
      if (limit <= 0) {
        return Result.failure(AppException.validation(
          message: '限制數量必須大於 0',
        ));
      }

      // 執行原有邏輯
      final coaches = await getRecommendedCoaches(limit: limit);
      
      debugPrint('✅ 成功獲取 ${coaches.length} 位推薦教練');
      return Result.success(coaches);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 獲取推薦教練失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 搜索教練（Safe 版本）
  Future<Result<List<DocumentSnapshot>>> searchCoachesSafe({
    String? query,
    List<String>? specialties,
    int limit = 20,
  }) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法搜索教練',
        ));
      }

      // 驗證參數
      if (limit <= 0) {
        return Result.failure(AppException.validation(
          message: '限制數量必須大於 0',
        ));
      }

      // 執行原有邏輯
      final results = await searchCoaches(
        query: query,
        specialties: specialties,
        limit: limit,
      );
      
      debugPrint('✅ 搜索到 ${results.length} 位教練');
      return Result.success(results);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 搜索教練失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 檢查配對關係（Safe 版本）
  Future<Result<bool>> isCoachStudentPairedSafe(
    String coachId,
    String studentId,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network());
      }

      // 驗證參數
      if (coachId.isEmpty || studentId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '教練或學員 ID 不能為空',
        ));
      }

      if (coachId == studentId) {
        return Result.failure(AppException.validation(
          message: '教練和學員不能是同一人',
        ));
      }

      // 執行原有邏輯
      final isPaired = await isCoachStudentPaired(coachId, studentId);
      
      debugPrint('✅ 配對檢查完成: $isPaired');
      return Result.success(isPaired);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 檢查配對關係失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 創建配對（Safe 版本）
  Future<Result<String>> createCoachStudentPairSafe(
    String coachId,
    String studentId,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法建立配對',
        ));
      }

      // 檢查是否登入
      if (currentUserId == null) {
        return Result.failure(AppException.unauthorized(
          message: '請先登入才能建立配對',
        ));
      }

      // 驗證參數
      if (coachId.isEmpty || studentId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '教練或學員 ID 不能為空',
        ));
      }

      if (coachId == studentId) {
        return Result.failure(AppException.validation(
          message: '教練和學員不能是同一人',
        ));
      }

      // 執行原有邏輯
      final pairId = await createCoachStudentPair(coachId, studentId);
      
      debugPrint('✅ 配對創建成功: $pairId');
      return Result.success(pairId);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 創建配對失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 獲取教練的學員列表（Safe 版本）
  Future<Result<List<DocumentSnapshot>>> getCoachStudentsSafe(
    String coachId,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法載入學員列表',
        ));
      }

      // 驗證參數
      if (coachId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '教練 ID 不能為空',
        ));
      }

      // 執行原有邏輯
      final students = await getCoachStudents(coachId);
      
      debugPrint('✅ 成功獲取 ${students.length} 位學員');
      return Result.success(students);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 獲取學員列表失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 獲取學員的教練列表（Safe 版本）
  Future<Result<List<DocumentSnapshot>>> getStudentCoachesSafe(
    String studentId,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法載入教練列表',
        ));
      }

      // 驗證參數
      if (studentId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '學員 ID 不能為空',
        ));
      }

      // 執行原有邏輯
      final coaches = await getStudentCoaches(studentId);
      
      debugPrint('✅ 成功獲取 ${coaches.length} 位教練');
      return Result.success(coaches);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 獲取教練列表失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 獲取用戶統計數據（Safe 版本）
  Future<Result<Map<String, dynamic>>> getUserStatsSafe(String userId) async {
    try {
      // 檢查網路狀態（如果需要從伺服器獲取）
      // 這個方法目前是模擬數據，所以可以不檢查網路
      
      // 驗證參數
      if (userId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '用戶 ID 不能為空',
        ));
      }

      // 執行原有邏輯
      final stats = await getUserStats(userId);
      
      debugPrint('✅ 成功獲取用戶統計數據');
      return Result.success(stats);
      
    } catch (e) {
      debugPrint('❌ 獲取統計數據失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 取消配對（Safe 版本）
  Future<Result<void>> unpairCoachStudentSafe(
    String coachId,
    String studentId,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法取消配對',
        ));
      }

      // 驗證參數
      if (coachId.isEmpty || studentId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '教練或學員 ID 不能為空',
        ));
      }

      // 執行原有邏輯
      await unpairCoachStudent(coachId, studentId);
      
      debugPrint('✅ 配對已取消');
      return Result.success(null);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 取消配對失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 獲取用戶詳細資料（Safe 版本）
  Future<Result<DocumentSnapshot?>> getUserDataSafe(String userId) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法載入用戶資料',
        ));
      }

      // 驗證參數
      if (userId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '用戶 ID 不能為空',
        ));
      }

      // 執行原有邏輯
      final userData = await getUserData(userId);
      
      if (userData == null) {
        debugPrint('⚠️ 找不到用戶資料');
      } else {
        debugPrint('✅ 成功獲取用戶資料');
      }
      
      return Result.success(userData);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 獲取用戶資料失敗: $e');
      return Result.failure(AppException.fromError(e));
    }
  }

  /// 🆕 更新用戶資料（Safe 版本）
  Future<Result<void>> updateUserDataSafe(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      // 檢查網路狀態
      if (!NetworkProvider().isOnline) {
        return Result.failure(AppException.network(
          message: '網路連接失敗，無法更新資料',
        ));
      }

      // 驗證參數
      if (userId.isEmpty) {
        return Result.failure(AppException.validation(
          message: '用戶 ID 不能為空',
        ));
      }

      if (data.isEmpty) {
        return Result.failure(AppException.validation(
          message: '更新資料不能為空',
        ));
      }

      // 執行原有邏輯
      await updateUserData(userId, data);
      
      debugPrint('✅ 用戶資料更新成功');
      return Result.success(null);
      
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase 錯誤: ${e.code} - ${e.message}');
      return Result.failure(AppException.firebase(
        message: _handleFirebaseError(e),
        code: e.code,
        originalError: e,
      ));
    } catch (e) {
      debugPrint('❌ 更新用戶資料失敗: $e');
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
        return '找不到相關資料';
      case 'already-exists':
        return '資料已存在';
      case 'unavailable':
        return '服務暫時無法使用，請稍後再試';
      case 'deadline-exceeded':
        return '請求超時，請檢查網路連接';
      case 'unauthenticated':
        return '請先登入';
      case 'resource-exhausted':
        return '操作過於頻繁，請稍後再試';
      case 'failed-precondition':
        return '操作條件不符';
      case 'aborted':
        return '操作被中止';
      case 'out-of-range':
        return '參數超出範圍';
      case 'unimplemented':
        return '功能尚未實作';
      case 'internal':
        return '系統內部錯誤';
      case 'data-loss':
        return '資料遺失或損壞';
      default:
        return '操作失敗，請稍後再試';
    }
  }
}