import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // *** 新增：用於 kDebugMode ***
// *** 新增：導入 Firebase 相關套件 ***
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// *** 新增：導入新的導航組件 ***
import '../../components/page_wrapper_with_navigation.dart';

class CoachHomePage extends StatefulWidget {
  // *** 修復：添加 key 參數 ***
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  // *** 新增：Firebase 實例 ***
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // *** 新增：真實用戶資料變數 ***
  User? firebaseUser;
  String realUserName = '';
  String userEmail = '';
  bool isLoading = true;

  // *** 新增：初始化方法來獲取真實用戶資料 ***
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// *** 新增：初始化用戶資料 ***
  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);
      
      // 獲取真實用戶資料
      firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        userEmail = firebaseUser!.email ?? '';
        
        // 從 Firestore 獲取用戶詳細資料
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser!.uid)
              .get();
          
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            realUserName = userData['displayName'] ?? firebaseUser!.displayName ?? '教練';
          } else {
            realUserName = firebaseUser!.displayName ?? '教練';
          }
        } catch (e) {
          // *** 修復：使用 debugPrint 替代 print ***
          if (kDebugMode) {
            debugPrint('獲取用戶資料失敗: $e');
          }
          realUserName = firebaseUser!.displayName ?? '教練';
        }
      } else {
        realUserName = '教練';
      }
      
      // 模擬加載延遲
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() => isLoading = false);
    } catch (e) {
      // *** 修復：使用 debugPrint 替代 print ***
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // *** 新增：顯示載入畫面 ***
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // *** 修改：使用新的頁面包裝器替代原本的 Scaffold ***
    return const PageWrapperWithNavigation(
      isCoach: true,
    );
  }
}