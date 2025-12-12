// lib/components/page_wrapper_with_navigation.dart
// 🎨 明亮版莫蘭迪風格 - 整合訓練計畫管理功能 + 優化設計
// ✅ v4.0：修復 Drawer 打開問題，添加浮動選單按鈕
// ✅ v3.9：新增快速回饋模板管理、週報總結入口
import '../pages/test/ai_food_test_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';  // 🆕 v4.0
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/modern_bottom_navigation.dart';
import '../pages/chat_detail_page.dart';
import '../pages/student_management_page.dart';
import '../pages/student_coach_management_page.dart';
import '../services/food_database_service.dart';

// ✅ 訓練相關頁面
import '../pages/improved_workout_log_page.dart';
import '../pages/workout/workout_plan_list_page.dart';
import '../pages/workout/create_workout_plan_page.dart';
import '../pages/workout/coach_plans_management_page.dart';

// 統計和設定頁面
import '../pages/stats/dashboard_page.dart';
import '../pages/stats/workout_stats_page.dart';
import '../pages/stats/nutrition_stats_page.dart';
import '../pages/settings/notification_settings_page.dart';

// 個人資料編輯頁面
import '../pages/profile/coach_edit_page.dart';
import '../pages/profile/trainee_edit_page.dart';

// 營養 OCR 掃描頁面
import '../pages/nutrition/ocr_scan_page.dart';

// 🆕 v3.9：快速回饋相關頁面
import '../pages/coach/feedback_templates_page.dart';
import '../pages/coach/weekly_report_page.dart';

// 🎨 引入明亮版莫蘭迪主題
import '../theme/app_theme.dart';

class PageWrapperWithNavigation extends StatefulWidget {
  final bool isCoach;
  final Widget? customHomePage;

  const PageWrapperWithNavigation({
    super.key,
    required this.isCoach,
    this.customHomePage,
  });

  @override
  State<PageWrapperWithNavigation> createState() => _PageWrapperWithNavigationState();
}

