import 'package:flutter/material.dart';

class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onCenterButtonPressed;
  final bool isCoach; // 區分教練和學員

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onCenterButtonPressed,
    this.isCoach = false,
  });

  @override
  Widget build(BuildContext context) {
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
                // 首頁
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  index: 0,
                  isActive: currentIndex == 0,
                ),
                
                // 第二個按鈕（教練：學員管理，學員：進度）
                _buildNavItem(
                  icon: isCoach ? Icons.group_outlined : Icons.trending_up_outlined,
                  activeIcon: isCoach ? Icons.group_rounded : Icons.trending_up_rounded,
                  index: 1,
                  isActive: currentIndex == 1,
                ),
                
                // 中央空間（為突出按鈕預留）
                const SizedBox(width: 60),
                
                // 第三個按鈕（聊天）
                _buildNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  index: 2,
                  isActive: currentIndex == 2,
                ),
                
                // 個人頁面
                _buildNavItem(
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
              onTap: onCenterButtonPressed,
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

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
    required bool isActive,
  }) {
    final Color activeColor = isCoach ? Colors.green : const Color(0xFF3B82F6);
    const Color inactiveColor = Colors.grey;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeColor : inactiveColor,
                size: 26,
              ),
              const SizedBox(height: 4),
              // 活動狀態指示點
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