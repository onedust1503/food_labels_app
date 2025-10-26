// lib/widgets/auth_wrapper.dart
// 登入流程檢查 - 根據角色自動導向適當頁面

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚠️ 記得在使用這個 widget 的地方 import 這些頁面
// import 'package:your_app/pages/profile/trainee_setup_page.dart';
// import 'package:your_app/pages/profile/coach_setup_page.dart';
// import 'package:your_app/pages/trainee/trainee_home_page.dart';
// import 'package:your_app/pages/coach/coach_home_page.dart';

class AuthWrapper extends StatelessWidget {
  final Widget loginPage;
  final Widget traineeHomePage;      // 學生主頁
  final Widget coachHomePage;        // 教練主頁
  final Widget traineeSetupPage;     // 學生設定頁面
  final Widget coachSetupPage;       // 教練設定頁面

  const AuthWrapper({
    Key? key,
    required this.loginPage,
    required this.traineeHomePage,
    required this.coachHomePage,
    required this.traineeSetupPage,
    required this.coachSetupPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (kDebugMode) {
          debugPrint('[AuthWrapper] ConnectionState: ${snapshot.connectionState}');
          debugPrint('[AuthWrapper] HasData: ${snapshot.hasData}');
          if (snapshot.hasData) {
            debugPrint('[AuthWrapper] User Email: ${snapshot.data?.email}');
          }
        }

        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        // 未登入
        if (!snapshot.hasData) {
          if (kDebugMode) {
            debugPrint('[AuthWrapper] 未登入，導向登入頁面');
          }
          return loginPage;
        }

        // 已登入 - 檢查用戶資料
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (kDebugMode) {
              debugPrint('[AuthWrapper] 用戶資料載入狀態: ${userSnapshot.connectionState}');
            }

            // 載入中
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen(message: '載入用戶資料...');
            }

            // 檢查資料
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final role = userData['role'] ?? '';
              
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 用戶角色: $role');
                debugPrint('[AuthWrapper] 用戶資料: $userData');
              }

              // 檢查是否需要設定
              final needsSetup = _needsProfileSetup(userData, role);
              
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 需要設定: $needsSetup');
              }

              // 如果需要設定，根據角色導向對應設定頁面
              if (needsSetup) {
                return _getSetupPageByRole(role);
              }

              // 已完成設定，根據角色導向對應主頁
              return _getHomePageByRole(role);
            }

            // 找不到用戶資料，返回登入頁面
            if (kDebugMode) {
              debugPrint('[AuthWrapper] 找不到用戶資料，返回登入頁面');
            }
            return loginPage;
          },
        );
      },
    );
  }

  // ✅ 根據角色返回對應的設定頁面
  Widget _getSetupPageByRole(String role) {
    if (kDebugMode) {
      debugPrint('[AuthWrapper] 導向設定頁面，角色: $role');
    }

    switch (role) {
      case 'coach':
        return coachSetupPage;
      case 'trainee':
        return traineeSetupPage;
      default:
        if (kDebugMode) {
          debugPrint('[AuthWrapper] 未知角色: $role，返回登入頁面');
        }
        return loginPage;
    }
  }

  // ✅ 根據角色返回對應的主頁
  Widget _getHomePageByRole(String role) {
    if (kDebugMode) {
      debugPrint('[AuthWrapper] 導向主頁，角色: $role');
    }

    switch (role) {
      case 'coach':
        return coachHomePage;
      case 'trainee':
        return traineeHomePage;
      default:
        if (kDebugMode) {
          debugPrint('[AuthWrapper] 未知角色: $role，返回登入頁面');
        }
        return loginPage;
    }
  }

  // ✅ 檢查是否需要完成設定（根據角色檢查不同欄位）
  bool _needsProfileSetup(Map<String, dynamic> userData, String role) {
    // 1. 檢查 profileSetupCompleted 欄位
    final profileSetupCompleted = userData['profileSetupCompleted'] ?? false;
    
    if (kDebugMode) {
      debugPrint('[AuthWrapper] profileSetupCompleted: $profileSetupCompleted');
    }
    
    // 如果明確標記為未完成
    if (!profileSetupCompleted) {
      return true;
    }

    // 2. 檢查必要欄位是否存在（防止資料不完整）
    final hasDisplayName = userData['displayName'] != null && 
                          (userData['displayName'] as String).isNotEmpty;

    if (kDebugMode) {
      debugPrint('[AuthWrapper] hasDisplayName: $hasDisplayName');
    }

    // 根據角色檢查不同的必要欄位
    if (role == 'trainee') {
      // 學生必須有：姓名、身高、體重、目標
      final hasHeight = userData['height'] != null;
      final hasWeight = userData['weight'] != null;
      final hasGoal = userData['goal'] != null;

      if (kDebugMode) {
        debugPrint('[AuthWrapper] 學生欄位檢查:');
        debugPrint('  - height: $hasHeight');
        debugPrint('  - weight: $hasWeight');
        debugPrint('  - goal: $hasGoal');
      }

      return !hasDisplayName || !hasHeight || !hasWeight || !hasGoal;
      
    } else if (role == 'coach') {
      // 教練必須有：姓名、專長
      final hasSpecialties = userData['specialties'] != null && 
                            (userData['specialties'] as List).isNotEmpty;

      if (kDebugMode) {
        debugPrint('[AuthWrapper] 教練欄位檢查:');
        debugPrint('  - specialties: $hasSpecialties');
      }

      return !hasDisplayName || !hasSpecialties;
    }

    // 未知角色，需要設定
    return true;
  }

  // 載入畫面
  Widget _buildLoadingScreen({String message = '載入中...'}) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade400, Colors.green.shade700],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}