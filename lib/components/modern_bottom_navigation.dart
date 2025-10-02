import 'package:flutter/material.dart';
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
    print('🎨 ModernBottomNavigation 渲染 - currentIndex: $currentIndex');
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 底部導航背景
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  index: 0,
                  isActive: currentIndex == 0,
                ),
                _buildNavItem(
                  context: context,
                  icon: isCoach ? Icons.group_outlined : Icons.trending_up_outlined,
                  activeIcon: isCoach ? Icons.group_rounded : Icons.trending_up_rounded,
                  index: 1,
                  isActive: currentIndex == 1,
                ),
                const SizedBox(width: 60),
                _buildChatNavItem(
                  context: context,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  index: 2,
                  isActive: currentIndex == 2,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  index: 3,
                  isActive: currentIndex == 3,
                ),
              ],
            ),
          ),
          
          // 中央突出按鈕
          Positioned(
            bottom: 10,
            child: GestureDetector(
              onTap: () {
                print('🔥 中央按鈕被點擊');
                onCenterButtonPressed?.call();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCoach 
                        ? [Colors.green[400]!, Colors.green[600]!]
                        : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isCoach ? Colors.green : Colors.blue).withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required int index,
    required bool isActive,
  }) {
    final ChatService chatService = ChatService();
    final Color activeColor = isCoach ? Colors.green : const Color(0xFF3B82F6);
    const Color inactiveColor = Colors.grey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          print('🔥 聊天按鈕被點擊 (index: $index)');
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: StreamBuilder<int>(
            stream: chatService.getTotalUnreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? activeIcon : icon,
                        color: isActive ? activeColor : inactiveColor,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 6 : 0,
                        height: isActive ? 6 : 0,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 10,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required int index,
    required bool isActive,
  }) {
    final Color activeColor = isCoach ? Colors.green : const Color(0xFF3B82F6);
    const Color inactiveColor = Colors.grey;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          print('🔥 導航按鈕被點擊 (index: $index)');
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeColor : inactiveColor,
                size: 26,
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 6 : 0,
                height: isActive ? 6 : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}