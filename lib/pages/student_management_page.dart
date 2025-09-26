// lib/pages/student_management_page.dart (更新版本)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/pairing_service.dart'; // 新增
import 'chat_detail_page.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final PairingService _pairingService = PairingService(); // 新增
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  List<DocumentSnapshot> _students = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _studentStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 載入學員列表
  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final students = await _userService.getCoachStudents(currentUserId);
      
      // 載入學員統計數據
      final Map<String, Map<String, dynamic>> stats = {};
      for (final student in students) {
        final studentStats = await _userService.getUserStats(student.id);
        stats[student.id] = studentStats;
      }
      
      setState(() {
        _students = students;
        _studentStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入學員列表失敗：$e');
    }
  }

  // 🆕 處理配對請求 - 接受
  Future<void> _acceptPairRequest(PairRequest request) async {
    try {
      // 顯示載入對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('正在處理配對請求...'),
            ],
          ),
        ),
      );

      // 接受配對請求
      final pairId = await _pairingService.acceptPairRequest(request.id);
      
      // 獲取聊天室ID
      final chatRoomId = await _pairingService.getChatRoomIdByPairId(pairId);
      
      // 發送歡迎訊息
      if (chatRoomId != null) {
        await _chatService.sendMessage(
          chatRoomId: chatRoomId,
          text: '歡迎！我是您的健身教練，很高興與您配對。讓我們一起達成您的健身目標！',
        );
      }

      if (mounted) {
        Navigator.of(context).pop(); // 關閉載入對話框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已接受 ${request.fromUserName} 的配對請求！'),
            backgroundColor: Colors.green,
          ),
        );

        // 刷新數據
        _loadStudents();
        
        // 如果有聊天室，導向聊天頁面
        if (chatRoomId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(
                chatId: chatRoomId,
                chatName: request.fromUserName,
                lastMessage: '歡迎！我是您的健身教練...',
                avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(request.fromUserName)}&background=3B82F6&color=fff',
                isOnline: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 關閉載入對話框
        _showErrorSnackBar('接受配對請求失敗：$e');
      }
    }
  }

  // 🆕 處理配對請求 - 拒絕
  Future<void> _rejectPairRequest(PairRequest request) async {
    // 顯示確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認拒絕'),
        content: Text('確定要拒絕 ${request.fromUserName} 的配對請求嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('確認拒絕'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _pairingService.rejectPairRequest(request.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已拒絕 ${request.fromUserName} 的配對請求'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        _showErrorSnackBar('拒絕配對請求失敗：$e');
      }
    }
  }

  // 聯繫學員
  Future<void> _contactStudent(DocumentSnapshot studentDoc) async {
    try {
      final studentData = studentDoc.data() as Map<String, dynamic>;
      final studentId = studentDoc.id;
      final studentName = studentData['displayName'] ?? '學員';
      
      final chatRoomId = await _chatService.createOrGetChatRoom(studentId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: studentName,
              lastMessage: '開始對話...',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(studentName)}&background=3B82F6&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('開啟聊天失敗：$e');
    }
  }

  // 查看學員詳情
  void _viewStudentDetail(DocumentSnapshot studentDoc) {
    final studentData = studentDoc.data() as Map<String, dynamic>;
    final studentName = studentData['displayName'] ?? '學員';
    final studentEmail = studentData['email'] ?? '';
    final studentBio = studentData['bio'] ?? '';
    final joinDate = studentData['createdAt'] as Timestamp?;
    final stats = _studentStats[studentDoc.id] ?? {};
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    studentEmail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (studentBio.isNotEmpty) ...[
                const Text(
                  '個人簡介：',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  studentBio,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              if (joinDate != null) ...[
                const Text(
                  '配對日期：',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(joinDate.toDate()),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // 統計數據
              const Text(
                '訓練統計：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('總訓練次數：'),
                        Text(
                          '${stats['totalWorkouts'] ?? 0} 次',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('連續天數：'),
                        Text(
                          '${stats['streak'] ?? 0} 天',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('完成率：'),
                        Text(
                          '${stats['completionRate'] ?? 0}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _contactStudent(studentDoc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('開始聊天'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('學員管理'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我的學員'),
            Tab(text: '配對請求'), // 🆕 更新標籤
          ],
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 我的學員列表
          _buildStudentsList(),
          
          // 配對請求列表 🆕 實際實現
          _buildPairRequestsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.person_add),
        label: const Text('邀請學員'),
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '尚無配對學員',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '等待學員主動配對或查看配對請求',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStudents,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          return _buildStudentCard(_students[index]);
        },
      ),
    );
  }

  // 🆕 實際實現配對請求列表
  Widget _buildPairRequestsList() {
    return StreamBuilder<List<PairRequest>>(
      stream: _pairingService.getPendingRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  '載入配對請求失敗',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
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

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '暫無配對請求',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '學員發送配對請求後會顯示在這裡',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _buildPairRequestCard(requests[index]);
          },
        );
      },
    );
  }

  // 🆕 配對請求卡片
  Widget _buildPairRequestCard(PairRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 請求者資訊
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        request.fromUserName.isNotEmpty 
                            ? request.fromUserName[0].toUpperCase() 
                            : 'S',
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
                        Text(
                          request.fromUserName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '學員',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRequestTime(request.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 狀態標籤
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '待處理',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 配對訊息
              if (request.message.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '配對訊息：',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 操作按鈕
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectPairRequest(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('拒絕'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptPairRequest(request),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('接受'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(DocumentSnapshot studentDoc) {
    final studentData = studentDoc.data() as Map<String, dynamic>;
    final studentName = studentData['displayName'] ?? '學員';
    final studentEmail = studentData['email'] ?? '';
    final studentBio = studentData['bio'] ?? '';
    final joinDate = studentData['createdAt'] as Timestamp?;
    final stats = _studentStats[studentDoc.id] ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 學員資訊頭部
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
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
                          studentName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (studentEmail.isNotEmpty)
                          Text(
                            studentEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (joinDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '配對日期：${_formatDate(joinDate.toDate())}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'detail':
                          _viewStudentDetail(studentDoc);
                          break;
                        case 'chat':
                          _contactStudent(studentDoc);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'detail',
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('查看詳情'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'chat',
                        child: ListTile(
                          leading: Icon(Icons.chat),
                          title: Text('開始聊天'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (studentBio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  studentBio,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 16),
              
              // 統計數據
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '${stats['totalWorkouts'] ?? 0}',
                      '總訓練',
                      Icons.fitness_center,
                    ),
                    _buildStatItem(
                      '${stats['streak'] ?? 0}',
                      '連續天數',
                      Icons.local_fire_department,
                    ),
                    _buildStatItem(
                      '${stats['completionRate'] ?? 0}%',
                      '完成率',
                      Icons.check_circle,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 操作按鈕
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewStudentDetail(studentDoc),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('詳情'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _contactStudent(studentDoc),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('聊天'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.green),
            SizedBox(width: 8),
            Text('邀請學員'),
          ],
        ),
        content: const Text(
          '邀請功能開發中\n\n未來將支援：\n• 發送邀請連結\n• 分享教練資訊\n• 批量邀請功能',
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

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // 🆕 格式化請求時間
  String _formatRequestTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小時前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分鐘前';
    } else {
      return '剛剛';
    }
  }
}