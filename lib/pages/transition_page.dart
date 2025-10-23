import 'package:flutter/material.dart';
import 'dart:async'; // 引入計時器功能
import '../main.dart'; // 引入 main.dart 以使用 AuthWrapper

class TransitionPage extends StatefulWidget {
  const TransitionPage({super.key});

  @override
  State<TransitionPage> createState() => _TransitionPageState();
}

class _TransitionPageState extends State<TransitionPage> {
  @override
  void initState() {
    super.initState();

    // 🔥 關鍵修正：
    // 上一個「圓形展開」動畫的持續時間是 1000 毫秒。
    // 我們在這裡設定一個同樣長度的計時器，確保該動畫完全播放完畢。
    Timer(const Duration(milliseconds: 1000), () {
      // 檢查頁面是否還在畫面上
      if (mounted) {
        // 現在，視覺轉場已經完成，我們可以安全地載入重量級的 AuthWrapper。
        // 我們使用一個簡單的「淡入」效果來讓登入頁的出現更柔和。
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500), // 淡入動畫持續 0.5 秒
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 這個頁面是一個視覺上的「緩衝墊」。
    // 「圓形展開」動畫揭露的就是這個空白的白色頁面。
    // 它的背景色與啟動動畫頁相同，確保視覺的連續性。
    return const Scaffold(
      backgroundColor: Colors.white, // 與 SplashScreen 背景色保持一致
      body: Center(), // 內容完全空白
    );
  }
}

