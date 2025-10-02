import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 新增：用於 kDebugMode
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/modern_bottom_navigation.dart'; // 修正：使用相對路徑
import '../pages/chat_detail_page.dart'; // 新增：聊天詳情頁面導入
import '../chat_service_test_page.dart'; // 新增：測試頁面導入
import '../pages/coach_search_page.dart'; // 新增：教練搜索頁面
import '../pages/student_management_page.dart'; // 新增：學員管理頁面
import '../pages/student_coach_management_page.dart'; // 新增：學員配對教練頁面


class PageWrapperWithNavigation extends StatefulWidget {
  final bool isCoach;

  const PageWrapperWithNavigation({
    super.key,
    required this.isCoach,
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
        
        // 從 Firestore 獲取用戶詳細資料
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
    print('🔥 導航點擊: index=$index');
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
    print('🔥 中央按鈕點擊');
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
              _buildHomePage(),
              _buildSecondPage(),
              _buildChatPage(),
              _buildProfilePage(),
            ],
          ),
          
          // 底部導航 - 🔥 更新為新版本
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

  // 首頁內容
  Widget _buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110), // 為底部導航留空間
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
                    widget.isCoach ? '今天也要幫助學員們達成目標！' : '今天也要加油訓練喔 💪',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 快速統計卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                child: Column(
                  children: [
                    Text(
                      widget.isCoach ? '教練儀表板' : '今日概況',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: widget.isCoach ? [
                        _buildStatItem('12', '總學員'),
                        _buildStatItem('8', '今日活躍'),
                        _buildStatItem('3', '待制定'),
                      ] : [
                        _buildStatItem('5', '本週訓練'),
                        _buildStatItem('1200', '消耗卡路里'),
                        _buildStatItem('85%', '目標完成'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 其他內容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                    // 測試按鈕
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ChatServiceTestPage()),
                          );
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('測試 ChatService'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 修改後的第二頁內容 - 🔥 整合配對系統
  Widget _buildSecondPage() {
    if (widget.isCoach) {
      // 教練看學員管理頁面
      return const StudentManagementPage();
    } else {
      // 學員看教練搜索頁面  
      return const StudentCoachManagementPage();
    }
  }

  // 🔥 新增：長期架構的聊天頁面實作（使用 chatRooms 集合）
  Widget _buildChatPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24, top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 保留原本的標題樣式
            const Text(
              '聊天',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔥 新增：使用 chatRooms 集合的即時聊天列表功能
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chatRooms')  // 🔥 修改：從 chats 改為 chatRooms
                    .where('participants', arrayContains: _auth.currentUser?.uid)
                    .where('isActive', isEqualTo: true)  // 🔥 新增：只顯示活躍的聊天室
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // 載入狀態
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 🔥 新增：詳細錯誤處理
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '載入聊天記錄時發生錯誤',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '錯誤詳情：${snapshot.error}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // 重新整理
                              setState(() {});
                            },
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    );
                  }

                  // 空狀態處理
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '尚無聊天記錄',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isCoach ? '與學員開始對話吧！' : '與教練開始對話吧！',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 建立聊天按鈕
                          ElevatedButton.icon(
                            onPressed: _showCreateChatDialog,
                            icon: const Icon(Icons.add),
                            label: Text(widget.isCoach ? '邀請學員' : '聯繫教練'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 🔥 新增：聊天室列表
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final chatRoomDoc = snapshot.data!.docs[index];
                      final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;
                      
                      return _buildChatRoomListItem(chatRoomDoc.id, chatRoomData);
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

  // 🔥 新增：聊天室列表項目（長期架構版本）
  Widget _buildChatRoomListItem(String chatRoomId, Map<String, dynamic> chatRoomData) {
    final participants = List<String>.from(chatRoomData['participants'] ?? []);
    final lastMessage = chatRoomData['lastMessage'] ?? '';
    final lastMessageTime = chatRoomData['lastMessageTime'] as Timestamp?;
    final lastMessageSender = chatRoomData['lastMessageSender'] ?? '';
    final currentUserId = _auth.currentUser?.uid;
    
    // 找到對方的 ID（非當前用戶的參與者）
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        String otherUserName = '未知用戶';
        bool otherUserIsCoach = false;
        
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          
          // 🔥 新增：調試資訊輸出（只在 Debug 模式）
          if (kDebugMode) {
            print('=== 聊天室調試資訊 ===');
            print('對方用戶ID: $otherUserId');
            print('對方用戶資料: $userData');
            print('對方 role: ${userData['role']}');
          }
          
          otherUserName = userData['displayName'] ?? '未知用戶';
          // 🔥 修改：支援您的 role 欄位格式和舊的 isCoach 格式
          otherUserIsCoach = (userData['role'] == 'coach') || (userData['isCoach'] == true);
          
          if (kDebugMode) {
            print('判斷結果 - 是教練: $otherUserIsCoach');
            print('========================');
          }
        }

        // 🔥 新增：判斷是否為自己發送的最後訊息
        final isMyLastMessage = lastMessageSender == currentUserId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openChatDetail(chatRoomId, otherUserName, otherUserIsCoach),
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
                  // 用戶頭像
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: otherUserIsCoach ? Colors.green : const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 聊天內容區域
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              otherUserName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (lastMessageTime != null)
                              Text(
                                _formatTime(lastMessageTime.toDate()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 角色標籤
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: otherUserIsCoach ? Colors.green : const Color(0xFF3B82F6),
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
                        const SizedBox(height: 8),
                        // 🔥 新增：最後訊息預覽（顯示發送者）
                        Row(
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
                                lastMessage.isNotEmpty ? lastMessage : '開始對話...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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
      },
    );
  }

  // 時間格式化輔助方法
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小時前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分鐘前';
    } else {
      return '剛剛';
    }
  }

  // 修改：開啟聊天詳情（導航到 ChatDetailPage）
  void _openChatDetail(String chatRoomId, String otherUserName, bool otherUserIsCoach) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          chatId: chatRoomId,
          chatName: otherUserName,
          lastMessage: '開始對話...',
          avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUserName)}&background=${otherUserIsCoach ? '22C55E' : '3B82F6'}&color=fff',
          isOnline: true,
        ),
      ),
    );
  }

  // 顯示建立聊天對話框
  void _showCreateChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 8),
            Text(widget.isCoach ? '邀請學員' : '聯繫教練'),
          ],
        ),
        content: Text(
          widget.isCoach 
              ? '此功能將允許您邀請學員開始對話，目前正在開發中。'
              : '此功能將幫助您聯繫可用的教練，目前正在開發中。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
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
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
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
                            fontSize: 20,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
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

  // 統計項目
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
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
                foregroundColor: Colors.white,
              ),
              child: const Text('確認登出'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      try {
        // 執行 Firebase 登出
        await _auth.signOut();
        
        // 導航到登入頁面
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('登出失敗：$e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}