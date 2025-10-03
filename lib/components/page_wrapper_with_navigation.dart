// lib/components/page_wrapper_with_navigation.dart
// 🔥 已修改：支援自定義首頁功能

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/modern_bottom_navigation.dart';
import '../pages/chat_detail_page.dart';
import '../chat_service_test_page.dart';
import '../pages/coach_search_page.dart';
import '../pages/student_management_page.dart';
import '../pages/student_coach_management_page.dart';
import '../services/food_database_service.dart'; // 🔥 新增

class PageWrapperWithNavigation extends StatefulWidget {
  final bool isCoach;
  final Widget? customHomePage; // 🔥 新增：可選的自定義首頁

  const PageWrapperWithNavigation({
    super.key,
    required this.isCoach,
    this.customHomePage, // 🔥 新增參數
  });

  @override
  State<PageWrapperWithNavigation> createState() => _PageWrapperWithNavigationState();
}

class _PageWrapperWithNavigationState extends State<PageWrapperWithNavigation> {
  int _currentIndex = 0;
  late PageController _pageController;
  
  // Firebase 實例
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 用戶資料
  String userName = '';
  String userEmail = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeUserData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 初始化用戶資料
  Future<void> _initializeUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        userEmail = user.email ?? '';
        
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['displayName'] ?? user.displayName ?? (widget.isCoach ? '教練' : '學員');
          } else {
            userName = user.displayName ?? (widget.isCoach ? '教練' : '學員');
          }
        } catch (e) {
          userName = user.displayName ?? (widget.isCoach ? '教練' : '學員');
        }
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 處理底部導航點擊
  void _onNavTap(int index) {
    if (kDebugMode) {
      debugPrint('🔥 導航點擊: index=$index');
    }
    
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onCenterButtonPressed() {
    if (kDebugMode) {
      debugPrint('🔥 中央按鈕點擊');
    }
    
    if (widget.isCoach) {
      _showCoachQuickActions();
    } else {
      _showStudentQuickActions();
    }
  }

  void _showCoachQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '快速操作',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center, color: Colors.green),
              ),
              title: const Text('新增訓練計畫'),
              subtitle: const Text('為學員建立新的訓練課程'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新增訓練計畫功能 (開發中)')),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group_add, color: Colors.blue),
              ),
              title: const Text('邀請學員'),
              subtitle: const Text('邀請新學員加入課程'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('邀請學員功能 (開發中)')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showStudentQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '快速操作',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
              ),
              title: const Text('營養掃描'),
              subtitle: const Text('拍照記錄飲食營養'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('營養掃描功能 (開發中)')),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center, color: Colors.green),
              ),
              title: const Text('記錄訓練'),
              subtitle: const Text('手動記錄訓練成果'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('記錄訓練功能 (開發中)')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // 主要內容頁面
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              _buildHomePage(), // 🔥 修改：支援自定義首頁
              _buildSecondPage(),
              _buildChatPage(),
              _buildProfilePage(),
            ],
          ),
          
          // 底部導航
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ModernBottomNavigation(
              currentIndex: _currentIndex,
              onTap: _onNavTap,
              onCenterButtonPressed: _onCenterButtonPressed,
              isCoach: widget.isCoach,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 修改：首頁內容 - 支援自定義首頁
  Widget _buildHomePage() {
    // 如果有傳入自定義首頁，就使用它
    if (widget.customHomePage != null) {
      return widget.customHomePage!;
    }
    
    // 否則使用預設首頁
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          children: [
            // 頂部歡迎區域
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isCoach 
                      ? [Colors.green[500]!, Colors.green[600]!]
                      : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    '嗨，$userName！',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isCoach 
                        ? '今天也要好好指導學員們！' 
                        : '今天也要認真訓練！',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 內容區域
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isCoach ? '近期活動' : '訓練進度',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isCoach 
                        ? '您的學員們本週總共完成了 45 次訓練，表現優秀！'
                        : '本週已完成 5 次訓練，繼續保持！',
                    style: TextStyle(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 第二頁內容
  Widget _buildSecondPage() {
    if (widget.isCoach) {
      return const StudentManagementPage();
    } else {
      return const StudentCoachManagementPage();
    }
  }

  // 聊天頁面
  Widget _buildChatPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24, top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '聊天',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chatRooms')
                    .where('participants', arrayContains: _auth.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('載入聊天時發生錯誤: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '尚無聊天記錄',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 🔥 在本地排序聊天室（按最後訊息時間）
                  List<QueryDocumentSnapshot> chatRooms = snapshot.data!.docs.toList();
                  chatRooms.sort((a, b) {
                    var aData = a.data() as Map<String, dynamic>;
                    var bData = b.data() as Map<String, dynamic>;
                    var aTime = aData['lastMessageTime'] as Timestamp?;
                    var bTime = bData['lastMessageTime'] as Timestamp?;
                    
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    
                    return bTime.compareTo(aTime); // 降序排列（最新的在前）
                  });

                  return ListView.builder(
                    itemCount: chatRooms.length,
                    itemBuilder: (context, index) {
                      var chatRoomDoc = chatRooms[index];
                      Map<String, dynamic> chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;
                      
                      List<dynamic> participants = chatRoomData['participants'] ?? [];
                      String otherUserId = participants.firstWhere(
                        (id) => id != _auth.currentUser?.uid,
                        orElse: () => '',
                      );

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(otherUserId).get(),
                        builder: (context, userSnapshot) {
                          String otherUserName = '未知用戶';
                          bool otherUserIsCoach = false;
                          
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            Map<String, dynamic> otherUserData = userSnapshot.data!.data() as Map<String, dynamic>;
                            otherUserName = otherUserData['displayName'] ?? '未知用戶';
                            otherUserIsCoach = otherUserData['role'] == 'coach';
                          }

                          String lastMessage = chatRoomData['lastMessage'] ?? '';
                          String lastMessageSenderId = chatRoomData['lastMessageSenderId'] ?? '';
                          bool isMyLastMessage = lastMessageSenderId == _auth.currentUser?.uid;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: otherUserIsCoach 
                                    ? Colors.green 
                                    : const Color(0xFF3B82F6),
                                child: Text(
                                  otherUserName.isNotEmpty 
                                      ? otherUserName[0].toUpperCase() 
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      otherUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: otherUserIsCoach 
                                          ? Colors.green 
                                          : const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      otherUserIsCoach ? '教練' : '學員',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    if (isMyLastMessage)
                                      Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '我：',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        lastMessage.isNotEmpty 
                                            ? lastMessage 
                                            : '尚無訊息',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatDetailPage(
                                      chatId: chatRoomDoc.id,           // ✅ 修正參數名稱
                                      chatName: otherUserName,          // ✅ 修正參數名稱
                                      lastMessage: lastMessage.isNotEmpty ? lastMessage : '開始對話...', // ✅ 正確
                                      avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUserName)}&background=${otherUserIsCoach ? '22C55E' : '3B82F6'}&color=fff', // ✅ 使用 UI Avatars 生成頭像
                                      isOnline: true,                   // ✅ 預設在線
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 個人頁面
  Widget _buildProfilePage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24, top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '個人中心',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // 用戶資料卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isCoach 
                                ? Colors.green 
                                : const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.isCoach ? '教練' : '學員',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 功能選項
            Expanded(
              child: Column(
                children: [
                  _buildProfileOption(
                    icon: Icons.edit_outlined,
                    title: '編輯個人資料',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('編輯個人資料功能 (開發中)')),
                      );
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.settings_outlined,
                    title: '應用程式設定',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('應用程式設定功能 (開發中)')),
                      );
                    },
                  ),
                  // 🔥 新增：初始化食物資料庫（開發/管理用）
                  _buildProfileOption(
                    icon: Icons.restaurant_menu,
                    title: '初始化食物資料庫',
                    onTap: () {
                      _initializeDatabase();
                    },
                  ),
                  _buildProfileOption(
                    icon: Icons.logout_outlined,
                    title: '登出',
                    onTap: () {
                      _handleSignOut();
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 個人中心選項
  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.grey[600],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? Colors.red : Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 登出功能
  void _handleSignOut() async {
    bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 8),
              const Text('確認登出'),
            ],
          ),
          content: const Text('您確定要登出嗎？\n登出後需要重新登入才能使用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
              ),
              child: const Text('確定登出'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      try {
        await _auth.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登出失敗: $e')),
          );
        }
      }
    }
  }

  // 🔥 新增：初始化食物資料庫
  void _initializeDatabase() async {
    // 顯示確認對話框
    bool? shouldInit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.orange),
              SizedBox(width: 8),
              Text('初始化食物資料庫'),
            ],
          ),
          content: const Text(
            '這將會在 Firestore 中建立基礎食物資料庫。\n\n'
            '如果資料庫已存在，將不會重複建立。\n\n'
            '確定要執行嗎？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    if (shouldInit != true) return;

    // 顯示載入對話框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在初始化資料庫...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      FoodDatabaseService foodService = FoodDatabaseService();
      await foodService.initializeFoodDatabase();
      
      // 關閉載入對話框
      if (mounted) Navigator.of(context).pop();
      
      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('食物資料庫初始化成功！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 關閉載入對話框
      if (mounted) Navigator.of(context).pop();
      
      // 顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      if (kDebugMode) {
        print('初始化食物資料庫失敗: $e');
      }
    }
  }
}