class _PageWrapperWithNavigationState extends State<PageWrapperWithNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  
  // 🆕 v4.0：使用 GlobalKey 控制 Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String userName = '';
  String userEmail = '';
  bool isLoading = true;
  
  // 🔥 動畫控制器
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeUserData();
    
    // 🔥 初始化 FAB 動畫
    _fabAnimationController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

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

  void _onNavTap(int index) {
    if (kDebugMode) {
      debugPrint('🔥 導航點擊: index=$index');
    }
    
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: AppAnimations.normal,
      curve: AppAnimations.defaultCurve,
    );
  }

  void _onCenterButtonPressed() {
    if (kDebugMode) {
      debugPrint('🔥 中央按鈕點擊');
    }
    
    // 🔥 FAB 動畫
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });
    
    if (widget.isCoach) {
      _showCoachQuickActions();
    } else {
      _showStudentQuickActions();
    }
  }
  
  // 🆕 v4.0：打開側邊欄的方法
  void _openDrawer() {
    HapticFeedback.lightImpact();
    _scaffoldKey.currentState?.openDrawer();
  }

  /// 🎨 教練快速操作 - 明亮莫蘭迪風格
  void _showCoachQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 頂部手柄
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔥 標題
            Text(
              '快速操作',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔥 創建訓練計畫
            _buildQuickActionItem(
              icon: Icons.add_chart,
              title: '創建訓練計畫',
              subtitle: '為學員建立新的訓練課程',
              gradient: AppColors.secondaryGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateWorkoutPlanPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 🔥 管理訓練計畫
            _buildQuickActionItem(
              icon: Icons.list_alt,
              title: '管理訓練計畫',
              subtitle: '查看和管理所有訓練計畫',
              gradient: AppColors.primaryGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CoachPlansManagementPage(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 🎨 學員快速操作 - 明亮莫蘭迪風格
  void _showStudentQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 頂部手柄
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔥 標題
            Text(
              '快速操作',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔥 記錄訓練
            _buildQuickActionItem(
              icon: Icons.fitness_center,
              title: '記錄訓練',
              subtitle: '記錄今日自由訓練',
              gradient: AppColors.energyGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImprovedWorkoutLogPage(
                      isCoach: false,
                      traineeId: null,
                      planId: null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 🔥 查看訓練計畫
            _buildQuickActionItem(
              icon: Icons.calendar_month,
              title: '訓練計畫',
              subtitle: '查看教練分配的訓練計畫',
              gradient: AppColors.warmGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkoutPlanListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 🔥 營養掃描
            _buildQuickActionItem(
              icon: Icons.camera_alt,
              title: '營養掃描',
              subtitle: '拍照記錄飲食營養',
              gradient: AppColors.primaryGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OcrScanPage(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 🎨 快速操作項目 - 莫蘭迪風格卡片
  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          children: [
            // 🔥 圖標
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            
            // 🔥 文字內容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            
            // 🔥 箭頭
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 側邊欄 - 明亮莫蘭迪風格
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // 🔥 側邊欄頂部 - 明亮莫蘭迪漸層
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: widget.isCoach 
                    ? AppColors.secondaryGradient
                    : AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: AppShadows.large,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 頭像 - 純白背景
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: AppTextStyles.h1.copyWith(
                          color: widget.isCoach ? AppColors.coach : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 🔥 用戶名
                  Text(
                    userName,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // 🔥 郵箱
                  Text(
                    userEmail,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            // 🔥 側邊欄選項列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // ✅ 教練專屬訓練管理選項
                  if (widget.isCoach) ...[
                    _buildDrawerHeader('💪 訓練管理'),
                    _buildDrawerItem(
                      icon: Icons.add_chart,
                      title: '創建訓練計畫',
                      subtitle: '為學員安排訓練',
                      color: AppColors.coach,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateWorkoutPlanPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.list_alt,
                      title: '管理訓練計畫',
                      subtitle: '查看和管理所有計畫',
                      color: AppColors.coach,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CoachPlansManagementPage(),
                          ),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Divider(height: 1),
                    ),
                    
                    // ═══════════════════════════════════════
                    // 🆕 v3.9：快速回饋功能區塊
                    // ═══════════════════════════════════════
                    _buildDrawerHeader('💬 回饋管理'),
                    _buildDrawerItem(
                      icon: Icons.flash_on,
                      title: '回饋模板',
                      subtitle: '管理快速回饋模板',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FeedbackTemplatesPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.summarize,
                      title: '週報總結',
                      subtitle: '查看本週學員表現',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WeeklyReportPage(),
                          ),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Divider(height: 1),
                    ),
                  ],

                  // 📊 統計相關選項
                  _buildDrawerHeader('📊 數據統計'),
                  _buildDrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: '數據儀表板',
                    subtitle: '查看整體數據總覽',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DashboardPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.fitness_center,
                    title: '運動統計',
                    subtitle: '查看訓練數據分析',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkoutStatsPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.restaurant,
                    title: '營養統計',
                    subtitle: '查看飲食數據分析',
                    color: AppColors.warning,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NutritionStatsPage(),
                        ),
                      );
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Divider(height: 1),
                  ),

                  // ⚙️ 設定相關選項
                  _buildDrawerHeader('⚙️ 設定'),
                  _buildDrawerItem(
                    icon: Icons.notifications_outlined,
                    title: '通知設定',
                    subtitle: '管理提醒通知',
                    color: AppColors.accent3,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 側邊欄分組標題
  Widget _buildDrawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 🎨 側邊欄選項項目 - 莫蘭迪風格
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isCoach ? AppColors.coach : AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,  // 🆕 v4.0：添加 GlobalKey
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      drawer: _buildDrawer(),
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
          
          // 🆕 v4.0：浮動選單按鈕（只在首頁顯示）
          if (_currentIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: _buildMenuButton(),
            ),
          
          // 底部導航
          ModernBottomNavigation(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            onCenterButtonPressed: _onCenterButtonPressed,
            isCoach: widget.isCoach,
          ),
        ],
      ),
    );
  }
  
  // 🆕 v4.0：浮動選單按鈕
  Widget _buildMenuButton() {
    return GestureDetector(
      onTap: _openDrawer,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.menu,
            color: widget.isCoach ? AppColors.coach : AppColors.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ==================== 頁面內容 (保持原有邏輯,優化視覺) ====================

  Widget _buildHomePage() {
    if (widget.customHomePage != null) {
      return widget.customHomePage!;
    }
    
    // 預設主頁 (如果沒有自訂)
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            children: [
              // 🔥 頂部歡迎卡片
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: widget.isCoach 
                      ? AppColors.secondaryGradient
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.emphasized,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '嗨,$userName!',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.isCoach 
                          ? '今天也要好好指導學員們！' 
                          : '今天也要認真訓練！',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 內容區域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isCoach ? '近期活動' : '訓練進度',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppShadows.medium,
                      ),
                      child: Text(
                        widget.isCoach 
                            ? '您的學員們本週總共完成了 45 次訓練,表現優秀！'
                            : '本週已完成 5 次訓練,繼續保持！',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondPage() {
    if (widget.isCoach) {
      return const StudentManagementPage();
    } else {
      return const StudentCoachManagementPage();
    }
  }

  Widget _buildChatPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '聊天',
                style: AppTextStyles.h2.copyWith(
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
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isCoach ? AppColors.coach : AppColors.primary,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '載入聊天時發生錯誤',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '尚無聊天記錄',
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    List<QueryDocumentSnapshot> chatRooms = snapshot.data!.docs.toList();
                    chatRooms.sort((a, b) {
                      var aData = a.data() as Map<String, dynamic>;
                      var bData = b.data() as Map<String, dynamic>;
                      var aTime = aData['lastMessageTime'] as Timestamp?;
                      var bTime = bData['lastMessageTime'] as Timestamp?;
                      
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      
                      return bTime.compareTo(aTime);
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
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppShadows.medium,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: otherUserIsCoach 
                                        ? AppColors.secondaryGradient
                                        : AppColors.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: AppShadows.small,
                                  ),
                                  child: Center(
                                    child: Text(
                                      otherUserName.isNotEmpty 
                                          ? otherUserName[0].toUpperCase() 
                                          : '?',
                                      style: AppTextStyles.h3.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        otherUserName,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: otherUserIsCoach 
                                            ? AppColors.coach.withValues(alpha: 0.15)
                                            : AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        otherUserIsCoach ? '教練' : '學員',
                                        style: AppTextStyles.caption.copyWith(
                                          color: otherUserIsCoach ? AppColors.coach : AppColors.primary,
                                          fontWeight: FontWeight.bold,
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
                                        Text(
                                          '我：',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          lastMessage.isNotEmpty 
                                              ? lastMessage 
                                              : '尚無訊息',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailPage(
                                        chatId: chatRoomDoc.id,
                                        chatName: otherUserName,
                                        lastMessage: lastMessage.isNotEmpty ? lastMessage : '開始對話...',
                                        avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUserName)}&background=${otherUserIsCoach ? '22C55E' : '3B82F6'}&color=fff',
                                        isOnline: true,
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
      ),
    );
  }

  Widget _buildProfilePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 110, left: 24, right: 24, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '個人中心',
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // 🔥 用戶資訊卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: widget.isCoach 
                      ? AppColors.secondaryGradient
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.emphasized,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.medium,
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: AppTextStyles.h2.copyWith(
                            color: widget.isCoach ? AppColors.coach : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userEmail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.isCoach ? '教練' : '學員',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
              
              // 🔥 選項列表
              Expanded(
                child: Column(
                  children: [
                    _buildProfileOption(
                      icon: Icons.edit_outlined,
                      title: '編輯個人資料',
                      color: AppColors.primary,
                      onTap: () {
                        if (widget.isCoach) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CoachEditPage(),
                            ),
                          ).then((_) {
                            _initializeUserData();
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TraineeEditPage(),
                            ),
                          ).then((_) {
                            _initializeUserData();
                          });
                        }
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.settings_outlined,
                      title: '應用程式設定',
                      color: AppColors.textSecondary,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('應用程式設定功能 (開發中)'),
                            backgroundColor: AppColors.info,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.restaurant_menu,
                      title: '初始化食物資料庫',
                      color: AppColors.warning,
                      onTap: () {
                        _initializeDatabase();
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.auto_awesome,
                      title: '🤖 AI 食物辨識測試',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AIFoodTestPage()),
                        );
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.logout_outlined,
                      title: '登出',
                      color: AppColors.error,
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
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.medium,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? color : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSignOut() async {
    bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              const Text('確認登出'),
            ],
          ),
          content: Text(
            '您確定要登出嗎？\n登出後需要重新登入才能使用。',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            SnackBar(
              content: Text('登出失敗: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _initializeDatabase() async {
    bool? shouldInit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.warning),
              const SizedBox(width: 12),
              const Text('初始化食物資料庫'),
            ],
          ),
          content: Text(
            '這將會在 Firestore 中建立基礎食物資料庫。\n\n'
            '如果資料庫已存在,將不會重複建立。\n\n'
            '確定要執行嗎？',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    if (shouldInit != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.xLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
              ),
              const SizedBox(height: 20),
              Text(
                '正在初始化資料庫...',
                style: AppTextStyles.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      FoodDatabaseService foodService = FoodDatabaseService();
      await foodService.initializeFoodDatabase();
      
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('食物資料庫初始化成功！'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化失敗: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('初始化食物資料庫失敗: $e');
      }
    }
  }
}