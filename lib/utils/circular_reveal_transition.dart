import 'package:flutter/material.dart';
import 'dart:math';

class CircularRevealTransitionRoute extends PageRouteBuilder {
  final Widget page;
  final Offset centerOffset; // 動畫開始的中心點

  CircularRevealTransitionRoute({
    required this.page,
    this.centerOffset = Offset.zero, // 預設從左上角開始
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionDuration: const Duration(milliseconds: 1000), // 控制動畫速度 (1秒)
          reverseTransitionDuration: const Duration(milliseconds: 1000),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // 使用 CurvedAnimation 讓動畫有 "easeOut" 的效果，更自然
            final easeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );

            return ClipPath(
              clipper: _CircularRevealClipper(
                fraction: easeAnimation.value,
                centerOffset: centerOffset,
              ),
              child: child,
            );
          },
        );
}

// 這個 Clipper 負責畫出一個不斷變大的圓形來裁切畫面
class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset centerOffset;

  _CircularRevealClipper({required this.fraction, required this.centerOffset});

  @override
  Path getClip(Size size) {
    final center = centerOffset == Offset.zero
        ? Offset(size.width / 2, size.height / 2)
        : centerOffset;
    
    // 計算圓形半徑，確保能完整覆蓋螢幕對角線
    final radius = sqrt(pow(size.width, 2) + pow(size.height, 2)) * fraction;

    // 建立一個以 center 為圓心，radius 為半徑的圓形路徑
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    // 每次動畫值改變時都要重新裁切
    return true;
  }
}

