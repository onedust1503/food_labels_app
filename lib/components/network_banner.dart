// lib/components/network_banner.dart
// 🎨 方案 A: 浮動卡片式 - Morandi 配色 + Soft UI 風格

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';

class NetworkBanner extends StatefulWidget {
  final Widget child;

  const NetworkBanner({
    super.key,
    required this.child,
  });

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // 🎨 Morandi 配色
  static const Color _offlineColor = Color(0xFFD4A574);      // 莫蘭迪橘
  static const Color _offlineColorDark = Color(0xFFC4956A);  // 深一點的橘
  static const Color _onlineColor = Color(0xFF7BA388);       // 莫蘭迪綠
  static const Color _onlineColorDark = Color(0xFF6B9378);   // 深一點的綠

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // 從下方滑入
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // 淡入
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // 輕微縮放效果
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, _) {
        final shouldShowBanner = !networkProvider.isOnline || networkProvider.showRecoveryBanner;
        
        if (shouldShowBanner) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }

        return Stack(
          children: [
            // 主要內容
            widget.child,
            
            // 浮動卡片橫幅
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                if (_animationController.value == 0 && !shouldShowBanner) {
                  return const SizedBox.shrink();
                }
                
                return Positioned(
                  bottom: 80, // 在底部導航欄上方
                  left: 16,
                  right: 16,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildFloatingCard(networkProvider),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingCard(NetworkProvider networkProvider) {
    final isRecovery = networkProvider.showRecoveryBanner && networkProvider.isOnline;
    
    // 根據狀態選擇顏色
    final primaryColor = isRecovery ? _onlineColor : _offlineColor;
    final secondaryColor = isRecovery ? _onlineColorDark : _offlineColorDark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // 主陰影
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          // 柔和的底部陰影
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRecovery 
              ? () => networkProvider.hideRecoveryBanner()
              : () => networkProvider.checkConnectivity(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // 圖標容器
                _buildIconContainer(isRecovery),
                
                const SizedBox(width: 14),
                
                // 文字內容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRecovery ? '網路已恢復' : '網路連線中斷',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRecovery ? '所有功能正常運作' : '部分功能可能無法使用',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 按鈕
                _buildActionButton(isRecovery, networkProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(bool isRecovery) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: isRecovery
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 26,
                    )
                  : _buildPulsingIcon(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulsingIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
            size: 26,
          ),
        );
      },
      onEnd: () {
        // 重複動畫
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildActionButton(bool isRecovery, NetworkProvider networkProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRecovery 
              ? () => networkProvider.hideRecoveryBanner()
              : () async {
                  await networkProvider.checkConnectivity();
                },
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isRecovery ? 14 : 18,
              vertical: 10,
            ),
            child: isRecovery
                ? const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  )
                : const Text(
                    '重試',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}