// lib/pages/coach/trainee_detail_page.dart
// 🎯 學員詳細資料主頁面 v2.0
// ✅ 整合 5 個分頁 + 莫蘭迪設計風格
// ✅ 新增計畫進度分頁

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../chat_detail_page.dart';
import 'trainee_basic_info_tab.dart';
import 'trainee_nutrition_tab.dart';
import 'trainee_workout_tab.dart';
import 'trainee_plans_tab.dart';

class TraineeDetailPage extends StatefulWidget {
  final String traineeId;
  final String traineeName;

  const TraineeDetailPage({
    Key? key,
    required this.traineeId,
    required this.traineeName,
  }) : super(key: key);

  @override
  State<TraineeDetailPage> createState() => _TraineeDetailPageState();
}

class _TraineeDetailPageState extends State<TraineeDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    try {
      final chatRoomId = await _chatService.createOrGetChatRoom(widget.traineeId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: widget.traineeName,
              lastMessage: '開始諮詢...',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.traineeName)}&background=22C55E&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('開啟聊天失敗：$e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 🎨 自訂 AppBar
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderBackground(),
              ),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.small,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // 🔥 聊天按鈕
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.small,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.coach,
                        size: 20,
                      ),
                    ),
                    onPressed: _startChat,
                    tooltip: '發送訊息',
                  ),
                ),
                // 🔥 更多選項
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.small,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      // TODO: 處理選項
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'create_plan',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: AppColors.coach),
                            SizedBox(width: 12),
                            Text('創建計畫'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, color: AppColors.primary),
                            SizedBox(width: 12),
                            Text('匯出報告'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.coach,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.coach,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: AppTextStyles.label,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.person_outline, size: 20),
                        text: '基本資料',
                      ),
                      Tab(
                        icon: Icon(Icons.assignment_outlined, size: 20),
                        text: '計畫進度',
                      ),
                      Tab(
                        icon: Icon(Icons.fitness_center, size: 20),
                        text: '訓練日誌',
                      ),
                      Tab(
                        icon: Icon(Icons.restaurant_outlined, size: 20),
                        text: '飲食日誌',
                      ),
                      Tab(
                        icon: Icon(Icons.show_chart, size: 20),
                        text: '進度圖表',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // 1️⃣ 基本資料分頁
            TraineeBasicInfoTab(traineeId: widget.traineeId),
            
            // 2️⃣ 🔥 新增：計畫進度分頁
            TraineePlansTab(traineeId: widget.traineeId),
            
            // 3️⃣ 訓練日誌分頁
            TraineeWorkoutTab(traineeId: widget.traineeId),
            
            // 4️⃣ 飲食日誌分頁
            TraineeNutritionTab(traineeId: widget.traineeId),
            
            // 5️⃣ 進度圖表分頁（佔位符）
            _buildProgressTabPlaceholder(),
          ],
        ),
      ),
    );
  }

  // 🎨 頂部背景
  Widget _buildHeaderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Row(
            children: [
              // 🔥 大頭像
              Hero(
                tag: 'avatar_${widget.traineeId}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.medium,
                  ),
                  child: Center(
                    child: Text(
                      widget.traineeName.isNotEmpty
                          ? widget.traineeName[0].toUpperCase()
                          : 'S',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.coach,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // 🔥 名稱與標籤
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.traineeName,
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '學員',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

  // 📊 進度圖表佔位符
  Widget _buildProgressTabPlaceholder() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.show_chart,
                size: 64,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '進度圖表功能',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '即將推出',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 32),
            // 🔥 功能預告
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.small,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '預計功能',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturePreviewItem(
                    Icons.trending_up,
                    '訓練進度趨勢圖',
                    AppColors.success,
                  ),
                  _buildFeaturePreviewItem(
                    Icons.monitor_weight_outlined,
                    '體重變化曲線',
                    AppColors.primary,
                  ),
                  _buildFeaturePreviewItem(
                    Icons.local_fire_department,
                    '熱量消耗統計',
                    AppColors.warning,
                  ),
                  _buildFeaturePreviewItem(
                    Icons.pie_chart_outline,
                    '營養素分布圖',
                    AppColors.accent3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePreviewItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}