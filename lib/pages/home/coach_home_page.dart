// lib/pages/home/coach_home_page.dart
// 🎨 明亮版莫蘭迪風格教練主頁
// ✨ 保持優雅柔和感 + 提升明度和活力

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../chat_detail_page.dart';

// ✅ 引入明亮版莫蘭迪設計系統
import '../../theme/app_theme.dart';

class CoachHomePage extends StatefulWidget {
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 統計數據
  int totalStudents = 0;
  int activeStudents = 0;
  int pendingRequests = 0;
  
  // 學員列表
  List<DocumentSnapshot> allStudents = [];
  List<Map<String, dynamic>> topStudents = [];
  
  // 🔥 動畫控制器
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 🔥 初始化動畫
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
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
      
      await _loadStudentsData();
      
      setState(() => isLoading = false);
      
      // 🔥 啟動進場動畫
      _animationController.forward();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudentsData() async {
    try {
      if (firebaseUser == null) return;
      
      allStudents = await _userService.getCoachStudents(firebaseUser!.uid);
      totalStudents = allStudents.length;
      
      activeStudents = await _calculateActiveStudents();
      await _identifyTopStudents();
      await _loadPendingRequests();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入學員數據失敗: $e');
      }
    }
  }

  Future<int> _calculateActiveStudents() async {
    int count = 0;
    DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    
    for (var student in allStudents) {
      try {
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

  Future<void> _identifyTopStudents() async {
    topStudents.clear();
    
    for (var student in allStudents) {
      try {
        final data = student.data() as Map<String, dynamic>;
        final studentName = data['displayName'] ?? '未命名學員';
        
        final stats = await _userService.getUserStats(student.id);
        final completionRate = stats['completionRate'] ?? 0;
        
        DateTime weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        final weekLogs = await _firestore
            .collection('workoutLogs')
            .where('userId', isEqualTo: student.id)
            .where('createdAt', isGreaterThan: weekStart)
            .get();
        
        final workoutDays = weekLogs.docs.length;
        bool needsAttention = completionRate < 70 || workoutDays < 3;
        
        topStudents.add({
          'id': student.id,
          'name': studentName,
          'goal': data['goal'] ?? '尚未設定目標',
          'progress': 0.0,
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
    
    topStudents.sort((a, b) {
      if (a['needsAttention'] && !b['needsAttention']) return -1;
      if (!a['needsAttention'] && b['needsAttention']) return 1;
      return (a['compliance'] as int).compareTo(b['compliance'] as int);
    });
    
    if (topStudents.length > 5) {
      topStudents = topStudents.sublist(0, 5);
    }
  }

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
      _showSnackBar('開啟聊天失敗：$e', AppColors.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          ),
        ),
      );
    }

    return PageWrapperWithNavigation(
      isCoach: true,
      customHomePage: _buildEnhancedHomePage(),
    );
  }

  // 🔥 明亮版莫蘭迪主頁
  Widget _buildEnhancedHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: _initializeData,
              color: AppColors.coach,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 24),
                      _buildStatisticsCards(),
                      const SizedBox(height: 28),
                      _buildTopStudentsSection(),
                      const SizedBox(height: 28),
                      _buildAllStudentsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 1. 歡迎區 - 明亮莫蘭迪綠色漸層
  Widget _buildWelcomeSection() {
    return AnimatedContainer(
      duration: AppAnimations.normal,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,  // 明亮薄荷綠漸層
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.emphasized,
      ),
      child: Row(
        children: [
          // 🔥 頭像使用純白背景
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.small,
            ),
            child: Center(
              child: Text(
                realUserName.isNotEmpty ? realUserName[0].toUpperCase() : 'C',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.coach,
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
                  '您好，$realUserName',
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '今天也要加油指導學員！',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // 🔥 通知圖標 - 莫蘭迪橘色
          if (pendingRequests > 0)
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.warning,  // 莫蘭迪橘
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.small,
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

  // 🎨 2. 統計卡片 - 明亮莫蘭迪配色
  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '總學員',
            '$totalStudents',
            Icons.people_outline,
            AppColors.primary,      // 明亮霧藍
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '活躍中',
            '$activeStudents',
            Icons.trending_up,
            AppColors.coach,        // 明亮薄荷綠
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '待處理',
            '$pendingRequests',
            Icons.pending_actions,
            AppColors.warning,      // 溫暖橘
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 3. 本週重點學員 - 柔和警示設計
  Widget _buildTopStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '本週重點學員',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: 查看全部重點學員
              },
              child: Text(
                '查看全部',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.coach,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (topStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.small,
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '所有學員進度良好！',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: needsAttention 
              ? AppColors.warning.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: needsAttention ? AppShadows.large : AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 🔥 頭像 - 莫蘭迪配色
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: needsAttention 
                      ? AppColors.warningGradient
                      : AppColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.small,
                ),
                child: Center(
                  child: Text(
                    student['name'][0].toUpperCase(),
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
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
                      children: [
                        Text(
                          student['name'],
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (needsAttention) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '需關注',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warning,
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
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 🔥 聊天按鈕 - 莫蘭迪綠
              IconButton(
                onPressed: () => _startConsultation(student['id'], student['name']),
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.coach.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.coach,
                    size: 20,
                  ),
                ),
                tooltip: '開始諮詢',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🔥 關鍵指標 - 柔和配色
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  Icons.calendar_today_outlined,
                  '訓練天數',
                  student['workoutDays'],
                  needsAttention && (student['workoutDays'] as String).split('/')[0] == '0' ||
                      (student['workoutDays'] as String).split('/')[0] == '1' ||
                      (student['workoutDays'] as String).split('/')[0] == '2',
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value, bool isWarning) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isWarning 
            ? LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.08),
                  AppColors.warning.withValues(alpha: 0.04),
                ],
              )
            : LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.08),
                  AppColors.success.withValues(alpha: 0.04),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning 
              ? AppColors.warning.withValues(alpha: 0.2)
              : AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isWarning ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWarning ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 4. 所有學員列表 - 簡潔明亮設計
  Widget _buildAllStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所有學員',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (allStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.small,
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '尚無學員',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '等待學員發送配對請求',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.secondaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.small,
          ),
          child: Center(
            child: Text(
              name[0].toUpperCase(),
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            goal,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        trailing: IconButton(
          onPressed: () => _startConsultation(student.id, name),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.coach.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: AppColors.coach,
              size: 20,
            ),
          ),
        ),
        onTap: () {
          // TODO: 導航至學員詳情頁面
        },
      ),
    );
  }
}