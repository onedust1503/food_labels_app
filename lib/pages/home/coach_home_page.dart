// lib/pages/home/coach_home_page.dart
// 🎨 教練主頁 v2.0 - 整合真實計畫進度
// ✨ 明亮版莫蘭迪風格 + 混合模式進度顯示

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../services/coach_workout_service.dart';
import '../chat_detail_page.dart';
import '../coach/trainee_detail_page.dart';

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
  final CoachWorkoutService _coachService = CoachWorkoutService();

  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 統計數據
  int totalStudents = 0;
  int activeStudents = 0;
  int pendingRequests = 0;
  
  // 🔥 學員進度數據（真實數據）
  List<StudentProgressSummary> _studentsProgress = [];
  List<StudentProgressSummary> _needsAttentionStudents = [];
  
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
      await _loadPendingRequests();
      
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

  // 🔥 載入學員真實進度數據
  Future<void> _loadStudentsData() async {
    try {
      if (firebaseUser == null) return;
      
      // 使用新的 CoachWorkoutService 獲取真實進度
      _studentsProgress = await _coachService.getCoachStudentsProgress();
      
      totalStudents = _studentsProgress.length;
      
      // 計算活躍學員（本週有訓練）
      activeStudents = _studentsProgress
          .where((s) => s.thisWeekCompletions > 0)
          .length;
      
      // 需要關注的學員
      _needsAttentionStudents = _studentsProgress
          .where((s) => s.needsAttention)
          .toList();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入學員進度失敗: $e');
      }
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

  void _viewStudentDetail(String studentId, String studentName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeDetailPage(
          traineeId: studentId,
          traineeName: studentName,
        ),
      ),
    );
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
                      _buildNeedsAttentionSection(),
                      const SizedBox(height: 28),
                      _buildStudentsProgressSection(),
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
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.emphasized,
      ),
      child: Row(
        children: [
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
                  _getGreetingMessage(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (pendingRequests > 0)
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                      color: AppColors.warning,
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

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早安！今天也要加油指導學員！';
    if (hour < 18) return '午安！學員們等著您的指導！';
    return '晚安！辛苦了一天！';
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
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '本週活躍',
            '$activeStudents',
            Icons.trending_up,
            AppColors.coach,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            '需關注',
            '${_needsAttentionStudents.length}',
            Icons.warning_amber_rounded,
            _needsAttentionStudents.isEmpty ? AppColors.success : AppColors.warning,
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
              color: color.withOpacity(0.12),
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

  // 🎨 3. 需要關注的學員
  Widget _buildNeedsAttentionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, 
                  color: _needsAttentionStudents.isEmpty 
                      ? AppColors.success 
                      : AppColors.warning,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '需要關注',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_needsAttentionStudents.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_needsAttentionStudents.length} 位',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_needsAttentionStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.small,
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
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
                    '太棒了！所有學員進度良好 🎉',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._needsAttentionStudents.take(3).map((student) => 
            _buildAttentionCard(student)),
      ],
    );
  }

  Widget _buildAttentionCard(StudentProgressSummary student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.warningGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                student.traineeName.isNotEmpty 
                    ? student.traineeName[0].toUpperCase() 
                    : 'S',
                style: AppTextStyles.h4.copyWith(
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
                Text(
                  student.traineeName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getAttentionReason(student),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _viewStudentDetail(
                  student.traineeId, 
                  student.traineeName,
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                tooltip: '查看詳情',
              ),
              IconButton(
                onPressed: () => _startConsultation(
                  student.traineeId, 
                  student.traineeName,
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.coach.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.coach,
                    size: 18,
                  ),
                ),
                tooltip: '發送訊息',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAttentionReason(StudentProgressSummary student) {
    if (student.thisWeekCompletions == 0) {
      return '本週尚未訓練';
    }
    if (student.onScheduleRate < 50) {
      return '按時率偏低 (${student.onScheduleRateText})';
    }
    return '進度需要關注';
  }

  // 🎨 4. 學員進度列表
  Widget _buildStudentsProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '學員進度',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: 導航到完整學員列表
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
        if (_studentsProgress.isEmpty)
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
                      color: AppColors.primary.withOpacity(0.08),
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
          ..._studentsProgress.map((student) => _buildStudentProgressCard(student)),
      ],
    );
  }

  Widget _buildStudentProgressCard(StudentProgressSummary student) {
    final progressPercent = student.weeklyCompletionRate / 100;
    final progressColor = AppColors.getProgressColor(progressPercent);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.medium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewStudentDetail(student.traineeId, student.traineeName),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 頂部：頭像 + 名稱 + 操作
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: student.needsAttention
                            ? AppColors.warningGradient
                            : AppColors.secondaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.small,
                      ),
                      child: Center(
                        child: Text(
                          student.traineeName.isNotEmpty 
                              ? student.traineeName[0].toUpperCase() 
                              : 'S',
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
                                student.traineeName,
                                style: AppTextStyles.h4.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (student.needsAttention) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '需關注',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (student.goal.isNotEmpty)
                            Text(
                              student.goal,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _startConsultation(
                        student.traineeId, 
                        student.traineeName,
                      ),
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.coach.withOpacity(0.12),
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
                // 進度條
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '本週進度',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          student.weeklyProgressText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPercent.clamp(0.0, 1.0),
                        backgroundColor: progressColor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 統計數據
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressMetric(
                        Icons.calendar_today_outlined,
                        '本週訓練',
                        student.weeklyProgressText,
                        student.thisWeekCompletions == 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        Icons.schedule,
                        '按時率',
                        student.onScheduleRateText,
                        student.onScheduleRate < 50,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        Icons.assignment_outlined,
                        '計畫數',
                        '${student.totalPlans}',
                        false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressMetric(
    IconData icon, 
    String label, 
    String value, 
    bool isWarning,
  ) {
    final color = isWarning ? AppColors.warning : AppColors.success;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}