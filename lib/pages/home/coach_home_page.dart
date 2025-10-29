// lib/pages/home/coach_home_page.dart
// 🎯 完整的教練端主頁 - 包含學員統計、重點學員、所有學員列表

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../chat_detail_page.dart';

class CoachHomePage extends StatefulWidget {
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 🔥 統計數據
  int totalStudents = 0;
  int activeStudents = 0;
  int pendingRequests = 0;
  
  // 🔥 學員列表
  List<DocumentSnapshot> allStudents = [];
  List<Map<String, dynamic>> topStudents = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);
      
      firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
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
          if (kDebugMode) {
            debugPrint('獲取用戶資料失敗: $e');
          }
          realUserName = firebaseUser!.displayName ?? '教練';
        }
      }
      
      // 🔥 載入學員數據
      await _loadStudentsData();
      
      setState(() => isLoading = false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  // 🔥 載入真實的學員數據
  Future<void> _loadStudentsData() async {
    try {
      if (firebaseUser == null) return;
      
      // 獲取所有學員
      allStudents = await _userService.getCoachStudents(firebaseUser!.uid);
      totalStudents = allStudents.length;
      
      // 計算活躍學員（本週有活動的學員）
      activeStudents = await _calculateActiveStudents();
      
      // 識別重點學員
      await _identifyTopStudents();
      
      // 獲取待處理的配對請求數
      await _loadPendingRequests();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入學員數據失敗: $e');
      }
    }
  }

  // 🔥 計算活躍學員數
  Future<int> _calculateActiveStudents() async {
    int count = 0;
    DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    for (var student in allStudents) {
      try {
        // 檢查學員是否有最近的訓練記錄
        final logs = await _firestore
            .collection('workoutLogs')
            .where('userId', isEqualTo: student.id)
            .where('createdAt', isGreaterThan: weekAgo)
            .limit(1)
            .get();
        
        if (logs.docs.isNotEmpty) {
          count++;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('檢查學員活躍度失敗: $e');
        }
      }
    }
    
    return count;
  }

  // 🔥 識別重點學員（需要關注的學員）
  Future<void> _identifyTopStudents() async {
    topStudents.clear();
    
    for (var student in allStudents) {
      try {
        final data = student.data() as Map<String, dynamic>;
        final studentName = data['displayName'] ?? '未命名學員';
        
        // 獲取學員的訓練統計
        final stats = await _userService.getUserStats(student.id);
        
        // 計算合規率（完成率）
        final completionRate = stats['completionRate'] ?? 0;
        
        // 獲取本週訓練天數
        DateTime weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        final weekLogs = await _firestore
            .collection('workoutLogs')
            .where('userId', isEqualTo: student.id)
            .where('createdAt', isGreaterThan: weekStart)
            .get();
        
        final workoutDays = weekLogs.docs.length;
        
        // 判斷是否需要關注（完成率低於70%或本週訓練天數少於3天）
        bool needsAttention = completionRate < 70 || workoutDays < 3;
        
        topStudents.add({
          'id': student.id,
          'name': studentName,
          'goal': data['goal'] ?? '尚未設定目標',
          'progress': 0.0, // TODO: 計算實際進度
          'compliance': completionRate,
          'workoutDays': '$workoutDays/7',
          'needsAttention': needsAttention,
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('處理學員 ${student.id} 數據失敗: $e');
        }
      }
    }
    
    // 排序：需要關注的學員排在前面
    topStudents.sort((a, b) {
      if (a['needsAttention'] && !b['needsAttention']) return -1;
      if (!a['needsAttention'] && b['needsAttention']) return 1;
      return (a['compliance'] as int).compareTo(b['compliance'] as int);
    });
    
    // 只保留前5位
    if (topStudents.length > 5) {
      topStudents = topStudents.sublist(0, 5);
    }
  }

  // 🔥 載入待處理的配對請求
  Future<void> _loadPendingRequests() async {
    try {
      if (firebaseUser == null) return;
      
      final requests = await _firestore
          .collection('pairRequests')
          .where('toUserId', isEqualTo: firebaseUser!.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      pendingRequests = requests.docs.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入配對請求失敗: $e');
      }
    }
  }

  // 🔥 開始與學員諮詢（進入聊天室）
  Future<void> _startConsultation(String studentId, String studentName) async {
    try {
      final chatRoomId = await _chatService.createOrGetChatRoom(studentId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: studentName,
              lastMessage: '開始諮詢...',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(studentName)}&background=22C55E&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('開啟聊天失敗：$e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PageWrapperWithNavigation(
      isCoach: true,
      customHomePage: _buildEnhancedHomePage(),
    );
  }

  // 🔥 增強版教練首頁
  Widget _buildEnhancedHomePage() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _initializeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 110),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 頂部歡迎區與通知
                _buildWelcomeSection(),
                const SizedBox(height: 20),

                // 2. 數據總覽卡片
                _buildStatisticsCards(),
                const SizedBox(height: 24),

                // 3. 本週重點學員
                _buildTopStudentsSection(),
                const SizedBox(height: 24),

                // 4. 所有學員列表
                _buildAllStudentsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 1. 歡迎區
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              realUserName.isNotEmpty ? realUserName[0].toUpperCase() : 'C',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '您好，$realUserName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '今天也要加油指導學員！',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // 通知圖標
          if (pendingRequests > 0)
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    // TODO: 導航至配對請求頁面
                  },
                  icon: const Icon(Icons.notifications, color: Colors.white),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$pendingRequests',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 🎨 2. 統計卡片
  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '總學員',
            '$totalStudents',
            Icons.people,
            Colors.blue.shade400,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '活躍中',
            '$activeStudents',
            Icons.trending_up,
            Colors.green.shade400,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '待處理',
            '$pendingRequests',
            Icons.pending_actions,
            Colors.orange.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 3. 本週重點學員
  Widget _buildTopStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '本週重點學員',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: 查看全部重點學員
              },
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topStudents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      '所有學員進度良好！',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...topStudents.map((student) => _buildTopStudentCard(student)),
      ],
    );
  }

  Widget _buildTopStudentCard(Map<String, dynamic> student) {
    final needsAttention = student['needsAttention'] as bool;
    final compliance = student['compliance'] as int;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: needsAttention ? Colors.orange.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: needsAttention ? Colors.orange.shade100 : Colors.green.shade100,
                  child: Text(
                    student['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: needsAttention ? Colors.orange : Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (needsAttention) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '需關注',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student['goal'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _startConsultation(student['id'], student['name']),
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: Colors.green,
                  tooltip: '開始諮詢',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 關鍵指標
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    Icons.calendar_today,
                    '訓練天數',
                    student['workoutDays'],
                    needsAttention && (student['workoutDays'] as String).startsWith('0') || (student['workoutDays'] as String).startsWith('1') || (student['workoutDays'] as String).startsWith('2'),
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    Icons.task_alt,
                    '達成率',
                    '$compliance%',
                    compliance < 70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value, bool isWarning) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWarning ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isWarning ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 4. 所有學員列表
  Widget _buildAllStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '所有學員',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (allStudents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      '尚無學員',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '等待學員發送配對請求',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...allStudents.map((student) => _buildStudentCard(student)),
      ],
    );
  }

  Widget _buildStudentCard(DocumentSnapshot student) {
    final data = student.data() as Map<String, dynamic>;
    final name = data['displayName'] ?? '未命名學員';
    final goal = data['goal'] ?? '尚未設定目標';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(goal),
        trailing: IconButton(
          onPressed: () => _startConsultation(student.id, name),
          icon: const Icon(Icons.chat_bubble_outline),
          color: Colors.green,
        ),
        onTap: () {
          // TODO: 導航至學員詳情頁面
        },
      ),
    );
  }
}