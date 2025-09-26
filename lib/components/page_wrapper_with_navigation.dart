// lib/components/page_wrapper_with_navigation.dart (更新版)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/modern_bottom_navigation.dart';
import '../pages/chat_detail_page.dart';
import '../chat_service_test_page.dart';
import '../pages/coach_search_page.dart';
import '../pages/student_management_page.dart';
import '../services/chat_service.dart'; // 🆕 新增
import '../services/pairing_service.dart'; // 🆕 新增

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
  
  // 🆕 新增服務實例
  final ChatService _chatService = ChatService();
  final PairingService _pairingService = PairingService();
  
  // 用戶資料
  String userName = '';
  String userEmail = '';
  bool isLoading = true;
  
  // 🆕 新增：統計數據
  Map<String, dynamic> _stats = {};

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

  // 🆕 增強的初始化方法
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
        
        // 🆕 載入統計數據
        await _loadStats();
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🆕 載入統計數據
  Future<void> _loadStats() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      if (widget.isCoach) {
        // 教練統計
        final studentCount = await _getCoachStudentCount(currentUserId);
        final pendingRequests = await _getPendingRequestCount(currentUserId);
        
        setState(() {
          _stats = {
            'totalStudents': studentCount,
            'pendingRequests': pendingRequests,
            'activeToday': studentCount > 0 ? (studentCount * 0.6).round() : 0,
          };
        });
      } else {
        // 學員統計
        final coachCount = await _getStudentCoachCount(currentUserId);
        final requestsSent = await _getRequestsSentCount(currentUserId);
        
        setState(() {
          _stats = {
            'currentCoaches': coachCount,
            'requestsSent': requestsSent,
            'weeklyTrainings': 5, // 模擬數據
            'caloriesBurned': 1200, // 模擬數據
            'goalCompletion': 85, // 模擬數據
          };
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('載入統計數據失敗: $e');
      }
    }
  }

  // 處理底部導航點擊
  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 🆕 增強的中央按鈕處理
  void _onCenterButtonPressed() {
    if (widget.isCoach) {
      _showCoachQuickActions();
    } else {
      _showStudentQuickActions();
    }
  }

  // 🆕 增強的教練快速操作
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
            
            // 🆕 處理配對請求
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pending_actions, color: Colors.orange),
              ),
              title: const Text('處理配對請求'),
              subtitle: Text('${_stats['pendingRequests'] ?? 0} 個待處理'),
              trailing: _stats['pendingRequests'] != null && _stats['pendingRequests'] > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_stats['pendingRequests']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                _navigateToStudentManagement();
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
              title: const Text('新增訓練計畫'),
              subtitle: const Text('為學員建立新的訓練課程'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonSnackBar('新增訓練計畫功能');
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics, color: Colors.blue),
              ),
              title: const Text('查看統計報告'),
              subtitle: const Text('學員進度和表現分析'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonSnackBar('統計報告功能');
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 🆕 增強的學員快速操作
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
            
            // 🆕 尋找教練
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search, color: Color(0xFF3B82F6)),
              ),
              title: const Text('尋找教練'),
              subtitle: const Text('搜索並配對合適的健身教練'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCoachSearch();
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
                _showComingSoonSnackBar('記錄訓練功能');
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.orange),
              ),
              title: const Text('營養掃描'),
              subtitle: const Text('拍照記錄飲食營養'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonSnackBar('營養掃描功能');
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

  // 🆕 增強的首頁內容
  Widget _buildHomePage() {
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
                        ? '今天也要幫助學員們達成目標！' 
                        : '今天也要加油訓練喔 💪',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  
                  // 🆕 新增：待處理提醒
                  if (widget.isCoach && _stats['pendingRequests'] != null && _stats['pendingRequests'] > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notification_important, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '您有 ${_stats['pendingRequests']} 個配對請求待處理',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _currentIndex = 1);
                              _pageController.animateToPage(1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text(
                              '查看',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 🆕 增強的統計卡片
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
                        _buildStatItem('${_stats['totalStudents'] ?? 0}', '總學員'),
                        _buildStatItem('${_stats['activeToday'] ?? 0}', '今日活躍'),
                        _buildStatItem('${_stats['pendingRequests'] ?? 0}', '待處理'),
                      ] : [
                        _buildStatItem('${_stats['weeklyTrainings'] ?? 0}', '本週訓練'),
                        _buildStatItem('${_stats['caloriesBurned'] ?? 0}', '消耗卡路里'),
                        _buildStatItem('${_stats['goalCompletion'] ?? 0}%', '目標完成'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 🆕 快速操作卡片
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
                      '快速操作',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            widget.isCoach ? '學員管理' : '尋找教練',
                            widget.isCoach ? Icons.group : Icons.search,
                            widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
                            () {
                              if (widget.isCoach) {
                                _navigateToStudentManagement();
                              } else {
                                _navigateToCoachSearch();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            '聊天',
                            Icons.chat_bubble,
                            Colors.orange,
                            () {
                              setState(() => _currentIndex = 2);
                              _pageController.animateToPage(2,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 測試按鈕（開發階段）
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

  Widget _buildSecondPage() {
    if (widget.isCoach) {
      return const StudentManagementPage();
    } else {
      return const CoachSearchPage();
    }
  }

  // 🆕 增強的聊天頁面（增加錯誤處理）
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
                    .where('isActive', isEqualTo: true)
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState('載入聊天記錄失敗', '${snapshot.error}');
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyChatState();
                  }

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
                    onTap: () => _showComingSoonSnackBar('編輯個人資料功能'),
                  ),
                  _buildProfileOption(
                    icon: Icons.settings_outlined,
                    title: '應用程式設定',
                    onTap: () => _showComingSoonSnackBar('應用程式設定功能'),
                  ),
                  _buildProfileOption(
                    icon: Icons.logout_outlined,
                    title: '登出',
                    onTap: _handleSignOut,
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

  // 🆕 輔助方法

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
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
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.isCoach) {
                _navigateToStudentManagement();
              } else {
                _navigateToCoachSearch();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(widget.isCoach ? '管理學員' : '尋找教練'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isCoach ? Colors.green : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomListItem(String chatRoomId, Map<String, dynamic> chatRoomData) {
    final participants = List<String>.from(chatRoomData['participants'] ?? []);
    final lastMessage = chatRoomData['lastMessage'] ?? '';
    final lastMessageTime = chatRoomData['lastMessageTime'] as Timestamp?;
    final lastMessageSender = chatRoomData['lastMessageSender'] ?? '';
    final currentUserId = _auth.currentUser?.uid;
    
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
          otherUserName = userData['displayName'] ?? '未知用戶';
          otherUserIsCoach = (userData['role'] == 'coach') || (userData['isCoach'] == true);
        }

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

  // 輔助方法
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

  void _navigateToStudentManagement() {
    setState(() => _currentIndex = 1);
    _pageController.animateToPage(1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToCoachSearch() {
    setState(() => _currentIndex = 1);
    _pageController.animateToPage(1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature (開發中)')),
    );
  }

  // 統計數據獲取方法
  Future<int> _getCoachStudentCount(String coachId) async {
    try {
      final QuerySnapshot pairs = await _firestore
          .collection('pairs')
          .where('coachId', isEqualTo: coachId)
          .where('status', isEqualTo: 'active')
          .get();
      return pairs.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getPendingRequestCount(String coachId) async {
    try {
      final QuerySnapshot requests = await _firestore
          .collection('pairRequests')
          .where('toUserId', isEqualTo: coachId)
          .where('status', isEqualTo: 'pending')
          .get();
      return requests.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getStudentCoachCount(String studentId) async {
    try {
      final QuerySnapshot pairs = await _firestore
          .collection('pairs')
          .where('traineeId', isEqualTo: studentId)
          .where('status', isEqualTo: 'active')
          .get();
      return pairs.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getRequestsSentCount(String studentId) async {
    try {
      final QuerySnapshot requests = await _firestore
          .collection('pairRequests')
          .where('fromUserId', isEqualTo: studentId)
          .get();
      return requests.docs.length;
    } catch (e) {
      return 0;
    }
  }

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
        await _auth.signOut();
        
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