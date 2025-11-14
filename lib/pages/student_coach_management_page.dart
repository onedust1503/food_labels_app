// lib/pages/student_coach_management_page.dart
// ✅ 整合新設計系統的教練管理頁面

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../services/pair_request_service.dart';
import 'chat_detail_page.dart';
import 'coach_search_page.dart';

// ✅ 導入設計系統
import '../theme/app_theme.dart';

class StudentCoachManagementPage extends StatefulWidget {
  const StudentCoachManagementPage({super.key});

  @override
  State<StudentCoachManagementPage> createState() => _StudentCoachManagementPageState();
}

class _StudentCoachManagementPageState extends State<StudentCoachManagementPage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final PairRequestService _pairRequestService = PairRequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  List<DocumentSnapshot> _coaches = [];
  bool _isLoading = true;
  
  // ✅ 新增：當前選中的 Tab 索引
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _loadCoaches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoaches() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final coaches = await _userService.getStudentCoaches(currentUserId);
      
      setState(() {
        _coaches = coaches;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入教練列表錯誤: $e');
      }
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入教練列表失敗：$e');
    }
  }

  Future<void> _contactCoach(DocumentSnapshot coachDoc) async {
    try {
      final coachData = coachDoc.data() as Map<String, dynamic>;
      final coachId = coachDoc.id;
      final coachName = coachData['displayName'] ?? '教練';
      
      // ✅ 修正：使用正確的方法名稱和參數
      final chatRoomId = await _chatService.createOrGetChatRoom(coachId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: coachName,
              lastMessage: '開始對話...',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(coachName)}&background=22C55E&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('開啟聊天室失敗：$e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      );
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '未知時間';
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('教練管理', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadCoaches,
          ),
        ],
        // ✅ 移除原有的 bottom TabBar
      ),
      body: Column(
        children: [
          // ✅ 新增：自定義 Chip Tabs
          _buildChipTabs(),
          
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCoachesList(),
                _buildRequestsList(),
                const CoachSearchPage(isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 新增：Chip 風格的 Tabs（跟主頁一致）
  Widget _buildChipTabs() {
    final tabs = ['我的教練', '配對請求', '尋找教練'];
    
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingMedium,
        vertical: AppSizes.paddingSmall,
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: AppSizes.gapSmall),
            child: InkWell(
              onTap: () {
                _tabController.animateTo(index);
              },
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingLarge,
                  vertical: AppSizes.paddingSmall,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary.withOpacity(0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                ),
                child: Text(
                  tabs[index],
                  style: AppTextStyles.label.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Tab 1: 我的教練列表
  Widget _buildCoachesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_coaches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: '尚未配對教練',
        subtitle: '前往「尋找教練」頁面發送配對請求',
        actionLabel: '尋找教練',
        onAction: () {
          _tabController.animateTo(2);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoaches,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        itemCount: _coaches.length,
        itemBuilder: (context, index) {
          return _buildCoachCard(_coaches[index]);
        },
      ),
    );
  }

  // Tab 2: 配對請求列表
  Widget _buildRequestsList() {
    return StreamBuilder<List<PairRequest>>(
      stream: _pairRequestService.getSentRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: '載入失敗',
            subtitle: '${snapshot.error}',
            actionLabel: '重試',
            onAction: () => setState(() {}),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inbox_outlined,
            title: '沒有配對請求',
            subtitle: '您還沒有發送任何配對請求',
            actionLabel: '尋找教練',
            onAction: () {
              _tabController.animateTo(2);
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final request = snapshot.data![index];
              return _buildRequestCard(request);
            },
          ),
        );
      },
    );
  }

  // ✅ 統一的空狀態組件
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.gapLarge),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.gapXLarge),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.search),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingXLarge,
                vertical: AppSizes.paddingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 配對請求卡片（使用新設計）
  Widget _buildRequestCard(PairRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (request.status) {
      case PairRequestStatus.pending:
        statusColor = AppColors.warning;
        statusText = '待處理';
        statusIcon = Icons.schedule;
        break;
      case PairRequestStatus.accepted:
        statusColor = AppColors.success;
        statusText = '已接受';
        statusIcon = Icons.check_circle;
        break;
      case PairRequestStatus.rejected:
        statusColor = AppColors.error;
        statusText = '已拒絕';
        statusIcon = Icons.cancel;
        break;
      case PairRequestStatus.cancelled:
        statusColor = AppColors.textTertiary;
        statusText = '已取消';
        statusIcon = Icons.block;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.gapMedium),
      decoration: BoxDecoration(
        color: request.status == PairRequestStatus.accepted
            ? AppColors.success.withOpacity(0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        boxShadow: AppShadows.medium,
      ),
      child: Padding(
        padding: AppSizes.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部：教練資訊 + 狀態標籤
            Row(
              children: [
                // 頭像
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.small,
                  ),
                  child: Center(
                    child: Text(
                      request.toUserName.isNotEmpty 
                          ? request.toUserName[0].toUpperCase()
                          : 'C',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.gapMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.toUserName,
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(request.createdAt),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ 狀態標籤（使用圓角容器）
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingMedium,
                    vertical: AppSizes.paddingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.gapMedium),
            
            // 訊息內容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              child: Text(
                request.message,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 教練卡片（使用新設計）
  Widget _buildCoachCard(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '';
    // ✅ 修復: 安全讀取 experience，支援 int 和 String
    final experienceRaw = coachData['experience'];
    final String experience = experienceRaw is String 
        ? experienceRaw 
        : (experienceRaw is int ? '${experienceRaw}年教學經驗' : '');
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.gapMedium),
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient.scale(0.3), // 淡綠色漸層
        borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        boxShadow: AppShadows.medium,
      ),
      child: Padding(
        padding: AppSizes.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上半部：教練資訊
            Row(
              children: [
                // 頭像
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.small,
                  ),
                  child: Center(
                    child: Text(
                      coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.gapMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coachName, style: AppTextStyles.h4),
                      const SizedBox(height: 4),
                      
                      // ✅ 認證標籤
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        ),
                        child: Text(
                          '認證教練',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      if (experience.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          experience,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            // 專長標籤
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: AppSizes.gapMedium),
              Wrap(
                spacing: AppSizes.gapSmall,
                runSpacing: AppSizes.gapSmall,
                children: specialties.take(3).map((specialty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                    child: Text(
                      specialty,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // 簡介
            if (coachBio.isNotEmpty) ...[
              const SizedBox(height: AppSizes.gapMedium),
              Text(
                coachBio,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: AppSizes.gapMedium),
            
            // 下半部：按鈕列
            Row(
              children: [
                // 查看詳情按鈕（Outline）
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showCoachDetailDialog(coachDoc);
                    },
                    icon: Icon(Icons.info_outline, size: AppSizes.iconSmall),
                    label: const Text('詳細'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.secondary, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.paddingSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.gapMedium),
                
                // 聊天按鈕（Filled）
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _contactCoach(coachDoc);
                    },
                    icon: Icon(Icons.chat_bubble_outline, size: AppSizes.iconSmall),
                    label: const Text('聊天'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.paddingSmall,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 教練詳情對話框
  void _showCoachDetailDialog(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '暫無簡介';
    // ✅ 修復: 安全讀取 experience，支援 int 和 String  
    final experienceRaw = coachData['experience'];
    final String experience = experienceRaw is String 
        ? experienceRaw 
        : (experienceRaw is int ? '${experienceRaw}年教學經驗' : '');
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    final certifications = List<String>.from(coachData['certifications'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        ),
        title: Text(coachName, style: AppTextStyles.h3),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (experience.isNotEmpty) ...[
                Text('經驗：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(experience, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSizes.gapMedium),
              ],
              
              Text('簡介：', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(coachBio, style: AppTextStyles.bodyMedium),
              
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: AppSizes.gapMedium),
                Text('專長：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSizes.gapSmall,
                  runSpacing: AppSizes.gapSmall,
                  children: specialties.map((s) => Chip(
                    label: Text(s, style: AppTextStyles.caption),
                    backgroundColor: AppColors.accent2.withOpacity(0.2),
                  )).toList(),
                ),
              ],
              
              if (certifications.isNotEmpty) ...[
                const SizedBox(height: AppSizes.gapMedium),
                Text('證照：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                ...certifications.map((cert) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(cert, style: AppTextStyles.bodySmall),
                      ),
                    ],
                  ),
                )),
              ],
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
              _contactCoach(coachDoc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('開始聊天'),
          ),
        ],
      ),
    );
  }
}