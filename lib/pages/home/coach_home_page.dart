// lib/pages/home/coach_home_page.dart
// 🎨 教練主頁 v3.0 - 整合待處理事項管理系統
// ✅ v3.0 新增：待回覆統計、待處理事項區塊、快速行動按鈕
// ✅ v2.0 整合真實計畫進度
// ✨ 明亮版莫蘭迪風格 + 混合模式進度顯示

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';  // 🔥 v3.5：觸覺反饋
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/page_wrapper_with_navigation.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../services/coach_workout_service.dart';
import '../../services/coach_dashboard_service.dart';  // 🔥 v3.0
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
  final CoachDashboardService _dashboardService = CoachDashboardService();  // 🔥 v3.0

  // 🔥 v3.1：滾動控制器
  final ScrollController _scrollController = ScrollController();

  User? firebaseUser;
  String realUserName = '';
  bool isLoading = true;
  
  // 🔥 v3.0：儀表板統計數據
  DashboardStats _stats = DashboardStats();
  List<PendingAction> _pendingActions = [];
  
  // 🔥 v3.2：已讀通知 ID 列表（本地狀態）
  final Set<String> _readNotificationIds = {};
  
  // 學員進度數據
  List<StudentProgressSummary> _studentsProgress = [];
  List<StudentProgressSummary> _needsAttentionStudents = [];
  
  // 動畫控制器
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
    _scrollController.dispose();  // 🔥 v3.1
    super.dispose();
  }

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
      // 🔥 如果不是第一次載入，重置動畫
      if (!isLoading) {
        _animationController.reset();
      }
      
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
      
      // 🔥 v3.0：並行載入所有數據
      await Future.wait([
        _loadDashboardData(),
        _loadStudentsData(),
      ]);
      
      setState(() => isLoading = false);
      _animationController.forward();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入數據失敗: $e');
      }
      setState(() => isLoading = false);
    }
  }

  // 🔥 v3.0：載入儀表板數據
  Future<void> _loadDashboardData() async {
    try {
      debugPrint('🔄 開始載入儀表板數據...');
      
      final results = await Future.wait([
        _dashboardService.getDashboardStats(),
        _dashboardService.getPendingActions(),
      ]);
      
      _stats = results[0] as DashboardStats;
      _pendingActions = results[1] as List<PendingAction>;
      
      debugPrint('✅ 儀表板數據載入完成: 待回覆=${_stats.needsHelpCount}, 待處理=${_pendingActions.length}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入儀表板數據失敗: $e');
      }
    }
  }

  Future<void> _loadStudentsData() async {
    try {
      if (firebaseUser == null) return;
      
      _studentsProgress = await _coachService.getCoachStudentsProgress();
      
      _needsAttentionStudents = _studentsProgress
          .where((s) => s.needsAttention)
          .toList();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入學員進度失敗: $e');
      }
    }
  }

  // 🔥 v3.0：處理待處理事項的行動
  Future<void> _handlePendingAction(PendingAction action) async {
    switch (action.type) {
      case PendingActionType.needsHelp:
        await _navigateToChatWithReply(action);
        break;
      case PendingActionType.newRequest:
        // TODO: 導航到配對請求頁面
        _showSnackBar('請前往學員管理查看配對請求', AppColors.primary);
        break;
      case PendingActionType.planExpiring:
        _viewStudentDetail(action.traineeId, action.traineeName);
        break;
      case PendingActionType.noActivity:
        await _startConsultation(action.traineeId, action.traineeName);
        break;
    }
  }

  // 🔥 v3.0：導航到聊天室並帶上回覆
  Future<void> _navigateToChatWithReply(PendingAction action) async {
    try {
      final chatRoomId = await _chatService.createOrGetChatRoom(action.traineeId);
      
      if (!mounted) return;

      // 創建回覆資料
      final replyData = _chatService.createReplyDataFromWorkout(
        {
          'sessionId': action.sessionId ?? '',
          'planName': action.extraData?['planName'] ?? action.extraData?['workoutName'] ?? '訓練',
          'workoutName': action.extraData?['workoutName'] ?? '訓練',
          'feedback': {
            'needHelp': true,
            'helpMessage': action.helpMessage,
          },
        },
        senderName: action.traineeName,
      );

      // 🔥 v3.1：使用 await 等待返回
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatRoomId,
            chatName: action.traineeName,
            avatarUrl: '',
            initialReplyData: replyData,
            initialIsReplyingToHelp: true,
          ),
        ),
      );
      
      // 🔥 返回後刷新（不顯示全屏加載）
      debugPrint('🔄 從聊天室返回，刷新主頁數據...');
      if (mounted) {
        await _refreshDataQuietly();
      }
    } catch (e) {
      _showSnackBar('開啟聊天室失敗：$e', AppColors.error);
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
              avatarUrl: '',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('開啟聊天失敗：$e', AppColors.error);
    }
  }

  // 🔥 v3.1：改用 async/await 確保刷新
  Future<void> _viewStudentDetail(String studentId, String studentName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeDetailPage(
          traineeId: studentId,
          traineeName: studentName,
        ),
      ),
    );
    
    // 🔥 返回後刷新（不顯示全屏加載）
    debugPrint('🔄 從學員詳情頁返回，刷新主頁數據...');
    if (mounted) {
      await _refreshDataQuietly();
    }
  }
  
  // 🔥 v3.1：靜默刷新（不顯示全屏加載指示器）
  Future<void> _refreshDataQuietly() async {
    try {
      debugPrint('🔄 靜默刷新數據...');
      
      // 並行載入所有數據
      await Future.wait([
        _loadDashboardData(),
        _loadStudentsData(),
      ]);
      
      // 更新 UI
      if (mounted) {
        setState(() {});
        debugPrint('✅ 靜默刷新完成');
      }
    } catch (e) {
      debugPrint('❌ 靜默刷新失敗: $e');
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

  // 🔥 v3.1：顯示通知列表彈窗
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildNotificationsSheet(sheetContext),
    );
  }

  Widget _buildNotificationsSheet(BuildContext sheetContext) {
    // 🔥 v3.5：使用 StatefulBuilder 讓彈窗內部可以更新狀態
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final unreadCount = _getUnreadCount();
        
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 頂部拖動條
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 標題
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '通知中心',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // 🔥 v3.5：顯示未讀數量
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: unreadCount > 0 ? Colors.red : AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 0 
                            ? '$unreadCount 項未讀'
                            : '全部已讀',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 🔥 v3.5：全部標記已讀按鈕
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      // 標記全部已讀
                      for (final action in _pendingActions) {
                        _readNotificationIds.add(_getNotificationId(action));
                      }
                      // 更新彈窗內部狀態
                      setSheetState(() {});
                      // 同時更新主頁狀態（更新鈴鐺紅點）
                      setState(() {});
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.done_all, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '全部標記已讀',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 1),
              // 通知列表
              Flexible(
                child: _pendingActions.isEmpty
                    ? _buildEmptyNotifications()
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingActions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildNotificationItemWithState(
                            _pendingActions[index],
                            setSheetState,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 v3.6：帶狀態更新的通知項目
  Widget _buildNotificationItemWithState(
    PendingAction action, 
    StateSetter setSheetState,
  ) {
    final notificationId = _getNotificationId(action);
    final isRead = _readNotificationIds.contains(notificationId);
    
    // 根據類型設置顏色和圖標
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    
    switch (action.type) {
      case PendingActionType.needsHelp:
        typeColor = Colors.red;
        typeIcon = Icons.help_outline;
        typeLabel = '需要協助';
        break;
      case PendingActionType.newRequest:
        typeColor = AppColors.primary;
        typeIcon = Icons.person_add;
        typeLabel = '配對請求';
        break;
      case PendingActionType.planExpiring:
        typeColor = AppColors.warning;
        typeIcon = Icons.event;
        typeLabel = '計畫到期';
        break;
      case PendingActionType.noActivity:
        typeColor = Colors.orange;
        typeIcon = Icons.warning_amber;
        typeLabel = '長時間無活動';
        break;
    }
    
    final displayColor = isRead ? typeColor.withOpacity(0.4) : typeColor;
    final bgOpacity = isRead ? 0.02 : 0.05;
    final borderOpacity = isRead ? 0.1 : 0.2;

    // 🔥 v3.7：整體卡片統一設計
    return Container(
      decoration: BoxDecoration(
        color: typeColor.withOpacity(bgOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: typeColor.withOpacity(borderOpacity),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 點擊整個卡片標記已讀
            if (!isRead) {
              HapticFeedback.lightImpact();
              _readNotificationIds.add(notificationId);
              setSheetState(() {});
              setState(() {});
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 未讀指示器
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                // 圖標
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: displayColor, size: 20),
                ),
                const SizedBox(width: 12),
                // 內容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: displayColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              typeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(action.createdAt),
                            style: AppTextStyles.caption.copyWith(color: Colors.grey),
                          ),
                          if (isRead) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, size: 14, color: Colors.grey),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                          color: isRead ? Colors.grey : null,
                        ),
                      ),
                      if (action.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          action.subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isRead ? Colors.grey : AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 箭頭按鈕 - 點擊跳轉處理
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    _handlePendingAction(action);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: displayColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: displayColor,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '沒有待處理的通知',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '所有事項都已處理完畢！',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 v3.2：生成通知唯一 ID
  String _getNotificationId(PendingAction action) {
    return '${action.type.name}_${action.traineeId}_${action.sessionId ?? action.createdAt.millisecondsSinceEpoch}';
  }
  
  // 🔥 v3.2：獲取未讀通知數量
  int _getUnreadCount() {
    int count = 0;
    for (final action in _pendingActions) {
      if (!_readNotificationIds.contains(_getNotificationId(action))) {
        count++;
      }
    }
    return count;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day}';
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
                controller: _scrollController,  // 🔥 v3.1：添加滾動控制器
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
                      // 🔥 v3.0：待處理事項（優先顯示）
                      if (_pendingActions.isNotEmpty) ...[
                        _buildPendingActionsSection(),
                        const SizedBox(height: 28),
                      ],
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

  // 🎨 1. 歡迎區
  Widget _buildWelcomeSection() {
    // 🔥 v3.0：計算總待處理數量
    final totalPending = _stats.needsHelpCount + _stats.pendingRequests;
    
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
          // 🔥 v3.4：顯示通知鈴鐺（有通知就顯示，紅點顯示未讀數）
          if (_pendingActions.isNotEmpty)
            GestureDetector(
              onTap: () {
                _showNotificationsSheet();
              },
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getUnreadCount() > 0 
                          ? Icons.notification_important
                          : Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  // 🔥 v3.4：只在有未讀時顯示紅點
                  if (_getUnreadCount() > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.small,
                        ),
                        child: Text(
                          '${_getUnreadCount()}',
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
            ),
        ],
      ),
    );
  }

  String _getGreetingMessage() {
    // 🔥 v3.0：根據待處理事項顯示不同訊息
    if (_stats.needsHelpCount > 0) {
      return '有 ${_stats.needsHelpCount} 位學員需要您的協助！';
    }
    
    final hour = DateTime.now().hour;
    if (hour < 12) return '早安！今天也要加油指導學員！';
    if (hour < 18) return '午安！學員們等著您的指導！';
    return '晚安！辛苦了一天！';
  }

  // 🎨 2. 統計卡片 - 🔥 v3.0 增加待回覆
  Widget _buildStatisticsCards() {
    return Column(
      children: [
        // 第一行：總學員、本週活躍
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '總學員',
                '${_stats.totalStudents}',
                Icons.people_outline,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '本週活躍',
                '${_stats.activeStudents}',
                Icons.trending_up,
                AppColors.coach,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：待回覆、需關注
        Row(
          children: [
            // 🔥 v3.0：待回覆（紅色醒目）
            Expanded(
              child: _buildStatCard(
                '待回覆',
                '${_stats.needsHelpCount}',
                Icons.support_agent,
                _stats.needsHelpCount > 0 ? Colors.red : AppColors.success,
                isUrgent: _stats.needsHelpCount > 0,
              ),
            ),
            const SizedBox(width: 12),
            // 🔥 v3.2：使用統一的數據來源
            Expanded(
              child: _buildStatCard(
                '需關注',
                '${_needsAttentionStudents.length}',
                Icons.warning_amber_rounded,
                _needsAttentionStudents.isEmpty ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, {
    bool isUrgent = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🔥 v3.4：簡化設計，移除緊急標籤
        final isSmallScreen = constraints.maxWidth < 160;
        final padding = isSmallScreen ? 12.0 : 16.0;
        final iconPadding = isSmallScreen ? 8.0 : 10.0;
        final iconSize = isSmallScreen ? 20.0 : 22.0;
        final spacing = isSmallScreen ? 10.0 : 12.0;
        
        return AnimatedContainer(
          duration: AppAnimations.fast,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.medium,
            // 🔥 v3.4：緊急時只加邊框，不加標籤
            border: isUrgent ? Border.all(color: Colors.red, width: 2) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.h2.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 22 : 26,
                      ),
                    ),
                    Text(
                      title,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 v3.0：待處理事項區塊
  Widget _buildPendingActionsSection() {
    // 只取需要協助的事項（最優先）
    final helpActions = _pendingActions
        .where((a) => a.type == PendingActionType.needsHelp)
        .take(5)
        .toList();

    if (helpActions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notification_important,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '待處理事項',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${helpActions.length} 項',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...helpActions.map((action) => _buildPendingActionCard(action)),
      ],
    );
  }

  Widget _buildPendingActionCard(PendingAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePendingAction(action),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 頭像
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      action.traineeName.isNotEmpty 
                          ? action.traineeName[0].toUpperCase() 
                          : 'S',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 內容 - 🔥 v3.3 修復 overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題行 - 使用 Wrap 避免 overflow
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              action.traineeName,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '需要協助',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 行動按鈕 - 🔥 v3.3 縮小按鈕
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '回覆',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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