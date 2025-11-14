// lib/components/modern_bottom_navigation.dart
// 🎨 修正版 - 解決底色、動畫、鍵盤問題

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';

class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onCenterButtonPressed;
  final bool isCoach;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterButtonPressed,
    this.isCoach = false,
  });

  @override
  Widget build(BuildContext context) {
    // 🎯 關鍵修正：使用 MediaQuery.viewInsets 來判斷鍵盤是否彈出
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      // 🎯 鍵盤彈出時隱藏導航欄（移到螢幕下方）
      bottom: isKeyboardVisible ? -100 : 20,
      left: 20,
      right: 20,
      child: IgnorePointer(
        ignoring: isKeyboardVisible, // 鍵盤出現時禁用點擊
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isKeyboardVisible ? 0.0 : 1.0,
          child: _buildNavigationBar(context),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      // 🎯 修正：添加半透明背景
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95), // 半透明白色背景
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.large,
        // 🎯 可選：添加模糊效果（需要 backdrop_filter）
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎯 Home 按鈕（活動時顯示文字）
          _buildHomeButton(
            context: context,
            isActive: currentIndex == 0,
          ),
          
          // 🎯 第二個按鈕
          _buildIconButton(
            context: context,
            icon: isCoach ? Icons.group_rounded : Icons.trending_up_rounded,
            index: 1,
            isActive: currentIndex == 1,
          ),
          
          // 🎯 中央加號按鈕
          _buildAddButton(context: context),
          
          // 🎯 聊天按鈕（帶未讀徽章）
          _buildChatButton(
            context: context,
            index: 2,
            isActive: currentIndex == 2,
          ),
          
          // 🎯 個人按鈕
          _buildIconButton(
            context: context,
            icon: Icons.person_rounded,
            index: 3,
            isActive: currentIndex == 3,
          ),
        ],
      ),
    );
  }

  // 🏠 Home 按鈕 - 優化動畫流暢度
  Widget _buildHomeButton({
    required BuildContext context,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => onTap(0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250), // 優化動畫時長
        curve: Curves.easeInOutCubic, // 更流暢的曲線
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.textPrimary
              : AppColors.surface, // 修正：未激活時也有背景
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive ? AppShadows.medium : AppShadows.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.home_rounded : Icons.home_outlined,
              color: isActive ? Colors.white : AppColors.textSecondary,
              size: 24,
            ),
            // 🎯 優化文字展開動畫
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              child: isActive
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          'Home',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // 🔘 一般 Icon 按鈕 - 修正底色
  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          // 🎯 修正：未激活時也顯示白色背景
          color: isActive 
              ? (isCoach ? AppColors.coach : AppColors.primary).withValues(alpha: 0.15)
              : AppColors.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: AppShadows.small,
        ),
        child: Icon(
          icon,
          color: isActive 
              ? (isCoach ? AppColors.coach : AppColors.primary)
              : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }

  // ➕ 中央加號按鈕
  Widget _buildAddButton({required BuildContext context}) {
    return GestureDetector(
      onTap: () {
        print('🔥 中央按鈕被點擊');
        onCenterButtonPressed?.call();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: isCoach 
              ? AppColors.secondaryGradient 
              : AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: AppShadows.coloredShadow(
            isCoach ? AppColors.coach : AppColors.primary,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // 💬 聊天按鈕 - 帶未讀徽章，修正底色
  Widget _buildChatButton({
    required BuildContext context,
    required int index,
    required bool isActive,
  }) {
    final ChatService chatService = ChatService();

    return GestureDetector(
      onTap: () => onTap(index),
      child: StreamBuilder<int>(
        stream: chatService.getTotalUnreadCountStream(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // 🎯 修正：未激活時也顯示白色背景
                  color: isActive 
                      ? (isCoach ? AppColors.coach : AppColors.primary).withValues(alpha: 0.15)
                      : AppColors.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.small,
                ),
                child: Icon(
                  isActive ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                  color: isActive 
                      ? (isCoach ? AppColors.coach : AppColors.primary)
                      : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              // 未讀徽章
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}